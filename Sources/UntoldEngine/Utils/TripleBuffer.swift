//
//  TripleBuffer.swift
//
//
//  Created by Harold Serrano on 8/20/25.
//

import Foundation
import Metal

public final class TripleBuffer<T> {
    private let device: MTLDevice
    private let inFlight: Int
    private let options: MTLResourceOptions
    private(set) var capacity: Int
    private(set) var buffers: [MTLBuffer]

    public init(device: MTLDevice,
                initialCapacity: Int,
                inFlight: Int = 3,
                options: MTLResourceOptions = .storageModeShared)
    {
        // 1) Compute locals (no `self` yet)
        let cap = max(1, initialCapacity)
        let len = MemoryLayout<T>.stride * cap

        // 2) Initialize stored properties (no closures capturing `self`)
        self.device = device
        self.inFlight = inFlight
        self.options = options
        capacity = cap
        buffers = [] // temp value to satisfy initialization

        // 3) Build the ring using locals (no `self` inside the closure)
        let ring = (0 ..< inFlight).map { _ in
            device.makeBuffer(length: len, options: options)!
        }
        buffers = ring
    }

    /// Grow ring if needed (power-of-two). No shrink.
    public func ensureCapacity(_ needed: Int) {
        guard needed > capacity else { return }
        var newCap = 1
        while newCap < needed {
            newCap <<= 1
        }
        capacity = newCap
        let len = MemoryLayout<T>.stride * newCap
        buffers = (0 ..< inFlight).map { _ in
            device.makeBuffer(length: len, options: options)!
        }
    }

    @inline(__always) private func writeIndex(_ frame: Int) -> Int { frame % inFlight }
    @inline(__always) private func readIndex(_ frame: Int) -> Int { (frame + inFlight - 1) % inFlight }

    @inline(__always) public func bufferForWrite(frame: Int) -> MTLBuffer {
        buffers[writeIndex(frame)]
    }

    @inline(__always) public func bufferForRead(frame: Int) -> MTLBuffer {
        frame == 0 ? buffers[writeIndex(frame)] : buffers[readIndex(frame)]
    }
}

// CPU Triple-buffer for plain Swift arrays (non MTLBuffers)
public final class TripleCPUBuffer<T> {
    private let inFlight: Int
    private var slots: [[T]]

    public init(inFlight: Int = 3, initialCapacity: Int = 0) {
        self.inFlight = max(1, inFlight)
        self.slots = (0..<self.inFlight).map { _ in [] }
        if initialCapacity > 0 {
            for i in 0..<self.inFlight { slots[i].reserveCapacity(initialCapacity) }
        }
    }

    @inline(__always) private func writeIndex(_ frame: Int) -> Int { frame % inFlight }
    @inline(__always) private func readIndex (_ frame: Int) -> Int { (frame + inFlight - 1) % inFlight }

    /// Publish the next frame's data into the write slot.
    public func setWrite(frame: Int, with data: [T]) {
        slots[writeIndex(frame)] = data
    }

    /// Get an immutable snapshot for rendering.
    public func snapshotForRead(frame: Int) -> [T] {
        slots[readIndex(frame)]
    }

    /// Optional: pre-reserve capacity on all slots to avoid reallocs.
    public func ensureCapacity(_ needed: Int) {
        for i in 0..<inFlight { if slots[i].capacity < needed { slots[i].reserveCapacity(needed) } }
    }
}

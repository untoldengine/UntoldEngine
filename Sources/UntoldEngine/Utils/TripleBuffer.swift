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

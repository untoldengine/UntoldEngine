//
//  CommandBufferMetricsCollector.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import Metal

final class CommandBufferMetricsCollector {
    private let capacity: Int
    private var samples: [Double]
    private var writeIndex: Int
    private var validSampleCount: Int
    private let lock = NSLock()

    init(capacity: Int = 2000) {
        self.capacity = capacity
        samples = [Double](repeating: 0.0, count: capacity)
        writeIndex = 0
        validSampleCount = 0
    }

    func record(_ durationMs: Double) {
        lock.lock()
        defer { lock.unlock() }

        samples[writeIndex] = durationMs
        writeIndex = (writeIndex + 1) % capacity
        if validSampleCount < capacity {
            validSampleCount += 1
        }
    }

    func snapshot() -> FrameMetricsSnapshot {
        lock.lock()
        defer { lock.unlock() }

        guard validSampleCount > 0 else {
            return FrameMetricsSnapshot()
        }

        // Copy valid samples
        var validSamples = [Double]()
        validSamples.reserveCapacity(validSampleCount)

        for i in 0 ..< validSampleCount {
            validSamples.append(samples[i])
        }

        // Sort for percentile computation
        validSamples.sort()

        let sum = validSamples.reduce(0.0, +)
        let mean = sum / Double(validSampleCount)
        let min = validSamples.first!
        let max = validSamples.last!

        // Compute percentiles
        let p95Index = Int(Double(validSampleCount - 1) * 0.95)
        let p99Index = Int(Double(validSampleCount - 1) * 0.99)

        let p95 = validSamples[p95Index]
        let p99 = validSamples[p99Index]

        return FrameMetricsSnapshot(
            sampleCount: validSampleCount,
            meanMs: mean,
            p95Ms: p95,
            p99Ms: p99,
            minMs: min,
            maxMs: max
        )
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }

        writeIndex = 0
        validSampleCount = 0
    }

    func attach(to commandBuffer: MTLCommandBuffer, label _: String?) {
        commandBuffer.addCompletedHandler { [weak self] buffer in
            let gpuStart = buffer.gpuStartTime
            let gpuEnd = buffer.gpuEndTime

            // Validate GPU times (can be zero or invalid on some systems)
            guard gpuStart > 0.0, gpuEnd > gpuStart else {
                return
            }

            let durationSeconds = gpuEnd - gpuStart
            let durationMs = durationSeconds * 1000.0

            self?.record(durationMs)
        }
    }
}

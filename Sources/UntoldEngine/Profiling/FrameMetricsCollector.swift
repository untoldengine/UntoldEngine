//
//  FrameMetricsCollector.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

final class FrameMetricsCollector {
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
}

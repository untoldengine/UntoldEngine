//
//  MetricsDebugLogger.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import QuartzCore

#if DEBUG
    public final class MetricsDebugLogger {
        private var lastLogTime: CFTimeInterval = 0.0
        private let logInterval: CFTimeInterval = 1.0

        public init() {}

        public func logIfNeeded() {
            let currentTime = CACurrentMediaTime()
            guard currentTime - lastLogTime >= logInterval else { return }
            lastLogTime = currentTime

            let snapshot = EngineProfiler.shared.snapshot()

            print("=== Engine Metrics ===")
            print("CPU Frame:")
            print("  Samples: \(snapshot.cpuFrame.sampleCount)")
            print("  Mean: \(String(format: "%.2f", snapshot.cpuFrame.meanMs)) ms")
            print("  P95: \(String(format: "%.2f", snapshot.cpuFrame.p95Ms)) ms")
            print("  P99: \(String(format: "%.2f", snapshot.cpuFrame.p99Ms)) ms")
            print("  Min: \(String(format: "%.2f", snapshot.cpuFrame.minMs)) ms")
            print("  Max: \(String(format: "%.2f", snapshot.cpuFrame.maxMs)) ms")

            print("GPU Command Buffer:")
            print("  Samples: \(snapshot.gpuCommandBuffer.sampleCount)")
            print("  Mean: \(String(format: "%.2f", snapshot.gpuCommandBuffer.meanMs)) ms")
            print("  P95: \(String(format: "%.2f", snapshot.gpuCommandBuffer.p95Ms)) ms")
            print("  P99: \(String(format: "%.2f", snapshot.gpuCommandBuffer.p99Ms)) ms")
            print("  Min: \(String(format: "%.2f", snapshot.gpuCommandBuffer.minMs)) ms")
            print("  Max: \(String(format: "%.2f", snapshot.gpuCommandBuffer.maxMs)) ms")
            print("======================")
        }
    }
#endif

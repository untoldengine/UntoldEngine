//
//  EngineProfiler.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal
import QuartzCore

public final class EngineProfiler: @unchecked Sendable {
    public static let shared = EngineProfiler()

    private let frameMetrics = FrameMetricsCollector()
    private let gpuMetrics = CommandBufferMetricsCollector()
    private let signposts = EngineSignposts()
    private let lock = NSLock()

    private var frameStartTime: CFTimeInterval = 0.0
    private var isEnabled: Bool {
        // Check global flag or environment variable
        if enableEngineMetrics {
            return true
        }
        if let envValue = ProcessInfo.processInfo.environment["UNTOLD_METRICS"], envValue == "1" {
            return true
        }
        return false
    }

    private init() {}

    public func beginFrame() {
        guard isEnabled else { return }

        lock.lock()
        frameStartTime = CACurrentMediaTime()
        lock.unlock()
        signposts.beginScope(.frame)
    }

    public func endFrame() {
        guard isEnabled else { return }

        let frameEndTime = CACurrentMediaTime()
        lock.lock()
        let start = frameStartTime
        lock.unlock()
        let durationSeconds = frameEndTime - start
        let durationMs = durationSeconds * 1000.0

        frameMetrics.record(durationMs)
        signposts.endScope(.frame)
    }

    public func beginScope(_ scope: ProfileScope) {
        guard isEnabled else { return }
        signposts.beginScope(scope)
    }

    public func endScope(_ scope: ProfileScope) {
        guard isEnabled else { return }
        signposts.endScope(scope)
    }

    public func attach(to commandBuffer: MTLCommandBuffer, label: String? = nil) {
        guard isEnabled else { return }
        gpuMetrics.attach(to: commandBuffer, label: label)
    }

    public func snapshot() -> MetricsSnapshot {
        let cpuSnapshot = frameMetrics.snapshot()
        let gpuSnapshot = gpuMetrics.snapshot()
        return MetricsSnapshot(cpuFrame: cpuSnapshot, gpuCommandBuffer: gpuSnapshot)
    }

    public func reset() {
        frameMetrics.reset()
        gpuMetrics.reset()
    }
}

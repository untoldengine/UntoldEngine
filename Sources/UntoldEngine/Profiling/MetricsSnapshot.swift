//
//  MetricsSnapshot.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation

public struct FrameMetricsSnapshot {
    public let sampleCount: Int
    public let meanMs: Double
    public let p95Ms: Double
    public let p99Ms: Double
    public let minMs: Double
    public let maxMs: Double

    public init(
        sampleCount: Int = 0,
        meanMs: Double = 0.0,
        p95Ms: Double = 0.0,
        p99Ms: Double = 0.0,
        minMs: Double = 0.0,
        maxMs: Double = 0.0
    ) {
        self.sampleCount = sampleCount
        self.meanMs = meanMs
        self.p95Ms = p95Ms
        self.p99Ms = p99Ms
        self.minMs = minMs
        self.maxMs = maxMs
    }
}

public struct MetricsSnapshot {
    public let cpuFrame: FrameMetricsSnapshot
    public let gpuCommandBuffer: FrameMetricsSnapshot

    public init(cpuFrame: FrameMetricsSnapshot, gpuCommandBuffer: FrameMetricsSnapshot) {
        self.cpuFrame = cpuFrame
        self.gpuCommandBuffer = gpuCommandBuffer
    }
}

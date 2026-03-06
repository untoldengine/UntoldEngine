//
//  MetricsSnapshot.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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

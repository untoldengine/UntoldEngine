//
//  HZBDebugMonitor.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import QuartzCore
import simd

public struct HZBDebugStats {
    public var frustumTestedCount: Int = 0
    public var hzbIsValid: Bool = false
    public var hzbMipCount: Int = 0
    public var selectedMipLevel: Int = 0
    public var selectedMipSize: simd_int2 = .zero

    public var frustumCandidateCount: Int = 0
    public var visibleAfterOcclusionCount: Int = 0
    public var occludedCount: Int = 0
    public var usedHZBThisFrame: Bool = false
    public var optimizedFrustumPath: Bool = false

    public var hzbBuildsThisSecond: Int = 0
    public var hzbCullPassesThisSecond: Int = 0

    public mutating func resetPerSecondCounters() {
        hzbBuildsThisSecond = 0
        hzbCullPassesThisSecond = 0
    }
}

public final class HZBDebugMonitor {
    public static let shared = HZBDebugMonitor()

    public private(set) var stats = HZBDebugStats()
    public var enableLogging: Bool = false

    private var lastResetTime: Double = 0

    private init() {
        lastResetTime = CACurrentMediaTime()
    }

    public func tick() {
        let now = CACurrentMediaTime()
        if now - lastResetTime >= 1.0 {
            if enableLogging {
                Logger.log(message: "[HZB] valid=\(stats.hzbIsValid) mips=\(stats.hzbMipCount) selectedMip=\(stats.selectedMipLevel) selectedSize=\(stats.selectedMipSize.x)x\(stats.selectedMipSize.y) candidates=\(stats.frustumCandidateCount) visible=\(stats.visibleAfterOcclusionCount) occluded=\(stats.occludedCount) usedHZB=\(stats.usedHZBThisFrame) builds/s=\(stats.hzbBuildsThisSecond) cullPasses/s=\(stats.hzbCullPassesThisSecond)")
            }

            stats.resetPerSecondCounters()
            lastResetTime = now
        }
    }

    public func recordBuild(valid: Bool, mipCount: Int, selectedMipLevel: Int, selectedMipSize: simd_int2) {
        stats.hzbIsValid = valid
        stats.hzbMipCount = mipCount
        stats.selectedMipLevel = selectedMipLevel
        stats.selectedMipSize = selectedMipSize
        stats.hzbBuildsThisSecond += 1
    }

    public func recordCull(testedCount: Int, candidateCount: Int, visibleCount: Int, usedHZB: Bool, optimizedPath: Bool) {
        stats.frustumTestedCount = max(0, testedCount)
        stats.frustumCandidateCount = max(0, candidateCount)
        stats.visibleAfterOcclusionCount = max(0, visibleCount)
        stats.occludedCount = max(0, stats.frustumCandidateCount - stats.visibleAfterOcclusionCount)
        stats.usedHZBThisFrame = usedHZB
        stats.optimizedFrustumPath = optimizedPath
        if usedHZB {
            stats.hzbCullPassesThisSecond += 1
        }
    }
}

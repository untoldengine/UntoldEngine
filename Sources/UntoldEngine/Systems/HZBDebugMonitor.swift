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

public final class HZBDebugMonitor: @unchecked Sendable {
    public static let shared = HZBDebugMonitor()

    private let lock = NSLock()
    private var _stats = HZBDebugStats()
    private var _enableLogging: Bool = false
    private var lastResetTime: Double = 0

    public var stats: HZBDebugStats {
        lock.lock()
        let value = _stats
        lock.unlock()
        return value
    }

    public var enableLogging: Bool {
        get {
            lock.lock()
            let value = _enableLogging
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            _enableLogging = newValue
            lock.unlock()
        }
    }

    private init() {
        lastResetTime = CACurrentMediaTime()
    }

    public func tick() {
        var shouldLog = false
        var snapshot = HZBDebugStats()

        lock.lock()
        let now = CACurrentMediaTime()
        if now - lastResetTime >= 1.0 {
            snapshot = _stats
            shouldLog = _enableLogging
            _stats.resetPerSecondCounters()
            lastResetTime = now
        }
        lock.unlock()

        if shouldLog {
            Logger.log(message: "[HZB] valid=\(snapshot.hzbIsValid) mips=\(snapshot.hzbMipCount) selectedMip=\(snapshot.selectedMipLevel) selectedSize=\(snapshot.selectedMipSize.x)x\(snapshot.selectedMipSize.y) candidates=\(snapshot.frustumCandidateCount) visible=\(snapshot.visibleAfterOcclusionCount) occluded=\(snapshot.occludedCount) usedHZB=\(snapshot.usedHZBThisFrame) builds/s=\(snapshot.hzbBuildsThisSecond) cullPasses/s=\(snapshot.hzbCullPassesThisSecond)")
        }
    }

    public func recordBuild(valid: Bool, mipCount: Int, selectedMipLevel: Int, selectedMipSize: simd_int2) {
        lock.lock()
        _stats.hzbIsValid = valid
        _stats.hzbMipCount = mipCount
        _stats.selectedMipLevel = selectedMipLevel
        _stats.selectedMipSize = selectedMipSize
        _stats.hzbBuildsThisSecond += 1
        lock.unlock()
    }

    public func recordCull(testedCount: Int, candidateCount: Int, visibleCount: Int, usedHZB: Bool, optimizedPath: Bool) {
        lock.lock()
        _stats.frustumTestedCount = max(0, testedCount)
        _stats.frustumCandidateCount = max(0, candidateCount)
        _stats.visibleAfterOcclusionCount = max(0, visibleCount)
        _stats.occludedCount = max(0, _stats.frustumCandidateCount - _stats.visibleAfterOcclusionCount)
        _stats.usedHZBThisFrame = usedHZB
        _stats.optimizedFrustumPath = optimizedPath
        if usedHZB {
            _stats.hzbCullPassesThisSecond += 1
        }
        lock.unlock()
    }
}

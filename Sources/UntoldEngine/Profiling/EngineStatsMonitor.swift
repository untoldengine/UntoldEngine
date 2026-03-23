//
//  EngineStatsMonitor.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import QuartzCore

public enum EngineStatsLoggingProfile: Equatable {
    case compact
    case verbose
}

public final class EngineStatsMonitor: @unchecked Sendable {
    public static let shared = EngineStatsMonitor()

    #if ENGINE_STATS_ENABLED
        private let lock = NSLock()
        private var currentSnapshot: EngineStatsSnapshot = .init()
        private var publishedSnapshot: EngineStatsSnapshot = .init()
        private var _enableLogging: Bool = false
        private var _loggingProfile: EngineStatsLoggingProfile = .compact
        private var _loggingIntervalSeconds: Double = 1.0
        private var lastLogTime: Double = 0.0

        // GPU timing — written from addCompletedHandler (async), read at completeFrame()
        private var _latestGPUExecutionMs: Double = 0.0
        private var _latestGPUFrameCadenceMs: Double = 0.0
        private var _lastGPUCompletionTime: Double = 0.0 // 0 = no completion seen yet

        // 30-frame rolling average for smoothed CPU frame time
        private let kSmoothingWindow = 30
        private var _frameMsBuffer: [Double] = .init(repeating: 0.0, count: 30)
        private var _frameMsBufferIndex: Int = 0
        private var _frameMsFilled: Int = 0
    #endif

    private init() {
        #if ENGINE_STATS_ENABLED
            lastLogTime = CACurrentMediaTime()
        #endif
    }

    public var enableLogging: Bool {
        get {
            #if ENGINE_STATS_ENABLED
                lock.lock()
                defer { lock.unlock() }
                return _enableLogging
            #else
                return false
            #endif
        }
        set {
            #if ENGINE_STATS_ENABLED
                lock.lock()
                _enableLogging = newValue
                lock.unlock()
            #endif
        }
    }

    public var loggingProfile: EngineStatsLoggingProfile {
        get {
            #if ENGINE_STATS_ENABLED
                lock.lock()
                defer { lock.unlock() }
                return _loggingProfile
            #else
                return .compact
            #endif
        }
        set {
            #if ENGINE_STATS_ENABLED
                lock.lock()
                _loggingProfile = newValue
                lock.unlock()
            #endif
        }
    }

    public var loggingIntervalSeconds: Double {
        get {
            #if ENGINE_STATS_ENABLED
                lock.lock()
                defer { lock.unlock() }
                return _loggingIntervalSeconds
            #else
                return 1.0
            #endif
        }
        set {
            #if ENGINE_STATS_ENABLED
                lock.lock()
                _loggingIntervalSeconds = max(0.1, newValue)
                lock.unlock()
            #endif
        }
    }

    public func snapshot() -> EngineStatsSnapshot {
        #if ENGINE_STATS_ENABLED
            lock.lock()
            defer { lock.unlock() }
            // Prefer a fully completed frame snapshot once available.
            if publishedSnapshot.frameIndex > 0 {
                return publishedSnapshot
            }
            return currentSnapshot
        #else
            return .init()
        #endif
    }

    /// Returns the in-progress snapshot being filled for the current frame.
    public func currentSnapshotInProgress() -> EngineStatsSnapshot {
        #if ENGINE_STATS_ENABLED
            lock.lock()
            defer { lock.unlock() }
            return currentSnapshot
        #else
            return .init()
        #endif
    }

    public func beginFrame(timestampSeconds: Double = CACurrentMediaTime()) {
        #if ENGINE_STATS_ENABLED
            lock.lock()
            currentSnapshot.frameIndex &+= 1
            currentSnapshot.timestampSeconds = timestampSeconds
            currentSnapshot.timing = .init()
            lock.unlock()
        #endif
    }

    public func update(_ updater: (inout EngineStatsSnapshot) -> Void) {
        #if ENGINE_STATS_ENABLED
            lock.lock()
            updater(&currentSnapshot)
            lock.unlock()
        #endif
    }

    /// Called from MTLCommandBuffer.addCompletedHandler to record true GPU timing.
    /// Safe to call from any thread.
    public func recordGPUCompletion(executionMs: Double) {
        #if ENGINE_STATS_ENABLED
            let now = CACurrentMediaTime()
            lock.lock()
            let cadenceMs = _lastGPUCompletionTime > 0
                ? (now - _lastGPUCompletionTime) * 1000.0
                : executionMs // first frame: use execution time as best estimate
            _lastGPUCompletionTime = now
            _latestGPUExecutionMs = executionMs
            _latestGPUFrameCadenceMs = cadenceMs
            lock.unlock()
        #endif
    }

    /// Publishes the current frame so API readers can safely consume it next frame.
    public func completeFrame() {
        #if ENGINE_STATS_ENABLED
            lock.lock()
            // Pull in latest GPU timing from async handler
            currentSnapshot.timing.gpuExecutionMs = _latestGPUExecutionMs
            currentSnapshot.timing.gpuFrameCadenceMs = _latestGPUFrameCadenceMs

            // Update 30-frame rolling average for CPU frame time
            let frameMs = currentSnapshot.timing.frameTotalMs
            _frameMsBuffer[_frameMsBufferIndex] = frameMs
            _frameMsBufferIndex = (_frameMsBufferIndex + 1) % kSmoothingWindow
            if _frameMsFilled < kSmoothingWindow { _frameMsFilled += 1 }
            var sum = 0.0
            for i in 0 ..< _frameMsFilled {
                sum += _frameMsBuffer[i]
            }
            currentSnapshot.timing.smoothedFrameMs = _frameMsFilled > 0
                ? sum / Double(_frameMsFilled)
                : frameMs

            publishedSnapshot = currentSnapshot
            lock.unlock()
        #endif
    }

    public func overwrite(with snapshot: EngineStatsSnapshot) {
        #if ENGINE_STATS_ENABLED
            lock.lock()
            currentSnapshot = snapshot
            publishedSnapshot = snapshot
            lock.unlock()
        #endif
    }

    public func reset() {
        #if ENGINE_STATS_ENABLED
            lock.lock()
            currentSnapshot = .init()
            publishedSnapshot = .init()
            lastLogTime = CACurrentMediaTime()
            _latestGPUExecutionMs = 0.0
            _latestGPUFrameCadenceMs = 0.0
            _lastGPUCompletionTime = 0.0
            _frameMsBuffer = .init(repeating: 0.0, count: kSmoothingWindow)
            _frameMsBufferIndex = 0
            _frameMsFilled = 0
            lock.unlock()
        #endif
    }

    public func tick() {
        #if ENGINE_STATS_ENABLED
            let now = CACurrentMediaTime()
            var shouldLog = false
            var snapshotToLog: EngineStatsSnapshot = .init()
            var profileToLog: EngineStatsLoggingProfile = .compact

            lock.lock()
            if _enableLogging, now - lastLogTime >= _loggingIntervalSeconds {
                lastLogTime = now
                snapshotToLog = publishedSnapshot.frameIndex > 0 ? publishedSnapshot : currentSnapshot
                profileToLog = _loggingProfile
                shouldLog = true
            }
            lock.unlock()

            guard shouldLog else { return }

            switch profileToLog {
            case .compact:
                Logger.log(
                    message: "[EngineStats] " + formatEngineStats(snapshotToLog, style: .compact),
                    category: LogCategory.engineStats.rawValue
                )
            case .verbose:
                Logger.log(
                    message: "[EngineStats]\n" + formatEngineStats(snapshotToLog, style: .expanded),
                    category: LogCategory.engineStats.rawValue
                )
            }
        #endif
    }
}

/// Returns the last completed frame snapshot for stable consumption from game `update()` loops.
public func getEngineStatsSnapshot() -> EngineStatsSnapshot {
    EngineStatsMonitor.shared.snapshot()
}

/// Returns the in-progress snapshot currently being populated for the active frame.
public func getEngineStatsSnapshotInProgress() -> EngineStatsSnapshot {
    EngineStatsMonitor.shared.currentSnapshotInProgress()
}

public func setEngineStatsLogging(enabled: Bool) {
    EngineStatsMonitor.shared.enableLogging = enabled
}

public func setEngineStatsLogging(
    enabled: Bool,
    profile: EngineStatsLoggingProfile,
    intervalSeconds: Double = 1.0
) {
    EngineStatsMonitor.shared.enableLogging = enabled
    EngineStatsMonitor.shared.loggingProfile = profile
    EngineStatsMonitor.shared.loggingIntervalSeconds = intervalSeconds
}

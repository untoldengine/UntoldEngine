//
//  GPUSubmissionGate.swift
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
#if canImport(UIKit)
    import UIKit
#endif

/// Whether the engine may send work to the GPU right now.
///
/// iOS, tvOS and visionOS refuse GPU work from an app that is not in the foreground: a command
/// buffer committed then fails with `MTLCommandBufferError.notPermitted`, Metal logs
/// "Insufficient Permission (to submit GPU work from background)" and the work is lost. On
/// Apple Vision Pro that is what taking the headset off does: the app resigns active and enters
/// the background. The compositor pauses its layer, but the engine's other GPU work (a texture
/// upload or resample, the room light's bakes, a frame already taken) would still be sent.
///
/// The gate closes when the app resigns active and opens when it is active again, as Apple asks
/// of a Metal app ("Preparing your Metal app to run in the background"): the frame loops take no
/// frame while it is closed, and the loaders wait at it instead of failing. Both transitions are
/// logged, with the pause's length. macOS never restricts the GPU, so the gate stays open there.
/// A host that drives the engine without UIKit, or a test, closes and opens it by hand.
public final class GPUSubmissionGate: @unchecked Sendable {
    public static let shared = GPUSubmissionGate()

    private let condition = NSCondition()
    private var isOpenValue = true
    private var resumeCountValue: UInt64 = 0
    private var closedAt: CFTimeInterval = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var lastCommitted: MTLCommandBuffer?
    private let observersLock = NSLock()
    private var observers: [NSObjectProtocol] = []
    /// The sites whose GPU work went on while the gate was closed (the main thread, which
    /// never waits), each logged once per pause.
    private var sitesWhilePaused: Set<String> = []
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    /// The wall-clock time of a log line, to set it against the system's own log.
    public static func logTimestamp() -> String {
        timestampFormatter.string(from: Date())
    }

    init() {}

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Whether GPU work may be sent now.
    public var isOpen: Bool {
        condition.lock()
        defer { condition.unlock() }
        return isOpenValue
    }

    /// How many times the gate has opened again after a close. A frame loop that sees the count
    /// change since its last frame knows the engine paused in between, and lets no time pass to
    /// the first frame after.
    public var resumeCount: UInt64 {
        condition.lock()
        defer { condition.unlock() }
        return resumeCountValue
    }

    /// Closes the gate: no GPU work is sent until `open(reason:)`. Closing a closed gate
    /// changes nothing.
    public func close(reason: String) {
        condition.lock()
        guard isOpenValue else {
            condition.unlock()
            return
        }
        isOpenValue = false
        closedAt = CACurrentMediaTime()
        sitesWhilePaused.removeAll()
        condition.unlock()
        print("Engine [\(Self.logTimestamp())]: GPU work paused: \(reason)")
    }

    /// Opens the gate and releases every waiter. Opening an open gate changes nothing.
    public func open(reason: String) {
        condition.lock()
        guard !isOpenValue else {
            condition.unlock()
            return
        }
        isOpenValue = true
        resumeCountValue &+= 1
        let pausedSeconds = CACurrentMediaTime() - closedAt
        let released = waiters
        waiters.removeAll()
        condition.broadcast()
        condition.unlock()
        for waiter in released {
            waiter.resume()
        }
        print("Engine [\(Self.logTimestamp())]: GPU work resumed after \(String(format: "%.1f", pausedSeconds)) s: \(reason)")
    }

    /// Blocks the calling thread until the gate is open, or until `timeout` seconds have passed
    /// (nil: as long as it takes), and returns whether it is open. The main thread never waits:
    /// the gate is opened from it, so there the call returns at once and the caller goes on,
    /// which is logged once per site and pause.
    @discardableResult
    public func waitUntilOpen(timeout: TimeInterval? = nil, file: StaticString = #fileID, line: UInt = #line) -> Bool {
        condition.lock()
        defer { condition.unlock() }
        if isOpenValue {
            return true
        }
        if Thread.isMainThread {
            let site = "\(file):\(line)"
            if sitesWhilePaused.insert(site).inserted {
                print("Engine [\(Self.logTimestamp())]: GPU work goes on while paused, from the main thread at \(site)")
            }
            return false
        }
        if let timeout {
            let deadline = Date(timeIntervalSinceNow: timeout)
            while !isOpenValue {
                guard condition.wait(until: deadline) else { break }
            }
        } else {
            while !isOpenValue {
                condition.wait()
            }
        }
        return isOpenValue
    }

    /// Suspends the task until the gate is open.
    public func waitUntilOpen() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            condition.lock()
            if isOpenValue {
                condition.unlock()
                continuation.resume()
            } else {
                waiters.append(continuation)
                condition.unlock()
            }
        }
    }

    /// Keeps the frame's command buffer just committed, so that entering the background can see
    /// it scheduled before the system restricts the GPU.
    public func noteCommitted(_ commandBuffer: MTLCommandBuffer) {
        condition.lock()
        lastCommitted = commandBuffer
        condition.unlock()
    }

    /// Waits for the last command buffer noted to be scheduled: work the app committed before it
    /// entered the background keeps its permission once the GPU has taken it, which Apple asks
    /// an app to make sure of in `applicationDidEnterBackground`.
    public func waitForCommittedWork() {
        condition.lock()
        let commandBuffer = lastCommitted
        lastCommitted = nil
        condition.unlock()
        guard let commandBuffer, commandBuffer.status == .committed else { return }
        commandBuffer.waitUntilScheduled()
    }

    /// Follows the app's state on the platforms that refuse a background app's GPU work (iOS,
    /// tvOS, visionOS): the gate closes when the app resigns active and opens when it becomes
    /// active again, and entering the background first sees the last frame scheduled. The
    /// renderer installs this once; on macOS there is nothing to follow.
    public func observeApplicationState() {
        #if canImport(UIKit) && !os(watchOS) && !targetEnvironment(macCatalyst)
            observersLock.lock()
            defer { observersLock.unlock() }
            guard observers.isEmpty else { return }
            let center = NotificationCenter.default
            observers = [
                center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                    self?.close(reason: "the app resigned active (the headset off, the app leaving the foreground or a system view in front)")
                },
                center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                    guard let self else { return }
                    close(reason: "the app entered the background")
                    print("Engine [\(Self.logTimestamp())]: the app is in the background; GPU work stays paused until it is active again")
                    waitForCommittedWork()
                },
                center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                    self?.open(reason: "the app is active again")
                },
            ]
        #endif
    }
}

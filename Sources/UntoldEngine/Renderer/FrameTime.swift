//
//  FrameTime.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// When the frame being prepared is predicted to reach the display, and how far that is from
/// the frame before.
///
/// A headset frame is drawn with the head pose predicted for its presentation instant, so an
/// object posed for `presentationTime` keeps its place against the world while the head moves,
/// and one moving along a path steps by the display's period from one frame to the next
/// instead of by the varying time between two game updates. A frame the display skipped lands
/// where the timeline says, and the frames after it step by one period again.
///
/// `presentationTime` is in the `CACurrentMediaTime()` base, which `ProcessInfo.systemUptime`
/// and ARKit's anchor timestamps share, so a game may keep its own timelines in that base.
public struct FrameTime: Sendable, Equatable {
    /// Seconds at which the frame is predicted to be shown.
    public let presentationTime: TimeInterval
    /// Seconds from the previous frame's presentation to this one's: one period on a steady
    /// cadence, more after a skipped frame, 0 on the first frame.
    public let deltaTime: TimeInterval
    /// The display's period as the loop knows it: the host's nominal frame interval, or the
    /// shortest spacing between presentations seen so far (0 until one has been seen).
    public let period: TimeInterval
    /// Refreshes between the previous frame and this one at which the display showed the
    /// previous frame again because no new one was ready. 0 on a steady cadence.
    public let skippedFrames: Int
    /// The engine's count of frames prepared, from 1.
    public let frameIndex: UInt64

    public init(
        presentationTime: TimeInterval,
        deltaTime: TimeInterval,
        period: TimeInterval,
        skippedFrames: Int,
        frameIndex: UInt64
    ) {
        self.presentationTime = presentationTime
        self.deltaTime = deltaTime
        self.period = period
        self.skippedFrames = skippedFrames
        self.frameIndex = frameIndex
    }

    /// Whether the display repeated the previous frame before this one.
    public var wasFrameSkipped: Bool { skippedFrames > 0 }

    /// No frame yet: every field zero.
    public static let zero = FrameTime(presentationTime: 0, deltaTime: 0, period: 0, skippedFrames: 0, frameIndex: 0)
}

/// Makes each frame's `FrameTime` from the presentation times a host loop predicts: the delta
/// between consecutive presentations, the period (the host's nominal one, or the shortest
/// spacing seen) and the refreshes skipped between two frames.
public struct FrameClock: Sendable, Equatable {
    /// The most recent frame, or nil before the first.
    public private(set) var current: FrameTime?
    /// The period the host declares (1 / the view's preferred frames per second), or nil to
    /// learn it from the presentation times.
    public var nominalPeriod: TimeInterval?
    private var learnedPeriod: TimeInterval?
    private var frameIndex: UInt64 = 0

    /// A spacing shorter than this is two frames for one refresh, not a period.
    static let shortestPeriod: TimeInterval = 1.0 / 250.0
    /// A spacing longer than this is a stall, not a period.
    static let longestPeriod: TimeInterval = 1.0 / 24.0

    public init(nominalPeriod: TimeInterval? = nil) {
        self.nominalPeriod = nominalPeriod
    }

    /// The display's period as the clock knows it, 0 before it knows one.
    public var period: TimeInterval { nominalPeriod ?? learnedPeriod ?? 0 }

    /// Advances to a frame predicted to be shown at `presentationTime` and returns its time.
    @discardableResult
    public mutating func advance(toPresentation presentationTime: TimeInterval) -> FrameTime {
        frameIndex &+= 1
        guard let previous = current else {
            let frame = FrameTime(presentationTime: presentationTime, deltaTime: 0, period: period, skippedFrames: 0, frameIndex: frameIndex)
            current = frame
            return frame
        }

        // A presentation before the previous one is a clock going backwards: no time passes.
        let delta = max(0, presentationTime - previous.presentationTime)
        if nominalPeriod == nil, delta >= Self.shortestPeriod, delta <= Self.longestPeriod {
            learnedPeriod = min(learnedPeriod ?? delta, delta)
        }

        let period = period
        var skipped = 0
        if period > 0, delta > 0 {
            // The refreshes the delta spans, less the one every frame takes.
            let refreshes = min(delta / period, 1_000_000).rounded()
            skipped = max(0, Int(refreshes) - 1)
        }

        let frame = FrameTime(presentationTime: presentationTime, deltaTime: delta, period: period, skippedFrames: skipped, frameIndex: frameIndex)
        current = frame
        return frame
    }

    /// Advances to a frame the loop estimates `lead` ahead of `now`, for a host with no
    /// predicted presentation time (an MTKView's draw): the delta is then the spacing of the
    /// draws on the wall clock.
    @discardableResult
    public mutating func advance(now: TimeInterval, lead: TimeInterval) -> FrameTime {
        advance(toPresentation: now + lead)
    }

    /// Forgets every frame: the next one is a first frame again.
    public mutating func reset() {
        current = nil
        learnedPeriod = nil
        frameIndex = 0
    }
}

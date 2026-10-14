//
//  FrameClockTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

/// The frame clock turns the presentation times a loop predicts into each frame's time: the
/// delta between presentations, the period it learns and the refreshes skipped between frames.
final class FrameClockTests: XCTestCase {
    private let period: TimeInterval = 1.0 / 100.0

    func testTheFirstFrameHasNoDeltaAndNoPeriodYet() {
        var clock = FrameClock()
        let frame = clock.advance(toPresentation: 500.0)
        XCTAssertEqual(frame.presentationTime, 500.0)
        XCTAssertEqual(frame.deltaTime, 0)
        XCTAssertEqual(frame.period, 0)
        XCTAssertEqual(frame.skippedFrames, 0)
        XCTAssertEqual(frame.frameIndex, 1)
        XCTAssertFalse(frame.wasFrameSkipped)
        XCTAssertEqual(clock.current, frame)
    }

    func testASteadyCadenceStepsByOnePeriodAndSkipsNothing() {
        var clock = FrameClock()
        var frames: [FrameTime] = []
        for index in 0 ..< 5 {
            frames.append(clock.advance(toPresentation: 500.0 + Double(index) * period))
        }
        XCTAssertEqual(frames.map(\.frameIndex), [1, 2, 3, 4, 5])
        for frame in frames.dropFirst() {
            XCTAssertEqual(frame.deltaTime, period, accuracy: 1e-9)
            XCTAssertEqual(frame.period, period, accuracy: 1e-9)
            XCTAssertEqual(frame.skippedFrames, 0)
        }
    }

    func testASkippedRefreshIsCountedAndTheNextFrameStepsByOnePeriodAgain() {
        var clock = FrameClock()
        // Slots 0, 1, 2, [3 missed], 4, 5.
        let frames = [0, 1, 2, 4, 5].map { clock.advance(toPresentation: 500.0 + Double($0) * period) }
        XCTAssertEqual(frames.map(\.skippedFrames), [0, 0, 0, 1, 0])
        XCTAssertTrue(frames[3].wasFrameSkipped)
        XCTAssertEqual(frames[3].deltaTime, 2 * period, accuracy: 1e-9)
        XCTAssertEqual(frames[4].deltaTime, period, accuracy: 1e-9)
        // The skip did not teach the clock a longer period.
        XCTAssertEqual(frames[4].period, period, accuracy: 1e-9)
    }

    func testAJitteringCadenceIsNotASkip() {
        var clock = FrameClock()
        var time = 500.0
        var skipped = 0
        for index in 0 ..< 20 {
            // The compositor's predictions wander by a tenth of a millisecond.
            time += period + (index % 2 == 0 ? 0.0001 : -0.0001)
            skipped += clock.advance(toPresentation: time).skippedFrames
        }
        XCTAssertEqual(skipped, 0)
        XCTAssertEqual(clock.period, period - 0.0001, accuracy: 1e-9)
    }

    func testAStallCountsEverySkippedRefresh() {
        var clock = FrameClock()
        clock.advance(toPresentation: 500.0)
        clock.advance(toPresentation: 500.0 + period)
        let frame = clock.advance(toPresentation: 500.0 + period + 0.5)
        XCTAssertEqual(frame.deltaTime, 0.5, accuracy: 1e-9)
        XCTAssertEqual(frame.skippedFrames, 49)
        // A stall is not a period either.
        XCTAssertEqual(clock.period, period, accuracy: 1e-9)
    }

    func testANominalPeriodIsUsedInsteadOfLearningOne() {
        var clock = FrameClock(nominalPeriod: 1.0 / 60.0)
        let first = clock.advance(toPresentation: 500.0)
        XCTAssertEqual(first.period, 1.0 / 60.0, accuracy: 1e-9)
        // Two draws a third of a frame apart do not shorten the period; two frames apart is a skip.
        let close = clock.advance(toPresentation: 500.0 + 1.0 / 180.0)
        XCTAssertEqual(close.period, 1.0 / 60.0, accuracy: 1e-9)
        XCTAssertEqual(close.skippedFrames, 0)
        let late = clock.advance(toPresentation: 500.0 + 1.0 / 180.0 + 2.0 / 60.0)
        XCTAssertEqual(late.skippedFrames, 1)
    }

    func testTimeGoingBackwardsPassesNoTime() {
        var clock = FrameClock()
        clock.advance(toPresentation: 500.0)
        clock.advance(toPresentation: 500.0 + period)
        let frame = clock.advance(toPresentation: 500.0)
        XCTAssertEqual(frame.deltaTime, 0)
        XCTAssertEqual(frame.skippedFrames, 0)
    }

    func testAnEstimateIsOneLeadAheadOfNow() {
        var clock = FrameClock(nominalPeriod: 1.0 / 60.0)
        let frame = clock.advance(now: 500.0, lead: 1.0 / 60.0)
        XCTAssertEqual(frame.presentationTime, 500.0 + 1.0 / 60.0, accuracy: 1e-9)
        let next = clock.advance(now: 500.0 + 1.0 / 60.0, lead: 1.0 / 60.0)
        XCTAssertEqual(next.deltaTime, 1.0 / 60.0, accuracy: 1e-9)
    }

    func testResetMakesTheNextFrameAFirstFrame() {
        var clock = FrameClock()
        clock.advance(toPresentation: 500.0)
        clock.advance(toPresentation: 500.0 + period)
        clock.reset()
        XCTAssertNil(clock.current)
        XCTAssertEqual(clock.period, 0)
        let frame = clock.advance(toPresentation: 900.0)
        XCTAssertEqual(frame.deltaTime, 0)
        XCTAssertEqual(frame.frameIndex, 1)
    }
}

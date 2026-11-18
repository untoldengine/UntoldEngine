//
//  TransformTrackTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

/// A transform track sampled at an absolute time: the pose for a frame depends on the frame's
/// presentation time alone.
final class TransformTrackTests: XCTestCase {
    /// One metre per second along x for one second.
    private let metrePerSecond = TransformTrack(keys: [
        TransformKey(time: 0, position: simd_float3(0, 0, 0)),
        TransformKey(time: 1, position: simd_float3(1, 0, 0)),
    ])

    private func x(_ pose: TransformPose?) -> Float {
        pose?.position.x ?? .nan
    }

    func testPoseAtTheKeysAndBetweenThem() {
        let turn = simd_quatf(angle: .pi / 2, axis: simd_float3(0, 1, 0))
        let track = TransformTrack(keys: [
            TransformKey(time: 2, position: simd_float3(2, 0, 0), rotation: turn, scale: simd_float3(repeating: 2)),
            TransformKey(time: 0, position: simd_float3(0, 0, 0)),
        ])
        // Keys are kept in time order whatever order they were given in.
        XCTAssertEqual(track.keys.map(\.time), [0, 2])
        XCTAssertEqual(track.duration, 2)
        XCTAssertEqual(x(track.pose(at: 0)), 0)
        XCTAssertEqual(x(track.pose(at: 2)), 2)
        let middle = track.pose(at: 1)
        XCTAssertEqual(x(middle), 1, accuracy: 1e-6)
        XCTAssertEqual(middle?.scale.x ?? .nan, 1.5, accuracy: 1e-6)
        XCTAssertEqual(middle?.rotation.angle ?? .nan, .pi / 4, accuracy: 1e-5)
    }

    func testThePoseHoldsOutsideTheKeysAndWrapsWhenLooping() {
        XCTAssertEqual(x(metrePerSecond.pose(at: -1)), 0)
        XCTAssertEqual(x(metrePerSecond.pose(at: 5)), 1)
        let looping = TransformTrack(keys: metrePerSecond.keys, loops: true)
        XCTAssertEqual(x(looping.pose(at: 1.25)), 0.25, accuracy: 1e-6)
        XCTAssertEqual(x(looping.pose(at: -0.25)), 0.75, accuracy: 1e-6)
        XCTAssertEqual(x(looping.pose(at: 1)), 0, accuracy: 1e-6)
        XCTAssertNil(TransformTrack(keys: []).pose(at: 0))
    }

    func testEasingKeepsTheEndpointsAndShapesTheMiddle() {
        for easing in [TrackEasing.linear, .easeIn, .easeOut, .easeInOut] {
            XCTAssertEqual(easing.progress(0), 0)
            XCTAssertEqual(easing.progress(1), 1)
            XCTAssertEqual(easing.progress(-3), 0)
            XCTAssertEqual(easing.progress(3), 1)
        }
        XCTAssertEqual(TrackEasing.linear.progress(0.25), 0.25)
        XCTAssertEqual(TrackEasing.easeIn.progress(0.5), 0.25)
        XCTAssertEqual(TrackEasing.easeOut.progress(0.5), 0.75)
        XCTAssertEqual(TrackEasing.easeInOut.progress(0.5), 0.5)
        XCTAssertLessThan(TrackEasing.easeInOut.progress(0.25), 0.25)
        let eased = TransformTrack(keys: [
            TransformKey(time: 0, position: simd_float3(0, 0, 0), easing: .easeIn),
            TransformKey(time: 1, position: simd_float3(1, 0, 0)),
        ])
        XCTAssertEqual(x(eased.pose(at: 0.5)), 0.25, accuracy: 1e-6)
    }

    func testThePoseForAFrameIsTakenAtItsPresentationTime() {
        let frame = FrameTime(presentationTime: 1000.25, deltaTime: 0.01, period: 0.01, skippedFrames: 0, frameIndex: 7)
        XCTAssertEqual(x(metrePerSecond.pose(for: frame, startedAt: 1000.0)), 0.25, accuracy: 1e-6)
    }

    /// The display showed one frame twice (the engine missed a slot), so the next frame's
    /// presentation is two periods on. A pose sampled at the frame's presentation time lands
    /// where the timeline says, and the frame after it steps by one period again. An object
    /// moved by the time between two updates — the wall clock the update happens to run at,
    /// a varying lag before each presentation — steps unevenly every frame and is off the
    /// timeline after the skip.
    func testARepeatedFrameDoesNotDoubleStepAnAbsoluteTimeAnimation() {
        let period: TimeInterval = 0.010
        let start: TimeInterval = 100.0
        // Presentation slots 0, 1, 2, [3 missed], 4, 5.
        let slots = [0, 1, 2, 4, 5]
        let presentations = slots.map { start + Double($0) * period }
        // How long before its presentation each frame's update ran.
        let lags: [TimeInterval] = [0.0063, 0.0071, 0.0058, 0.0094, 0.0066]

        var clock = FrameClock()
        var frames: [FrameTime] = []
        var sampled: [Float] = []
        var stepped: [Float] = []
        var steppedPosition: Float = 0
        var previousUpdate: TimeInterval?
        for (presentation, lag) in zip(presentations, lags) {
            let frame = clock.advance(toPresentation: presentation)
            frames.append(frame)
            sampled.append(x(metrePerSecond.pose(for: frame, startedAt: start)))

            let updateTime = presentation - lag
            if let previousUpdate {
                steppedPosition += Float(updateTime - previousUpdate) // one metre per second
            }
            previousUpdate = updateTime
            stepped.append(steppedPosition)
        }

        XCTAssertEqual(frames.map(\.skippedFrames), [0, 0, 0, 1, 0])

        // Sampled at presentation time: exactly the timeline's positions.
        let expected = slots.map { Float($0) * Float(period) }
        for (position, wanted) in zip(sampled, expected) {
            XCTAssertEqual(position, wanted, accuracy: 1e-6)
        }
        // One period per frame, two across the skipped slot, one again after it.
        let sampledSteps = zip(sampled.dropFirst(), sampled).map { $0 - $1 }
        for (step, frame) in zip(sampledSteps, frames.dropFirst()) {
            XCTAssertEqual(step, Float(period) * Float(1 + frame.skippedFrames), accuracy: 1e-6)
        }

        // Stepped by the time between updates: no step is a period, and after the skip the
        // position is off the timeline by the change in lag.
        let steppedSteps = zip(stepped.dropFirst(), stepped).map { $0 - $1 }
        for step in steppedSteps {
            XCTAssertNotEqual(step, Float(period), accuracy: 0.0005)
            XCTAssertNotEqual(step, Float(2 * period), accuracy: 0.0005)
        }
        XCTAssertNotEqual(stepped[3], expected[3], accuracy: 0.002)
    }
}

//
//  FrameTimeLoopTests.swift
//  UntoldEngineRenderTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

/// The frame's time reaches the game, the update event and the extensions from the loop, and
/// a pose the game samples at it is the pose for the frame's presentation instant, not for
/// the wall clock the update happens to run at.
final class FrameTimeLoopTests: BaseRenderSetup {
    private final class TimeRecordingExtension: EngineExtension, @unchecked Sendable {
        let id = "test.frameTime.recording"
        var frames: [FrameTime] = []

        func update(deltaTime _: Float, context: EngineExtensionUpdateContext) {
            frames.append(context.frameTime)
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        if CameraSystem.shared.activeCamera == nil {
            let camera = createEntity()
            createGameCamera(entityId: camera)
            CameraSystem.shared.activeCamera = camera
        }
        gameMode = true
    }

    override func tearDown() async throws {
        EngineExtensionRegistry.shared.removeAll()
        try await super.tearDown()
    }

    func testAPoseSampledByTheGameMatchesTheFramesPresentationTime() throws {
        // A timeline nowhere near the wall clock: a pose taken from CACurrentMediaTime() or
        // from the time between two of these calls would be nowhere near the expected one.
        let start: TimeInterval = 1000.0
        let period: TimeInterval = 0.010
        let metrePerSecond = TransformTrack(keys: [
            TransformKey(time: 0, position: simd_float3(0, 0, 0)),
            TransformKey(time: 1, position: simd_float3(1, 0, 0)),
        ])
        let entity = createEntity()
        registerTransformComponent(entityId: entity)

        var frames: [FrameTime] = []
        renderer.setupCallbacks(
            frameUpdate: { frame in
                frames.append(frame)
                applyTransformTrack(entityId: entity, track: metrePerSecond, startedAt: start, frame: frame)
            },
            handleInput: {}
        )
        var events: [FrameTime] = []
        let token = renderer.onUpdate { events.append($0.frameTime) }
        defer { token.cancel() }
        let recorder = TimeRecordingExtension()
        EngineExtensionRegistry.shared.register(recorder)

        for index in 0 ..< 3 {
            XCTAssertTrue(renderer.updateXR(presentationTime: start + Double(index) * period))
            XCTAssertEqual(getLocalPosition(entityId: entity).x, Float(index) * Float(period), accuracy: 1e-5)
        }

        let presentations = [start, start + period, start + 2 * period]
        XCTAssertEqual(frames.map(\.presentationTime), presentations)
        XCTAssertEqual(frames.count, 3)
        for (frame, delta) in zip(frames, [0, period, period]) {
            XCTAssertEqual(frame.deltaTime, delta, accuracy: 1e-9)
        }
        XCTAssertEqual(frames.map(\.skippedFrames), [0, 0, 0])
        // The engine's delta is the presentation delta, not the microseconds between the calls.
        XCTAssertEqual(timeSinceLastUpdate, Float(period), accuracy: 1e-6)
        XCTAssertEqual(events.map(\.presentationTime), presentations)
        XCTAssertEqual(recorder.frames.map(\.presentationTime), presentations)
        XCTAssertEqual(renderer.frameTime, try XCTUnwrap(frames.last))
        XCTAssertEqual(currentFrameTime, try XCTUnwrap(frames.last))
    }

    func testTheGameUpdateDeltaIsThePresentationDeltaAndASkippedFrameIsReported() {
        var deltas: [Float] = []
        renderer.setupCallbacks(gameUpdate: { deltas.append($0) }, handleInput: {})
        let start: TimeInterval = 2000.0
        let period: TimeInterval = 1.0 / 90.0
        XCTAssertTrue(renderer.updateXR(presentationTime: start))
        XCTAssertTrue(renderer.updateXR(presentationTime: start + period))
        // The display showed the second frame twice: the third is two periods on.
        XCTAssertTrue(renderer.updateXR(presentationTime: start + 3 * period))

        XCTAssertEqual(deltas.count, 3)
        XCTAssertEqual(deltas[0], 0)
        XCTAssertEqual(deltas[1], Float(period), accuracy: 1e-6)
        XCTAssertEqual(deltas[2], Float(2 * period), accuracy: 1e-6)
        XCTAssertEqual(renderer.frameTime.skippedFrames, 1)
        XCTAssertEqual(renderer.frameTime.period, period, accuracy: 1e-9)
    }

    func testAFrameWithoutAPredictionIsPosedOnePeriodAheadOfNow() {
        let before = CACurrentMediaTime()
        XCTAssertTrue(renderer.updateXR())
        let after = CACurrentMediaTime()
        let period = UntoldRenderer.defaultFramePeriod
        XCTAssertGreaterThanOrEqual(renderer.frameTime.presentationTime, before + period)
        XCTAssertLessThanOrEqual(renderer.frameTime.presentationTime, after + period)
        XCTAssertEqual(renderer.frameTime.period, period, accuracy: 1e-9)
    }
}

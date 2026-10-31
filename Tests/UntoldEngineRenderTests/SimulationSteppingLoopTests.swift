//
//  SimulationSteppingLoopTests.swift
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

/// The simulation stage through the real frame loop: what the frames the renderer draws hand
/// to a `fixedUpdate` under per-frame stepping.
final class SimulationSteppingLoopTests: BaseRenderSetup {
    /// One bucket per frame, opened by `update`; the simulation steps the frame ran land in it.
    private final class StepRecordingExtension: EngineExtension, @unchecked Sendable {
        let id = "test.simulationStepping.loop"
        var stepsPerFrame: [[Float]] = []

        func update(deltaTime _: Float, context _: EngineExtensionUpdateContext) {
            stepsPerFrame.append([])
        }

        func fixedUpdate(deltaTime: Float, context _: EngineExtensionUpdateContext) {
            stepsPerFrame[stepsPerFrame.count - 1].append(deltaTime)
        }
    }

    /// These tests bring no scene: a camera is all the loop needs.
    override func initializeAssets() {
        let camera = findGameCamera()
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: simd_float3(0, 1, 4), target: .zero, up: simd_float3(0, 1, 0))
    }

    override func tearDown() async throws {
        simulationStepping = .fixed
        physicsAccumulator = 0
        EngineExtensionRegistry.shared.removeAll()
        try await super.tearDown()
    }

    func testPerFrameSteppingStepsOnEveryFrameTheLoopDraws() {
        setEngine(.simulationStepping(.perFrame))
        let recorder = StepRecordingExtension()
        XCTAssertEqual(EngineExtensionRegistry.shared.register(recorder), .registered)

        // Frames spaced by the wall clock, each well over the shortest frame the mode steps.
        var deltas: [Float] = []
        for _ in 0 ..< 6 {
            Thread.sleep(forTimeInterval: 0.012)
            renderer.draw(in: renderer.metalView)
            deltas.append(timeSinceLastUpdate)
        }
        XCTAssertEqual(recorder.stepsPerFrame.count, 6)

        // The first frame after a reset has no delta; every frame after it is simulated whole:
        // at least one step, their deltas summing to the frame's own, none over the bound.
        let h: Float = 1.0 / 60.0
        for frame in 1 ..< 6 {
            let steps = recorder.stepsPerFrame[frame]
            XCTAssertGreaterThanOrEqual(steps.count, 1, "frame \(frame) ran no simulation step")
            XCTAssertEqual(steps.reduce(0, +), min(deltas[frame], 5 * h), accuracy: 1e-5, "frame \(frame)")
            for step in steps {
                XCTAssertLessThanOrEqual(step, 1.1 * h + 1e-6, "frame \(frame)")
            }
        }
    }
}

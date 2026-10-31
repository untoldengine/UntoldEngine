//
//  SimulationSteppingTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

private final class StepRecordingEngineExtension: EngineExtension, @unchecked Sendable {
    let id = "test.simulationStepping.engine"
    var stepDeltas: [Float] = []

    func fixedUpdate(deltaTime: Float, context _: EngineExtensionUpdateContext) {
        stepDeltas.append(deltaTime)
    }
}

private final class StepRecordingRenderExtension: RenderExtension, @unchecked Sendable {
    let id = "test.simulationStepping.render"
    var stepDeltas: [Float] = []

    func fixedUpdate(deltaTime: Float, context _: EngineExtensionUpdateContext) {
        stepDeltas.append(deltaTime)
    }

    func buildGraph(_: inout RenderGraphBuilder, context _: RenderGraphBuildContext) {}
}

/// The simulation stage through the real `PhysicsCoordinator` and registries, driven frame by
/// frame without a renderer: what the backend and every other participant see per frame.
@MainActor
final class SimulationSteppingTests: XCTestCase {
    private let h: Float = 1.0 / 60.0

    override func setUp() async throws {
        resetEngineTestState()
    }

    override func tearDown() {
        PhysicsBackendRegistry.shared.resetForTesting()
        simulationStepping = .fixed
        physicsAccumulator = 0
        super.tearDown()
    }

    private func makeContext() -> EngineExtensionUpdateContext {
        EngineExtensionUpdateContext(
            viewport: SIMD2<Int>(640, 480),
            immersionStyle: .none,
            frameIndex: 0,
            currentEye: 0,
            isPrimaryEye: true
        )
    }

    /// The backend's step deltas bucketed by the frame that ran them. The first step locks the
    /// registry for the run, so a fresh backend per cadence needs it unlocked first.
    private func backendStepsPerFrame(deltas: [Float]) -> [[Float]] {
        PhysicsBackendRegistry.shared.resetForTesting()
        let plugin = RecordingBackendPlugin()
        XCTAssertEqual(PhysicsBackendRegistry.shared.install(plugin), .installed)
        let backend = plugin.backend
        return deltas.map { delta in
            let before = backend.stepDeltas.count
            updateSimulationSteps(deltaTime: delta, context: makeContext())
            return Array(backend.stepDeltas[before...])
        }
    }

    func testPerFrameSteppingStepsTheBackendOnEveryFrameOfAHundredHertzCadence() {
        setEngine(.simulationStepping(.perFrame))

        let hundredHertz = backendStepsPerFrame(deltas: Array(repeating: 0.010, count: 10))
        for (frame, steps) in hundredHertz.enumerated() {
            XCTAssertEqual(steps.count, 1, "frame \(frame) ran \(steps.isEmpty ? "no" : "\(steps.count)") simulation step\(steps.count == 1 ? "" : "s")")
            XCTAssertEqual(steps.reduce(0, +), 0.010, accuracy: 1e-7, "frame \(frame)")
        }

        let ninetyHertz = backendStepsPerFrame(deltas: Array(repeating: 1.0 / 90.0, count: 9))
        for (frame, steps) in ninetyHertz.enumerated() {
            XCTAssertEqual(steps.count, 1, "frame \(frame)")
            XCTAssertEqual(steps.reduce(0, +), 1.0 / 90.0, accuracy: 1e-7, "frame \(frame)")
        }

        // XR half-rate pacing at 100 Hz: two refreshes a frame, two sub-steps of one refresh.
        let halfRate = backendStepsPerFrame(deltas: Array(repeating: 0.020, count: 5))
        for (frame, steps) in halfRate.enumerated() {
            XCTAssertEqual(steps.count, 2, "frame \(frame)")
            for step in steps {
                XCTAssertEqual(step, 0.010, accuracy: 1e-7, "frame \(frame)")
            }
        }
    }

    func testFixedSteppingLeavesTwoFramesInFiveWithoutABackendStep() {
        XCTAssertEqual(simulationStepping, .fixed)

        let hundredHertz = backendStepsPerFrame(deltas: Array(repeating: 0.010, count: 10))
        XCTAssertEqual(hundredHertz.map(\.count), [0, 1, 0, 1, 0, 1, 1, 0, 1, 0])
        for (frame, steps) in hundredHertz.enumerated() where !steps.isEmpty {
            XCTAssertEqual(steps[0], h, accuracy: 1e-7, "frame \(frame)")
        }
    }

    func testEveryFixedUpdateParticipantGetsThePlansDelta() {
        setEngine(.simulationStepping(.perFrame))
        let plugin = RecordingBackendPlugin()
        XCTAssertEqual(PhysicsBackendRegistry.shared.install(plugin), .installed)
        let engineRecorder = StepRecordingEngineExtension()
        XCTAssertEqual(EngineExtensionRegistry.shared.register(engineRecorder), .registered)
        let renderRecorder = StepRecordingRenderExtension()
        XCTAssertEqual(RenderExtensionRegistry.shared.register(renderRecorder), .registered)
        var customDeltas: [Float] = []
        registerCustomSystem { customDeltas.append($0) }

        let plan = updateSimulationSteps(deltaTime: 0.035, context: makeContext())

        XCTAssertEqual(plan.stepCount, 2)
        XCTAssertEqual(plan.stepDelta, 0.0175, accuracy: 1e-7)
        XCTAssertEqual(plan.accumulator, 0)
        for (name, deltas) in [
            ("backend", plugin.backend.stepDeltas),
            ("engine extension", engineRecorder.stepDeltas),
            ("render extension", renderRecorder.stepDeltas),
            ("custom system", customDeltas),
        ] {
            XCTAssertEqual(deltas.count, 2, name)
            for delta in deltas {
                XCTAssertEqual(delta, 0.0175, accuracy: 1e-7, name)
            }
        }
    }

    func testFixedSteppingCarriesTheResidualBitForBitAcrossFrames() {
        XCTAssertEqual(simulationStepping, .fixed)
        let frame: Float = 0.010

        updateSimulationSteps(deltaTime: frame, context: makeContext())
        XCTAssertEqual(physicsAccumulator.bitPattern, frame.bitPattern)

        // The old loop: accumulate, step once, subtract. One write of the same value.
        updateSimulationSteps(deltaTime: frame, context: makeContext())
        let oldLoopResidual = (frame + frame) - h
        XCTAssertEqual(physicsAccumulator.bitPattern, oldLoopResidual.bitPattern)
    }
}

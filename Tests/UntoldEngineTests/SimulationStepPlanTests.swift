//
//  SimulationStepPlanTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

/// The stepping policy alone, without a frame, a registry or a backend: the fixed arm is the
/// old accumulator loop bit for bit, and the per-frame arm lands on every frame at any rate.
final class SimulationStepPlanTests: XCTestCase {
    private let h: Float = 1.0 / 60.0

    private func plan(_ stepping: SimulationStepping, _ delta: Float, carried: Float = 0) -> SimulationStepPlan {
        SimulationStepPlan(stepping: stepping, frameDelta: delta, accumulator: carried, fixedStep: h)
    }

    /// The loop as `runFrame` ran it at 8e105612 (L695-711), transcribed: the reference the
    /// fixed arm is held to, operation for operation.
    private func oldAccumulatorLoop(accumulator: Float, frameDelta: Float) -> (steps: Int, accumulator: Float) {
        var physicsAccumulator = accumulator
        physicsAccumulator += frameDelta
        let maxSteps = 5
        var steps = 0
        while physicsAccumulator >= h, steps < maxSteps {
            physicsAccumulator -= h
            steps += 1
        }
        return (steps, physicsAccumulator)
    }

    private func stepCounts(_ stepping: SimulationStepping, frames: [Float]) -> [Int] {
        var carried: Float = 0
        return frames.map { delta in
            let result = plan(stepping, delta, carried: carried)
            carried = result.accumulator
            return result.stepCount
        }
    }

    // MARK: - Fixed

    func testFixedSteppingIsTheOldAccumulatorLoopBitForBit() {
        // Five exact steps from a zero accumulator first, the one case where the carried value
        // meets the step exactly and `>=` is what decides; then a seeded LCG, which keeps the
        // sequence the same on every run: 5,000 deltas in 0 ... 0.12 s, then the 100 Hz cadence
        // and the edge values a frame can produce.
        var state: UInt32 = 12345
        var deltas: [Float] = Array(repeating: h, count: 5)
        for _ in 0 ..< 5000 {
            state = state &* 1_664_525 &+ 1_013_904_223
            deltas.append(Float(state >> 8) / Float(1 << 24) * 0.12)
        }
        deltas += Array(repeating: 0.010, count: 10)
        deltas += [0, h, 2 * h, 0.1]

        var oldAccumulator: Float = 0
        var newAccumulator: Float = 0
        for (index, delta) in deltas.enumerated() {
            let old = oldAccumulatorLoop(accumulator: oldAccumulator, frameDelta: delta)
            let new = plan(.fixed, delta, carried: newAccumulator)
            XCTAssertEqual(new.stepCount, old.steps, "frame \(index)")
            XCTAssertEqual(new.stepDelta, h, "frame \(index)")
            XCTAssertEqual(new.accumulator.bitPattern, old.accumulator.bitPattern, "frame \(index)")
            oldAccumulator = old.accumulator
            newAccumulator = new.accumulator
        }
    }

    func testFixedSteppingAtAHundredHertzLeavesTwoFramesInFiveWithoutAStep() {
        // The defect as numbers: on a 100 Hz display two frames in five run no step, on a
        // 90 Hz one one in three. Whatever only moves in a step stands still on those frames.
        XCTAssertEqual(
            stepCounts(.fixed, frames: Array(repeating: 0.010, count: 10)),
            [0, 1, 0, 1, 0, 1, 1, 0, 1, 0]
        )
        XCTAssertEqual(
            stepCounts(.fixed, frames: Array(repeating: 1.0 / 90.0, count: 9)),
            [0, 1, 0, 1, 1, 0, 1, 1, 0]
        )
    }

    func testFixedSteppingAtExactlySixtyHertzStepsOnceAFrameAndCarriesNothing() {
        // The carried value meets the step exactly: it is `>=`, not `>`, that runs the step,
        // and the residual is a true zero, not a sliver.
        var carried: Float = 0
        for frame in 0 ..< 5 {
            let result = plan(.fixed, h, carried: carried)
            XCTAssertEqual(result.stepCount, 1, "frame \(frame)")
            XCTAssertEqual(result.accumulator.bitPattern, 0, "frame \(frame)")
            carried = result.accumulator
        }
    }

    // MARK: - Per frame

    func testPerFrameSteppingLandsOneStepOfTheFrameDeltaOnEveryFrame() {
        let cadences: [Float] = [0.010, 1.0 / 90.0]
        for delta in cadences {
            var carried: Float = 0
            for frame in 0 ..< 10 {
                let result = plan(.perFrame, delta, carried: carried)
                XCTAssertEqual(result.stepCount, 1, "frame \(frame) at \(delta)")
                XCTAssertEqual(result.stepDelta, delta, "frame \(frame) at \(delta)")
                XCTAssertEqual(result.accumulator, 0, "frame \(frame) at \(delta)")
                carried = result.accumulator
            }
        }
    }

    func testPerFrameSteppingKeepsAJitteredSixtyHertzFrameWhole() {
        // A 60 Hz frame's wall-clock jitter is noise: it stays one step up to a tenth of a
        // step over. The edge is recorded deliberately: 18.4 ms is two.
        let jittered: [Float] = [h, 0.0166, 0.0168, 0.018]
        for delta in jittered {
            let result = plan(.perFrame, delta)
            XCTAssertEqual(result.stepCount, 1, "\(delta)")
            XCTAssertEqual(result.stepDelta, delta, "\(delta)")
        }
        let halved = plan(.perFrame, 0.0184)
        XCTAssertEqual(halved.stepCount, 2)
        XCTAssertEqual(halved.stepDelta, 0.0092, accuracy: 1e-7)
    }

    func testPerFrameSteppingDividesALongFrameIntoEqualSubSteps() {
        let expectations: [(delta: Float, count: Int, stepDelta: Float)] = [
            (0.020, 2, 0.010),
            (2.0 / 90.0, 2, 1.0 / 90.0),
            (0.035, 2, 0.0175),
            (0.040, 3, 0.040 / 3),
            (0.050, 3, h),
        ]
        for expectation in expectations {
            let result = plan(.perFrame, expectation.delta)
            XCTAssertEqual(result.stepCount, expectation.count, "\(expectation.delta)")
            XCTAssertEqual(result.stepDelta, expectation.stepDelta, accuracy: 1e-7, "\(expectation.delta)")
            XCTAssertLessThanOrEqual(result.stepDelta, 1.1 * h, "\(expectation.delta)")
            XCTAssertEqual(Float(result.stepCount) * result.stepDelta, expectation.delta, accuracy: 1e-7, "\(expectation.delta)")
            XCTAssertEqual(result.accumulator, 0, "\(expectation.delta)")
        }
    }

    func testPerFrameSteppingCapsAStallAtFiveFixedStepsAndCarriesNothing() {
        let stalls: [Float] = [0.1, 0.5]
        for delta in stalls {
            let result = plan(.perFrame, delta)
            XCTAssertEqual(result.stepCount, 5, "\(delta)")
            XCTAssertEqual(result.stepDelta, h, accuracy: 1e-7, "\(delta)")
            XCTAssertEqual(result.accumulator, 0, "\(delta)")
        }
    }

    func testPerFrameSteppingRunsNothingWithoutTime() {
        let noTime: [Float] = [0, -0.01, .nan, .infinity]
        for delta in noTime {
            let result = plan(.perFrame, delta)
            XCTAssertEqual(result.stepCount, 0, "\(delta)")
            XCTAssertEqual(result.stepDelta, 0, "\(delta)")
            XCTAssertEqual(result.accumulator, 0, "\(delta)")
        }
    }

    func testPerFrameSteppingRunsNothingForASecondDrawOfOneRefresh() {
        // A spacing under the clock's shortest period is a second draw for one refresh, not a
        // frame of the display: nothing is simulated and nothing is carried. The floor itself
        // is a frame.
        let slivers: [Float] = [0.001, 0.003, 0.0039]
        for delta in slivers {
            let result = plan(.perFrame, delta)
            XCTAssertEqual(result.stepCount, 0, "\(delta)")
            XCTAssertEqual(result.stepDelta, 0, "\(delta)")
            XCTAssertEqual(result.accumulator, 0, "\(delta)")
        }
        let shortest = plan(.perFrame, SimulationStepPlan.shortestFrame)
        XCTAssertEqual(shortest.stepCount, 1)
        XCTAssertEqual(shortest.stepDelta, SimulationStepPlan.shortestFrame)
    }

    func testSwitchingModesDropsTheResidualAndFixedResumesFromZero() {
        let fixed = plan(.fixed, 0.010, carried: 0.0133)
        XCTAssertEqual(fixed.stepCount, 1)
        XCTAssertEqual(fixed.accumulator, 0.0133 + 0.010 - h, accuracy: 1e-6)

        let perFrame = plan(.perFrame, 0.010, carried: fixed.accumulator)
        XCTAssertEqual(perFrame.stepCount, 1)
        XCTAssertEqual(perFrame.stepDelta, 0.010)
        XCTAssertEqual(perFrame.accumulator, 0)

        let resumed = plan(.fixed, 0.010, carried: perFrame.accumulator)
        XCTAssertEqual(resumed.stepCount, 0)
        XCTAssertEqual(resumed.accumulator, 0.010)
    }

    func testPerFrameSubStepsNeverExceedTheBoundAcrossASweep() {
        // From the shortest frame that is stepped at all up to a quarter-second stall.
        var delta = SimulationStepPlan.shortestFrame
        while delta <= 0.25 {
            let result = plan(.perFrame, delta)
            XCTAssertGreaterThanOrEqual(result.stepCount, 1, "\(delta)")
            XCTAssertLessThanOrEqual(result.stepCount, 5, "\(delta)")
            XCTAssertLessThanOrEqual(result.stepDelta, 1.1 * h, "\(delta)")
            XCTAssertEqual(Float(result.stepCount) * result.stepDelta, min(delta, 5 * h), accuracy: 1e-6, "\(delta)")
            XCTAssertEqual(result.accumulator, 0, "\(delta)")
            delta += 0.0005
        }
    }
}

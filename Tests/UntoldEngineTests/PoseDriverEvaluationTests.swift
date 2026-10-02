//
//  PoseDriverEvaluationTests.swift
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

final class PoseDriverEvaluationTests: XCTestCase {
    private let rest = simd_quatf(angle: 0.35, axis: simd_normalize(simd_float3(0.2, 0.9, 0.1)))
    private let driverPose = simd_quatf(angle: 1.92, axis: simd_float3(1, 0, 0)) // ~110° elbow curl

    func testExamplePoseActivatesAtExactlyOne() {
        // The clip-sampled local rotation composes as rest ∘ basis; feeding
        // exactly that must return full weight.
        let current = rest * driverPose
        let weight = PoseDriverEvaluation.weight(
            currentLocalRotation: current,
            restLocalRotation: rest,
            driverPose: driverPose,
            radius: 0.9
        )
        XCTAssertEqual(weight, 1.0, accuracy: 1e-4)
    }

    func testRestPoseIsInactive() {
        let weight = PoseDriverEvaluation.weight(
            currentLocalRotation: rest,
            restLocalRotation: rest,
            driverPose: driverPose,
            radius: 0.9
        )
        XCTAssertEqual(weight, 0.0, "A 110° driver must not fire at rest")
    }

    func testFalloffIsMonotonicTowardTheDriverPose() {
        var previous: Float = -1
        for step in stride(from: Float(0), through: 1, by: 0.25) {
            let partial = rest * simd_quatf(angle: 1.92 * step, axis: simd_float3(1, 0, 0))
            let weight = PoseDriverEvaluation.weight(
                currentLocalRotation: partial,
                restLocalRotation: rest,
                driverPose: driverPose,
                radius: 1.2
            )
            XCTAssertGreaterThanOrEqual(weight, previous, "weight must grow as the pose approaches the driver")
            previous = weight
        }
        XCTAssertEqual(previous, 1.0, accuracy: 1e-4)
    }

    func testAntipodalQuaternionsCompareEqual() {
        // q and -q are the same rotation; the driver must fire either way.
        let current = rest * driverPose
        let negatedDriver = simd_quatf(vector: -driverPose.vector)
        let weight = PoseDriverEvaluation.weight(
            currentLocalRotation: current,
            restLocalRotation: rest,
            driverPose: negatedDriver,
            radius: 0.9
        )
        XCTAssertEqual(weight, 1.0, accuracy: 1e-4)
    }

    func testRestRotationExtractionIgnoresScale() {
        var transform = simd_float4x4(rest)
        transform.columns.0 *= 0.01
        transform.columns.1 *= 0.01
        transform.columns.2 *= 0.01
        let extracted = PoseDriverEvaluation.restRotation(from: transform)
        XCTAssertEqual(abs(simd_dot(extracted.vector, rest.vector)), 1.0, accuracy: 1e-4)
    }
}

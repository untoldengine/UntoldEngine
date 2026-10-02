//
//  ExternalPoseTests.swift
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

final class ExternalPoseTests: XCTestCase {
    private func restPose(for skeleton: Skeleton) -> PoseBuffer {
        var pose = PoseBuffer()
        pose.resize(jointCount: skeleton.jointPaths.count)
        for joint in 0 ..< skeleton.jointPaths.count {
            let rest = skeleton.restTransform[joint]
            pose.translations[joint] = simd_float3(rest.columns.3.x, rest.columns.3.y, rest.columns.3.z)
            pose.rotations[joint] = PoseDriverEvaluation.restRotation(from: rest)
        }
        return pose
    }

    private func worldRotations(skeleton: Skeleton, pose: PoseBuffer) -> [simd_quatf] {
        var world: [simd_quatf] = []
        for joint in 0 ..< skeleton.jointPaths.count {
            if let parent = skeleton.parentIndices[joint] {
                world.append(simd_normalize(world[parent] * pose.rotations[joint]))
            } else {
                world.append(pose.rotations[joint])
            }
        }
        return world
    }

    private func assertEqual(_ a: simd_quatf, _ b: simd_quatf, accuracy: Float = 1e-4, line: UInt = #line) {
        XCTAssertGreaterThan(abs(simd_dot(a.vector, b.vector)), 1 - accuracy, "\(a) vs \(b)", line: line)
    }

    /// Driving the forearm and the upper arm by world deltas reaches exactly
    /// those world orientations; undriven joints keep their local pose.
    func testWorldDeltasSolveThroughTheHierarchy() {
        let skeleton = MuscleGeometryTests.makeArmSkeleton()
        var pose = restPose(for: skeleton)
        var state = ExternalPoseState()
        state.worldRotationDeltas = [simd_quatf?](repeating: nil, count: skeleton.jointPaths.count)
        let upperArmDelta = simd_quatf(angle: 0.7, axis: simd_float3(0, 1, 0))
        let forearmDelta = simd_quatf(angle: -1.2, axis: simd_float3(0, 0, 1))
        state.worldRotationDeltas[1] = upperArmDelta
        state.worldRotationDeltas[2] = forearmDelta

        applyExternalPose(state: &state, skeleton: skeleton, pose: &pose)

        let world = worldRotations(skeleton: skeleton, pose: pose)
        let rest = restWorldRotations(of: skeleton)
        assertEqual(world[1], upperArmDelta * rest[1])
        assertEqual(world[2], forearmDelta * rest[2])
        // The hand (undriven) keeps its rest local rotation, so its world
        // orientation follows the forearm.
        assertEqual(pose.rotations[3], PoseDriverEvaluation.restRotation(from: skeleton.restTransform[3]))
        assertEqual(world[3], world[2] * pose.rotations[3])
        // The foot chain is untouched.
        assertEqual(world[4], rest[4])
    }

    func testWeightBlendsAndRootTranslationIsAppliedInParentSpace() {
        let skeleton = MuscleGeometryTests.makeArmSkeleton()
        var pose = restPose(for: skeleton)
        let restTranslation = pose.translations[1]
        var state = ExternalPoseState()
        state.worldRotationDeltas = [simd_quatf?](repeating: nil, count: skeleton.jointPaths.count)
        state.worldRotationDeltas[2] = simd_quatf(angle: 1.0, axis: simd_float3(0, 0, 1))
        state.rootJointIndex = 1
        state.rootTranslationDelta = simd_float3(0, -0.1, 0)
        state.weight = 0.5

        applyExternalPose(state: &state, skeleton: skeleton, pose: &pose)

        // Half the delta: the forearm turned 0.5 rad, the root moved half way.
        assertEqual(pose.rotations[2], simd_quatf(angle: 0.5, axis: simd_float3(0, 0, 1)), accuracy: 1e-3)
        XCTAssertEqual(pose.translations[1].y, restTranslation.y - 0.05, accuracy: 1e-5)

        state.clear()
        XCTAssertFalse(state.isActive)
    }
}

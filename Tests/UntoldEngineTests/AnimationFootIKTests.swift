//
//  AnimationFootIKTests.swift
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

@MainActor
final class AnimationFootIKTests: XCTestCase {
    var entityId: EntityID!

    private let deltaTime: Float = 1.0 / 90.0
    private let identityRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)

    // Chain: root at origin, hip at y=0.9, knee at y=0.45, ankle at y=0.1.
    // Leg reach = 0.8, fully extended straight down in the rest pose.
    private let jointPaths = ["root", "root/hip", "root/hip/knee", "root/hip/knee/ankle"]
    private var hipIndex: Int {
        1
    }

    private var ankleIndex: Int {
        3
    }

    override func setUp() async throws {
        resetEngineTestState()

        entityId = createEntity()
        registerComponent(entityId: entityId, componentType: SkeletonComponent.self)
        registerComponent(entityId: entityId, componentType: AnimationComponent.self)
        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)

        let locals = [
            simd_float4x4.identity,
            simd_float4x4(translation: simd_float3(0, 0.9, 0)),
            simd_float4x4(translation: simd_float3(0, -0.45, 0)),
            simd_float4x4(translation: simd_float3(0, -0.35, 0)),
        ]
        // Bind transforms are model-space accumulations of the locals.
        let binds = [
            simd_float4x4.identity,
            simd_float4x4(translation: simd_float3(0, 0.9, 0)),
            simd_float4x4(translation: simd_float3(0, 0.45, 0)),
            simd_float4x4(translation: simd_float3(0, 0.1, 0)),
        ]
        let runtimeSkeleton = RuntimeSkeleton(
            jointPaths: jointPaths,
            parentIndices: [nil, 0, 1, 2],
            bindTransforms: binds,
            restTransforms: locals
        )
        scene.get(component: SkeletonComponent.self, for: entityId)?.skeleton =
            Skeleton(runtimeSkeleton: runtimeSkeleton)

        // Constant standing pose so foot placement is fully deterministic.
        let channels = jointPaths.enumerated().map { index, path in
            RuntimeAnimationChannel(
                jointPath: path,
                translations: [
                    .init(time: 0.0, value: localTranslation(of: locals[index])),
                    .init(time: 1.0, value: localTranslation(of: locals[index])),
                ],
                rotations: [
                    .init(time: 0.0, value: SIMD4<Float>(0, 0, 0, 1)),
                    .init(time: 1.0, value: SIMD4<Float>(0, 0, 0, 1)),
                ]
            )
        }
        let clip = AnimationClip(runtimeClip: RuntimeAnimationClip(name: "stand", duration: 1.0, channels: channels))

        let animationComponent = scene.get(component: AnimationComponent.self, for: entityId)!
        animationComponent.animationClips["stand"] = clip

        setFootIKChains(entityId: entityId, chains: [
            FootIKChainDescriptor(hipPath: "root/hip", kneePath: "root/hip/knee", anklePath: "root/hip/knee/ankle"),
        ])
    }

    override func tearDown() async throws {
        destroyEntity(entityId: entityId)
    }

    private func localTranslation(of matrix: simd_float4x4) -> simd_float3 {
        simd_float3(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
    }

    private var animationComponent: AnimationComponent {
        scene.get(component: AnimationComponent.self, for: entityId)!
    }

    /// Model-space ankle position recomputed from the component's pose.
    private func anklePosition() -> simd_float3 {
        var positions: [simd_float3] = []
        var rotations: [simd_quatf] = []
        computeForwardKinematics(
            pose: animationComponent.localPose,
            parentIndices: [nil, 0, 1, 2],
            positions: &positions,
            rotations: &rotations
        )
        return positions[ankleIndex]
    }

    private func playOneFrame(groundHeight: Float?) {
        setFootIKGroundQuery(entityId: entityId) { _ in
            groundHeight.map { FootIKGroundSample(height: $0) }
        }
        changeAnimation(entityId: entityId, name: "stand", transitionHalflife: 0)
        AnimationSystem.shared.update(deltaTime)
    }

    // MARK: - Two-bone solver

    private func forwardKinematics(
        a: simd_float3, b: simd_float3, c: simd_float3,
        aLocal: simd_quatf, bLocal: simd_quatf
    ) -> simd_float3 {
        let bNew = a + aLocal.act(b - a)
        return bNew + (aLocal * bLocal).act(c - b)
    }

    func testSolverReachesReachableTarget() {
        let a = simd_float3(0, 2, 0)
        let b = simd_float3(0.05, 1, 0)
        let c = simd_float3(0, 0, 0)
        let target = simd_float3(0.5, 0.8, 0)

        var aLocal = identityRotation
        var bLocal = identityRotation
        solveTwoBoneIK(
            a: a, b: b, c: c, target: target, bendHint: simd_float3(0, 0, 1),
            aGlobalRotation: identityRotation, bGlobalRotation: identityRotation,
            aLocalRotation: &aLocal, bLocalRotation: &bLocal
        )

        let solved = forwardKinematics(a: a, b: b, c: c, aLocal: aLocal, bLocal: bLocal)
        XCTAssertLessThan(simd_length(solved - target), 2e-3, "Solved ankle must land on the target")
    }

    func testSolverClampsUnreachableTarget() {
        let a = simd_float3(0, 2, 0)
        let b = simd_float3(0.05, 1, 0)
        let c = simd_float3(0, 0, 0)
        let reach = simd_length(b - a) + simd_length(c - b)
        let target = simd_float3(3, 2, 0)

        var aLocal = identityRotation
        var bLocal = identityRotation
        solveTwoBoneIK(
            a: a, b: b, c: c, target: target, bendHint: simd_float3(0, 0, 1),
            aGlobalRotation: identityRotation, bGlobalRotation: identityRotation,
            aLocalRotation: &aLocal, bLocalRotation: &bLocal
        )

        let solved = forwardKinematics(a: a, b: b, c: c, aLocal: aLocal, bLocal: bLocal)
        XCTAssertEqual(simd_length(solved - a), reach, accuracy: 2e-3, "Chain must extend to full reach")
        let direction = simd_normalize(target - a)
        let solvedDirection = simd_normalize(solved - a)
        XCTAssertLessThan(simd_length(direction - solvedDirection), 2e-3, "Chain must point at the target")
    }

    func testSolverHandlesStraightChainWithBendHint() {
        let a = simd_float3(0, 2, 0)
        let b = simd_float3(0, 1, 0)
        let c = simd_float3(0, 0, 0)
        let target = simd_float3(0.6, 1.2, 0)

        var aLocal = identityRotation
        var bLocal = identityRotation
        solveTwoBoneIK(
            a: a, b: b, c: c, target: target, bendHint: simd_float3(0, 0, 1),
            aGlobalRotation: identityRotation, bGlobalRotation: identityRotation,
            aLocalRotation: &aLocal, bLocalRotation: &bLocal
        )

        let solved = forwardKinematics(a: a, b: b, c: c, aLocal: aLocal, bLocal: bLocal)
        XCTAssertLessThan(simd_length(solved - target), 2e-3, "Straight chain must still reach via the bend hint")
    }

    // MARK: - Foot placement

    func testFootLiftsOntoRaisedGround() {
        setFootIKEnabled(entityId: entityId, enabled: true)
        playOneFrame(groundHeight: 0.2)

        // Ground at 0.2 plus the ankle's authored height (0.1) above the
        // clip's ground plane.
        let ankle = anklePosition()
        XCTAssertEqual(ankle.y, 0.3, accuracy: 2e-3)
        XCTAssertEqual(ankle.x, 0, accuracy: 2e-3)
        XCTAssertEqual(ankle.z, 0, accuracy: 2e-3)
    }

    func testUnreachableGroundClampsAtFullExtension() {
        setFootIKEnabled(entityId: entityId, enabled: true)
        // Desired ankle would be at -0.4; the leg (reach 0.8 from hip at
        // 0.9) is already fully extended at 0.1 and cannot go lower.
        playOneFrame(groundHeight: -0.5)

        XCTAssertEqual(anklePosition().y, 0.1, accuracy: 2e-3, "Fully extended leg cannot reach below full extension")
    }

    func testCorrectionBeyondMaxAdjustmentIsIgnored() {
        setFootIKEnabled(entityId: entityId, enabled: true)
        playOneFrame(groundHeight: 5.0)

        XCTAssertEqual(anklePosition().y, 0.1, accuracy: 1e-4, "A sample far above the foot is not ground; pose must be untouched")
    }

    func testDisabledByDefault() {
        var queried = false
        setFootIKGroundQuery(entityId: entityId) { _ in
            queried = true
            return FootIKGroundSample(height: 0.2)
        }
        changeAnimation(entityId: entityId, name: "stand", transitionHalflife: 0)
        AnimationSystem.shared.update(deltaTime)

        XCTAssertFalse(isFootIKEnabled(entityId: entityId))
        XCTAssertFalse(queried, "Disabled foot IK must not sample the ground")
        XCTAssertEqual(anklePosition().y, 0.1, accuracy: 1e-5)
    }

    func testMissingGroundLeavesPoseUntouched() {
        setFootIKEnabled(entityId: entityId, enabled: true)
        playOneFrame(groundHeight: nil)

        XCTAssertEqual(anklePosition().y, 0.1, accuracy: 1e-5)
    }

    func testInvalidChainPathsAreIgnored() {
        setFootIKChains(entityId: entityId, chains: [
            FootIKChainDescriptor(hipPath: "no/such", kneePath: "no/such/knee", anklePath: "no/such/ankle"),
        ])
        setFootIKEnabled(entityId: entityId, enabled: true)
        playOneFrame(groundHeight: 0.2)

        XCTAssertEqual(anklePosition().y, 0.1, accuracy: 1e-5, "Unresolvable chains must be dropped without effect")
    }

    func testEnableDisableRoundTrip() {
        setFootIKEnabled(entityId: entityId, enabled: true)
        XCTAssertTrue(isFootIKEnabled(entityId: entityId))
        setFootIKEnabled(entityId: entityId, enabled: false)
        XCTAssertFalse(isFootIKEnabled(entityId: entityId))
    }
}

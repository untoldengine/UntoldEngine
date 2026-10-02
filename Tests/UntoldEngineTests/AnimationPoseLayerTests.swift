//
//  AnimationPoseLayerTests.swift
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
final class AnimationPoseLayerTests: XCTestCase {
    var entityId: EntityID!

    private let deltaTime: Float = 1.0 / 60.0

    // Chain: root at origin, shoulder at y=1.4, elbow 0.3 below, hand 0.3
    // below that — an arm hanging straight down, reach 0.6.
    private let jointPaths = ["root", "root/shoulder", "root/shoulder/elbow", "root/shoulder/elbow/hand"]
    private let raised = simd_quatf(angle: .pi / 2, axis: simd_float3(1, 0, 0))

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
            simd_float4x4(translation: simd_float3(0, 1.4, 0)),
            simd_float4x4(translation: simd_float3(0, -0.3, 0)),
            simd_float4x4(translation: simd_float3(0, -0.3, 0)),
        ]
        let binds = [
            simd_float4x4.identity,
            simd_float4x4(translation: simd_float3(0, 1.4, 0)),
            simd_float4x4(translation: simd_float3(0, 1.1, 0)),
            simd_float4x4(translation: simd_float3(0, 0.8, 0)),
        ]
        scene.get(component: SkeletonComponent.self, for: entityId)?.skeleton = Skeleton(runtimeSkeleton: RuntimeSkeleton(
            jointPaths: jointPaths, parentIndices: [nil, 0, 1, 2], bindTransforms: binds, restTransforms: locals
        ))

        func clip(name: String, shoulder: simd_quatf) -> AnimationClip {
            let channels = jointPaths.enumerated().map { index, path in
                let rotation = index == 1 ? shoulder : simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
                let key = SIMD4<Float>(rotation.imag.x, rotation.imag.y, rotation.imag.z, rotation.real)
                return RuntimeAnimationChannel(
                    jointPath: path,
                    translations: [
                        .init(time: 0.0, value: localTranslation(of: locals[index])),
                        .init(time: 1.0, value: localTranslation(of: locals[index])),
                    ],
                    rotations: [.init(time: 0.0, value: key), .init(time: 1.0, value: key)]
                )
            }
            return AnimationClip(runtimeClip: RuntimeAnimationClip(name: name, duration: 1.0, channels: channels))
        }
        let animationComponent = scene.get(component: AnimationComponent.self, for: entityId)!
        animationComponent.animationClips["hang"] = clip(name: "hang", shoulder: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1))
        animationComponent.animationClips["raise"] = clip(name: "raise", shoulder: raised)
        changeAnimation(entityId: entityId, name: "hang", transitionHalflife: 0)
    }

    override func tearDown() async throws {
        destroyEntity(entityId: entityId)
    }

    private var animationComponent: AnimationComponent {
        scene.get(component: AnimationComponent.self, for: entityId)!
    }

    private func localTranslation(of matrix: simd_float4x4) -> simd_float3 {
        simd_float3(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
    }

    private func shoulderAngle() -> Float {
        simd_length(toScaledAngleAxis(animationComponent.localPose.rotations[1]))
    }

    private func handPosition() -> simd_float3 {
        var positions: [simd_float3] = []
        var rotations: [simd_quatf] = []
        computeForwardKinematics(
            pose: animationComponent.localPose, parentIndices: [nil, 0, 1, 2],
            positions: &positions, rotations: &rotations
        )
        return positions[3]
    }

    // MARK: - Pose layer

    func testLayerReplacesMaskedJointsAtFullWeight() {
        setPoseLayerMask(entityId: entityId, rootJointPaths: ["root/shoulder"])
        setPoseLayerClip(entityId: entityId, name: "raise", transitionHalflife: 0)
        setPoseLayerWeight(entityId: entityId, weight: 1, halflife: 0)
        AnimationSystem.shared.update(deltaTime)

        XCTAssertEqual(shoulderAngle(), .pi / 2, accuracy: 1e-3)
        XCTAssertEqual(simd_length(toScaledAngleAxis(animationComponent.localPose.rotations[0])), 0, accuracy: 1e-5)
        XCTAssertEqual(simd_length(toScaledAngleAxis(animationComponent.localPose.rotations[2])), 0, accuracy: 1e-5)
    }

    func testLayerWeightBlendsHalfway() {
        setPoseLayerMask(entityId: entityId, rootJointPaths: ["root/shoulder"])
        setPoseLayerClip(entityId: entityId, name: "raise", transitionHalflife: 0)
        setPoseLayerWeight(entityId: entityId, weight: 0.5, halflife: 0)
        AnimationSystem.shared.update(deltaTime)

        XCTAssertEqual(shoulderAngle(), .pi / 4, accuracy: 1e-2)
    }

    func testLayerWeightAndClipSwitchEaseInsteadOfCutting() {
        setPoseLayerMask(entityId: entityId, rootJointPaths: ["root/shoulder"])
        setPoseLayerClip(entityId: entityId, name: "raise", transitionHalflife: 0)
        setPoseLayerWeight(entityId: entityId, weight: 1, halflife: 0.1)

        // Weight: one halflife brings the arm halfway, a second none of it.
        var angles: [Float] = []
        for _ in 0 ..< 60 {
            AnimationSystem.shared.update(deltaTime)
            angles.append(shoulderAngle())
        }
        XCTAssertEqual(angles[5], .pi / 4, accuracy: 0.08)
        XCTAssertEqual(angles[59], .pi / 2, accuracy: 1e-2)
        XCTAssertTrue(zip(angles, angles.dropFirst()).allSatisfy { $0 <= $1 + 1e-5 })

        // Clip switch: the outgoing clip fades over its halflife.
        setPoseLayerClip(entityId: entityId, name: "hang", transitionHalflife: 0.1)
        angles.removeAll()
        for _ in 0 ..< 60 {
            AnimationSystem.shared.update(deltaTime)
            angles.append(shoulderAngle())
        }
        XCTAssertEqual(angles[5], .pi / 4, accuracy: 0.08)
        XCTAssertEqual(angles[59], 0, accuracy: 1e-2)
        XCTAssertTrue(zip(angles, angles.dropFirst()).allSatisfy { $0 >= $1 - 1e-5 })
    }

    // MARK: - Reach IK

    private func configureReach() {
        setReachIKChains(entityId: entityId, chains: [
            ReachIKChainDescriptor(
                shoulderPath: "root/shoulder", elbowPath: "root/shoulder/elbow", handPath: "root/shoulder/elbow/hand",
                bendDirection: simd_float3(1, 0, 0)
            ),
        ])
    }

    func testReachTouchesATargetWithinReach() {
        configureReach()
        let target = simd_float3(0.3, 1.0, 0.2)
        setReachIKTarget(entityId: entityId, worldPosition: target, weight: 1, halflife: 0)
        AnimationSystem.shared.update(deltaTime)

        XCTAssertLessThan(simd_distance(handPosition(), target), 0.01)
    }

    func testReachPointsAtATargetBeyondReach() {
        configureReach()
        setReachIKTarget(entityId: entityId, worldPosition: simd_float3(0, 1.4, 5), weight: 1, halflife: 0, reach: 0.95)
        AnimationSystem.shared.update(deltaTime)

        // 95% of the 0.6 m arm along +z from the shoulder.
        XCTAssertLessThan(simd_distance(handPosition(), simd_float3(0, 1.4, 0.57)), 0.01)
    }

    func testReachFollowsAJumpingTargetOverSeveralFrames() {
        configureReach()
        setReachIKTarget(entityId: entityId, worldPosition: simd_float3(0.3, 1.0, 0.2), weight: 1, halflife: 0)
        AnimationSystem.shared.update(deltaTime)
        let before = handPosition()
        // The target jumps to the other side: the hand crosses over in a
        // few frames, not one.
        setReachIKTarget(entityId: entityId, worldPosition: simd_float3(-0.3, 1.0, 0.2), weight: 1, halflife: 0)
        AnimationSystem.shared.update(deltaTime)
        let afterOne = handPosition()
        XCTAssertLessThan(abs(afterOne.x - before.x), 0.15)
        for _ in 0 ..< 40 {
            AnimationSystem.shared.update(deltaTime)
        }
        XCTAssertLessThan(simd_distance(handPosition(), simd_float3(-0.3, 1.0, 0.2)), 0.01)
    }

    func testReachEasesOutWhenReleased() {
        configureReach()
        setReachIKTarget(entityId: entityId, worldPosition: simd_float3(0, 1.4, 5), weight: 1, halflife: 0)
        AnimationSystem.shared.update(deltaTime)
        setReachIKTarget(entityId: entityId, worldPosition: nil, halflife: 0.1)
        var hands: [simd_float3] = []
        for _ in 0 ..< 60 {
            AnimationSystem.shared.update(deltaTime)
            hands.append(handPosition())
        }
        XCTAssertGreaterThan(hands[5].z, 0.2)
        XCTAssertLessThan(hands[59].z, 0.01)
        XCTAssertNil(animationComponent.reachIK.targetWorld)
    }
}

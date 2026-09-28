//
//  AnimationReachChainTargetTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

/// Reach IK with a target per chain: two arms, each going its own way.
@MainActor
final class AnimationReachChainTargetTests: XCTestCase {
    var entityId: EntityID!

    private let deltaTime: Float = 1.0 / 60.0

    /// Two arms hanging straight down from shoulders 0.2 m either side of
    /// the root at y = 1.4; upper arm and forearm 0.3 m each.
    private let jointPaths = [
        "root",
        "root/shoulder_l", "root/shoulder_l/elbow_l", "root/shoulder_l/elbow_l/hand_l",
        "root/shoulder_r", "root/shoulder_r/elbow_r", "root/shoulder_r/elbow_r/hand_r",
    ]
    private let parents: [Int?] = [nil, 0, 1, 2, 0, 4, 5]
    private let leftShoulder = simd_float3(0.2, 1.4, 0)
    private let rightShoulder = simd_float3(-0.2, 1.4, 0)

    override func setUp() async throws {
        resetEngineTestState()

        entityId = createEntity()
        registerComponent(entityId: entityId, componentType: SkeletonComponent.self)
        registerComponent(entityId: entityId, componentType: AnimationComponent.self)
        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)

        let down = simd_float3(0, -0.3, 0)
        let localTranslations = [simd_float3(0, 0, 0), leftShoulder, down, down, rightShoulder, down, down]
        let bindTranslations = [
            simd_float3(0, 0, 0),
            leftShoulder, leftShoulder + down, leftShoulder + down * 2,
            rightShoulder, rightShoulder + down, rightShoulder + down * 2,
        ]
        scene.get(component: SkeletonComponent.self, for: entityId)?.skeleton = Skeleton(runtimeSkeleton: RuntimeSkeleton(
            jointPaths: jointPaths, parentIndices: parents,
            bindTransforms: bindTranslations.map { simd_float4x4(translation: $0) },
            restTransforms: localTranslations.map { simd_float4x4(translation: $0) }
        ))

        let identity = SIMD4<Float>(0, 0, 0, 1)
        let channels = jointPaths.enumerated().map { index, path in
            RuntimeAnimationChannel(
                jointPath: path,
                translations: [
                    .init(time: 0.0, value: localTranslations[index]),
                    .init(time: 1.0, value: localTranslations[index]),
                ],
                rotations: [.init(time: 0.0, value: identity), .init(time: 1.0, value: identity)]
            )
        }
        let animationComponent = scene.get(component: AnimationComponent.self, for: entityId)!
        animationComponent.animationClips["hang"] = AnimationClip(
            runtimeClip: RuntimeAnimationClip(name: "hang", duration: 1.0, channels: channels)
        )
        changeAnimation(entityId: entityId, name: "hang", transitionHalflife: 0)

        setReachIKChains(entityId: entityId, chains: [
            ReachIKChainDescriptor(
                shoulderPath: jointPaths[1], elbowPath: jointPaths[2], handPath: jointPaths[3],
                bendDirection: simd_float3(0, 0, -1)
            ),
            ReachIKChainDescriptor(
                shoulderPath: jointPaths[4], elbowPath: jointPaths[5], handPath: jointPaths[6],
                bendDirection: simd_float3(0, 0, -1)
            ),
        ])
    }

    override func tearDown() async throws {
        destroyEntity(entityId: entityId)
    }

    private var animationComponent: AnimationComponent {
        scene.get(component: AnimationComponent.self, for: entityId)!
    }

    /// Model-space positions of the left and right hand.
    private func hands() -> (left: simd_float3, right: simd_float3) {
        var positions: [simd_float3] = []
        var rotations: [simd_quatf] = []
        computeForwardKinematics(
            pose: animationComponent.localPose, parentIndices: parents,
            positions: &positions, rotations: &rotations
        )
        return (positions[3], positions[6])
    }

    func testEveryChainReachesItsOwnTarget() {
        let left = simd_float3(0.4, 1.2, 0.3)
        let right = simd_float3(-0.3, 1.6, 0.2)
        setReachIKChainTargets(
            entityId: entityId,
            targets: [ReachIKChainTarget(position: left), ReachIKChainTarget(position: right)],
            halflife: 0
        )
        AnimationSystem.shared.update(deltaTime)

        XCTAssertLessThan(simd_distance(hands().left, left), 0.01)
        XCTAssertLessThan(simd_distance(hands().right, right), 0.01)
    }

    func testAShoulderTargetIsAnOffsetFromTheChainsShoulder() {
        let offset = simd_float3(0.1, -0.2, 0.3)
        setReachIKChainTargets(
            entityId: entityId,
            targets: [
                ReachIKChainTarget(position: offset, space: .shoulder),
                ReachIKChainTarget(position: offset, space: .shoulder),
            ],
            halflife: 0
        )
        AnimationSystem.shared.update(deltaTime)

        XCTAssertLessThan(simd_distance(hands().left, leftShoulder + offset), 0.01)
        XCTAssertLessThan(simd_distance(hands().right, rightShoulder + offset), 0.01)
    }

    func testWorldAndModelTargetsDifferByTheEntityTransform() {
        translateTo(entityId: entityId, position: simd_float3(2, 0, 0))
        let point = simd_float3(0.3, 1.2, 0.3)
        setReachIKChainTargets(
            entityId: entityId,
            targets: [
                ReachIKChainTarget(position: point, space: .model),
                ReachIKChainTarget(position: simd_float3(2, 0, 0) + simd_float3(-0.3, 1.2, 0.3), space: .world),
            ],
            halflife: 0
        )
        AnimationSystem.shared.update(deltaTime)

        XCTAssertLessThan(simd_distance(hands().left, point), 0.01)
        XCTAssertLessThan(simd_distance(hands().right, simd_float3(-0.3, 1.2, 0.3)), 0.01)
    }

    func testAGroundTargetKeepsTheHeightOfThePose() {
        setReachIKChainTargets(
            entityId: entityId,
            targets: [ReachIKChainTarget(position: simd_float3(0.3, 5, 0.1), space: .modelGround), nil],
            halflife: 0, reach: 1
        )
        AnimationSystem.shared.update(deltaTime)

        // Over the spot, as far down as the arm reaches: the height asked
        // for (5) is ignored and the pose's own (0.8) is out of reach from
        // there, so the hand ends on the line toward it.
        let hand = hands().left
        let toGoal = simd_normalize(simd_float3(0.3, 0.8, 0.1) - leftShoulder)
        XCTAssertLessThan(simd_distance(hand, leftShoulder + toGoal * 0.6), 0.01)
    }

    func testAFullReachStraightensTheChain() {
        setReachIKChainTargets(
            entityId: entityId,
            targets: [ReachIKChainTarget(position: simd_float3(2, 0, 0), space: .shoulder), nil],
            halflife: 0, reach: 1
        )
        AnimationSystem.shared.update(deltaTime)

        let hand = hands().left
        XCTAssertFalse(hand.x.isNaN)
        XCTAssertLessThan(simd_distance(hand, leftShoulder + simd_float3(0.6, 0, 0)), 0.01)
    }

    func testAChainWithoutATargetKeepsItsPose() {
        let rest = rightShoulder + simd_float3(0, -0.6, 0)
        setReachIKChainTargets(
            entityId: entityId,
            targets: [ReachIKChainTarget(position: simd_float3(0.4, 1.2, 0.3)), nil],
            halflife: 0
        )
        AnimationSystem.shared.update(deltaTime)

        XCTAssertLessThan(simd_distance(hands().left, simd_float3(0.4, 1.2, 0.3)), 0.01)
        XCTAssertLessThan(simd_distance(hands().right, rest), 1e-4)
    }

    func testAChainWithoutATargetReachesForTheSharedOne() {
        let shared = simd_float3(-0.2, 1.4, 0.4)
        setReachIKTarget(entityId: entityId, worldPosition: shared, weight: 1, halflife: 0)
        setReachIKChainTargets(
            entityId: entityId,
            targets: [ReachIKChainTarget(position: simd_float3(0.4, 1.2, 0.3)), nil],
            halflife: 0
        )
        AnimationSystem.shared.update(deltaTime)

        XCTAssertLessThan(simd_distance(hands().left, simd_float3(0.4, 1.2, 0.3)), 0.01)
        XCTAssertLessThan(simd_distance(hands().right, shared), 0.01)
    }

    func testATargetHalflifeOfZeroFollowsTheTargetExactly() {
        let first = ReachIKChainTarget(position: simd_float3(0.1, -0.2, 0.3), space: .shoulder)
        let second = ReachIKChainTarget(position: simd_float3(-0.1, -0.3, 0.2), space: .shoulder)
        setReachIKChainTargets(entityId: entityId, targets: [first, nil], halflife: 0, targetHalflife: 0)
        AnimationSystem.shared.update(deltaTime)
        setReachIKChainTargets(entityId: entityId, targets: [second, nil], halflife: 0, targetHalflife: 0)
        AnimationSystem.shared.update(deltaTime)

        XCTAssertLessThan(simd_distance(hands().left, leftShoulder + second.position), 0.01)
    }

    func testAJumpingChainTargetIsFollowedOverSeveralFrames() {
        let first = ReachIKChainTarget(position: simd_float3(0.2, -0.2, 0.3), space: .shoulder)
        let second = ReachIKChainTarget(position: simd_float3(-0.2, -0.2, 0.3), space: .shoulder)
        setReachIKChainTargets(entityId: entityId, targets: [first, nil], halflife: 0)
        AnimationSystem.shared.update(deltaTime)
        let before = hands().left
        setReachIKChainTargets(entityId: entityId, targets: [second, nil], halflife: 0)
        AnimationSystem.shared.update(deltaTime)
        XCTAssertLessThan(abs(hands().left.x - before.x), 0.1)
        for _ in 0 ..< 40 {
            AnimationSystem.shared.update(deltaTime)
        }
        XCTAssertLessThan(simd_distance(hands().left, leftShoulder + second.position), 0.01)
    }

    func testChainTargetsEaseOutWhenReleased() {
        let rest = leftShoulder + simd_float3(0, -0.6, 0)
        setReachIKChainTargets(
            entityId: entityId,
            targets: [ReachIKChainTarget(position: simd_float3(0, 0, 0.5), space: .shoulder), nil],
            halflife: 0
        )
        AnimationSystem.shared.update(deltaTime)
        setReachIKChainTargets(entityId: entityId, targets: [], halflife: 0.1)
        var distances: [Float] = []
        for _ in 0 ..< 60 {
            AnimationSystem.shared.update(deltaTime)
            distances.append(simd_distance(hands().left, rest))
        }
        XCTAssertGreaterThan(distances[5], 0.2)
        XCTAssertLessThan(distances[59], 0.01)
        XCTAssertTrue(animationComponent.reachIK.chainTargets.isEmpty)
    }
}

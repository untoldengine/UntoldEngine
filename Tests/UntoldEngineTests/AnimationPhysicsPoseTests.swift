//
//  AnimationPhysicsPoseTests.swift
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
final class AnimationPhysicsPoseTests: XCTestCase {
    var entityId: EntityID!

    private let deltaTime: Float = 1.0 / 60.0

    // Chain: root at origin, a 1 m above it, b 0.5 m above a. The clip
    // holds a constant pose that turns a about z and b about x, so the
    // animated locals differ from the rest offsets and a joint that keeps
    // "its animated local" is distinguishable from one that keeps rest.
    private let jointPaths = ["root", "root/a", "root/a/b"]
    private let parentIndices: [Int?] = [nil, 0, 1]
    private let aOffset = simd_float3(0, 1, 0)
    private let bOffset = simd_float3(0, 0.5, 0)
    private let aRotation = simd_quatf(angle: 0.3, axis: simd_float3(0, 0, 1))
    private let bRotation = simd_quatf(angle: 0.2, axis: simd_float3(1, 0, 0))

    private var restLocals: [simd_float4x4] {
        [.identity, simd_float4x4(translation: aOffset), simd_float4x4(translation: bOffset)]
    }

    private var binds: [simd_float4x4] {
        [
            .identity,
            simd_float4x4(translation: aOffset),
            simd_float4x4(translation: aOffset + bOffset),
        ]
    }

    // Physics targets, deliberately off the animated chain.
    private let physicsA = rigid(simd_float3(0.2, 1.3, 0.1), simd_quatf(angle: 0.5, axis: simd_float3(1, 0, 0)))
    private let physicsB = rigid(simd_float3(0.3, 1.2, -0.1), simd_quatf(angle: 0.7, axis: simd_float3(0, 1, 0)))

    override func setUp() async throws {
        resetEngineTestState()

        entityId = createEntity()
        registerComponent(entityId: entityId, componentType: SkeletonComponent.self)
        registerComponent(entityId: entityId, componentType: AnimationComponent.self)
        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)

        scene.get(component: SkeletonComponent.self, for: entityId)?.skeleton = Skeleton(runtimeSkeleton: RuntimeSkeleton(
            jointPaths: jointPaths, parentIndices: parentIndices, bindTransforms: binds, restTransforms: restLocals
        ))

        let translations = [simd_float3.zero, aOffset, bOffset]
        let rotations = [simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), aRotation, bRotation]
        let channels = jointPaths.enumerated().map { index, path in
            let rotation = rotations[index]
            let key = SIMD4<Float>(rotation.imag.x, rotation.imag.y, rotation.imag.z, rotation.real)
            return RuntimeAnimationChannel(
                jointPath: path,
                translations: [
                    .init(time: 0.0, value: translations[index]),
                    .init(time: 1.0, value: translations[index]),
                ],
                rotations: [.init(time: 0.0, value: key), .init(time: 1.0, value: key)]
            )
        }
        let animationComponent = scene.get(component: AnimationComponent.self, for: entityId)!
        animationComponent.animationClips["hold"] = AnimationClip(
            runtimeClip: RuntimeAnimationClip(name: "hold", duration: 1.0, channels: channels)
        )
        changeAnimation(entityId: entityId, name: "hold", transitionHalflife: 0)
    }

    override func tearDown() async throws {
        destroyEntity(entityId: entityId)
    }

    // MARK: - Helpers

    private var animationComponent: AnimationComponent {
        scene.get(component: AnimationComponent.self, for: entityId)!
    }

    private static func rigid(_ translation: simd_float3, _ rotation: simd_quatf) -> simd_float4x4 {
        simd_float4x4(translation: translation) * simd_float4x4(rotation)
    }

    private func translation(of matrix: simd_float4x4) -> simd_float3 {
        simd_float3(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
    }

    private func rotation(of matrix: simd_float4x4) -> simd_quatf {
        AnimationClip.localRotation(from: matrix, scale: AnimationClip.localScale(from: matrix))
    }

    /// The model transforms the clip alone composes.
    private var animatedModel: [simd_float4x4] {
        let a = Self.rigid(aOffset, aRotation)
        return [.identity, a, a * Self.rigid(bOffset, bRotation)]
    }

    private func displayedModel() -> [simd_float4x4] {
        let transforms = getJointModelTransforms(entityId: entityId)
        XCTAssertNotNil(transforms)
        return transforms ?? []
    }

    private func assertMatrix(
        _ actual: simd_float4x4, _ expected: simd_float4x4, accuracy: Float = 1e-4,
        _ message: String = "", file: StaticString = #filePath, line: UInt = #line
    ) {
        for column in 0 ..< 4 {
            XCTAssertLessThan(
                simd_length(actual[column] - expected[column]), accuracy,
                "\(message) column \(column): \(actual[column]) vs \(expected[column])", file: file, line: line
            )
        }
    }

    private func setPose(weights: [Float], a: simd_float4x4? = nil, b: simd_float4x4? = nil) {
        setPhysicsPose(
            entityId: entityId,
            jointModelTransforms: [.identity, a ?? .identity, b ?? .identity],
            jointWeights: weights
        )
    }

    // MARK: - Reading the skeleton

    func testJointInfoAndModelTransformsAgreeWithTheBindPoseBeforeAnyUpdate() throws {
        let info = try XCTUnwrap(getSkeletonJointInfo(entityId: entityId))
        XCTAssertEqual(info.jointPaths, jointPaths)
        XCTAssertEqual(info.parentIndices, parentIndices)
        XCTAssertEqual(info.bindModelTransforms.count, jointPaths.count)

        let displayed = displayedModel()
        XCTAssertEqual(displayed.count, jointPaths.count)
        for index in jointPaths.indices {
            assertMatrix(info.bindModelTransforms[index], binds[index], "bind \(index)")
            assertMatrix(displayed[index], binds[index], "displayed \(index)")
            // The reported parents compose the reported bind pose through
            // the rest offsets.
            if let parent = info.parentIndices[index] {
                assertMatrix(
                    info.bindModelTransforms[parent] * restLocals[index], info.bindModelTransforms[index], "compose \(index)"
                )
            }
        }
    }

    func testModelTransformsFollowTheAnimatedPoseAfterAnUpdate() {
        AnimationSystem.shared.update(deltaTime)

        let displayed = displayedModel()
        for index in jointPaths.indices {
            assertMatrix(displayed[index], animatedModel[index], "joint \(index)")
            if let parent = parentIndices[index] {
                let local = Self.rigid(animationComponent.localPose.translations[index], animationComponent.localPose.rotations[index])
                assertMatrix(displayed[index], displayed[parent] * local, "compose \(index)")
            }
        }
    }

    func testReadersReturnNilWithoutASkeleton() {
        let bare = createEntity()
        XCTAssertNil(getSkeletonJointInfo(entityId: bare))
        XCTAssertNil(getJointModelTransforms(entityId: bare))
        XCTAssertNil(getAnimatedJointModelTransforms(entityId: bare))
        destroyEntity(entityId: bare)
    }

    func testAnimatedTransformsAreTheDisplayedOnesWithoutAPhysicsPose() throws {
        let beforeUpdate = try XCTUnwrap(getAnimatedJointModelTransforms(entityId: entityId))
        for index in jointPaths.indices {
            assertMatrix(beforeUpdate[index], binds[index], "bind \(index)")
        }

        AnimationSystem.shared.update(deltaTime)
        let animated = try XCTUnwrap(getAnimatedJointModelTransforms(entityId: entityId))
        let displayed = displayedModel()
        for index in jointPaths.indices {
            assertMatrix(animated[index], displayed[index], "joint \(index)")
        }
    }

    func testAnimatedTransformsStayTheClipsWhileAPhysicsPoseIsDisplayed() throws {
        setPose(weights: [0, 1, 1], a: physicsA, b: physicsB)
        AnimationSystem.shared.update(deltaTime)

        let displayed = displayedModel()
        assertMatrix(displayed[1], physicsA, "the displayed pose is the bodies'")
        let animated = try XCTUnwrap(getAnimatedJointModelTransforms(entityId: entityId))
        for index in jointPaths.indices {
            assertMatrix(animated[index], animatedModel[index], "joint \(index)")
        }

        // Cleared, the two agree again on the next update.
        clearPhysicsPose(entityId: entityId)
        AnimationSystem.shared.update(deltaTime)
        let after = try XCTUnwrap(getAnimatedJointModelTransforms(entityId: entityId))
        for index in jointPaths.indices {
            assertMatrix(after[index], displayedModel()[index], "joint \(index)")
        }
    }

    // MARK: - Blending

    func testFullWeightOnALeafTakesThePhysicsTransform() {
        setPose(weights: [0, 0, 1], b: physicsB)
        AnimationSystem.shared.update(deltaTime)

        let displayed = displayedModel()
        assertMatrix(displayed[2], physicsB)
        assertMatrix(displayed[1], animatedModel[1], "the unweighted parent keeps the clip")
        assertMatrix(displayed[0], .identity)
    }

    func testHalfWeightGivesTheHalfwayRotation() {
        setPose(weights: [0, 0, 0.5], b: physicsB)
        AnimationSystem.shared.update(deltaTime)

        // With the parent untouched, slerping the local rotation is the
        // same as slerping the model rotation.
        let expectedRotation = simd_slerp(rotation(of: animatedModel[2]), rotation(of: physicsB), 0.5)
        let expectedPosition = simd_mix(
            translation(of: animatedModel[2]), translation(of: physicsB), simd_float3(repeating: 0.5)
        )
        assertMatrix(displayedModel()[2], Self.rigid(expectedPosition, expectedRotation))
    }

    func testJointBelowADrivenJointKeepsItsAnimatedLocal() {
        setPose(weights: [0, 1, 0], a: physicsA)
        AnimationSystem.shared.update(deltaTime)

        let displayed = displayedModel()
        assertMatrix(displayed[1], physicsA)
        assertMatrix(displayed[2], physicsA * Self.rigid(bOffset, bRotation), "b rides on the physics-driven a")
    }

    func testTranslationFollowsPhysicsOnlyAtTheTopOfADrivenSubtree() {
        setPose(weights: [0, 1, 1], a: physicsA, b: physicsB)
        AnimationSystem.shared.update(deltaTime)

        let displayed = displayedModel()
        // a's parent is at weight 0, so a takes the physics translation.
        assertMatrix(displayed[1], physicsA)
        // b's parent is driven, so b keeps its animated bone offset under a
        // and takes only the physics rotation.
        let expectedPosition = translation(of: physicsA) + rotation(of: physicsA).act(bOffset)
        assertMatrix(displayed[2], Self.rigid(expectedPosition, rotation(of: physicsB)))
        XCTAssertGreaterThan(simd_distance(expectedPosition, translation(of: physicsB)), 0.1, "Sanity: the rule is observable")
    }

    func testClearPhysicsPoseRestoresTheAnimatedPoseNextUpdate() {
        setPose(weights: [0, 1, 0], a: physicsA)
        AnimationSystem.shared.update(deltaTime)
        assertMatrix(displayedModel()[1], physicsA)

        clearPhysicsPose(entityId: entityId)
        XCTAssertFalse(animationComponent.physicsPose.isActive)
        AnimationSystem.shared.update(deltaTime)

        let displayed = displayedModel()
        for index in jointPaths.indices {
            assertMatrix(displayed[index], animatedModel[index], "joint \(index)")
        }
    }

    func testPhysicsPoseIsNotAppliedWhilePaused() {
        AnimationSystem.shared.update(deltaTime)
        setPose(weights: [0, 1, 0], a: physicsA)
        pauseAnimationComponent(entityId: entityId, isPaused: true)
        AnimationSystem.shared.update(deltaTime)
        assertMatrix(displayedModel()[1], animatedModel[1], "paused: the last composed pose stays")

        pauseAnimationComponent(entityId: entityId, isPaused: false)
        AnimationSystem.shared.update(deltaTime)
        assertMatrix(displayedModel()[1], physicsA, "resumed: the pending pose lands")
    }

    func testWrongArrayCountsAreIgnored() {
        setPhysicsPose(entityId: entityId, jointModelTransforms: [.identity, physicsA], jointWeights: [0, 1, 0])
        XCTAssertFalse(animationComponent.physicsPose.isActive)
        setPhysicsPose(entityId: entityId, jointModelTransforms: [.identity, physicsA, .identity], jointWeights: [0, 1])
        XCTAssertFalse(animationComponent.physicsPose.isActive)

        AnimationSystem.shared.update(deltaTime)
        let displayed = displayedModel()
        for index in jointPaths.indices {
            assertMatrix(displayed[index], animatedModel[index], "joint \(index)")
        }
    }

    /// A rig whose root carries a rest scale: the model pose read back
    /// (rest scale included) hands itself in as the physics pose without
    /// moving anything, and a physics target lands where it says.
    func testRestScaleRoundTripsThroughThePhysicsPose() {
        let scale: Float = 2
        scene.get(component: SkeletonComponent.self, for: entityId)?.skeleton = Skeleton(runtimeSkeleton: RuntimeSkeleton(
            jointPaths: jointPaths, parentIndices: parentIndices,
            bindTransforms: [
                simd_float4x4(scale: simd_float3(repeating: scale)),
                simd_float4x4(translation: aOffset * scale) * simd_float4x4(scale: simd_float3(repeating: scale)),
                simd_float4x4(translation: (aOffset + bOffset) * scale) * simd_float4x4(scale: simd_float3(repeating: scale)),
            ],
            restTransforms: [
                simd_float4x4(scale: simd_float3(repeating: scale)),
                simd_float4x4(translation: aOffset),
                simd_float4x4(translation: bOffset),
            ]
        ))
        changeAnimation(entityId: entityId, name: "hold", transitionHalflife: 0)
        AnimationSystem.shared.update(deltaTime)
        let animated = displayedModel()
        XCTAssertEqual(translation(of: animated[1]).y, aOffset.y * scale, accuracy: 1e-4, "the root's rest scale reaches the child")

        // Identity round trip at full weight everywhere.
        setPhysicsPose(entityId: entityId, jointModelTransforms: animated, jointWeights: [1, 1, 1])
        AnimationSystem.shared.update(deltaTime)
        let roundTrip = displayedModel()
        for index in jointPaths.indices {
            assertMatrix(roundTrip[index], animated[index], accuracy: 1e-3, "joint \(index)")
        }

        // A moved subtree top lands on its model-space target.
        let target = Self.rigid(simd_float3(0.4, 2.6, 0.2), simd_quatf(angle: 0.4, axis: simd_float3(0, 0, 1)))
            * simd_float4x4(scale: simd_float3(repeating: scale))
        setPhysicsPose(entityId: entityId, jointModelTransforms: [.identity, target, .identity], jointWeights: [0, 1, 0])
        AnimationSystem.shared.update(deltaTime)
        let moved = displayedModel()
        XCTAssertLessThan(simd_distance(translation(of: moved[1]), translation(of: target)), 1e-3)
        let expectedRotation = rotation(of: target)
        let actualRotation = rotation(of: moved[1])
        XCTAssertGreaterThan(abs(simd_dot(actualRotation.vector, expectedRotation.vector)), 0.9999)
    }

    /// The blend reaches the skin and nothing else: the local pose the
    /// engine keeps between updates — what a transition or a motion
    /// matching jump inertializes from — is the animation's own.
    func testTheBlendStaysOutOfThePoseHistory() {
        setPose(weights: [0, 0, 1], b: physicsB)
        AnimationSystem.shared.update(deltaTime)
        assertMatrix(displayedModel()[2], physicsB, "the skin shows the physics pose")
        let animatedLocal = Self.rigid(bOffset, bRotation)
        let kept = Self.rigid(animationComponent.localPose.translations[2], animationComponent.localPose.rotations[2])
        assertMatrix(kept, animatedLocal, "the local pose kept between updates is the clip's")

        // A transition begun now inertializes from the clip, not from the
        // physics pose: once the physics pose is cleared, the displayed
        // pose is the clip's at once, with no offset to decay.
        changeAnimation(entityId: entityId, name: "hold", transitionHalflife: 0.3)
        clearPhysicsPose(entityId: entityId)
        AnimationSystem.shared.update(deltaTime)
        let displayed = displayedModel()
        for index in jointPaths.indices {
            assertMatrix(displayed[index], animatedModel[index], accuracy: 1e-3, "joint \(index)")
        }
    }

    func testWeightsAreClampedToTheUnitRange() {
        setPhysicsPose(
            entityId: entityId, jointModelTransforms: [.identity, physicsA, .identity], jointWeights: [-1, 3, 0]
        )
        XCTAssertEqual(animationComponent.physicsPose.weights, [0, 1, 0])
        AnimationSystem.shared.update(deltaTime)
        assertMatrix(displayedModel()[1], physicsA)
    }
}

//
//  AnimationPolicyTests.swift
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
final class AnimationPolicyTests: XCTestCase {
    var entityId: EntityID!

    override func setUp() async throws {
        resetEngineTestState()

        entityId = createEntity()
        registerComponent(entityId: entityId, componentType: SkeletonComponent.self)
        registerComponent(entityId: entityId, componentType: AnimationComponent.self)
        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)

        let runtimeSkeleton = RuntimeSkeleton(
            jointPaths: ["root"],
            parentIndices: [nil],
            bindTransforms: [.identity],
            restTransforms: [.identity]
        )
        scene.get(component: SkeletonComponent.self, for: entityId)?.skeleton =
            Skeleton(runtimeSkeleton: runtimeSkeleton)
    }

    override func tearDown() async throws {
        destroyEntity(entityId: entityId)
    }

    private var animationComponent: AnimationComponent {
        scene.get(component: AnimationComponent.self, for: entityId)!
    }

    // MARK: - Defaults and accessors

    func testDefaultPolicyIsInherit() {
        XCTAssertEqual(getAnimationPolicy(entityId: entityId), .inherit)
    }

    func testSetAndGetPolicyRoundTrip() {
        setAnimationPolicy(entityId: entityId, policy: .forceOff)
        XCTAssertEqual(getAnimationPolicy(entityId: entityId), .forceOff)

        setAnimationPolicy(entityId: entityId, policy: .forceOn)
        XCTAssertEqual(getAnimationPolicy(entityId: entityId), .forceOn)

        setAnimationPolicy(entityId: entityId, policy: .inherit)
        XCTAssertEqual(getAnimationPolicy(entityId: entityId), .inherit)
    }

    func testGetPolicyWithoutAnimationComponentReturnsInherit() {
        let bareEntity = createEntity()
        defer { destroyEntity(entityId: bareEntity) }

        XCTAssertEqual(getAnimationPolicy(entityId: bareEntity), .inherit)
    }

    // MARK: - Hierarchical resolution

    func testSetPolicyOnParentAppliesToDescendantComponents() {
        let parentId = createEntity()
        registerComponent(entityId: parentId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: parentId, componentType: WorldTransformComponent.self)
        registerComponent(entityId: parentId, componentType: ScenegraphComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
        defer { destroyEntity(entityId: parentId) }

        setParent(childId: entityId, parentId: parentId)

        // The parent itself has no AnimationComponent; the call must resolve
        // to the child, matching the other animation APIs.
        setAnimationPolicy(entityId: parentId, policy: .forceOff)

        XCTAssertEqual(getAnimationPolicy(entityId: entityId), .forceOff)
        XCTAssertEqual(getAnimationPolicy(entityId: parentId), .forceOff)
    }

    // MARK: - Playback gating

    func testPolicyGate() {
        animationComponent.policy = .inherit
        XCTAssertTrue(animationPolicyAllowsPlayback(animationComponent))

        animationComponent.policy = .forceOn
        XCTAssertTrue(animationPolicyAllowsPlayback(animationComponent))

        animationComponent.policy = .forceOff
        XCTAssertFalse(animationPolicyAllowsPlayback(animationComponent))
    }

    func testForceOffFreezesPlaybackClock() {
        animationComponent.currentTime = 1.25

        setAnimationPolicy(entityId: entityId, policy: .forceOff)
        AnimationSystem.shared.update(0.1)
        XCTAssertEqual(animationComponent.currentTime, 1.25, "forceOff must freeze the playback clock")

        setAnimationPolicy(entityId: entityId, policy: .inherit)
        AnimationSystem.shared.update(0.1)
        XCTAssertEqual(animationComponent.currentTime, 1.35, accuracy: 1e-5, "restoring the policy must resume the clock")
    }

    func testForceOffDoesNotTouchPauseState() {
        pauseAnimationComponent(entityId: entityId, isPaused: true)
        setAnimationPolicy(entityId: entityId, policy: .forceOff)
        setAnimationPolicy(entityId: entityId, policy: .inherit)

        XCTAssertTrue(
            isAnimationComponentPaused(entityId: entityId),
            "Policy round-trip must preserve the entity's own pause state"
        )
    }

    func testGlobalDisableStillOverridesForceOn() {
        animationComponent.currentTime = 0
        setAnimationPolicy(entityId: entityId, policy: .forceOn)

        AnimationSystem.shared.isEnabled = false
        defer { AnimationSystem.shared.isEnabled = true }
        AnimationSystem.shared.update(0.1)

        XCTAssertEqual(animationComponent.currentTime, 0, "Global off has precedence over forceOn")
    }
}

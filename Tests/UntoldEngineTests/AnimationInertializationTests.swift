//
//  AnimationInertializationTests.swift
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
final class AnimationInertializationTests: XCTestCase {
    var entityId: EntityID!

    private let deltaTime: Float = 1.0 / 90.0

    override func setUp() async throws {
        resetEngineTestState()

        entityId = createEntity()
        registerComponent(entityId: entityId, componentType: SkeletonComponent.self)
        registerComponent(entityId: entityId, componentType: AnimationComponent.self)
        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)

        let runtimeSkeleton = RuntimeSkeleton(
            jointPaths: ["root", "root/arm"],
            parentIndices: [nil, 0],
            bindTransforms: [.identity, simd_float4x4(translation: simd_float3(0, 1, 0))],
            restTransforms: [.identity, simd_float4x4(translation: simd_float3(0, 1, 0))]
        )
        scene.get(component: SkeletonComponent.self, for: entityId)?.skeleton =
            Skeleton(runtimeSkeleton: runtimeSkeleton)

        let animationComponent = scene.get(component: AnimationComponent.self, for: entityId)!
        animationComponent.animationClips["low"] = makeClip(name: "low", rootHeight: 0)
        animationComponent.animationClips["high"] = makeClip(name: "high", rootHeight: 2)
    }

    override func tearDown() async throws {
        destroyEntity(entityId: entityId)
    }

    /// Constant-pose clip whose root sits at `rootHeight` — the pose gap
    /// between two of these clips is exactly the height difference, which
    /// makes offset decay easy to assert against.
    private func makeClip(name: String, rootHeight: Float) -> AnimationClip {
        let rootChannel = RuntimeAnimationChannel(
            jointPath: "root",
            translations: [
                .init(time: 0.0, value: simd_float3(0, rootHeight, 0)),
                .init(time: 2.0, value: simd_float3(0, rootHeight, 0)),
            ],
            rotations: [
                .init(time: 0.0, value: SIMD4<Float>(0, 0, 0, 1)),
                .init(time: 2.0, value: SIMD4<Float>(0, 0, 0, 1)),
            ]
        )
        return AnimationClip(runtimeClip: RuntimeAnimationClip(name: name, duration: 2.0, channels: [rootChannel]))
    }

    private var animationComponent: AnimationComponent {
        scene.get(component: AnimationComponent.self, for: entityId)!
    }

    private func playAndSettle(_ name: String, frames: Int = 5) {
        changeAnimation(entityId: entityId, name: name, transitionHalflife: 0)
        for _ in 0 ..< frames {
            AnimationSystem.shared.update(deltaTime)
        }
    }

    private var displayedRootHeight: Float {
        animationComponent.localPose.translations[0].y
    }

    // MARK: - Spring damper math

    func testSpringDamperDecaysTowardZero() {
        var x = simd_float3(1, 0, 0)
        var v = simd_float3.zero
        let halflife: Float = 0.1

        let initial = simd_length(x)
        var elapsed: Float = 0
        while elapsed < halflife * 8 {
            decaySpringDamper(&x, &v, halflife: halflife, deltaTime: 1.0 / 90.0)
            elapsed += 1.0 / 90.0
        }

        XCTAssertLessThan(simd_length(x), initial * 0.01, "Offset must be under 1% after 8 halflives")
        XCTAssertLessThan(simd_length(v), 0.1, "Velocity must settle with the offset")
    }

    func testSpringDamperIsStableForLargeTimeSteps() {
        var x = simd_float3(1, 2, 3)
        var v = simd_float3(-5, 4, 0)

        decaySpringDamper(&x, &v, halflife: 0.1, deltaTime: 1.0)

        XCTAssertLessThan(simd_length(x), 1e-2, "Exact form must not explode on a huge dt")
    }

    func testScaledAngleAxisRoundTrip() {
        let rotations: [simd_quatf] = [
            simd_quatf(angle: 0.7, axis: simd_normalize(simd_float3(1, 2, 3))),
            simd_quatf(angle: -1.3, axis: simd_normalize(simd_float3(0, 1, 0))),
            simd_quatf(angle: 0.0001, axis: simd_float3(1, 0, 0)),
            simd_quatf(angle: 3.0, axis: simd_normalize(simd_float3(-1, 0, 1))),
        ]

        for rotation in rotations {
            let roundTripped = fromScaledAngleAxis(toScaledAngleAxis(rotation))
            // Compare as rotations (q and -q are the same rotation).
            let dot = abs(simd_dot(rotation.vector, roundTripped.vector))
            XCTAssertEqual(dot, 1.0, accuracy: 1e-5, "Round trip must preserve the rotation")
        }
    }

    func testScaledAngleAxisTakesShortestArc() {
        let rotation = simd_quatf(angle: 0.5, axis: simd_float3(0, 1, 0))
        let negated = simd_quatf(vector: -rotation.vector)

        let a = toScaledAngleAxis(rotation)
        let b = toScaledAngleAxis(negated)
        XCTAssertEqual(simd_length(a - b), 0, accuracy: 1e-5, "q and -q must produce the same rotation vector")
        XCTAssertEqual(simd_length(a), 0.5, accuracy: 1e-5)
    }

    // MARK: - Hard cut

    func testZeroHalflifeIsAHardCut() {
        playAndSettle("low")

        changeAnimation(entityId: entityId, name: "high", transitionHalflife: 0)
        AnimationSystem.shared.update(deltaTime)

        XCTAssertEqual(displayedRootHeight, 2.0, accuracy: 1e-5, "Zero halflife must pop straight to the new clip")
        XCTAssertFalse(animationComponent.transition.isActive)
    }

    func testChangeAnimationResetsPlaybackClock() {
        playAndSettle("low", frames: 30)
        XCTAssertGreaterThan(animationComponent.currentTime, 0)

        changeAnimation(entityId: entityId, name: "high", transitionHalflife: 0.1)
        XCTAssertEqual(animationComponent.currentTime, 0, "New clip must start from its beginning")
    }

    func testFirstEverChangeAnimationFallsBackToHardCut() {
        // No pose has been displayed yet — nothing to blend from.
        changeAnimation(entityId: entityId, name: "high", transitionHalflife: 0.2)
        XCTAssertFalse(animationComponent.transition.isActive)

        AnimationSystem.shared.update(deltaTime)
        XCTAssertEqual(displayedRootHeight, 2.0, accuracy: 1e-5)
    }

    // MARK: - Inertialized transition behavior

    func testTransitionIsContinuousAtTheSwitch() {
        playAndSettle("low")
        let heightBeforeSwitch = displayedRootHeight

        changeAnimation(entityId: entityId, name: "high", transitionHalflife: 0.15)
        XCTAssertTrue(animationComponent.transition.isActive)
        AnimationSystem.shared.update(deltaTime)

        // One 90 Hz frame into a 0.15 s halflife transition, the pose must
        // still be near the outgoing pose, not the incoming one.
        let jump = abs(displayedRootHeight - heightBeforeSwitch)
        XCTAssertLessThan(jump, 0.25, "Pose must not snap at the switch (moved \(jump) of a 2.0 gap)")
    }

    func testTransitionConvergesToIncomingClip() {
        playAndSettle("low")

        let halflife: Float = 0.1
        changeAnimation(entityId: entityId, name: "high", transitionHalflife: halflife)

        var elapsed: Float = 0
        while elapsed < halflife * 10 {
            AnimationSystem.shared.update(deltaTime)
            elapsed += deltaTime
        }

        XCTAssertEqual(displayedRootHeight, 2.0, accuracy: 0.02, "Pose must converge to the incoming clip")
    }

    func testTransitionDeactivatesAfterSettling() {
        playAndSettle("low")
        changeAnimation(entityId: entityId, name: "high", transitionHalflife: 0.05)
        XCTAssertTrue(animationComponent.transition.isActive)

        for _ in 0 ..< 300 {
            AnimationSystem.shared.update(deltaTime)
        }

        XCTAssertFalse(animationComponent.transition.isActive, "Settled transition must switch itself off")
    }

    func testTransitionGapShrinksOverTime() {
        playAndSettle("low")
        changeAnimation(entityId: entityId, name: "high", transitionHalflife: 0.1)

        AnimationSystem.shared.update(deltaTime)
        let earlyGap = abs(displayedRootHeight - 2.0)

        for _ in 0 ..< 45 { // 0.5 s = 5 halflives
            AnimationSystem.shared.update(deltaTime)
        }
        let lateGap = abs(displayedRootHeight - 2.0)

        XCTAssertLessThan(lateGap, earlyGap * 0.1, "Offset must have decayed by an order of magnitude after 5 halflives")
    }

    func testRapidRetargetingStaysContinuous() {
        playAndSettle("low")

        changeAnimation(entityId: entityId, name: "high", transitionHalflife: 0.1)
        for _ in 0 ..< 4 {
            AnimationSystem.shared.update(deltaTime)
        }
        let heightMidTransition = displayedRootHeight

        // Interrupt the half-finished transition and go back.
        changeAnimation(entityId: entityId, name: "low", transitionHalflife: 0.1)
        AnimationSystem.shared.update(deltaTime)

        let jump = abs(displayedRootHeight - heightMidTransition)
        XCTAssertLessThan(jump, 0.25, "Interrupting a transition must capture the displayed pose, not the clip pose")
    }
}

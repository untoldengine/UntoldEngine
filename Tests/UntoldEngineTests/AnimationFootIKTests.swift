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

        // Root drifts +X at 0.5 m/s while the leg stays straight — the
        // whole chain (ankle included) slides horizontally, the analog of
        // residual root-motion slide during stance.
        let driftChannels = jointPaths.enumerated().map { index, path in
            RuntimeAnimationChannel(
                jointPath: path,
                translations: [
                    .init(time: 0.0, value: localTranslation(of: locals[index])),
                    .init(time: 1.0, value: localTranslation(of: locals[index])
                        + (index == 0 ? simd_float3(0.5, 0, 0) : .zero)),
                ],
                rotations: [
                    .init(time: 0.0, value: SIMD4<Float>(0, 0, 0, 1)),
                    .init(time: 1.0, value: SIMD4<Float>(0, 0, 0, 1)),
                ]
            )
        }
        animationComponent.animationClips["drift"] = AnimationClip(
            runtimeClip: RuntimeAnimationClip(name: "drift", duration: 1.0, channels: driftChannels)
        )

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

    // MARK: - Stance locking

    /// While the animated ankle drifts slower than the exit speed, the lock
    /// must pin it to where it planted; once the drift exceeds the lock
    /// distance the foot releases and catches up to the animation.
    func testStanceLockPinsSlowDriftAndReleases() {
        setFootIKGroundQuery(entityId: entityId) { _ in FootIKGroundSample(height: 0) }
        setFootIKEnabled(entityId: entityId, enabled: true)
        setFootIKStanceLocking(entityId: entityId, enabled: true)

        // Plant: two static frames lock the foot at x = 0.
        changeAnimation(entityId: entityId, name: "stand", transitionHalflife: 0)
        AnimationSystem.shared.update(deltaTime)
        AnimationSystem.shared.update(deltaTime)

        // Drift at 0.5 m/s — below the exit speed, so the lock holds.
        changeAnimation(entityId: entityId, name: "drift", transitionHalflife: 0)
        for _ in 0 ..< 15 {
            AnimationSystem.shared.update(deltaTime)
        }
        let heldX = anklePosition().x
        let animatedX = animationComponent.currentTime * 0.5
        XCTAssertGreaterThan(animatedX, 0.06, "Sanity: the animation has drifted")
        XCTAssertLessThan(heldX, 0.03, "Locked ankle must stay near its anchor while the chain drifts")

        // Keep drifting past maxLockDistance (0.2 m at 0.5 m/s = 0.4 s):
        // the lock releases and the catch-up decay hands the foot back.
        for _ in 0 ..< 60 {
            AnimationSystem.shared.update(deltaTime)
        }
        let finalAnimatedX = min(animationComponent.currentTime, 1.0) * 0.5
        XCTAssertEqual(anklePosition().x, finalAnimatedX, accuracy: 0.02,
                       "After release the foot must catch up to the animation")
    }

    /// The frame the lock releases must land exactly where the last locked
    /// frame did: the stored offset is what lines the two up, so the
    /// catch-up decay may only start on the frame after.
    func testStanceLockReleaseFrameIsContinuous() {
        // Raising the ground bends the knee, so every target below is
        // within reach and the solve lands exactly on it.
        setFootIKGroundQuery(entityId: entityId) { _ in FootIKGroundSample(height: 0.1) }
        setFootIKEnabled(entityId: entityId, enabled: true)
        setFootIKStanceLocking(entityId: entityId, enabled: true)

        changeAnimation(entityId: entityId, name: "stand", transitionHalflife: 0)
        AnimationSystem.shared.update(deltaTime)
        AnimationSystem.shared.update(deltaTime)
        XCTAssertTrue(animationComponent.footIK.lockStates[0].locked, "Sanity: two static frames plant the foot")

        // Drift until the animation pulls the ankle past maxLockDistance.
        changeAnimation(entityId: entityId, name: "drift", transitionHalflife: 0)
        var lastLockedX = anklePosition().x
        var released = false
        for _ in 0 ..< 60 {
            AnimationSystem.shared.update(deltaTime)
            if animationComponent.footIK.lockStates[0].locked == false {
                released = true
                break
            }
            lastLockedX = anklePosition().x
        }
        XCTAssertTrue(released, "Sanity: the drift released the lock")

        // Release frame: the foot has not moved from the last locked frame.
        let releaseX = anklePosition().x
        XCTAssertEqual(releaseX, lastLockedX, accuracy: 1e-4,
                       "The release frame must line up with the last locked frame")

        // Next frame: the decay takes its first step toward the animation.
        let releaseAnimatedX = animationComponent.currentTime * 0.5
        AnimationSystem.shared.update(deltaTime)
        let decay = exp(-0.693_147_18 * deltaTime / animationComponent.footIK.releaseHalflife)
        let expectedX = animationComponent.currentTime * 0.5 + (releaseX - releaseAnimatedX) * decay
        XCTAssertEqual(anklePosition().x, expectedX, accuracy: 1e-4,
                       "The catch-up decay begins on the frame after release")
    }

    /// A foot that re-locks while the catch-up decay is still running must
    /// not snap to the animated ankle: the re-lock frame continues the decay
    /// by one step, and the catch-up then completes while the foot stays
    /// locked.
    func testStanceLockRelockMidDecayEasesIn() {
        setFootIKGroundQuery(entityId: entityId) { _ in FootIKGroundSample(height: 0.1) }
        setFootIKEnabled(entityId: entityId, enabled: true)
        setFootIKStanceLocking(entityId: entityId, enabled: true)

        changeAnimation(entityId: entityId, name: "stand", transitionHalflife: 0)
        AnimationSystem.shared.update(deltaTime)
        AnimationSystem.shared.update(deltaTime)

        // Drift past maxLockDistance so the lock releases, then a few more
        // frames so a sizeable offset is still decaying.
        changeAnimation(entityId: entityId, name: "drift", transitionHalflife: 0)
        var released = false
        for _ in 0 ..< 60 {
            AnimationSystem.shared.update(deltaTime)
            if animationComponent.footIK.lockStates[0].locked == false {
                released = true
                break
            }
        }
        XCTAssertTrue(released, "Sanity: the drift released the lock")
        for _ in 0 ..< 5 {
            AnimationSystem.shared.update(deltaTime)
        }
        let animatedX = animationComponent.currentTime * 0.5
        var previousX = anklePosition().x
        XCTAssertLessThan(previousX, animatedX - 0.05, "Sanity: a sizeable offset is still decaying")

        // Freeze the animation: the ankle stops, so the foot re-locks. Every
        // frame from here on continues the decay by exactly one step.
        setAnimationPlaybackSpeed(entityId: entityId, speed: 0)
        let decay = exp(-0.693_147_18 * deltaTime / animationComponent.footIK.releaseHalflife)
        for frame in 0 ..< 60 {
            AnimationSystem.shared.update(deltaTime)
            XCTAssertTrue(animationComponent.footIK.lockStates[0].locked, "A stationary foot stays locked (frame \(frame))")
            let expectedX = animatedX + (previousX - animatedX) * decay
            // Under ~4 mm of lateral offset the two-bone solve skips its aim
            // rotation, so exact steps are only asserted above that band.
            if abs(expectedX - animatedX) > 0.01 {
                XCTAssertEqual(anklePosition().x, expectedX, accuracy: 1e-4,
                               "Re-locking continues the decay instead of snapping (frame \(frame))")
            }
            previousX = anklePosition().x
        }
        XCTAssertEqual(previousX, animatedX, accuracy: 5e-3, "The catch-up completes while locked")
    }

    /// A hard cut that moves a planted foot within the solver's reach must
    /// ease the foot to the new stance: no pop on the cut frame, a re-plant
    /// at the new animated ankle, and a catch-up that completes without the
    /// lock flickering.
    func testStanceLockCutWithinReachEasesToNewStance() {
        setFootIKGroundQuery(entityId: entityId) { _ in FootIKGroundSample(height: 0.1) }
        setFootIKEnabled(entityId: entityId, enabled: true)
        setFootIKStanceLocking(entityId: entityId, enabled: true)

        changeAnimation(entityId: entityId, name: "stand", transitionHalflife: 0)
        AnimationSystem.shared.update(deltaTime)
        AnimationSystem.shared.update(deltaTime)

        // Jump 0.35 m in a single frame: play the drift clip 0.7 s in one
        // step, then freeze it there.
        changeAnimation(entityId: entityId, name: "drift", transitionHalflife: 0)
        setAnimationPlaybackSpeed(entityId: entityId, speed: 0.7 / deltaTime)
        AnimationSystem.shared.update(deltaTime)
        setAnimationPlaybackSpeed(entityId: entityId, speed: 0)
        let cutX = animationComponent.currentTime * 0.5
        XCTAssertEqual(cutX, 0.35, accuracy: 1e-4, "Sanity: the cut moved the ankle 0.35 m")
        XCTAssertEqual(anklePosition().x, 0, accuracy: 1e-4, "The cut frame keeps the foot where it was planted")

        let decay = exp(-0.693_147_18 * deltaTime / animationComponent.footIK.releaseHalflife)
        var previousX = anklePosition().x
        for frame in 0 ..< 60 {
            AnimationSystem.shared.update(deltaTime)
            XCTAssertTrue(animationComponent.footIK.lockStates[0].locked, "The foot re-plants and stays locked (frame \(frame))")
            let expectedX = cutX + (previousX - cutX) * decay
            // Under ~4 mm of lateral offset the two-bone solve skips its aim
            // rotation, so exact steps are only asserted above that band.
            if abs(expectedX - cutX) > 0.01 {
                XCTAssertEqual(anklePosition().x, expectedX, accuracy: 1e-4,
                               "The catch-up runs one decay step per frame (frame \(frame))")
            }
            previousX = anklePosition().x
        }
        XCTAssertEqual(previousX, cutX, accuracy: 5e-3, "The foot settles on the new stance")
    }

    /// A cut larger than maxAdjustment cannot be absorbed: the solve skips
    /// the cut frame and the foot shows the animated pose. It must then
    /// re-plant right there, not pop back toward the old anchor a few
    /// frames later once the leftover catch-up shrinks under the bound.
    func testStanceLockCutBeyondMaxAdjustmentReplantsWithoutPoppingBack() {
        setFootIKGroundQuery(entityId: entityId) { _ in FootIKGroundSample(height: 0) }
        animationComponent.footIK.maxAdjustment = 0.3
        setFootIKEnabled(entityId: entityId, enabled: true)
        setFootIKStanceLocking(entityId: entityId, enabled: true)

        changeAnimation(entityId: entityId, name: "stand", transitionHalflife: 0)
        AnimationSystem.shared.update(deltaTime)
        AnimationSystem.shared.update(deltaTime)

        changeAnimation(entityId: entityId, name: "drift", transitionHalflife: 0)
        setAnimationPlaybackSpeed(entityId: entityId, speed: 0.7 / deltaTime)
        AnimationSystem.shared.update(deltaTime)
        setAnimationPlaybackSpeed(entityId: entityId, speed: 0)
        let cutX = animationComponent.currentTime * 0.5
        XCTAssertEqual(anklePosition().x, cutX, accuracy: 1e-4, "A cut beyond maxAdjustment shows the animated foot")

        for frame in 0 ..< 10 {
            AnimationSystem.shared.update(deltaTime)
            XCTAssertTrue(animationComponent.footIK.lockStates[0].locked, "The foot re-plants on the new stance (frame \(frame))")
            XCTAssertEqual(anklePosition().x, cutX, accuracy: 1e-4,
                           "The foot must not pop back toward the old anchor (frame \(frame))")
        }
    }

    /// A release while a catch-up is still in flight must fold the pinned
    /// offset into it, so the release frame continues the decay by one step
    /// rather than dropping the leftover and popping.
    func testStanceLockReleaseMidCatchUpStaysContinuous() {
        setFootIKGroundQuery(entityId: entityId) { _ in FootIKGroundSample(height: 0.1) }
        setFootIKEnabled(entityId: entityId, enabled: true)
        setFootIKStanceLocking(entityId: entityId, enabled: true)

        changeAnimation(entityId: entityId, name: "stand", transitionHalflife: 0)
        AnimationSystem.shared.update(deltaTime)
        AnimationSystem.shared.update(deltaTime)

        // Drift to a distance release, decay a little, then freeze so the
        // foot re-locks with a catch-up still in flight.
        changeAnimation(entityId: entityId, name: "drift", transitionHalflife: 0)
        var released = false
        for _ in 0 ..< 60 {
            AnimationSystem.shared.update(deltaTime)
            if animationComponent.footIK.lockStates[0].locked == false {
                released = true
                break
            }
        }
        XCTAssertTrue(released, "Sanity: the drift released the lock")
        for _ in 0 ..< 5 {
            AnimationSystem.shared.update(deltaTime)
        }
        setAnimationPlaybackSpeed(entityId: entityId, speed: 0)
        for _ in 0 ..< 3 {
            AnimationSystem.shared.update(deltaTime)
        }
        XCTAssertTrue(animationComponent.footIK.lockStates[0].locked, "Sanity: the foot re-locked mid-catch-up")
        let lockedAnimatedX = animationComponent.currentTime * 0.5
        let lastLockedX = anklePosition().x
        XCTAssertLessThan(lastLockedX, lockedAnimatedX - 0.03, "Sanity: a catch-up is still in flight")

        // Swing the foot away at 2 m/s: the release frame must continue the
        // decay from the last locked frame, leftover included.
        setAnimationPlaybackSpeed(entityId: entityId, speed: 4)
        AnimationSystem.shared.update(deltaTime)
        XCTAssertFalse(animationComponent.footIK.lockStates[0].locked, "Sanity: a fast foot releases")
        let decay = exp(-0.693_147_18 * deltaTime / animationComponent.footIK.releaseHalflife)
        let expectedX = lockedAnimatedX + (lastLockedX - lockedAnimatedX) * decay
        XCTAssertEqual(anklePosition().x, expectedX, accuracy: 1e-4,
                       "A release mid-catch-up must not drop the leftover offset")
    }

    /// A probe miss while a catch-up is in flight shows the raw foot for
    /// that frame; the catch-up must be dropped so the foot does not pop
    /// back toward the old anchor once the probe recovers.
    func testStanceLockProbeMissMidCatchUpDropsTheCatchUp() {
        setFootIKGroundQuery(entityId: entityId) { _ in FootIKGroundSample(height: 0.1) }
        setFootIKEnabled(entityId: entityId, enabled: true)
        setFootIKStanceLocking(entityId: entityId, enabled: true)

        changeAnimation(entityId: entityId, name: "stand", transitionHalflife: 0)
        AnimationSystem.shared.update(deltaTime)
        AnimationSystem.shared.update(deltaTime)

        changeAnimation(entityId: entityId, name: "drift", transitionHalflife: 0)
        var released = false
        for _ in 0 ..< 60 {
            AnimationSystem.shared.update(deltaTime)
            if animationComponent.footIK.lockStates[0].locked == false {
                released = true
                break
            }
        }
        XCTAssertTrue(released, "Sanity: the drift released the lock")
        AnimationSystem.shared.update(deltaTime)
        AnimationSystem.shared.update(deltaTime)
        XCTAssertGreaterThan(simd_length(animationComponent.footIK.lockStates[0].releaseOffset), 0.1,
                             "Sanity: a catch-up is in flight")

        // One frame without ground: the foot shows the raw animated pose.
        setFootIKGroundQuery(entityId: entityId) { _ in nil }
        AnimationSystem.shared.update(deltaTime)
        XCTAssertEqual(anklePosition().x, animationComponent.currentTime * 0.5, accuracy: 1e-4,
                       "Sanity: with no ground the foot follows the animation")
        XCTAssertEqual(simd_length(animationComponent.footIK.lockStates[0].releaseOffset), 0, accuracy: 1e-6,
                       "A probe miss drops the catch-up")

        // Probe back: no pop back toward the old anchor.
        setFootIKGroundQuery(entityId: entityId) { _ in FootIKGroundSample(height: 0.1) }
        AnimationSystem.shared.update(deltaTime)
        XCTAssertEqual(anklePosition().x, animationComponent.currentTime * 0.5, accuracy: 1e-4,
                       "After the probe recovers the foot follows the animation")
    }

    func testStanceLockIgnoresFastFeet() {
        setFootIKGroundQuery(entityId: entityId) { _ in FootIKGroundSample(height: 0) }
        setFootIKEnabled(entityId: entityId, enabled: true)
        setFootIKStanceLocking(entityId: entityId, enabled: true)

        // Jump straight into the drift clip with NO planted frames — the
        // very first sampled frame has no history and the foot then moves
        // at 0.5 m/s... use a faster proxy: scale playback so the ankle
        // moves at 2 m/s, above the exit speed; the lock must never engage.
        setAnimationPlaybackSpeed(entityId: entityId, speed: 4.0)
        changeAnimation(entityId: entityId, name: "drift", transitionHalflife: 0)
        for _ in 0 ..< 20 {
            AnimationSystem.shared.update(deltaTime)
        }
        // currentTime already advances at the playback speed.
        let animatedX = min(animationComponent.currentTime, 1.0) * 0.5
        XCTAssertEqual(anklePosition().x, animatedX, accuracy: 0.02,
                       "A fast-moving foot must follow the animation, never the lock")
    }

    func testStanceLockOffPreservesBehavior() {
        setFootIKGroundQuery(entityId: entityId) { _ in FootIKGroundSample(height: 0) }
        setFootIKEnabled(entityId: entityId, enabled: true)

        changeAnimation(entityId: entityId, name: "drift", transitionHalflife: 0)
        for _ in 0 ..< 15 {
            AnimationSystem.shared.update(deltaTime)
        }
        let animatedX = animationComponent.currentTime * 0.5
        XCTAssertEqual(anklePosition().x, animatedX, accuracy: 1e-4,
                       "Without stance locking the foot follows the animation exactly")
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

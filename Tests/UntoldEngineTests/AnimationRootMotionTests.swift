//
//  AnimationRootMotionTests.swift
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
final class AnimationRootMotionTests: XCTestCase {
    var entityId: EntityID!

    private let deltaTime: Float = 1.0 / 90.0

    override func setUp() async throws {
        resetEngineTestState()

        entityId = createEntity()
        registerComponent(entityId: entityId, componentType: SkeletonComponent.self)
        registerComponent(entityId: entityId, componentType: AnimationComponent.self)
        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)

        let runtimeSkeleton = RuntimeSkeleton(
            jointPaths: ["root", "root/hips"],
            parentIndices: [nil, 0],
            bindTransforms: [.identity, simd_float4x4(translation: simd_float3(0, 1, 0))],
            restTransforms: [.identity, simd_float4x4(translation: simd_float3(0, 1, 0))]
        )
        scene.get(component: SkeletonComponent.self, for: entityId)?.skeleton =
            Skeleton(runtimeSkeleton: runtimeSkeleton)

        let animationComponent = scene.get(component: AnimationComponent.self, for: entityId)!
        animationComponent.animationClips["walk"] = makeWalkClip()
        animationComponent.animationClips["turn"] = makeTurnClip()
    }

    override func tearDown() async throws {
        destroyEntity(entityId: entityId)
    }

    /// Straight walk: root travels 2 m along +Z over the 2 s loop at a
    /// constant 1 m/s, bobbing at a constant height of 0.9.
    private func makeWalkClip() -> AnimationClip {
        let rootChannel = RuntimeAnimationChannel(
            jointPath: "root",
            translations: [
                .init(time: 0.0, value: simd_float3(0, 0.9, 0)),
                .init(time: 1.0, value: simd_float3(0, 0.9, 1)),
                .init(time: 2.0, value: simd_float3(0, 0.9, 2)),
            ],
            rotations: [
                .init(time: 0.0, value: SIMD4<Float>(0, 0, 0, 1)),
                .init(time: 2.0, value: SIMD4<Float>(0, 0, 0, 1)),
            ]
        )
        return AnimationClip(runtimeClip: RuntimeAnimationClip(name: "walk", duration: 2.0, channels: [rootChannel]))
    }

    /// One-shot lunge: root travels 1 m over the first second of a 2 s
    /// clip, channel marked non-repeating — the sampler clamps it at its
    /// last key for the rest of the clip instead of cycling.
    private func makeOneShotClip() -> AnimationClip {
        let rootChannel = RuntimeAnimationChannel(
            jointPath: "root",
            translations: [
                .init(time: 0.0, value: simd_float3(0, 0.9, 0)),
                .init(time: 1.0, value: simd_float3(0, 0.9, 1)),
            ],
            rotations: [
                .init(time: 0.0, value: SIMD4<Float>(0, 0, 0, 1)),
                .init(time: 1.0, value: SIMD4<Float>(0, 0, 0, 1)),
            ]
        )
        let clip = AnimationClip(runtimeClip: RuntimeAnimationClip(name: "lunge", duration: 2.0, channels: [rootChannel]))
        clip.jointAnimation["root"]?.repeatAnimation = false
        return clip
    }

    /// Turn in place: root yaws 90° about +Y over the 2 s loop, no travel.
    private func makeTurnClip() -> AnimationClip {
        func yawKey(_ angle: Float) -> SIMD4<Float> {
            let q = simd_quatf(angle: angle, axis: simd_float3(0, 1, 0))
            return SIMD4<Float>(q.imag.x, q.imag.y, q.imag.z, q.real)
        }
        let rootChannel = RuntimeAnimationChannel(
            jointPath: "root",
            translations: [
                .init(time: 0.0, value: simd_float3(0, 0.9, 0)),
                .init(time: 2.0, value: simd_float3(0, 0.9, 0)),
            ],
            rotations: [
                .init(time: 0.0, value: yawKey(0)),
                .init(time: 1.0, value: yawKey(.pi / 4)),
                .init(time: 2.0, value: yawKey(.pi / 2)),
            ]
        )
        return AnimationClip(runtimeClip: RuntimeAnimationClip(name: "turn", duration: 2.0, channels: [rootChannel]))
    }

    private var animationComponent: AnimationComponent {
        scene.get(component: AnimationComponent.self, for: entityId)!
    }

    private var rootIndex: Int {
        0
    }

    private func run(frames: Int, onFrame: ((Int) -> Void)? = nil) {
        for frame in 0 ..< frames {
            AnimationSystem.shared.update(deltaTime)
            onFrame?(frame)
        }
    }

    // MARK: - Default off

    func testRootMotionDisabledByDefault() {
        changeAnimation(entityId: entityId, name: "walk", transitionHalflife: 0)
        run(frames: 90) // 1 s in

        XCTAssertFalse(isRootMotionEnabled(entityId: entityId))
        XCTAssertEqual(getLocalPosition(entityId: entityId).z, 0, "Entity must not move with root motion off")
        XCTAssertGreaterThan(
            animationComponent.localPose.translations[rootIndex].z, 0.9,
            "Pose root keeps its authored travel with root motion off"
        )
    }

    func testEnableDisableRoundTrip() {
        setRootMotionEnabled(entityId: entityId, enabled: true)
        XCTAssertTrue(isRootMotionEnabled(entityId: entityId))
        setRootMotionEnabled(entityId: entityId, enabled: false)
        XCTAssertFalse(isRootMotionEnabled(entityId: entityId))
    }

    // MARK: - Straight travel

    func testEntityAccumulatesClipDisplacementAcrossLoops() {
        setRootMotionEnabled(entityId: entityId, enabled: true)
        changeAnimation(entityId: entityId, name: "walk", transitionHalflife: 0)

        // 3 s at 1 m/s across a 2 s loop (one wrap). The first frame is the
        // extraction baseline, so expected travel is total minus one frame.
        run(frames: 270)

        let expected: Float = 3.0 - deltaTime
        XCTAssertEqual(getLocalPosition(entityId: entityId).z, expected, accuracy: 1e-3)
        XCTAssertEqual(getLocalPosition(entityId: entityId).x, 0, accuracy: 1e-5)
        XCTAssertEqual(getLocalPosition(entityId: entityId).y, 0, accuracy: 1e-5, "Vertical motion stays in the pose")
    }

    func testNoSnapAtLoopWrap() {
        setRootMotionEnabled(entityId: entityId, enabled: true)
        changeAnimation(entityId: entityId, name: "walk", transitionHalflife: 0)

        var previousZ = getLocalPosition(entityId: entityId).z
        var maxStep: Float = 0
        run(frames: 270) { _ in
            let z = getLocalPosition(entityId: self.entityId).z
            maxStep = max(maxStep, abs(z - previousZ))
            previousZ = z
        }

        // At 1 m/s a 90 Hz frame moves ~0.0111 m; a wrap snap would move ~2 m.
        XCTAssertLessThan(maxStep, deltaTime * 1.5, "Loop wrap must not snap the entity")
    }

    func testPoseRootIsGrounded() {
        setRootMotionEnabled(entityId: entityId, enabled: true)
        changeAnimation(entityId: entityId, name: "walk", transitionHalflife: 0)
        run(frames: 90)

        let rootTranslation = animationComponent.localPose.translations[rootIndex]
        XCTAssertEqual(rootTranslation.x, 0, accuracy: 1e-6)
        XCTAssertEqual(rootTranslation.z, 0, accuracy: 1e-6, "Horizontal travel must be stripped from the pose")
        XCTAssertEqual(rootTranslation.y, 0.9, accuracy: 1e-5, "Vertical offset must stay in the pose")
    }

    // MARK: - Yaw

    func testEntityAccumulatesClipYaw() {
        setRootMotionEnabled(entityId: entityId, enabled: true)
        changeAnimation(entityId: entityId, name: "turn", transitionHalflife: 0)

        // One full 2 s loop turns 90°, minus the one-frame baseline.
        run(frames: 180)

        let rotation = getRotationQuaternion(entityId: entityId)
        let (yaw, _) = yawTwist(rotation)
        let expected: Float = .pi / 2 - (.pi / 4) * deltaTime
        XCTAssertEqual(yaw, expected, accuracy: 0.01)
    }

    func testPoseRootYawIsStripped() {
        setRootMotionEnabled(entityId: entityId, enabled: true)
        changeAnimation(entityId: entityId, name: "turn", transitionHalflife: 0)
        run(frames: 90)

        let (poseYaw, _) = yawTwist(animationComponent.localPose.rotations[rootIndex])
        XCTAssertEqual(poseYaw, 0, accuracy: 1e-4, "Yaw must be stripped from the pose root")
    }

    // MARK: - Interplay with transitions and clip switches

    func testTransitionWithRootMotionStaysGrounded() {
        setRootMotionEnabled(entityId: entityId, enabled: true)
        changeAnimation(entityId: entityId, name: "walk", transitionHalflife: 0)
        run(frames: 60)

        changeAnimation(entityId: entityId, name: "turn", transitionHalflife: 0.15)
        run(frames: 30) { _ in
            let rootTranslation = self.animationComponent.localPose.translations[self.rootIndex]
            XCTAssertEqual(rootTranslation.x, 0, accuracy: 1e-4, "Transition must blend grounded poses")
            XCTAssertEqual(rootTranslation.z, 0, accuracy: 1e-4, "Transition must blend grounded poses")
        }
    }

    func testClipSwitchDoesNotTeleportEntity() {
        setRootMotionEnabled(entityId: entityId, enabled: true)
        changeAnimation(entityId: entityId, name: "walk", transitionHalflife: 0)
        run(frames: 135) // mid-clip, root at z ≈ 1.5

        let zBeforeSwitch = getLocalPosition(entityId: entityId).z
        changeAnimation(entityId: entityId, name: "turn", transitionHalflife: 0)
        AnimationSystem.shared.update(deltaTime)

        let jump = abs(getLocalPosition(entityId: entityId).z - zBeforeSwitch)
        XCTAssertLessThan(jump, 1e-4, "Switching clips must re-baseline, not apply a spurious delta")
    }

    // MARK: - Non-repeating clips

    func testNonRepeatingChannelDoesNotInjectLoopJump() {
        animationComponent.animationClips["lunge"] = makeOneShotClip()

        setRootMotionEnabled(entityId: entityId, enabled: true)
        changeAnimation(entityId: entityId, name: "lunge", transitionHalflife: 0)

        // 1.89 s: well past the channel's 1 s last key (the clamp window the
        // old fmod misread as a loop wrap), still before the 2 s outer wrap.
        var previousZ = getLocalPosition(entityId: entityId).z
        var maxStep: Float = 0
        run(frames: 170) { _ in
            let z = getLocalPosition(entityId: self.entityId).z
            maxStep = max(maxStep, abs(z - previousZ))
            previousZ = z
        }

        XCTAssertEqual(
            getLocalPosition(entityId: entityId).z, 1.0 - deltaTime, accuracy: 1e-3,
            "Entity travels the authored 1 m; the clamped channel contributes no further delta"
        )
        XCTAssertLessThan(
            maxStep, deltaTime * 1.5,
            "Clamping at the last key must not read as a loop wrap and inject the per-loop displacement"
        )
    }

    // MARK: - Pitch and roll preservation

    /// The swing–twist split must remove only yaw. Pure pitch (and pure
    /// roll) composed with yaw decomposes exactly — the twist is the yaw
    /// factor — so grounding must return the authored lean untouched; a
    /// sign error or axis mixup in the twist projection would break this.
    func testPitchAndRollSurviveGrounding() {
        let yaw = simd_quatf(angle: 0.7, axis: simd_float3(0, 1, 0))
        let leans: [(name: String, swing: simd_quatf)] = [
            ("pitch", simd_quatf(angle: 0.4, axis: simd_float3(1, 0, 0))),
            ("roll", simd_quatf(angle: -0.3, axis: simd_float3(0, 0, 1))),
        ]

        for (name, swing) in leans {
            var pose = PoseBuffer()
            pose.resize(jointCount: 1)
            pose.translations[0] = simd_float3(0.3, 0.9, 1.2)
            pose.rotations[0] = simd_normalize(swing * yaw)

            stripRootMotion(from: &pose, rootIndex: 0)

            XCTAssertEqual(pose.translations[0].x, 0, accuracy: 1e-6)
            XCTAssertEqual(pose.translations[0].z, 0, accuracy: 1e-6)
            XCTAssertEqual(pose.translations[0].y, 0.9, accuracy: 1e-6, "Vertical offset must survive grounding")

            let (residualYaw, _) = yawTwist(pose.rotations[0])
            XCTAssertEqual(residualYaw, 0, accuracy: 1e-5, "Yaw must be fully stripped (\(name) case)")

            let dot = abs(simd_dot(pose.rotations[0].vector, swing.vector))
            XCTAssertEqual(dot, 1.0, accuracy: 1e-5, "\(name) must come through the swing–twist split untouched")
        }
    }

    // MARK: - Hierarchical assets

    /// Hierarchical assets (setEntityMeshAsync) carry their
    /// AnimationComponent on a skinned scenegraph child while the game
    /// holds and steers the asset root. Root motion deltas must anchor to
    /// the entity the public API was called on — the gameplay handle — not
    /// the component's entity, or the child drifts inside the asset while
    /// the root the game steers stays put.
    func testHierarchicalAssetAnchorsMotionToAPIEntity() {
        let root = createEntity()
        registerComponent(entityId: root, componentType: LocalTransformComponent.self)
        registerComponent(entityId: root, componentType: WorldTransformComponent.self)
        registerComponent(entityId: root, componentType: ScenegraphComponent.self)
        defer { destroyEntity(entityId: root) }

        // Reparent the fixture entity (which carries all the components)
        // under the root, then call every API on the root — like a game.
        setParent(childId: entityId, parentId: root)

        setRootMotionEnabled(entityId: root, enabled: true)
        changeAnimation(entityId: root, name: "walk", transitionHalflife: 0)
        run(frames: 90) // 1 s of the 1 m/s walk

        XCTAssertGreaterThan(
            getLocalPosition(entityId: root).z, 0.5,
            "Root motion must move the API entity (the gameplay handle)"
        )
        XCTAssertEqual(
            simd_length(getLocalPosition(entityId: entityId)), 0, accuracy: 1e-4,
            "The component's child entity must not drift inside the asset"
        )
    }

    /// Modular assets (one skinned part per mesh, e.g. a UE character
    /// exported per body part) resolve to SEVERAL animation components that
    /// all sample the same clips against the same anchor. The extracted
    /// deltas must move the anchor once — not once per part.
    func testMultiComponentAssetAppliesRootMotionOnce() throws {
        let root = createEntity()
        registerComponent(entityId: root, componentType: LocalTransformComponent.self)
        registerComponent(entityId: root, componentType: WorldTransformComponent.self)
        registerComponent(entityId: root, componentType: ScenegraphComponent.self)

        // A second skinned part: same skeleton, same clip, own components.
        let sibling = createEntity()
        registerComponent(entityId: sibling, componentType: SkeletonComponent.self)
        registerComponent(entityId: sibling, componentType: AnimationComponent.self)
        registerComponent(entityId: sibling, componentType: RenderComponent.self)
        registerComponent(entityId: sibling, componentType: ScenegraphComponent.self)
        registerComponent(entityId: sibling, componentType: LocalTransformComponent.self)
        registerComponent(entityId: sibling, componentType: WorldTransformComponent.self)
        let runtimeSkeleton = RuntimeSkeleton(
            jointPaths: ["root", "root/hips"],
            parentIndices: [nil, 0],
            bindTransforms: [.identity, simd_float4x4(translation: simd_float3(0, 1, 0))],
            restTransforms: [.identity, simd_float4x4(translation: simd_float3(0, 1, 0))]
        )
        scene.get(component: SkeletonComponent.self, for: sibling)?.skeleton =
            Skeleton(runtimeSkeleton: runtimeSkeleton)
        let siblingAnimation = try XCTUnwrap(scene.get(component: AnimationComponent.self, for: sibling))
        siblingAnimation.animationClips["walk"] = makeWalkClip()
        defer {
            destroyEntity(entityId: sibling)
            destroyEntity(entityId: root)
        }

        setParent(childId: entityId, parentId: root)
        setParent(childId: sibling, parentId: root)

        setRootMotionEnabled(entityId: root, enabled: true)
        changeAnimation(entityId: root, name: "walk", transitionHalflife: 0)
        run(frames: 90) // 1 s of the 1 m/s walk

        XCTAssertEqual(
            getLocalPosition(entityId: root).z, 1.0 - deltaTime, accuracy: 1e-3,
            "Two components sharing an anchor must move it at clip speed, not 2x"
        )
        for part in try [XCTUnwrap(entityId), sibling] {
            let animationComponent = try XCTUnwrap(scene.get(component: AnimationComponent.self, for: part))
            XCTAssertEqual(
                animationComponent.localPose.translations[0].z, 0, accuracy: 1e-4,
                "Every part must still ground its own pose"
            )
        }
    }

    // MARK: - Root joint override

    func testRootJointPathOverride() {
        setRootMotionEnabled(entityId: entityId, enabled: true, rootJointPath: "root/hips")
        changeAnimation(entityId: entityId, name: "walk", transitionHalflife: 0)
        run(frames: 90)

        // The override points at a joint the clip does not animate, so no
        // deltas are produced and the authored root travel stays in the pose.
        XCTAssertEqual(getLocalPosition(entityId: entityId).z, 0, accuracy: 1e-5)
        XCTAssertGreaterThan(animationComponent.localPose.translations[rootIndex].z, 0.9)
    }
}

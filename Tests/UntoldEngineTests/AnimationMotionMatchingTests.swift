//
//  AnimationMotionMatchingTests.swift
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
final class AnimationMotionMatchingTests: XCTestCase {
    var entityId: EntityID!

    private let deltaTime: Float = 1.0 / 90.0

    // Skeleton: root plus two feet hanging off it at ±x.
    private let jointPaths = ["root", "root/foot_l", "root/foot_r"]
    private let parentIndices: [Int?] = [nil, 0, 0]

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
            simd_float4x4(translation: simd_float3(0, 0.9, 0)),
            simd_float4x4(translation: simd_float3(-0.1, -0.9, 0)),
            simd_float4x4(translation: simd_float3(0.1, -0.9, 0)),
        ]
        let binds = [
            simd_float4x4(translation: simd_float3(0, 0.9, 0)),
            simd_float4x4(translation: simd_float3(-0.1, 0, 0)),
            simd_float4x4(translation: simd_float3(0.1, 0, 0)),
        ]
        let runtimeSkeleton = RuntimeSkeleton(
            jointPaths: jointPaths,
            parentIndices: parentIndices,
            bindTransforms: binds,
            restTransforms: locals
        )
        scene.get(component: SkeletonComponent.self, for: entityId)?.skeleton =
            Skeleton(runtimeSkeleton: runtimeSkeleton)

        let animationComponent = scene.get(component: AnimationComponent.self, for: entityId)!
        animationComponent.animationClips["walk"] = makeClip(name: "walk", speed: 1.0)
        animationComponent.animationClips["idle"] = makeClip(name: "idle", speed: 0.0)

        setRootMotionEnabled(entityId: entityId, enabled: true)
        // The synthetic clips have constant foot velocities (no gait), so
        // foot velocity is down-weighted to keep the goal decisive.
        setMotionMatching(entityId: entityId, descriptor: MotionMatchingDescriptor(
            leftFootPath: "root/foot_l",
            rightFootPath: "root/foot_r",
            weights: MotionMatchingWeights(footVelocity: 0.5)
        ))
    }

    override func tearDown() async throws {
        destroyEntity(entityId: entityId)
    }

    /// Locomotion clip whose root travels along +z at `speed` m/s over a
    /// 2 s loop (speed 0 = idle). Feet are unanimated and ride along.
    private func makeClip(name: String, speed: Float) -> AnimationClip {
        let rootChannel = RuntimeAnimationChannel(
            jointPath: "root",
            translations: [
                .init(time: 0.0, value: simd_float3(0, 0.9, 0)),
                .init(time: 1.0, value: simd_float3(0, 0.9, speed)),
                .init(time: 2.0, value: simd_float3(0, 0.9, speed * 2)),
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

    private func buildDatabase() -> MotionDatabase? {
        let skeleton = scene.get(component: SkeletonComponent.self, for: entityId)!.skeleton!
        let clips = [animationComponent.animationClips["walk"]!, animationComponent.animationClips["idle"]!]
        let compiled = clips.map { animationComponent.compiledClip(for: $0, skeleton: skeleton) }
        return MotionDatabase(
            clips: clips,
            compiledClips: compiled,
            skeleton: skeleton,
            leftFootPath: "root/foot_l",
            rightFootPath: "root/foot_r",
            sampleRate: 30,
            weights: MotionMatchingWeights()
        )
    }

    private func run(seconds: Float, goal: simd_float3) {
        setMotionMatchingGoal(entityId: entityId, desiredVelocity: goal)
        var time: Float = 0
        while time < seconds {
            AnimationSystem.shared.update(deltaTime)
            time += deltaTime
        }
    }

    // MARK: - Database construction

    func testDatabaseFrameCountAndLayout() throws {
        let database = try XCTUnwrap(buildDatabase())

        // Two 2 s clips at 30 Hz.
        XCTAssertEqual(database.frames.count, 120)
        XCTAssertEqual(database.dimensions, 27)
        XCTAssertEqual(database.frames.filter { $0.clipIndex == 0 }.count, 60)
    }

    func testWalkFramesEncodeTravelFeatures() throws {
        let database = try XCTUnwrap(buildDatabase())

        // A mid-clip walk frame: hip velocity ≈ (0, 0, 1) m/s in character
        // space, and the 1 s trajectory sample ≈ 1 m ahead.
        let index = try XCTUnwrap(database.frames.firstIndex { $0.clipIndex == 0 && abs($0.time - 0.5) < 1e-3 })
        let features = database.rawFeatures(at: index)

        XCTAssertEqual(features[12], 0, accuracy: 1e-3, "hip velocity x")
        XCTAssertEqual(features[14], 1.0, accuracy: 1e-2, "hip velocity z")

        // Trajectory horizon entries: (x, z, sin, cos) per horizon.
        XCTAssertEqual(features[15 + 1], 0.33, accuracy: 2e-2, "0.33 s trajectory z")
        XCTAssertEqual(features[15 + 9], 1.0, accuracy: 2e-2, "1.0 s trajectory z")
        XCTAssertEqual(features[15 + 3], 1.0, accuracy: 1e-3, "facing cos stays forward")
    }

    func testIdleFramesEncodeStillness() throws {
        let database = try XCTUnwrap(buildDatabase())

        let index = try XCTUnwrap(database.frames.firstIndex { $0.clipIndex == 1 && abs($0.time - 0.5) < 1e-3 })
        let features = database.rawFeatures(at: index)

        XCTAssertEqual(features[14], 0, accuracy: 1e-3, "idle hip velocity z")
        XCTAssertEqual(features[15 + 9], 0, accuracy: 1e-3, "idle 1.0 s trajectory z")
    }

    func testTrajectoryWrapsAcrossLoopWithoutSnap() throws {
        let database = try XCTUnwrap(buildDatabase())

        // A walk frame near the clip end: its 1 s trajectory crosses the
        // loop wrap and must still be ≈ 1 m ahead, not negative.
        let index = try XCTUnwrap(database.frames.firstIndex { $0.clipIndex == 0 && abs($0.time - 1.8) < 1e-2 })
        let features = database.rawFeatures(at: index)
        XCTAssertEqual(features[15 + 9], 1.0, accuracy: 5e-2, "trajectory must wrap with per-loop displacement")
    }

    // MARK: - Search

    func testSearchFindsExactStoredFrame() throws {
        let database = try XCTUnwrap(buildDatabase())

        // Query with a stored frame's own features: that frame (or one
        // with identical features) must win.
        let index = 30
        let query = database.rawFeatures(at: index)
        let best = try XCTUnwrap(database.search(query: query))

        let expected = database.rawFeatures(at: index)
        let found = database.rawFeatures(at: best)
        for d in 0 ..< database.dimensions {
            XCTAssertEqual(found[d], expected[d], accuracy: 1e-3, "dimension \(d)")
        }
    }

    func testSearchSeparatesWalkFromIdleByGoal() throws {
        let database = try XCTUnwrap(buildDatabase())

        // Walk-like query (features of a walk frame) must land in the walk
        // clip; idle-like in the idle clip.
        let walkIndex = try XCTUnwrap(database.frames.firstIndex { $0.clipIndex == 0 && abs($0.time - 1.0) < 1e-3 })
        let idleIndex = try XCTUnwrap(database.frames.firstIndex { $0.clipIndex == 1 && abs($0.time - 1.0) < 1e-3 })

        let bestWalk = try XCTUnwrap(database.search(query: database.rawFeatures(at: walkIndex)))
        let bestIdle = try XCTUnwrap(database.search(query: database.rawFeatures(at: idleIndex)))

        XCTAssertEqual(database.frames[bestWalk].clipIndex, 0)
        XCTAssertEqual(database.frames[bestIdle].clipIndex, 1)
    }

    // MARK: - End to end: goal-driven clip selection

    func testForwardGoalSelectsWalkAndMovesEntity() {
        setMotionMatchingEnabled(entityId: entityId, enabled: true)

        run(seconds: 1.5, goal: simd_float3(0, 0, 1))

        XCTAssertEqual(animationComponent.currentAnimation?.name, "walk")
        XCTAssertGreaterThan(
            getLocalPosition(entityId: entityId).z, 0.3,
            "Walk clip's root motion must move the entity toward the goal"
        )
    }

    func testZeroGoalSettlesOnIdle() {
        setMotionMatchingEnabled(entityId: entityId, enabled: true)

        run(seconds: 1.5, goal: simd_float3(0, 0, 1))
        XCTAssertEqual(animationComponent.currentAnimation?.name, "walk")

        run(seconds: 2.5, goal: .zero)
        XCTAssertEqual(animationComponent.currentAnimation?.name, "idle")

        let position = getLocalPosition(entityId: entityId).z
        AnimationSystem.shared.update(deltaTime)
        XCTAssertEqual(
            getLocalPosition(entityId: entityId).z, position, accuracy: 1e-4,
            "Idle must stop the entity"
        )
    }

    func testContinuityKeepsPlaybackMonotonicUnderConstantGoal() {
        setMotionMatchingEnabled(entityId: entityId, enabled: true)
        run(seconds: 1.0, goal: simd_float3(0, 0, 1))

        // Under a constant, matched goal, playback should advance without
        // re-jumping every search (currentTime never rewinds noticeably).
        var previousTime = animationComponent.currentTime
        var time: Float = 0
        while time < 1.0 {
            AnimationSystem.shared.update(deltaTime)
            let current = animationComponent.currentTime
            XCTAssertGreaterThan(current, previousTime - 0.25, "Playback rewound more than a search step at t=\(time)")
            previousTime = current
            time += deltaTime
        }
    }

    func testDisabledByDefault() {
        // Descriptor set in setUp, but not enabled: nothing should play.
        run(seconds: 0.5, goal: simd_float3(0, 0, 1))
        XCTAssertNil(animationComponent.currentAnimation)
        XCTAssertFalse(isMotionMatchingEnabled(entityId: entityId))
    }
}

extension AnimationMotionMatchingTests {
    /// Hierarchical assets (setEntityMeshAsync) carry their
    /// AnimationComponent on a scenegraph child while the game drives the
    /// root. Root motion deltas and the character frame must anchor to the
    /// entity the public API was called on, not the component's entity.
    @MainActor
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
        setMotionMatching(entityId: root, descriptor: MotionMatchingDescriptor(
            leftFootPath: "root/foot_l",
            rightFootPath: "root/foot_r",
            weights: MotionMatchingWeights(footVelocity: 0.5)
        ))
        setMotionMatchingEnabled(entityId: root, enabled: true)
        setMotionMatchingGoal(entityId: root, desiredVelocity: simd_float3(0, 0, 1))

        var time: Float = 0
        while time < 1.5 {
            AnimationSystem.shared.update(deltaTime)
            time += deltaTime
        }

        XCTAssertGreaterThan(
            getLocalPosition(entityId: root).z, 0.3,
            "Root motion must move the API entity (the gameplay handle)"
        )
        XCTAssertEqual(
            simd_length(getLocalPosition(entityId: entityId)), 0, accuracy: 1e-4,
            "The component's child entity must not drift inside the asset"
        )
    }
}

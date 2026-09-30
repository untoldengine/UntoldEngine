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

    /// Turn-in-place clip: the root yaws +90° about +Y over the 2 s loop
    /// with no travel.
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

    /// Stop clip: the root travels +z at 1 m/s through the first second of
    /// the 2 s clip and stands through the second.
    private func makeStopClip() -> AnimationClip {
        let rootChannel = RuntimeAnimationChannel(
            jointPath: "root",
            translations: [
                .init(time: 0.0, value: simd_float3(0, 0.9, 0)),
                .init(time: 1.0, value: simd_float3(0, 0.9, 1)),
                .init(time: 2.0, value: simd_float3(0, 0.9, 1)),
            ],
            rotations: [
                .init(time: 0.0, value: SIMD4<Float>(0, 0, 0, 1)),
                .init(time: 2.0, value: SIMD4<Float>(0, 0, 0, 1)),
            ]
        )
        return AnimationClip(runtimeClip: RuntimeAnimationClip(name: "stop", duration: 2.0, channels: [rootChannel]))
    }

    private func buildDatabase(clips: [AnimationClip], oneShot: Set<String>, tail: Float) -> MotionDatabase? {
        let skeleton = scene.get(component: SkeletonComponent.self, for: entityId)!.skeleton!
        let compiled = clips.map { animationComponent.compiledClip(for: $0, skeleton: skeleton) }
        return MotionDatabase(
            clips: clips,
            compiledClips: compiled,
            skeleton: skeleton,
            leftFootPath: "root/foot_l",
            rightFootPath: "root/foot_r",
            sampleRate: 30,
            weights: MotionMatchingWeights(),
            oneShotClipNames: oneShot,
            oneShotTail: tail
        )
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

    /// A goal behind the character must be met by turning: the predicted
    /// trajectory is a turn-rate-limited arc with speed scaled by the
    /// cosine of the heading error, so the turn clip's "rotate in place"
    /// trajectory wins — not the walk driven backward, which no clip
    /// contains and which used to make the search degenerate.
    func testGoalBehindSelectsTurnNotBackwardTravel() {
        animationComponent.animationClips["turn"] = makeTurnClip()
        setMotionMatchingEnabled(entityId: entityId, enabled: true)

        run(seconds: 1.0, goal: simd_float3(0, 0, -1))

        XCTAssertEqual(animationComponent.currentAnimation?.name, "turn",
                       "A goal behind the character must select the turn clip")
        XCTAssertGreaterThan(getLocalPosition(entityId: entityId).z, -0.1,
                             "The character must not be driven backward toward the goal")
        let (yaw, _) = yawTwist(getRotationQuaternion(entityId: entityId))
        XCTAssertGreaterThan(abs(yaw), 0.2, "The turn clip's root yaw must be rotating the character toward the goal")
    }

    /// A database with only straight clips cannot turn the character; the
    /// heading warp closes the error while traveling, and stays off when
    /// the rate is zero.
    func testHeadingWarpClosesErrorStraightClipsCannot() {
        func yawAfterChase(warpRate: Float) -> Float {
            setRootMotionEnabled(entityId: entityId, enabled: true)
            setMotionMatching(entityId: entityId, descriptor: MotionMatchingDescriptor(
                leftFootPath: "root/foot_l",
                rightFootPath: "root/foot_r",
                clipNames: ["walk"],
                headingCorrectionRate: warpRate
            ))
            setMotionMatchingEnabled(entityId: entityId, enabled: true)
            rotateTo(entityId: entityId, rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1))
            var time: Float = 0
            while time < 1.5 {
                // goal 90° to the right of the initial +Z heading
                setMotionMatchingGoal(entityId: entityId, desiredVelocity: simd_float3(1, 0, 0), desiredFacing: simd_float3(1, 0, 0))
                AnimationSystem.shared.update(deltaTime)
                time += deltaTime
            }
            return yawTwist(getRotationQuaternion(entityId: entityId)).yaw
        }

        let withoutWarp = yawAfterChase(warpRate: 0)
        XCTAssertLessThan(abs(withoutWarp), 0.1, "Straight clips alone must not turn the character")

        let withWarp = yawAfterChase(warpRate: 2.0)
        XCTAssertGreaterThan(withWarp, 0.8, "The warp must rotate the traveling character toward the goal")
    }

    /// A candidate that beats the incumbent by less than the minimum gain
    /// must not win, however good the relative margin looks.
    func testSearchIgnoresNegligibleGains() throws {
        let database = try XCTUnwrap(buildDatabase())
        XCTAssertGreaterThan(database.frames.count, 32)

        // Query reproducing frame 30 exactly; its neighbour is the incumbent.
        let query = database.rawFeatures(at: 30)
        let exact = try XCTUnwrap(database.search(query: query, preferredIndex: 31, minimumGain: 0))
        XCTAssertNotEqual(exact, 31, "With no floor the exact match wins")
        XCTAssertEqual(database.search(query: query, preferredIndex: 31, minimumGain: 1e6), 31,
                       "With a floor larger than the gain the incumbent keeps playing")
    }

    func testPrepareBuildsDatabaseBeforeEnable() {
        prepareMotionMatching(entityId: entityId)
        XCTAssertNotNil(animationComponent.motionMatching.database, "Built eagerly")
        XCTAssertFalse(isMotionMatchingEnabled(entityId: entityId))
        XCTAssertNil(animationComponent.currentAnimation, "Preparing does not start playback")

        let database = animationComponent.motionMatching.database
        setMotionMatchingEnabled(entityId: entityId, enabled: true)
        run(seconds: 0.1, goal: simd_float3(0, 0, 1))
        XCTAssertNotNil(animationComponent.currentAnimation, "First enabled update searches")
        XCTAssertTrue(animationComponent.motionMatching.database === database, "Prepared database is kept")
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

    // MARK: - Hands and runway

    func testHandFeaturesExtendTheLayout() throws {
        let skeleton = try XCTUnwrap(scene.get(component: SkeletonComponent.self, for: entityId)?.skeleton)
        let walk = try XCTUnwrap(animationComponent.animationClips["walk"])
        let clips = [walk]
        let compiled = clips.map { animationComponent.compiledClip(for: $0, skeleton: skeleton) }
        // The feet stand in for hands on this skeleton: the six extra
        // dimensions must mirror the foot positions.
        let database = try XCTUnwrap(MotionDatabase(
            clips: clips, compiledClips: compiled, skeleton: skeleton,
            leftFootPath: "root/foot_l", rightFootPath: "root/foot_r",
            leftHandPath: "root/foot_l", rightHandPath: "root/foot_r",
            sampleRate: 30, weights: MotionMatchingWeights()
        ))
        XCTAssertTrue(database.hasHands)
        XCTAssertEqual(database.dimensions, 33)
        let raw = database.rawFeatures(at: 10)
        for d in 0 ..< 6 {
            XCTAssertEqual(raw[15 + d], raw[d], accuracy: 1e-5)
        }
        // Without hand paths the layout is unchanged.
        let plain = try XCTUnwrap(buildDatabase())
        XCTAssertFalse(plain.hasHands)
        XCTAssertEqual(plain.dimensions, 27)
    }

    func testRunwayPenaltyMovesAStandingMatchOffAOneShotTail() throws {
        let stop = makeStopClip()
        let skeleton = try XCTUnwrap(scene.get(component: SkeletonComponent.self, for: entityId)?.skeleton)
        let compiled = [animationComponent.compiledClip(for: stop, skeleton: skeleton)]
        func database(penalty: Float) throws -> MotionDatabase {
            try XCTUnwrap(MotionDatabase(
                clips: [stop], compiledClips: compiled, skeleton: skeleton,
                leftFootPath: "root/foot_l", rightFootPath: "root/foot_r",
                sampleRate: 30, weights: MotionMatchingWeights(),
                oneShotClipNames: ["stop"], oneShotTail: 0, oneShotRunwayPenalty: penalty
            ))
        }
        // Standing near the end: without a penalty the incumbent holds
        // (every standing frame costs the same); with one, an equal frame
        // a second earlier wins.
        let free = try database(penalty: 0)
        let taxed = try database(penalty: 1)
        let tail = try XCTUnwrap(free.frameIndex(ofClip: stop, time: 1.9))
        let query = free.rawFeatures(at: tail)
        let held = try XCTUnwrap(free.search(query: query, preferredIndex: tail, minimumGain: 0.05))
        XCTAssertEqual(held, tail)
        let moved = try XCTUnwrap(taxed.search(query: query, preferredIndex: tail, minimumGain: 0.05))
        XCTAssertNotEqual(moved, tail)
        XCTAssertLessThanOrEqual(taxed.frames[moved].time, 1.0 + 1e-4)
        XCTAssertEqual(taxed.runwayPenalties[tail], 0.81, accuracy: 0.02)
        XCTAssertEqual(taxed.runwayPenalties[moved], 0, accuracy: 1e-6)
    }

    // MARK: - One-shot clips

    func testOneShotTrajectoryExtrapolatesInsteadOfWrapping() throws {
        let stop = makeStopClip()
        let looping = try XCTUnwrap(buildDatabase(clips: [stop], oneShot: [], tail: 0))
        let oneShot = try XCTUnwrap(buildDatabase(clips: [stop], oneShot: ["stop"], tail: 0))

        // Standing at 1.5 s, one second ahead: the looping database wraps
        // into the clip's travel, the one-shot database keeps standing.
        let zAtOneSecond = MotionFeatureLayout.poseDimensions + 2 * 4 + 1
        let loopingFrame = try XCTUnwrap(looping.frameIndex(ofClip: stop, time: 1.5))
        let oneShotFrame = try XCTUnwrap(oneShot.frameIndex(ofClip: stop, time: 1.5))
        XCTAssertGreaterThan(looping.rawFeatures(at: loopingFrame)[zAtOneSecond], 0.4)
        XCTAssertEqual(oneShot.rawFeatures(at: oneShotFrame)[zAtOneSecond], 0, accuracy: 1e-3)

        // A one-shot clip drops its last sample so no velocity wraps either.
        XCTAssertEqual(looping.frames.count, 60)
        XCTAssertEqual(oneShot.frames.count, 59)
        XCTAssertTrue(oneShot.isOneShot(clip: stop))
        XCTAssertFalse(looping.isOneShot(clip: stop))
    }

    func testOneShotTailIsNotSearchable() throws {
        let stop = makeStopClip()
        let database = try XCTUnwrap(buildDatabase(clips: [stop], oneShot: ["stop"], tail: 0.5))

        // Frames past 1.5 s are never returned, even for their own features.
        let tailFrame = try XCTUnwrap(database.frameIndex(ofClip: stop, time: 1.8))
        XCTAssertFalse(database.searchable[tailFrame])
        let best = try XCTUnwrap(database.search(query: database.rawFeatures(at: tailFrame)))
        XCTAssertTrue(database.searchable[best])
        XCTAssertLessThanOrEqual(database.frames[best].time, 1.5 + 1e-4)
        XCTAssertEqual(database.searchable.filter { $0 == false }.count, 14)
    }

    func testOneShotPlaybackLeavesThroughAJumpBeforeTheEnd() throws {
        animationComponent.animationClips["stop"] = makeStopClip()
        setMotionMatching(entityId: entityId, descriptor: MotionMatchingDescriptor(
            leftFootPath: "root/foot_l",
            rightFootPath: "root/foot_r",
            clipNames: ["stop", "idle"],
            oneShotClipNames: ["stop"],
            weights: MotionMatchingWeights(footVelocity: 0.5)
        ))
        setMotionMatchingEnabled(entityId: entityId, enabled: true)
        setMotionMatchingGoal(entityId: entityId, desiredVelocity: .zero)
        prepareMotionMatching(entityId: entityId)
        AnimationSystem.shared.update(deltaTime) // hard start on the first database frame

        // Standing in the stop clip's second half with a standing goal:
        // nothing beats the incumbent, so only the end guard can move it.
        let stop = try XCTUnwrap(animationComponent.animationClips["stop"])
        animationComponent.currentAnimation = stop
        animationComponent.currentTime = 1.2

        var time: Float = 0
        var maxTime: Float = 0
        var sawJump = false
        var wrapped = false
        while time < 1.5, sawJump == false {
            let before = animationComponent.currentTime
            AnimationSystem.shared.update(deltaTime)
            time += deltaTime
            if animationComponent.motionMatching.timeSinceJump == 0 {
                sawJump = true
            } else if animationComponent.currentAnimation === stop {
                maxTime = max(maxTime, animationComponent.currentTime)
                if animationComponent.currentTime < before {
                    wrapped = true
                }
            }
        }
        XCTAssertFalse(wrapped, "a one-shot clip must never wrap")
        XCTAssertLessThan(maxTime, 2.0)
        XCTAssertTrue(sawJump, "playback should leave a one-shot clip through a search before its end")
    }
}

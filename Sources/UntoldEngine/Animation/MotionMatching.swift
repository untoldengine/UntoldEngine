//
//  MotionMatching.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

// Motion matching controller: instead of a hand-authored state machine
// choosing clips, gameplay states a *goal* (desired velocity and facing —
// typically straight from the steering system) and the controller
// periodically searches the motion database for the frame that best
// matches the current pose and the predicted future trajectory, then jumps
// there through an inertialized transition. Root motion should be enabled
// on the entity: the clips' own travel is what moves the character.
// See docs/Architecture/animationPoseLayer.md.

/// Configuration for motion matching on one entity.
public struct MotionMatchingDescriptor {
    /// Clip names to include in the database; empty means every clip
    /// loaded on the entity.
    public var clipNames: [String]

    /// Feet joints for pose features.
    public var leftFootPath: String
    public var rightFootPath: String

    /// Database resample rate in frames per second.
    public var sampleRate: Float

    /// How often the database is searched, in seconds.
    public var searchInterval: Float

    /// Halflife of the inertialized transition used for jumps.
    public var transitionHalflife: Float

    /// Halflife of the simulated velocity's approach to the desired
    /// velocity — lower is more responsive, higher is smoother.
    public var predictionHalflife: Float

    public var weights: MotionMatchingWeights

    public init(
        leftFootPath: String,
        rightFootPath: String,
        clipNames: [String] = [],
        sampleRate: Float = 30,
        searchInterval: Float = 0.1,
        transitionHalflife: Float = 0.1,
        predictionHalflife: Float = 0.25,
        weights: MotionMatchingWeights = MotionMatchingWeights()
    ) {
        self.leftFootPath = leftFootPath
        self.rightFootPath = rightFootPath
        self.clipNames = clipNames
        self.sampleRate = sampleRate
        self.searchInterval = searchInterval
        self.transitionHalflife = transitionHalflife
        self.predictionHalflife = predictionHalflife
        self.weights = weights
    }
}

/// Per-entity motion matching state.
struct MotionMatchingState {
    var isEnabled = false
    var descriptor: MotionMatchingDescriptor?
    var database: MotionDatabase?

    /// The gameplay handle whose transform expresses the character's world
    /// position and heading (see RootMotionState.anchorEntity).
    var anchorEntity: EntityID = .invalid

    /// World-space goal, set by gameplay every frame (or whenever it
    /// changes).
    var desiredVelocity = simd_float3.zero
    var desiredFacing: simd_float3?

    /// First-order-lag simulated velocity in character space; drives the
    /// trajectory prediction.
    var simulatedVelocity = simd_float3.zero

    var searchClock: Float = 0

    /// Query history for finite-difference features.
    var hasHistory = false
    var previousLeftFootWorld = simd_float3.zero
    var previousRightFootWorld = simd_float3.zero
    var previousWorldPosition = simd_float3.zero
    var historyElapsed: Float = 0

    /// FK scratch.
    var fkPositions: [simd_float3] = []
    var fkRotations: [simd_quatf] = []
    var query: [Float] = []

    mutating func reset() {
        database = nil
        simulatedVelocity = .zero
        searchClock = 0
        hasHistory = false
        historyElapsed = 0
    }
}

// MARK: - Per-frame update

/// Runs one motion matching step for an entity: advances the simulated
/// velocity, and on the search cadence builds a query from the current
/// pose + predicted trajectory, searches the database, and jumps when a
/// better frame is found. Called before the frame's pose sampling, so a
/// jump takes effect the same frame.
func updateMotionMatching(
    entityId: EntityID,
    animationComponent: AnimationComponent,
    skeleton: Skeleton,
    deltaTime: Float
) {
    guard animationComponent.motionMatching.isEnabled,
          let descriptor = animationComponent.motionMatching.descriptor
    else { return }

    if animationComponent.motionMatching.database == nil {
        buildMotionDatabase(animationComponent: animationComponent, skeleton: skeleton, descriptor: descriptor)
        // Force a search on the first update so the entity starts playing.
        animationComponent.motionMatching.searchClock = descriptor.searchInterval
    }
    guard let database = animationComponent.motionMatching.database else { return }

    let anchor = animationComponent.motionMatching.anchorEntity == .invalid
        ? entityId
        : animationComponent.motionMatching.anchorEntity

    // Character frame: the gameplay handle's world yaw (the pose root is
    // grounded when root motion is on, so that transform carries heading).
    let entityRotation = getRotationQuaternion(entityId: anchor)
    let entityYaw = yawTwist(
        simd_length_squared(entityRotation.vector) < 1e-8
            ? simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
            : entityRotation
    ).yaw
    let inverseEntityYaw = simd_quatf(angle: -entityYaw, axis: simd_float3(0, 1, 0))

    // Advance the simulated velocity toward the goal (first-order lag).
    let desiredVelocityCS = inverseEntityYaw.act(animationComponent.motionMatching.desiredVelocity)
    let lambda = 0.693_147_18 / max(descriptor.predictionHalflife, 1e-3)
    let approach = 1 - exp(-lambda * deltaTime)
    animationComponent.motionMatching.simulatedVelocity +=
        (desiredVelocityCS - animationComponent.motionMatching.simulatedVelocity) * approach

    animationComponent.motionMatching.searchClock += deltaTime
    animationComponent.motionMatching.historyElapsed += deltaTime
    guard animationComponent.motionMatching.searchClock >= descriptor.searchInterval else { return }
    animationComponent.motionMatching.searchClock = 0

    // Nothing playing yet: hard-start on the first database frame; the
    // next search will course-correct with a real query.
    guard animationComponent.currentAnimation != nil, animationComponent.hasSampledPose else {
        let frame = database.frames[0]
        motionMatchingJump(
            entityId: entityId,
            animationComponent: animationComponent,
            skeleton: skeleton,
            database: database,
            frameIndex: 0,
            halflife: 0
        )
        _ = frame
        return
    }

    // Seed the search with where playback currently is, so equal-cost
    // frames never cause a jump.
    var preferredIndex: Int?
    if let current = animationComponent.currentAnimation {
        let wrapped = fmod(animationComponent.currentTime, max(current.duration, 1e-4))
        preferredIndex = database.frameIndex(ofClip: current, time: wrapped)
    }

    guard let query = buildMotionMatchingQuery(
        entityId: entityId,
        anchorEntity: anchor,
        animationComponent: animationComponent,
        skeleton: skeleton,
        database: database,
        descriptor: descriptor,
        inverseEntityYaw: inverseEntityYaw
    ), let best = database.search(query: query, preferredIndex: preferredIndex) else { return }

    let frame = database.frames[best]
    let clip = database.clips[frame.clipIndex]

    // Continuity: when the winner is (near) where playback would naturally
    // be anyway, keep playing instead of re-transitioning every search.
    if let current = animationComponent.currentAnimation, current === clip {
        let duration = max(clip.duration, 1e-4)
        let wrapped = fmod(animationComponent.currentTime, duration)
        var difference = abs(wrapped - frame.time)
        difference = min(difference, duration - difference)
        if difference < database.sampleInterval * 2 {
            return
        }
    }

    motionMatchingJump(
        entityId: entityId,
        animationComponent: animationComponent,
        skeleton: skeleton,
        database: database,
        frameIndex: best,
        halflife: descriptor.transitionHalflife
    )
}

// MARK: - Query construction

private func buildMotionMatchingQuery(
    entityId: EntityID,
    anchorEntity: EntityID,
    animationComponent: AnimationComponent,
    skeleton: Skeleton,
    database: MotionDatabase,
    descriptor: MotionMatchingDescriptor,
    inverseEntityYaw: simd_quatf
) -> [Float]? {
    let pose = animationComponent.localPose
    guard pose.jointCount == skeleton.jointPaths.count else { return nil }

    animationComponent.motionMatching.refreshForwardKinematics(pose: pose, parentIndices: skeleton.parentIndices)
    let positions = animationComponent.motionMatching.fkPositions
    let rotations = animationComponent.motionMatching.fkRotations

    // Character frame from the pose root (identity when root motion has
    // grounded the pose — this also covers the ungrounded case).
    let root = database.rootJointIndex
    let rootYaw = yawTwist(rotations[root]).yaw
    let inverseRootYaw = simd_quatf(angle: -rootYaw, axis: simd_float3(0, 1, 0))
    let rootHorizontal = simd_float3(positions[root].x, 0, positions[root].z)

    let leftFoot = inverseRootYaw.act(positions[database.leftFootIndex] - rootHorizontal)
    let rightFoot = inverseRootYaw.act(positions[database.rightFootIndex] - rootHorizontal)
    let worldPosition = getPosition(entityId: anchorEntity)

    // Velocities are world-space finite differences rotated into the
    // character frame — the entity's own travel is part of a foot's
    // velocity, matching how the database measures it from clip root
    // motion.
    let worldMatrix = scene.get(component: WorldTransformComponent.self, for: entityId)?.space ?? .identity
    func toWorld(_ p: simd_float3) -> simd_float3 {
        let w = worldMatrix * simd_float4(p, 1)
        return simd_float3(w.x, w.y, w.z)
    }
    let leftFootWorld = toWorld(positions[database.leftFootIndex])
    let rightFootWorld = toWorld(positions[database.rightFootIndex])

    let elapsed = animationComponent.motionMatching.historyElapsed
    var leftVelocity = simd_float3.zero
    var rightVelocity = simd_float3.zero
    var hipVelocity = simd_float3.zero
    if animationComponent.motionMatching.hasHistory, elapsed > 1e-4 {
        leftVelocity = inverseEntityYaw.act(
            (leftFootWorld - animationComponent.motionMatching.previousLeftFootWorld) / elapsed
        )
        rightVelocity = inverseEntityYaw.act(
            (rightFootWorld - animationComponent.motionMatching.previousRightFootWorld) / elapsed
        )
        hipVelocity = inverseEntityYaw.act(
            (worldPosition - animationComponent.motionMatching.previousWorldPosition) / elapsed
        )
    }

    animationComponent.motionMatching.previousLeftFootWorld = leftFootWorld
    animationComponent.motionMatching.previousRightFootWorld = rightFootWorld
    animationComponent.motionMatching.previousWorldPosition = worldPosition
    animationComponent.motionMatching.hasHistory = true
    animationComponent.motionMatching.historyElapsed = 0

    var query: [Float] = []
    query.reserveCapacity(database.dimensions)
    for value in [leftFoot, rightFoot, leftVelocity, rightVelocity, hipVelocity] {
        query.append(value.x)
        query.append(value.y)
        query.append(value.z)
    }

    // Predicted trajectory: integrate the first-order lag of the simulated
    // velocity toward the desired velocity, in character space. Facing
    // approaches the desired facing with the same time constant.
    let velocity = animationComponent.motionMatching.simulatedVelocity
    let desiredVelocityCS = inverseEntityYaw.act(animationComponent.motionMatching.desiredVelocity)
    let lambda = 0.693_147_18 / max(descriptor.predictionHalflife, 1e-3)

    var desiredYawDelta: Float = 0
    if let facing = animationComponent.motionMatching.desiredFacing,
       simd_length_squared(simd_float3(facing.x, 0, facing.z)) > 1e-8
    {
        let facingCS = inverseEntityYaw.act(simd_float3(facing.x, 0, facing.z))
        desiredYawDelta = atan2(facingCS.x, facingCS.z)
    } else if simd_length_squared(simd_float3(desiredVelocityCS.x, 0, desiredVelocityCS.z)) > 1e-6 {
        desiredYawDelta = atan2(desiredVelocityCS.x, desiredVelocityCS.z)
    }

    for horizon in MotionFeatureLayout.trajectoryHorizons {
        let decay = (1 - exp(-lambda * horizon)) / lambda
        let position = desiredVelocityCS * horizon + (velocity - desiredVelocityCS) * decay
        query.append(position.x)
        query.append(position.z)
        let yawAtHorizon = desiredYawDelta * (1 - exp(-lambda * horizon))
        query.append(sin(yawAtHorizon))
        query.append(cos(yawAtHorizon))
    }

    return query
}

// MARK: - Database build and jumps

private func buildMotionDatabase(
    animationComponent: AnimationComponent,
    skeleton: Skeleton,
    descriptor: MotionMatchingDescriptor
) {
    let names = descriptor.clipNames.isEmpty
        ? animationComponent.animationClips.keys.sorted()
        : descriptor.clipNames

    var clips: [AnimationClip] = []
    var compiled: [CompiledAnimationClip] = []
    for name in names {
        guard let clip = animationComponent.animationClips[name] else { continue }
        clips.append(clip)
        compiled.append(animationComponent.compiledClip(for: clip, skeleton: skeleton))
    }

    animationComponent.motionMatching.database = MotionDatabase(
        clips: clips,
        compiledClips: compiled,
        skeleton: skeleton,
        leftFootPath: descriptor.leftFootPath,
        rightFootPath: descriptor.rightFootPath,
        sampleRate: descriptor.sampleRate,
        weights: descriptor.weights
    )
}

/// Jumps playback to a database frame through an inertialized transition
/// (or a hard cut when `halflife` is zero), re-baselining root motion.
func motionMatchingJump(
    entityId: EntityID,
    animationComponent: AnimationComponent,
    skeleton _: Skeleton,
    database: MotionDatabase,
    frameIndex: Int,
    halflife: Float
) {
    let frame = database.frames[frameIndex]
    let clip = database.clips[frame.clipIndex]

    beginAnimationTransition(
        entityId: entityId,
        animationComponent: animationComponent,
        to: clip,
        halflife: halflife,
        targetTime: frame.time
    )
    animationComponent.currentAnimation = clip
    animationComponent.currentTime = frame.time
    animationComponent.rootMotion.resetHistory()
}

extension MotionMatchingState {
    /// Single-access FK refresh (see the exclusivity note on
    /// `FootIKState.refreshForwardKinematics`).
    mutating func refreshForwardKinematics(pose: PoseBuffer, parentIndices: [Int?]) {
        computeForwardKinematics(
            pose: pose,
            parentIndices: parentIndices,
            positions: &fkPositions,
            rotations: &fkRotations
        )
    }
}

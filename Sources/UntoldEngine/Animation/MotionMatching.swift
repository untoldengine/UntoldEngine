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

    /// Hand joints, optional: when both are given their positions join the
    /// pose features (weighted by `weights.handPosition`), so a jump
    /// prefers a clip whose arms are near where they already are instead
    /// of flapping the upper body between clips the feet call equal.
    public var leftHandPath: String?
    public var rightHandPath: String?

    /// Database resample rate in frames per second.
    public var sampleRate: Float

    /// How often the database is searched, in seconds.
    public var searchInterval: Float

    /// Halflife of the inertialized transition used for jumps.
    public var transitionHalflife: Float

    /// Halflife of the simulated velocity's approach to the desired
    /// velocity — lower is more responsive, higher is smoother.
    public var predictionHalflife: Float

    /// Fastest heading change the predicted trajectory may request, in
    /// radians per second. The query is built as a turn-rate-limited arc
    /// toward the goal: heading rotates at most this fast and commanded
    /// speed scales with the cosine of the remaining heading error, so an
    /// off-heading goal asks for "turn (in place), then accelerate" — a
    /// trajectory the database's turn and circular clips actually contain
    /// — instead of full-speed travel in a direction no clip can do.
    public var maxTurnRate: Float

    /// Orientation warp: a rate-limited yaw correction (radians per second)
    /// applied to the anchor while the character travels, closing whatever
    /// heading error the chosen clips leave. Databases rarely contain a
    /// curved clip for every speed — a pack may have circular sprints and
    /// in-place pivots but no curved walk — so without a warp the search
    /// prefers "walk straight, slightly off-heading" over "stop and pivot",
    /// and a 20-30° error persists indefinitely. Scaled by travel speed so
    /// a standing character never rotates without a pivot clip. Zero (the
    /// default) disables it; a few radians per second is typical.
    public var headingCorrectionRate: Float

    /// Travel speed at which the orientation warp reaches its full rate;
    /// below it the rate scales down linearly, to nothing when standing.
    /// The default 0.5 m/s lets a shamble bend its path at nearly the full
    /// rate, which on a character taking slow steps reads as a rigid turn
    /// with no footwork. Raise it so slow motion turns through pivot and
    /// arc clips and only a moving character's path is bent.
    public var headingCorrectionSpeed: Float

    /// Absolute floor on the cost improvement a candidate frame needs over
    /// the incumbent before a jump fires (scaled feature-space units). The
    /// relative switch margin is meaningless when both costs are tiny — a
    /// standing character re-matching the stillest frame of its idle every
    /// search "restarts" the idle instead of playing it through.
    public var switchMinimumGain: Float

    /// Minimum time playback runs before another jump may fire. The search
    /// still runs every `searchInterval`, but without this floor a frame
    /// that systematically beats the incumbent (for example the velocity
    /// peak of a cycle when the goal speed exceeds the clip's mean) wins
    /// every search and playback treadmills on one spot — a frozen-looking
    /// pose that never advances through the cycle.
    public var minPlayTime: Float

    /// Clips that must never wrap: starts, stops, pivots, or a long
    /// capture. The database assumes every other clip loops — a frame near
    /// the end predicts its trajectory into the clip's own beginning and
    /// playback runs straight through the wrap, which for a stop clip is a
    /// hard cut from standing back into the run. A one-shot clip instead
    /// extrapolates its trajectory past the end at its terminal velocity and
    /// yaw rate, forces a search — with no incumbent bias — as playback
    /// comes within a search interval of the end, and keeps the frames that
    /// could not play for `minPlayTime` before that out of the candidate
    /// set, so it always leaves through an inertialized jump and never
    /// bounces straight back out. Should the search find nothing, playback
    /// holds the last frame rather than wrapping.
    public var oneShotClipNames: Set<String>

    /// Cost added to a one-shot clip's frame as its playable time runs out
    /// (nothing with a second or more left, all of it at the end), so an
    /// equally good frame with runway wins: without it a standing goal
    /// settles on the still tail of a stop clip, is forced out at its end,
    /// and lands straight back on it — a half-second loop of jumps where a
    /// looping idle was available.
    public var oneShotRunwayPenalty: Float

    public var weights: MotionMatchingWeights

    public init(
        leftFootPath: String,
        rightFootPath: String,
        leftHandPath: String? = nil,
        rightHandPath: String? = nil,
        clipNames: [String] = [],
        sampleRate: Float = 30,
        searchInterval: Float = 0.1,
        transitionHalflife: Float = 0.1,
        predictionHalflife: Float = 0.25,
        maxTurnRate: Float = 2.0,
        headingCorrectionRate: Float = 0,
        headingCorrectionSpeed: Float = 0.5,
        switchMinimumGain: Float = 0.05,
        minPlayTime: Float = 0.3,
        oneShotClipNames: Set<String> = [],
        oneShotRunwayPenalty: Float = 1,
        weights: MotionMatchingWeights = MotionMatchingWeights()
    ) {
        self.leftFootPath = leftFootPath
        self.rightFootPath = rightFootPath
        self.leftHandPath = leftHandPath
        self.rightHandPath = rightHandPath
        self.clipNames = clipNames
        self.sampleRate = sampleRate
        self.searchInterval = searchInterval
        self.transitionHalflife = transitionHalflife
        self.predictionHalflife = predictionHalflife
        self.maxTurnRate = maxTurnRate
        self.headingCorrectionRate = headingCorrectionRate
        self.headingCorrectionSpeed = headingCorrectionSpeed
        self.switchMinimumGain = switchMinimumGain
        self.minPlayTime = minPlayTime
        self.oneShotClipNames = oneShotClipNames
        self.oneShotRunwayPenalty = oneShotRunwayPenalty
        self.weights = weights
    }
}

/// Signed heading error (radians, wrapped) from the character's forward to
/// the goal: the desired facing when one is set, else the desired velocity
/// direction. Zero when the goal gives no direction.
func motionMatchingGoalYawDelta(
    state: MotionMatchingState,
    inverseEntityYaw: simd_quatf
) -> Float {
    if let facing = state.desiredFacing,
       simd_length_squared(simd_float3(facing.x, 0, facing.z)) > 1e-8
    {
        let facingCS = inverseEntityYaw.act(simd_float3(facing.x, 0, facing.z))
        return atan2(facingCS.x, facingCS.z)
    }
    let velocityCS = inverseEntityYaw.act(state.desiredVelocity)
    if simd_length_squared(simd_float3(velocityCS.x, 0, velocityCS.z)) > 1e-6 {
        return atan2(velocityCS.x, velocityCS.z)
    }
    return 0
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
    var timeSinceJump: Float = .greatestFiniteMagnitude

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

    /// Scratch for the playing clip's raw pose (hand features).
    var rawSampler = ClipSampler()
    var rawPose = PoseBuffer()
    var rawPositions: [simd_float3] = []
    var rawRotations: [simd_quatf] = []

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

    // Advance the simulated velocity toward what the goal asks for ALONG
    // THE CURRENT HEADING: full desired speed when aligned, scaled down by
    // the cosine of the heading error, zero when the goal is behind — the
    // heading change itself is expressed by the arc trajectory below and
    // realized by the clips' root yaw. Lagging toward the raw goal vector
    // would drive the query sideways or backward at full speed, a
    // trajectory no clip contains, and the search would degenerate.
    let desiredVelocityCS = inverseEntityYaw.act(animationComponent.motionMatching.desiredVelocity)
    let goalYawDelta = motionMatchingGoalYawDelta(
        state: animationComponent.motionMatching,
        inverseEntityYaw: inverseEntityYaw
    )
    let desiredSpeed = simd_length(simd_float3(desiredVelocityCS.x, 0, desiredVelocityCS.z))
    let alignedSpeed = desiredSpeed * max(0, cos(goalYawDelta))
    let lambda = 0.693_147_18 / max(descriptor.predictionHalflife, 1e-3)
    let approach = 1 - exp(-lambda * deltaTime)
    animationComponent.motionMatching.simulatedVelocity +=
        (simd_float3(0, 0, alignedSpeed) - animationComponent.motionMatching.simulatedVelocity) * approach

    // Orientation warp: close the residual heading error the clips leave,
    // proportionally to how fast the character is ACTUALLY traveling (the
    // root motion applied last frame) — the simulated speed collapses for
    // large errors by design, but a character mid-stride can still bend
    // its path; a standing one must wait for a pivot clip.
    if descriptor.headingCorrectionRate > 0, abs(goalYawDelta) > 1e-4, deltaTime > 0 {
        let travel = animationComponent.rootMotion.isEnabled
            ? simd_length(animationComponent.rootMotion.lastWorldVelocity)
            : simd_length(animationComponent.motionMatching.simulatedVelocity)
        let movementScale = min(1, travel / max(descriptor.headingCorrectionSpeed, 1e-3))
        let maxStep = descriptor.headingCorrectionRate * deltaTime * movementScale
        let step = max(-maxStep, min(maxStep, goalYawDelta))
        if abs(step) > 1e-6 {
            let base = simd_length_squared(entityRotation.vector) < 1e-8
                ? simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
                : entityRotation
            let corrected = simd_normalize(base * simd_quatf(angle: step, axis: simd_float3(0, 1, 0)))
            rotateTo(entityId: anchor, rotation: corrected)
        }
    }

    animationComponent.motionMatching.searchClock += deltaTime
    animationComponent.motionMatching.historyElapsed += deltaTime
    animationComponent.motionMatching.timeSinceJump += deltaTime

    // A one-shot clip leaves through a search, never through the wrap:
    // within the last search interval (plus two samples of slack) every
    // update searches with no incumbent bias, and playback is held short of
    // the end in case nothing is found, so the pose freezes on the last
    // frame instead of cutting to the first.
    var forced = false
    if let current = animationComponent.currentAnimation, database.isOneShot(clip: current) {
        let duration = max(current.duration, 1e-4)
        let step = deltaTime * animationComponent.playbackSpeed
        if duration - animationComponent.currentTime <= descriptor.searchInterval + 2 * database.sampleInterval {
            forced = true
            animationComponent.motionMatching.searchClock = descriptor.searchInterval
        }
        if animationComponent.currentTime + step >= duration - 1e-3 {
            animationComponent.currentTime = max(0, duration - 1e-3 - step)
        }
    }

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
    // frames never cause a jump (not when forced out of a one-shot clip).
    var preferredIndex: Int?
    if !forced, let current = animationComponent.currentAnimation {
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
    ), let best = database.search(query: query, preferredIndex: preferredIndex, minimumGain: descriptor.switchMinimumGain) else { return }

    let frame = database.frames[best]
    let clip = database.clips[frame.clipIndex]

    // Continuity: when the winner is (near) where playback would naturally
    // be anyway, keep playing instead of re-transitioning every search.
    if !forced, let current = animationComponent.currentAnimation, current === clip {
        let duration = max(clip.duration, 1e-4)
        let wrapped = fmod(animationComponent.currentTime, duration)
        var difference = abs(wrapped - frame.time)
        difference = min(difference, duration - difference)
        if difference < database.sampleInterval * 2 {
            return
        }
    }

    guard forced || animationComponent.motionMatching.timeSinceJump >= descriptor.minPlayTime else { return }

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
    if let leftHand = database.leftHandIndex, let rightHand = database.rightHandIndex {
        // The hands come from the playing clip's own pose, not the displayed
        // one: right after a jump the displayed arms still carry the decaying
        // transition offset, and matching against that had the search chase
        // its own blend from frame to frame. The clip's hands say where the
        // arms are headed; a candidate is judged against that.
        var handPositions = positions
        var handRootHorizontal = rootHorizontal
        var handInverseYaw = inverseRootYaw
        if let current = animationComponent.currentAnimation {
            let compiled = animationComponent.compiledClip(for: current, skeleton: skeleton)
            animationComponent.motionMatching.refreshRawPose(
                compiled: compiled, clip: current,
                time: fmod(animationComponent.currentTime, max(current.duration, 1e-4)),
                parentIndices: skeleton.parentIndices
            )
            handPositions = animationComponent.motionMatching.rawPositions
            let rawRoot = handPositions[root]
            handRootHorizontal = simd_float3(rawRoot.x, 0, rawRoot.z)
            handInverseYaw = simd_quatf(
                angle: -yawTwist(animationComponent.motionMatching.rawRotations[root]).yaw,
                axis: simd_float3(0, 1, 0)
            )
        }
        for value in [
            handInverseYaw.act(handPositions[leftHand] - handRootHorizontal),
            handInverseYaw.act(handPositions[rightHand] - handRootHorizontal),
        ] {
            query.append(value.x)
            query.append(value.y)
            query.append(value.z)
        }
    }

    // Predicted trajectory: a turn-rate-limited arc toward the goal.
    // Heading rotates at most `maxTurnRate` toward the goal direction, and
    // speed lags toward the desired speed scaled by the cosine of the
    // remaining heading error — so a goal behind the character predicts
    // "rotate roughly in place, then accelerate out of the turn", which is
    // exactly the trajectory shape of turn and circular clips.
    let desiredVelocityCS = inverseEntityYaw.act(animationComponent.motionMatching.desiredVelocity)
    let desiredSpeed = simd_length(simd_float3(desiredVelocityCS.x, 0, desiredVelocityCS.z))
    let goalYawDelta = motionMatchingGoalYawDelta(
        state: animationComponent.motionMatching,
        inverseEntityYaw: inverseEntityYaw
    )
    let lambda = 0.693_147_18 / max(descriptor.predictionHalflife, 1e-3)
    let turnRate = max(descriptor.maxTurnRate, 1e-3)

    var arcYaw: Float = 0
    var arcPosition = simd_float3.zero
    var arcSpeed = max(0, animationComponent.motionMatching.simulatedVelocity.z)
    var arcTime: Float = 0
    let integrationStep: Float = 1.0 / 30.0
    for horizon in MotionFeatureLayout.trajectoryHorizons {
        while arcTime < horizon - 1e-6 {
            let step = min(integrationStep, horizon - arcTime)
            let remaining = goalYawDelta - arcYaw
            arcYaw += max(-turnRate * step, min(turnRate * step, remaining))
            let desiredNow = desiredSpeed * max(0, cos(goalYawDelta - arcYaw))
            arcSpeed += (desiredNow - arcSpeed) * (1 - exp(-lambda * step))
            arcPosition += simd_float3(sin(arcYaw), 0, cos(arcYaw)) * (arcSpeed * step)
            arcTime += step
        }
        query.append(arcPosition.x)
        query.append(arcPosition.z)
        query.append(sin(arcYaw))
        query.append(cos(arcYaw))
    }

    return query
}

// MARK: - Database build and jumps

func buildMotionDatabase(
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
        leftHandPath: descriptor.leftHandPath,
        rightHandPath: descriptor.rightHandPath,
        sampleRate: descriptor.sampleRate,
        weights: descriptor.weights,
        oneShotClipNames: descriptor.oneShotClipNames,
        // A target must be playable for minPlayTime before the end guard
        // (a search interval plus two samples from the end) forces it out.
        oneShotTail: descriptor.minPlayTime + descriptor.searchInterval + 2 / max(descriptor.sampleRate, 1),
        oneShotRunwayPenalty: descriptor.oneShotRunwayPenalty
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
    animationComponent.motionMatching.timeSinceJump = 0
    animationComponent.rootMotion.beginVelocityBlend(halflife: halflife)
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

    /// Samples the playing clip's raw pose at `time` and runs FK on it.
    mutating func refreshRawPose(compiled: CompiledAnimationClip, clip: AnimationClip, time: Float, parentIndices: [Int?]) {
        rawSampler.sample(compiled, time: time, duration: clip.duration, speed: clip.speed, into: &rawPose)
        computeForwardKinematics(
            pose: rawPose,
            parentIndices: parentIndices,
            positions: &rawPositions,
            rotations: &rawRotations
        )
    }
}

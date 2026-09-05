//
//  RootMotion.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

// Root motion: a locomotion clip authored with its root joint traveling
// (a walk that actually moves forward) normally drags the mesh away from
// the entity transform and snaps back when the clip loops. With root motion
// enabled, the root's horizontal translation and yaw deltas are extracted
// each frame and applied to the entity transform instead, and the pose is
// grounded — the character moves through the world because its animation
// says so. Vertical root motion, pitch, and roll stay in the pose (a
// stumbling zombie still leans).
//
// Loop wrap is handled with the clip's precomputed per-loop root
// displacement and yaw: when the sampled channel time wraps, the delta is
// corrected by one full loop instead of snapping backward.
// See docs/Architecture/animationPoseLayer.md.

/// Per-entity root motion state.
struct RootMotionState {
    var isEnabled = false

    /// Entity whose transform receives the extracted deltas — the entity
    /// the public API was called on (the gameplay handle). Hierarchical
    /// assets keep their AnimationComponent on a skinned descendant, but
    /// games move the asset root.
    var anchorEntity: EntityID = .invalid

    /// Whether this component applies its deltas to the anchor. Modular
    /// assets carry one AnimationComponent per skinned part, all sampling
    /// the same clips against the same anchor; exactly one of them drives
    /// the transform or the anchor moves at N× clip speed. The others still
    /// extract and ground their poses so every part stays in sync.
    var drivesAnchor = true

    /// Optional joint-path override; by default the skeleton's first
    /// parentless joint drives root motion.
    var rootJointPath: String?
    var resolvedRootIndex: Int?

    /// Last frame's raw (pre-strip) root sample, for delta extraction.
    var hasPreviousSample = false
    var previousTranslation = simd_float3.zero
    var previousYaw: Float = 0
    var previousTranslationTime: Float = 0
    var previousRotationTime: Float = 0

    /// Forget the sample history (clip switches, enable toggles); the next
    /// frame re-baselines with a zero delta.
    mutating func resetHistory() {
        hasPreviousSample = false
    }
}

// MARK: - Angle helpers

/// Wraps an angle to (-π, π] so frame-to-frame yaw deltas never take the
/// long way around.
@inline(__always)
func wrapAngle(_ angle: Float) -> Float {
    var wrapped = fmod(angle + .pi, 2 * .pi)
    if wrapped < 0 {
        wrapped += 2 * .pi
    }
    return wrapped - .pi
}

/// Swing–twist decomposition about the +Y axis: returns the yaw angle and
/// the twist quaternion, with the remainder (`q * twist⁻¹`) carrying pitch
/// and roll. The twist is normalized to the shortest arc so yaw is always
/// in (-π, π].
@inline(__always)
func yawTwist(_ q: simd_quatf) -> (yaw: Float, twist: simd_quatf) {
    let projected = simd_float4(0, q.imag.y, 0, q.real)
    let length = simd_length(projected)
    guard length > 1e-8 else {
        // A 180° rotation about a horizontal axis has no well-defined yaw.
        return (0, simd_quatf(ix: 0, iy: 0, iz: 0, r: 1))
    }
    var twist = simd_quatf(vector: projected / length)
    if twist.real < 0 {
        twist = simd_quatf(vector: -twist.vector)
    }
    return (2 * atan2(twist.imag.y, twist.real), twist)
}

/// Grounds the root joint of a local pose: horizontal translation is zeroed
/// and yaw removed (the entity transform owns both once root motion is on);
/// vertical translation, pitch, and roll remain.
@inline(__always)
func stripRootMotion(from pose: inout PoseBuffer, rootIndex: Int) {
    guard rootIndex >= 0, rootIndex < pose.jointCount else { return }
    pose.translations[rootIndex].x = 0
    pose.translations[rootIndex].z = 0
    let (_, twist) = yawTwist(pose.rotations[rootIndex])
    pose.rotations[rootIndex] = simd_normalize(pose.rotations[rootIndex] * twist.inverse)
}

// MARK: - Per-frame extraction

/// Resolves which joint drives root motion, caching the answer until the
/// state is reconfigured.
func resolveRootMotionJointIndex(
    state: inout RootMotionState,
    skeleton: Skeleton,
    compiledClip: CompiledAnimationClip
) -> Int? {
    if let cached = state.resolvedRootIndex {
        return cached
    }
    let index: Int? = if let path = state.rootJointPath {
        skeleton.jointPaths.firstIndex(of: path)
    } else {
        compiledClip.rootJointIndex
    }
    state.resolvedRootIndex = index
    return index
}

/// Extracts this frame's root translation/yaw deltas from the raw sampled
/// pose, applies them to the entity transform (character space rotated into
/// the entity's current orientation), and grounds the pose's root joint.
///
/// Must run on the raw sampled pose, before transition offsets are applied,
/// so the deltas come from the clip and transitions blend grounded poses.
func applyRootMotion(
    entityId: EntityID,
    animationComponent: AnimationComponent,
    skeleton: Skeleton,
    compiledClip: CompiledAnimationClip,
    clipDuration: Float,
    clipSpeed: Float
) {
    guard animationComponent.rootMotion.isEnabled else { return }
    guard let rootIndex = resolveRootMotionJointIndex(
        state: &animationComponent.rootMotion,
        skeleton: skeleton,
        compiledClip: compiledClip
    ), rootIndex < animationComponent.localPose.jointCount else { return }

    let channel = compiledClip.channels[rootIndex]
    guard channel.animated else { return }

    let translation = animationComponent.localPose.translations[rootIndex]
    let (yaw, _) = yawTwist(animationComponent.localPose.rotations[rootIndex])

    // Channel-wrapped sample times, replicating the sampler's per-channel
    // wrap, to detect when the clip looped between frames. Non-repeating
    // channels clamp at their last key (like the sampler), so a one-shot
    // clip never fakes a wrap and never injects a per-loop correction.
    let channelTime = fmod(animationComponent.currentTime, clipDuration) * clipSpeed
    let translationTime = wrappedChannelTime(channelTime, lastKeyTime: channel.translationTimes.last, repeats: channel.repeats)
    let rotationTime = wrappedChannelTime(channelTime, lastKeyTime: channel.rotationTimes.last, repeats: channel.repeats)

    let motionEntity = animationComponent.rootMotion.anchorEntity == .invalid
        ? entityId
        : animationComponent.rootMotion.anchorEntity

    if animationComponent.rootMotion.hasPreviousSample, animationComponent.rootMotion.drivesAnchor {
        var delta = translation - animationComponent.rootMotion.previousTranslation
        if translationTime < animationComponent.rootMotion.previousTranslationTime {
            delta += compiledClip.rootTranslationPerLoop
        }

        var yawDelta = yaw - animationComponent.rootMotion.previousYaw
        if rotationTime < animationComponent.rootMotion.previousRotationTime {
            yawDelta += compiledClip.rootYawPerLoop
        }
        yawDelta = wrapAngle(yawDelta)

        let horizontal = simd_float3(delta.x, 0, delta.z)
        if scene.get(component: LocalTransformComponent.self, for: motionEntity) != nil {
            // LocalTransformComponent's default rotation is the zero
            // quaternion (simd_quatf()), which rotates every vector to zero
            // — treat it as identity so deltas survive on never-rotated
            // entities.
            var entityRotation = getRotationQuaternion(entityId: motionEntity)
            if simd_length_squared(entityRotation.vector) < 1e-8 {
                entityRotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
            }
            if simd_length_squared(horizontal) > 0 {
                translateBy(entityId: motionEntity, position: entityRotation.act(horizontal))
            }
            if yawDelta != 0 {
                let yawRotation = simd_quatf(angle: yawDelta, axis: simd_float3(0, 1, 0))
                rotateTo(entityId: motionEntity, rotation: simd_normalize(entityRotation * yawRotation))
            }
        }
    }

    animationComponent.rootMotion.previousTranslation = translation
    animationComponent.rootMotion.previousYaw = yaw
    animationComponent.rootMotion.previousTranslationTime = translationTime
    animationComponent.rootMotion.previousRotationTime = rotationTime
    animationComponent.rootMotion.hasPreviousSample = true

    stripRootMotion(from: &animationComponent.localPose, rootIndex: rootIndex)
}

@inline(__always)
private func wrappedChannelTime(_ time: Float, lastKeyTime: Float?, repeats: Bool) -> Float {
    guard let lastKeyTime, lastKeyTime > 0 else { return 0 }
    guard repeats else { return min(time, lastKeyTime) }
    return fmod(time, lastKeyTime)
}

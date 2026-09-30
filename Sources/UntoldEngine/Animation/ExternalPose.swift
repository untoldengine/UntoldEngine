//
//  ExternalPose.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// A pose fed from outside the clip pipeline (motion capture, trackers,
/// procedural controllers): per-joint rotation deltas expressed in model
/// space on top of the skeleton's rest world orientation, plus an optional
/// root translation. Applied after clip sampling and transitions, before
/// the pose layer and IK, and solved through the hierarchy so unlisted
/// joints keep their animated local rotation while listed joints reach the
/// requested world orientation.
struct ExternalPoseState {
    /// Model-space delta per skeleton joint (nil = not driven).
    var worldRotationDeltas: [simd_quatf?] = []
    var rootJointIndex: Int?
    var rootTranslationDelta: simd_float3?
    var weight: Float = 1
    /// Rest world rotations per joint, rebuilt when the joint count changes.
    var restWorldRotations: [simd_quatf] = []
    var jointIndexCache: [String: Int?] = [:]

    var isActive: Bool {
        weight > 0 && (rootTranslationDelta != nil || worldRotationDeltas.contains { $0 != nil })
    }

    mutating func clear() {
        worldRotationDeltas.removeAll()
        rootJointIndex = nil
        rootTranslationDelta = nil
    }
}

/// Solves the external pose into `pose` (local space) for `skeleton`.
func applyExternalPose(state: inout ExternalPoseState, skeleton: Skeleton, pose: inout PoseBuffer) {
    let jointCount = skeleton.jointPaths.count
    guard state.isActive, pose.rotations.count == jointCount else { return }
    if state.worldRotationDeltas.count != jointCount {
        state.worldRotationDeltas = Array(state.worldRotationDeltas.prefix(jointCount))
            + [simd_quatf?](repeating: nil, count: max(0, jointCount - state.worldRotationDeltas.count))
    }
    if state.restWorldRotations.count != jointCount {
        state.restWorldRotations = restWorldRotations(of: skeleton)
    }
    let weight = min(max(state.weight, 0), 1)

    // Parents precede children in the joint order (the world-pose compose
    // relies on it too), so one forward pass solves every joint.
    var currentWorld = [simd_quatf](repeating: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), count: jointCount)
    for joint in 0 ..< jointCount {
        let parentWorld = skeleton.parentIndices[joint].map { currentWorld[$0] }
            ?? simd_quatf(angle: 0, axis: simd_float3(0, 1, 0))
        if let delta = state.worldRotationDeltas[joint] {
            let targetWorld = simd_normalize(delta * state.restWorldRotations[joint])
            let desiredLocal = simd_normalize(parentWorld.inverse * targetWorld)
            pose.rotations[joint] = weight >= 1
                ? desiredLocal
                : simd_slerp(pose.rotations[joint], desiredLocal, weight)
        }
        currentWorld[joint] = simd_normalize(parentWorld * pose.rotations[joint])
    }

    if let root = state.rootJointIndex, let delta = state.rootTranslationDelta, root < pose.translations.count {
        let parentWorld = skeleton.parentIndices[root].map { currentWorld[$0] }
            ?? simd_quatf(angle: 0, axis: simd_float3(0, 1, 0))
        pose.translations[root] += parentWorld.inverse.act(delta) * weight
    }
}

/// Rest-pose world rotation of every joint (scale factored out).
func restWorldRotations(of skeleton: Skeleton) -> [simd_quatf] {
    var world: [simd_quatf] = []
    world.reserveCapacity(skeleton.jointPaths.count)
    for joint in 0 ..< skeleton.jointPaths.count {
        let local = PoseDriverEvaluation.restRotation(from: skeleton.restTransform[joint])
        if let parent = skeleton.parentIndices[joint], parent < world.count {
            world.append(simd_normalize(world[parent] * local))
        } else {
            world.append(local)
        }
    }
    return world
}

// MARK: - Public API

/// Drives `entityId`'s joints from an external pose source. Each entry
/// rotates the named joint's rest world orientation by the given model-space
/// delta; the engine solves the local rotations through the hierarchy, so
/// joints not listed keep their animated pose. `rootJoint` receives
/// `rootTranslationDelta` (model space) on top of its animated translation.
/// The pose applies every frame until `clearEntityExternalPose`, also while
/// the entity's clip is paused. Joint names resolve by path, `/name` suffix
/// or last path component.
public func setEntityExternalPose(
    entityId: EntityID,
    worldRotationDeltas: [String: simd_quatf],
    rootJoint: String? = nil,
    rootTranslationDelta: simd_float3? = nil,
    weight: Float = 1
) {
    guard scene.exists(entityId) else { return }
    for targetEntityId in resolveAnimationBindingTargetEntities(entityId: entityId) {
        guard let animationComponent = scene.get(component: AnimationComponent.self, for: targetEntityId),
              let skeleton = scene.get(component: SkeletonComponent.self, for: targetEntityId)?.skeleton
        else { continue }
        var state = animationComponent.externalPose
        let jointCount = skeleton.jointPaths.count
        state.worldRotationDeltas = [simd_quatf?](repeating: nil, count: jointCount)
        for (name, delta) in worldRotationDeltas {
            let index: Int?
            if let cached = state.jointIndexCache[name] {
                index = cached
            } else {
                index = skeleton.muscleJointIndex(named: name)
                state.jointIndexCache[name] = index
            }
            if let index {
                state.worldRotationDeltas[index] = simd_normalize(delta)
            }
        }
        state.rootJointIndex = rootJoint.flatMap { skeleton.muscleJointIndex(named: $0) }
        state.rootTranslationDelta = rootTranslationDelta
        state.weight = weight
        animationComponent.externalPose = state
    }
}

/// Stops driving `entityId` from an external pose source.
public func clearEntityExternalPose(entityId: EntityID) {
    guard scene.exists(entityId) else { return }
    for targetEntityId in resolveAnimationBindingTargetEntities(entityId: entityId) {
        scene.get(component: AnimationComponent.self, for: targetEntityId)?.externalPose.clear()
    }
}

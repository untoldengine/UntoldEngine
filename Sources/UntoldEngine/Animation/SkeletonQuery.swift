//
//  SkeletonQuery.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// One joint of an entity's skeleton in its current pose.
public struct SkeletonJointPose: Sendable, Equatable {
    /// Full joint path, as the asset names it.
    public var path: String
    /// Index of the parent joint in the same list (nil for a root).
    public var parentIndex: Int?
    /// Joint origin in world space.
    public var worldPosition: simd_float3
    /// Joint orientation in world space.
    public var worldRotation: simd_quatf
}

/// One joint of an entity's skeleton in its rest pose.
public struct SkeletonRestJoint: Sendable, Equatable {
    /// Full joint path, as the asset names it.
    public var path: String
    /// Index of the parent joint in the same list (nil for a root).
    public var parentIndex: Int?
    /// Joint origin in the entity's model space, rest pose.
    public var modelPosition: simd_float3
    /// Joint orientation in model space, rest pose.
    public var modelRotation: simd_quatf
}

/// The rest pose of `entityId`'s skeleton in its model space (the pose the
/// external-pose deltas are applied on), one entry per joint in the
/// skeleton's order. Empty when the entity has no skeleton.
public func entitySkeletonRestJointPoses(entityId: EntityID) -> [SkeletonRestJoint] {
    guard scene.exists(entityId) else { return [] }
    for targetEntityId in resolveAnimationBindingTargetEntities(entityId: entityId) {
        guard let skeleton = scene.get(component: SkeletonComponent.self, for: targetEntityId)?.skeleton else { continue }
        let jointCount = skeleton.jointPaths.count
        guard skeleton.restTransform.count == jointCount else { continue }
        var world = [simd_float4x4](repeating: matrix_identity_float4x4, count: jointCount)
        var joints: [SkeletonRestJoint] = []
        joints.reserveCapacity(jointCount)
        for index in 0 ..< jointCount {
            let local = skeleton.restTransform[index]
            if let parent = skeleton.parentIndices[index], parent < index {
                world[index] = world[parent] * local
            } else {
                world[index] = local
            }
            let origin = world[index].columns.3
            joints.append(SkeletonRestJoint(
                path: skeleton.jointPaths[index],
                parentIndex: skeleton.parentIndices[index],
                modelPosition: simd_float3(origin.x, origin.y, origin.z),
                modelRotation: PoseDriverEvaluation.restRotation(from: world[index])
            ))
        }
        return joints
    }
    return []
}

/// The current pose of `entityId`'s skeleton (after the animation update:
/// clips, transitions, external pose and pose layer), one entry per joint in
/// the skeleton's order, parents before children. Empty when the entity has
/// no skeleton. Reads the pose the animation system last composed, so call
/// it after that update in the frame.
public func entitySkeletonJointPoses(entityId: EntityID) -> [SkeletonJointPose] {
    guard scene.exists(entityId) else { return [] }
    for targetEntityId in resolveAnimationBindingTargetEntities(entityId: entityId) {
        guard let skeleton = scene.get(component: SkeletonComponent.self, for: targetEntityId)?.skeleton else { continue }
        let modelToWorld = scene.get(component: WorldTransformComponent.self, for: targetEntityId)?.space ?? matrix_identity_float4x4
        let jointCount = skeleton.jointPaths.count
        guard skeleton.currentPose.count == jointCount, skeleton.bindTransform.count == jointCount else { continue }
        var poses: [SkeletonJointPose] = []
        poses.reserveCapacity(jointCount)
        for index in 0 ..< jointCount {
            // currentPose holds world * inverse(bind): undo the bind to get
            // the joint's model-space transform.
            let model = skeleton.currentPose[index] * skeleton.bindTransform[index]
            let world = modelToWorld * model
            let origin = world.columns.3
            poses.append(SkeletonJointPose(
                path: skeleton.jointPaths[index],
                parentIndex: skeleton.parentIndices[index],
                worldPosition: simd_float3(origin.x, origin.y, origin.z),
                worldRotation: PoseDriverEvaluation.restRotation(from: world)
            ))
        }
        return poses
    }
    return []
}

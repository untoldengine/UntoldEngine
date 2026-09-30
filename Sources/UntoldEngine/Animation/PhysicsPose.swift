//
//  PhysicsPose.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

// Physics pose: a pose handed in from outside the animation pipeline — a
// ragdoll, a physics-driven arm, a hit reaction simulated by a physics
// plugin — blended into the displayed pose per joint by a weight. The
// plugin reads the skeleton (`getSkeletonJointInfo`) once to build its
// rig, reads the displayed joint transforms (`getJointModelTransforms`)
// to drive or seed its bodies, and hands a model-space pose back
// (`setPhysicsPose`) that the next animation update blends in. Runs last,
// after foot IK, so every animated stage has had its say and the physics
// result is what lands on the skin. See docs/API/UsingPhysicsPose.md.

/// The joints of an entity's skeleton, for building a physics rig that maps
/// onto it.
public struct SkeletonJointInfo: Sendable {
    /// Skeleton joint order (parents before children).
    public let jointPaths: [String]
    /// nil for a parentless joint.
    public let parentIndices: [Int?]
    /// Model-space bind pose, one per joint.
    public let bindModelTransforms: [simd_float4x4]

    /// The engine builds these from an entity's skeleton; a game builds one
    /// only to describe a skeleton of its own (tests, offline tools).
    public init(jointPaths: [String], parentIndices: [Int?], bindModelTransforms: [simd_float4x4]) {
        self.jointPaths = jointPaths
        self.parentIndices = parentIndices
        self.bindModelTransforms = bindModelTransforms
    }
}

/// Per-entity physics pose state: the pose last handed in and the scratch
/// the blend composes it against.
struct PhysicsPoseState {
    var isActive = false
    /// Model-space target per joint, as the plugin gave it.
    var modelTransforms: [simd_float4x4] = []
    /// Blend weight per joint, 0…1.
    var weights: [Float] = []

    /// Model-space forward kinematics of the pose as blended so far, walked
    /// alongside the joints; reused across frames so the stage never
    /// allocates in steady state.
    var positions: [simd_float3] = []
    var rotations: [simd_quatf] = []
    /// Accumulated rest scale per joint, the factor a child's local
    /// translation picks up from its ancestors' rest scales.
    var scales: [simd_float3] = []

    /// The animated local pose the blend replaced, put back once the skin
    /// has taken the blend: the physics pose lands on the skin only, never
    /// in the pose history that transitions and motion matching inertialize
    /// from — a body driven toward the animation must not drag the
    /// animation after itself.
    var animatedLocalPose = PoseBuffer()
    var blendedThisFrame = false

    mutating func clear() {
        isActive = false
        modelTransforms = []
        weights = []
        blendedThisFrame = false
    }
}

extension PoseBuffer {
    /// Copies `other` in without allocating in steady state.
    mutating func assign(from other: PoseBuffer) {
        resize(jointCount: other.jointCount)
        for index in 0 ..< other.jointCount {
            translations[index] = other.translations[index]
            rotations[index] = other.rotations[index]
        }
    }
}

/// Blends the physics pose into `animationComponent.localPose`, joint by
/// joint in skeleton order, against forward kinematics of the pose as
/// modified so far — so a joint under a physics-driven parent is measured
/// relative to where physics put that parent, not where the clip did.
///
/// A weighted joint slerps its local rotation toward the physics rotation.
/// It also lerps its local translation toward the physics translation when
/// it is the top of a physics-driven subtree (no parent, or a parent at
/// weight 0); below that, joints keep their animated bone offsets, so a
/// rig whose bodies drift apart never stretches the skin. Joints at weight
/// 0 keep their animated local transform relative to their (possibly
/// physics-driven) parent.
///
/// Rotations are composed rigidly, as in the IK stages. Rest scale enters
/// only where it moves a joint: a child's local translation is scaled by
/// its ancestors' rest scales when the skeleton builds the skin, so the
/// walk accumulates that factor and applies it to translations both ways —
/// the model-space pose a plugin reads with `getJointModelTransforms`
/// (rest scale included) comes back through here unchanged. Exact for
/// uniform rest scales; a non-uniform rest scale under a rotation is
/// approximated by its per-axis factors.
func applyPhysicsPose(
    entityId _: EntityID,
    animationComponent: AnimationComponent,
    skeleton: Skeleton,
    localScales: [simd_float3]
) {
    animationComponent.physicsPose.blendedThisFrame = false
    guard animationComponent.physicsPose.isActive else { return }

    let jointCount = skeleton.jointPaths.count
    guard animationComponent.localPose.jointCount == jointCount,
          animationComponent.physicsPose.modelTransforms.count == jointCount,
          animationComponent.physicsPose.weights.count == jointCount
    else { return }

    // The animated pose survives the blend (see `restoreAnimatedLocalPose`).
    animationComponent.physicsPose.animatedLocalPose.assign(from: animationComponent.localPose)
    animationComponent.physicsPose.blendedThisFrame = true

    if animationComponent.physicsPose.positions.count != jointCount {
        animationComponent.physicsPose.positions = [simd_float3](repeating: .zero, count: jointCount)
        animationComponent.physicsPose.rotations = [simd_quatf](
            repeating: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), count: jointCount
        )
        animationComponent.physicsPose.scales = [simd_float3](repeating: simd_float3(repeating: 1), count: jointCount)
    }
    let hasScales = localScales.count == jointCount

    let parentIndices = skeleton.parentIndices
    let weights = animationComponent.physicsPose.weights
    let modelTransforms = animationComponent.physicsPose.modelTransforms

    for index in 0 ..< jointCount {
        let parentIndex = parentIndices[index]
        let parentPosition = parentIndex.map { animationComponent.physicsPose.positions[$0] } ?? .zero
        let parentRotation = parentIndex.map { animationComponent.physicsPose.rotations[$0] }
            ?? simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        let parentScale = parentIndex.map { animationComponent.physicsPose.scales[$0] } ?? simd_float3(repeating: 1)

        let weight = weights[index]
        if weight > 0 {
            // The physics target, taken into the parent's blended frame.
            let target = modelTransforms[index]
            let targetModelPosition = simd_float3(target.columns.3.x, target.columns.3.y, target.columns.3.z)
            let targetModelRotation = AnimationClip.localRotation(
                from: target, scale: AnimationClip.localScale(from: target)
            )
            let inverseParentRotation = parentRotation.inverse
            let targetLocalRotation = simd_normalize(inverseParentRotation * targetModelRotation)

            animationComponent.localPose.rotations[index] = simd_normalize(
                simd_slerp(animationComponent.localPose.rotations[index], targetLocalRotation, weight)
            )

            let parentIsAnimated = parentIndex.map { weights[$0] <= 0 } ?? true
            if parentIsAnimated {
                let targetLocalPosition = inverseParentRotation.act(targetModelPosition - parentPosition) / parentScale
                animationComponent.localPose.translations[index] = simd_mix(
                    animationComponent.localPose.translations[index], targetLocalPosition, simd_float3(repeating: weight)
                )
            }
        }

        animationComponent.physicsPose.positions[index] = parentPosition
            + parentRotation.act(parentScale * animationComponent.localPose.translations[index])
        animationComponent.physicsPose.rotations[index] = simd_normalize(
            parentRotation * animationComponent.localPose.rotations[index]
        )
        animationComponent.physicsPose.scales[index] = hasScales ? parentScale * localScales[index] : parentScale
    }
}

/// Once the skin has taken the blended pose, the animated local pose comes
/// back: everything that reads `localPose` between updates — a transition
/// beginning, the pose history, the next frame's inertialization — sees the
/// animation's own pose. The displayed model pose keeps the blend.
func restoreAnimatedLocalPose(animationComponent: AnimationComponent) {
    guard animationComponent.physicsPose.blendedThisFrame else { return }
    animationComponent.localPose.assign(from: animationComponent.physicsPose.animatedLocalPose)
}

//
//  FootIK.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

// Foot IK: plants feet on real geometry instead of the flat plane the clip
// was authored against. For each configured leg chain (hip → knee → ankle),
// the ground is sampled beneath the animated ankle, the ankle's authored
// height above the clip's ground plane is preserved above the real terrain,
// and the two-bone solver adjusts the hip and knee so the foot lands there.
// Runs after root motion and transitions, before the pose is composed for
// skinning. Joint scales are assumed uniform (1) along the leg chains.

/// A world-space ground sample beneath a foot.
public struct FootIKGroundSample {
    public var height: Float
    public var normal: simd_float3

    public init(height: Float, normal: simd_float3 = simd_float3(0, 1, 0)) {
        self.height = height
        self.normal = normal
    }
}

/// Returns the ground beneath a world position, or nil when there is no
/// ground to plant on (the foot is left as authored that frame).
public typealias FootIKGroundQuery = (simd_float3) -> FootIKGroundSample?

/// One leg chain, identified by skeleton joint paths.
public struct FootIKChainDescriptor {
    public var hipPath: String
    public var kneePath: String
    public var anklePath: String

    /// Extra world-space offset added above the sampled ground, for rigs
    /// whose clips are not authored with the ground at model height 0.
    public var footHeight: Float

    /// Model-space direction the knee bows toward when the leg is straight
    /// and the pose gives no bend to follow (default: character forward).
    public var bendDirection: simd_float3

    public init(
        hipPath: String,
        kneePath: String,
        anklePath: String,
        footHeight: Float = 0,
        bendDirection: simd_float3 = simd_float3(0, 0, 1)
    ) {
        self.hipPath = hipPath
        self.kneePath = kneePath
        self.anklePath = anklePath
        self.footHeight = footHeight
        self.bendDirection = bendDirection
    }
}

/// Per-entity foot IK state.
struct FootIKState {
    var isEnabled = false
    var descriptors: [FootIKChainDescriptor] = []

    /// Corrections larger than this are ignored — a sample this far from
    /// the animated foot is a wall, a ledge, or a bad probe, not ground.
    var maxAdjustment: Float = 0.5

    /// Custom ground provider; nil uses the scene ray-picking systems.
    var groundQuery: FootIKGroundQuery?

    /// Joint indices resolved against the skeleton; nil until first use or
    /// after reconfiguration. Chains with unresolvable paths are dropped.
    var resolvedChains: [(hip: Int, knee: Int, ankle: Int, footHeight: Float, bendDirection: simd_float3)]?

    /// Forward-kinematics scratch, reused across frames.
    var jointPositions: [simd_float3] = []
    var jointRotations: [simd_quatf] = []

    mutating func invalidateResolution() {
        resolvedChains = nil
    }

    /// Refreshes the FK scratch from a pose. Lives on the state so the
    /// caller opens a single exclusive access on the component property
    /// (two separate `&footIK.x` arguments would overlap and trap).
    mutating func refreshForwardKinematics(pose: PoseBuffer, parentIndices: [Int?]) {
        computeForwardKinematics(
            pose: pose,
            parentIndices: parentIndices,
            positions: &jointPositions,
            rotations: &jointRotations
        )
    }
}

// MARK: - Forward kinematics

/// Computes model-space joint positions and rotations from a local pose.
/// Scale is ignored — IK chains are assumed unit-scale. Parents must
/// precede children in joint order (same contract as pose composition).
func computeForwardKinematics(
    pose: PoseBuffer,
    parentIndices: [Int?],
    positions: inout [simd_float3],
    rotations: inout [simd_quatf]
) {
    let jointCount = pose.jointCount
    if positions.count != jointCount {
        positions = [simd_float3](repeating: .zero, count: jointCount)
        rotations = [simd_quatf](repeating: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), count: jointCount)
    }

    for index in 0 ..< jointCount {
        if let parentIndex = parentIndices[index] {
            positions[index] = positions[parentIndex] + rotations[parentIndex].act(pose.translations[index])
            rotations[index] = simd_normalize(rotations[parentIndex] * pose.rotations[index])
        } else {
            positions[index] = pose.translations[index]
            rotations[index] = pose.rotations[index]
        }
    }
}

// MARK: - Per-frame application

/// Plants each configured foot chain on the sampled ground by adjusting the
/// hip and knee local rotations in `animationComponent.localPose`.
func applyFootIK(
    entityId: EntityID,
    animationComponent: AnimationComponent,
    skeleton: Skeleton
) {
    guard animationComponent.footIK.isEnabled else { return }

    let chains = resolveFootIKChains(state: &animationComponent.footIK, skeleton: skeleton)
    guard chains.isEmpty == false else { return }

    let pose = animationComponent.localPose
    guard pose.jointCount == skeleton.jointPaths.count else { return }

    animationComponent.footIK.refreshForwardKinematics(
        pose: pose,
        parentIndices: skeleton.parentIndices
    )

    let worldMatrix = scene.get(component: WorldTransformComponent.self, for: entityId)?.space ?? .identity
    let inverseWorldMatrix = worldMatrix.inverse
    let maxAdjustment = animationComponent.footIK.maxAdjustment

    for chain in chains {
        guard chain.hip < pose.jointCount, chain.knee < pose.jointCount, chain.ankle < pose.jointCount else {
            continue
        }

        let positions = animationComponent.footIK.jointPositions
        let rotations = animationComponent.footIK.jointRotations

        let ankleModel = positions[chain.ankle]
        let ankleWorld4 = worldMatrix * simd_float4(ankleModel, 1)
        let ankleWorld = simd_float3(ankleWorld4.x, ankleWorld4.y, ankleWorld4.z)

        guard let ground = sampleGround(
            at: ankleWorld,
            state: animationComponent.footIK,
            excluding: entityId
        ) else { continue }

        // Preserve the ankle's authored height above the clip's ground
        // plane (model height 0) above the real terrain.
        let desiredWorldHeight = ground.height + ankleModel.y + chain.footHeight
        let correction = desiredWorldHeight - ankleWorld.y
        guard abs(correction) > 1e-5, abs(correction) <= maxAdjustment else { continue }

        let targetWorld = ankleWorld + simd_float3(0, correction, 0)
        let targetModel4 = inverseWorldMatrix * simd_float4(targetWorld, 1)
        let targetModel = simd_float3(targetModel4.x, targetModel4.y, targetModel4.z)

        // Bow the knee the way the clip already bends it. A hint that is
        // collinear with the chain (a perfectly straight leg) is useless —
        // fall back to the chain's configured bend direction.
        let hipPosition = positions[chain.hip]
        let kneePosition = positions[chain.knee]
        let anklePosition = positions[chain.ankle]
        let chainDirection = anklePosition - hipPosition
        var bendHint = kneePosition - (hipPosition + anklePosition) * 0.5
        if simd_length_squared(simd_cross(chainDirection, bendHint)) < 1e-8 {
            bendHint = chain.bendDirection
        }

        var hipLocal = animationComponent.localPose.rotations[chain.hip]
        var kneeLocal = animationComponent.localPose.rotations[chain.knee]
        solveTwoBoneIK(
            a: hipPosition,
            b: kneePosition,
            c: anklePosition,
            target: targetModel,
            bendHint: bendHint,
            aGlobalRotation: rotations[chain.hip],
            bGlobalRotation: rotations[chain.knee],
            aLocalRotation: &hipLocal,
            bLocalRotation: &kneeLocal
        )
        animationComponent.localPose.rotations[chain.hip] = hipLocal
        animationComponent.localPose.rotations[chain.knee] = kneeLocal
    }
}

// MARK: - Private helpers

private func resolveFootIKChains(
    state: inout FootIKState,
    skeleton: Skeleton
) -> [(hip: Int, knee: Int, ankle: Int, footHeight: Float, bendDirection: simd_float3)] {
    if let resolved = state.resolvedChains {
        return resolved
    }

    var resolved: [(hip: Int, knee: Int, ankle: Int, footHeight: Float, bendDirection: simd_float3)] = []
    for descriptor in state.descriptors {
        guard let hip = skeleton.jointPaths.firstIndex(of: descriptor.hipPath),
              let knee = skeleton.jointPaths.firstIndex(of: descriptor.kneePath),
              let ankle = skeleton.jointPaths.firstIndex(of: descriptor.anklePath)
        else { continue }
        resolved.append((
            hip: hip, knee: knee, ankle: ankle,
            footHeight: descriptor.footHeight,
            bendDirection: descriptor.bendDirection
        ))
    }

    state.resolvedChains = resolved
    return resolved
}

private func sampleGround(
    at worldPosition: simd_float3,
    state: FootIKState,
    excluding entityId: EntityID
) -> FootIKGroundSample? {
    if let query = state.groundQuery {
        return query(worldPosition)
    }
    return footIKDefaultGroundSample(at: worldPosition, excluding: entityId)
}

/// Default ground provider: a downward scene ray pick from above the foot,
/// rejecting hits on the character itself (or its scenegraph descendants).
func footIKDefaultGroundSample(
    at worldPosition: simd_float3,
    excluding entityId: EntityID
) -> FootIKGroundSample? {
    let probeUp: Float = 1.0
    let probeDown: Float = 3.0

    let origin = worldPosition + simd_float3(0, probeUp, 0)
    let options = ScenePickOptions(maxDistance: probeUp + probeDown)
    guard let hit = pickEntity(rayOrigin: origin, rayDirection: simd_float3(0, -1, 0), options: options) else {
        return nil
    }

    guard hit.entityId != entityId, isScenegraphDescendant(hit.entityId, of: entityId) == false else {
        return nil
    }

    return FootIKGroundSample(height: hit.worldPosition.y, normal: hit.worldNormal ?? simd_float3(0, 1, 0))
}

private func isScenegraphDescendant(_ candidate: EntityID, of ancestor: EntityID) -> Bool {
    var current = candidate
    var steps = 0
    while let scenegraph = scene.get(component: ScenegraphComponent.self, for: current),
          scenegraph.parent != .invalid,
          steps < 128
    {
        if scenegraph.parent == ancestor {
            return true
        }
        current = scenegraph.parent
        steps += 1
    }
    return false
}

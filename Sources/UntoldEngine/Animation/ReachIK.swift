//
//  ReachIK.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

// Reach IK: bends two-bone chains (shoulder → elbow → hand for an arm, hip
// → knee → ankle for a leg held on a spot) toward a world
// target with the two-bone solver foot IK uses. A target within reach is
// touched; one beyond it is pointed at, the arm extended to a fraction of
// its length along the direction so the elbow never locks. The influence
// eases in and out, and the solve blends over whatever the pose (or the
// pose layer) put the arms in, so the elbow keeps the posture's bend. Runs
// after the pose layer and before foot IK. Chains share one target (a
// character grabbing at something) or take one each (hands driven by
// tracking). See docs/API/UsingPoseLayers.md.

private let ln2: Float = 0.693_147_18

/// One arm chain, identified by skeleton joint paths.
public struct ReachIKChainDescriptor {
    public var shoulderPath: String
    public var elbowPath: String
    public var handPath: String

    /// Model-space direction the elbow bows toward when the arm is straight
    /// and the pose gives no bend to follow (default: down).
    public var bendDirection: simd_float3

    public init(
        shoulderPath: String,
        elbowPath: String,
        handPath: String,
        bendDirection: simd_float3 = simd_float3(0, -1, 0)
    ) {
        self.shoulderPath = shoulderPath
        self.elbowPath = elbowPath
        self.handPath = handPath
        self.bendDirection = bendDirection
    }
}

/// Where one chain reaches, when the chains do not share a target.
public struct ReachIKChainTarget: Sendable {
    public enum Space: Sendable {
        /// A world position.
        case world
        /// A position in the entity's model space.
        case model
        /// An offset from the chain's own shoulder, along the model axes:
        /// the hand keeps its place relative to the body however the body
        /// moves this frame.
        case shoulder
        /// A spot in the entity's model space whose height is ignored:
        /// the chain's end goes over it at the height the pose gives it
        /// (a foot held where it stands while the pose lifts and lowers
        /// it).
        case modelGround
    }

    public var position: simd_float3
    public var space: Space

    public init(position: simd_float3, space: Space = .world) {
        self.position = position
        self.space = space
    }
}

/// Per-entity reach IK state.
struct ReachIKState {
    var descriptors: [ReachIKChainDescriptor] = []
    var resolvedChains: [(shoulder: Int, elbow: Int, hand: Int, bendDirection: simd_float3)]?

    /// World-space target; kept while the influence fades out.
    var targetWorld: simd_float3?
    /// The target the solve actually uses: eases toward `targetWorld` with
    /// `targetHalflife`, so a target that jumps (a tracked head that
    /// jitters, a player who teleports) moves the hands over a few frames
    /// instead of one. Nil until the first target.
    var smoothedTarget: simd_float3?
    var targetHalflife: Float = 0.08
    /// The same easing for the chains' own targets: theirs to set, so a
    /// tracked hand followed exactly does not make the shared target jump.
    var chainTargetHalflife: Float = 0.08
    var weight: Float = 0
    var targetWeight: Float = 0
    var halflife: Float = 0.25
    /// Fraction of the chain length used when the target is beyond reach.
    var reach: Float = 0.95
    /// Per-chain multipliers on the influence, index-aligned with the
    /// chains (empty: 1 for all) — one hand lunging while the other holds.
    var chainWeights: [Float] = []
    /// Per-chain targets, index-aligned with the chains; a chain without
    /// one reaches for `targetWorld`.
    var chainTargets: [ReachIKChainTarget?] = []
    /// The chain targets as the solve uses them, eased like
    /// `smoothedTarget`, each in its target's own space.
    var smoothedChainTargets: [ReachIKChainTarget?] = []

    var jointPositions: [simd_float3] = []
    var jointRotations: [simd_quatf] = []

    mutating func invalidateResolution() {
        resolvedChains = nil
    }

    var hasChainTargets: Bool {
        chainTargets.contains { $0 != nil }
    }

    /// The chain's own target eased toward its newest value; a target that
    /// is new, or changed space, is taken as it is.
    mutating func easedChainTarget(_ index: Int, ease: Float) -> ReachIKChainTarget? {
        guard index < chainTargets.count, let target = chainTargets[index] else {
            if index < smoothedChainTargets.count {
                smoothedChainTargets[index] = nil
            }
            return nil
        }
        if smoothedChainTargets.count <= index {
            smoothedChainTargets += [ReachIKChainTarget?](repeating: nil, count: index + 1 - smoothedChainTargets.count)
        }
        var eased = target
        if let previous = smoothedChainTargets[index], previous.space == target.space {
            eased.position = previous.position + (target.position - previous.position) * ease
        }
        smoothedChainTargets[index] = eased
        return eased
    }

    mutating func refreshForwardKinematics(pose: PoseBuffer, parentIndices: [Int?]) {
        computeForwardKinematics(
            pose: pose, parentIndices: parentIndices,
            positions: &jointPositions, rotations: &jointRotations
        )
    }

    mutating func resolvedChains(skeleton: Skeleton) -> [(shoulder: Int, elbow: Int, hand: Int, bendDirection: simd_float3)] {
        if let resolvedChains {
            return resolvedChains
        }
        var resolved: [(shoulder: Int, elbow: Int, hand: Int, bendDirection: simd_float3)] = []
        for descriptor in descriptors {
            guard let shoulder = skeleton.jointPaths.firstIndex(of: descriptor.shoulderPath),
                  let elbow = skeleton.jointPaths.firstIndex(of: descriptor.elbowPath),
                  let hand = skeleton.jointPaths.firstIndex(of: descriptor.handPath)
            else { continue }
            resolved.append((shoulder: shoulder, elbow: elbow, hand: hand, bendDirection: descriptor.bendDirection))
        }
        resolvedChains = resolved
        return resolved
    }
}

/// Eases the influence and bends each chain toward the target.
func applyReachIK(
    entityId: EntityID,
    animationComponent: AnimationComponent,
    skeleton: Skeleton,
    deltaTime: Float
) {
    guard animationComponent.reachIK.descriptors.isEmpty == false else { return }

    let step = 1 - exp(-ln2 * deltaTime / max(animationComponent.reachIK.halflife, 1e-4))
    animationComponent.reachIK.weight += (animationComponent.reachIK.targetWeight - animationComponent.reachIK.weight) * step
    if abs(animationComponent.reachIK.targetWeight - animationComponent.reachIK.weight) < 1e-3 {
        animationComponent.reachIK.weight = animationComponent.reachIK.targetWeight
    }
    let weight = animationComponent.reachIK.weight
    let rawTarget = animationComponent.reachIK.targetWorld
    guard weight > 1e-4, rawTarget != nil || animationComponent.reachIK.hasChainTargets else {
        if animationComponent.reachIK.targetWeight <= 0 {
            animationComponent.reachIK.targetWorld = nil
            animationComponent.reachIK.smoothedTarget = nil
            animationComponent.reachIK.chainTargets.removeAll()
            animationComponent.reachIK.smoothedChainTargets.removeAll()
        }
        return
    }
    let ease = 1 - exp(-ln2 * deltaTime / max(animationComponent.reachIK.targetHalflife, 1e-4))
    let chainEase = 1 - exp(-ln2 * deltaTime / max(animationComponent.reachIK.chainTargetHalflife, 1e-4))
    var targetWorld: simd_float3?
    if let rawTarget {
        if let previous = animationComponent.reachIK.smoothedTarget {
            targetWorld = previous + (rawTarget - previous) * ease
        } else {
            targetWorld = rawTarget
        }
    }
    animationComponent.reachIK.smoothedTarget = targetWorld

    let chains = animationComponent.reachIK.resolvedChains(skeleton: skeleton)
    guard chains.isEmpty == false else { return }
    let pose = animationComponent.localPose
    guard pose.jointCount == skeleton.jointPaths.count else { return }

    animationComponent.reachIK.refreshForwardKinematics(pose: pose, parentIndices: skeleton.parentIndices)
    let positions = animationComponent.reachIK.jointPositions
    let rotations = animationComponent.reachIK.jointRotations

    let worldMatrix = scene.get(component: WorldTransformComponent.self, for: entityId)?.space ?? .identity
    let worldToModel = worldMatrix.inverse
    func modelPosition(_ world: simd_float3) -> simd_float3 {
        let p = worldToModel * simd_float4(world, 1)
        return simd_float3(p.x, p.y, p.z)
    }
    let targetModel = targetWorld.map(modelPosition)
    let reach = animationComponent.reachIK.reach
    let chainWeights = animationComponent.reachIK.chainWeights

    for (index, chain) in chains.enumerated() {
        // Eased every frame, also while the chain's weight is zero, so
        // the target is current when the weight returns.
        let chainTarget = animationComponent.reachIK.easedChainTarget(index, ease: chainEase)
        let chainWeight = weight * (index < chainWeights.count ? min(max(chainWeights[index], 0), 1) : 1)
        guard chainWeight > 1e-4 else { continue }
        guard chain.shoulder < pose.jointCount, chain.elbow < pose.jointCount, chain.hand < pose.jointCount else {
            continue
        }
        let shoulder = positions[chain.shoulder]
        let elbow = positions[chain.elbow]
        let hand = positions[chain.hand]
        let armLength = simd_length(elbow - shoulder) + simd_length(hand - elbow)
        guard armLength > 1e-4 else { continue }

        // Beyond reach the arm points at the target, a little short of
        // straight.
        var goal: simd_float3
        if let chainTarget {
            switch chainTarget.space {
            case .world: goal = modelPosition(chainTarget.position)
            case .model: goal = chainTarget.position
            case .shoulder: goal = shoulder + chainTarget.position
            case .modelGround: goal = simd_float3(chainTarget.position.x, hand.y, chainTarget.position.z)
            }
        } else if let targetModel {
            goal = targetModel
        } else {
            continue
        }
        let toTarget = goal - shoulder
        let distance = simd_length(toTarget)
        guard distance > 1e-4 else { continue }
        let maxReach = armLength * reach
        if distance > maxReach {
            goal = shoulder + toTarget / distance * maxReach
        }

        var bendHint = elbow - (shoulder + hand) * 0.5
        if simd_length_squared(simd_cross(hand - shoulder, bendHint)) < 1e-8 {
            bendHint = chain.bendDirection
        }

        var shoulderLocal = pose.rotations[chain.shoulder]
        var elbowLocal = pose.rotations[chain.elbow]
        solveTwoBoneIK(
            a: shoulder, b: elbow, c: hand,
            target: goal,
            bendHint: bendHint,
            aGlobalRotation: rotations[chain.shoulder],
            bGlobalRotation: rotations[chain.elbow],
            aLocalRotation: &shoulderLocal,
            bLocalRotation: &elbowLocal
        )
        animationComponent.localPose.rotations[chain.shoulder] = simd_normalize(
            simd_slerp(pose.rotations[chain.shoulder], shoulderLocal, chainWeight)
        )
        animationComponent.localPose.rotations[chain.elbow] = simd_normalize(
            simd_slerp(pose.rotations[chain.elbow], elbowLocal, chainWeight)
        )
    }
}

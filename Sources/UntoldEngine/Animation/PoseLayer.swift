//
//  PoseLayer.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

// Pose layer: one override clip on top of whatever the entity is playing,
// sampled on its own clock, whose local rotations replace those of a joint
// subset — an upper-body posture (arms hanging, arms raised) over any
// locomotion, hand-picked or motion matched. The subset is given as
// subtree roots (both clavicles: everything under them). Layer clip
// switches crossfade over a halflife and the layer's influence eases to its
// target weight, so a posture change reads as a movement, not a cut. Runs
// after the base clip's transition offsets and before IK, so motion
// matching (which reads feet and hips) never sees it and reach IK bends
// the layered arms. See docs/API/UsingPoseLayers.md.

private let ln2: Float = 0.693_147_18

/// Per-entity pose layer state.
struct PoseLayerState {
    /// Joint paths whose subtrees the layer overrides.
    var maskRootPaths: [String] = []
    /// Per-joint mask resolved against the skeleton; nil until first use or
    /// after reconfiguration.
    var mask: [Bool]?

    var clip: AnimationClip?
    var time: Float = 0
    var sampler = ClipSampler()
    var pose = PoseBuffer()

    /// The layer clip on its way out, sampled alongside while `crossfade`
    /// (its remaining share) is above zero.
    var previousClip: AnimationClip?
    var previousTime: Float = 0
    var previousSampler = ClipSampler()
    var previousPose = PoseBuffer()
    var crossfade: Float = 0
    var crossfadeHalflife: Float = 0

    var weight: Float = 0
    var targetWeight: Float = 0
    var weightHalflife: Float = 0.2

    var isConfigured: Bool {
        maskRootPaths.isEmpty == false
    }

    mutating func invalidateResolution() {
        mask = nil
    }

    /// Joints at or under any mask root, cached against the skeleton.
    mutating func resolvedMask(skeleton: Skeleton) -> [Bool] {
        if let mask, mask.count == skeleton.jointPaths.count {
            return mask
        }
        let resolved = skeleton.jointPaths.map { path in
            maskRootPaths.contains { root in path == root || path.hasPrefix(root + "/") }
        }
        mask = resolved
        return resolved
    }

    /// Eases the weight, advances both clocks and samples the layer pose
    /// (the outgoing clip folded in by its remaining share). Returns false
    /// when there is nothing to blend this frame.
    mutating func advance(
        deltaTime: Float,
        compiled: CompiledAnimationClip?,
        previousCompiled: CompiledAnimationClip?
    ) -> Bool {
        let step = 1 - exp(-ln2 * deltaTime / max(weightHalflife, 1e-4))
        weight += (targetWeight - weight) * step
        if abs(targetWeight - weight) < 1e-3 {
            weight = targetWeight
        }
        guard let clip, let compiled, weight > 1e-4 else { return false }

        time += deltaTime
        sampler.sample(compiled, time: time, duration: clip.duration, speed: clip.speed, into: &pose)

        if crossfade > 1e-3, let previousClip, let previousCompiled {
            // The outgoing clip's share decays before it is used, like the
            // weight above: the first frame after a switch already moves.
            crossfade *= exp(-ln2 * deltaTime / max(crossfadeHalflife, 1e-4))
            previousTime += deltaTime
            previousSampler.sample(
                previousCompiled, time: previousTime, duration: previousClip.duration, speed: previousClip.speed,
                into: &previousPose
            )
            if previousPose.jointCount == pose.jointCount {
                for index in 0 ..< pose.jointCount {
                    pose.rotations[index] = simd_normalize(
                        simd_slerp(pose.rotations[index], previousPose.rotations[index], crossfade)
                    )
                }
            }
            if crossfade < 1e-3 {
                crossfade = 0
                self.previousClip = nil
            }
        } else {
            crossfade = 0
            previousClip = nil
        }
        return true
    }

    /// Switches the layer to `clip`, keeping the current one fading out
    /// over `halflife` (zero cuts). Restating the current clip is a no-op.
    mutating func play(_ newClip: AnimationClip, halflife: Float) {
        guard clip !== newClip else { return }
        if let clip, halflife > 0 {
            previousClip = clip
            previousTime = time
            previousSampler = ClipSampler()
            crossfade = 1
            crossfadeHalflife = halflife
        } else {
            previousClip = nil
            crossfade = 0
        }
        clip = newClip
        time = 0
        sampler = ClipSampler()
    }
}

/// Blends the layer clip's rotations into the masked joints of the
/// displayed pose, by the layer's current weight.
func applyPoseLayer(
    animationComponent: AnimationComponent,
    skeleton: Skeleton,
    deltaTime: Float
) {
    guard animationComponent.poseLayer.isConfigured else { return }

    let compiled = animationComponent.poseLayer.clip.map { animationComponent.compiledClip(for: $0, skeleton: skeleton) }
    let previousCompiled = animationComponent.poseLayer.previousClip.map {
        animationComponent.compiledClip(for: $0, skeleton: skeleton)
    }
    guard animationComponent.poseLayer.advance(
        deltaTime: deltaTime, compiled: compiled, previousCompiled: previousCompiled
    ) else { return }

    let mask = animationComponent.poseLayer.resolvedMask(skeleton: skeleton)
    let weight = animationComponent.poseLayer.weight
    let layerPose = animationComponent.poseLayer.pose
    guard layerPose.jointCount == animationComponent.localPose.jointCount,
          mask.count == layerPose.jointCount
    else { return }

    for index in 0 ..< mask.count where mask[index] {
        animationComponent.localPose.rotations[index] = simd_normalize(
            simd_slerp(animationComponent.localPose.rotations[index], layerPose.rotations[index], weight)
        )
    }
}

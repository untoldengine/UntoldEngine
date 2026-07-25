//
//  Inertialization.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

// Inertialized animation transitions.
//
// Instead of crossfading two clips (which samples both for the whole blend
// and averages them), an inertialized transition captures the *offset*
// between the pose being displayed and the incoming clip's pose at the
// moment of the switch — plus the offset's velocity — and decays that
// offset to zero with a critically damped spring. After the transition
// frame only the incoming clip is sampled; the decaying offset rides on
// top. The result is continuous in both pose and velocity at the switch.
//
// Formulation follows Daniel Holden's exact spring damper
// (theorangeduck.com, "Spring-It-On" / "Inertialization"), parameterized
// by halflife. See docs/Architecture/animationPoseLayer.md.

// MARK: - Spring damper

private let ln2: Float = 0.693_147_180_559_945_3

/// Advances a critically damped spring that decays `x` (and its velocity
/// `v`) toward zero with the given halflife. Exact closed form — stable for
/// any `deltaTime`.
@inline(__always)
func decaySpringDamper(
    _ x: inout simd_float3,
    _ v: inout simd_float3,
    halflife: Float,
    deltaTime: Float
) {
    let y = (4.0 * ln2) / max(halflife, 1e-5) * 0.5
    let j1 = v + x * y
    let eydt = exp(-y * deltaTime)
    x = eydt * (x + j1 * deltaTime)
    v = eydt * (v - j1 * y * deltaTime)
}

// MARK: - Rotation vector helpers

/// Rotation vector (scaled angle-axis, `2·log(q)`) of a unit quaternion.
/// The quaternion is flipped to the shortest arc first so offsets never
/// take the long way around.
@inline(__always)
func toScaledAngleAxis(_ q: simd_quatf) -> simd_float3 {
    let shortest = q.real < 0 ? simd_quatf(vector: -q.vector) : q
    let imagLength = simd_length(shortest.imag)
    guard imagLength > 1e-8 else {
        // Small-angle approximation of 2·log(q).
        return shortest.imag * (2.0 / max(shortest.real, 1e-8))
    }
    let angle = 2.0 * atan2(imagLength, shortest.real)
    return (shortest.imag / imagLength) * angle
}

/// Unit quaternion from a rotation vector (inverse of `toScaledAngleAxis`).
@inline(__always)
func fromScaledAngleAxis(_ v: simd_float3) -> simd_quatf {
    let angle = simd_length(v)
    guard angle > 1e-8 else {
        // Small-angle approximation of exp(v/2).
        return simd_normalize(simd_quatf(ix: v.x * 0.5, iy: v.y * 0.5, iz: v.z * 0.5, r: 1))
    }
    return simd_quatf(angle: angle, axis: v / angle)
}

// MARK: - Pose transition state

/// Per-entity inertialized transition: per-joint offsets between the pose
/// displayed at the switch and the incoming clip, decayed to zero each
/// frame and added on top of the incoming clip's sampled pose.
struct PoseTransition {
    private(set) var isActive = false
    private var halflife: Float = 0
    private var translationOffsets: [simd_float3] = []
    private var translationVelocities: [simd_float3] = []
    private var rotationOffsets: [simd_float3] = []
    private var rotationVelocities: [simd_float3] = []

    /// Scratch poses reused across transitions to sample the incoming clip
    /// at its start time and one velocity step later.
    var scratchTarget = PoseBuffer()
    var scratchTargetNext = PoseBuffer()

    /// Offsets whose squared magnitude never exceeds this are invisible;
    /// the transition deactivates once every joint is below it.
    private static let doneThreshold: Float = 1e-10

    /// Captures transition offsets at the moment of a clip switch.
    ///
    /// - `sourcePose`: the pose displayed on screen last frame.
    /// - `sourcePrevious`/`sourceDeltaTime`: the displayed pose one frame
    ///   earlier, for velocity estimation (`hasSourcePrevious` false on the
    ///   very first frame — source velocity is treated as zero).
    /// - `targetPose`/`targetNext`/`targetDeltaTime`: the incoming clip at
    ///   its start time and one small step later.
    mutating func begin(
        halflife: Float,
        sourcePose: PoseBuffer,
        sourcePrevious: PoseBuffer,
        hasSourcePrevious: Bool,
        sourceDeltaTime: Float,
        targetPose: PoseBuffer,
        targetNext: PoseBuffer,
        targetDeltaTime: Float
    ) {
        let jointCount = sourcePose.jointCount
        guard jointCount > 0,
              targetPose.jointCount == jointCount,
              targetNext.jointCount == jointCount,
              targetDeltaTime > 0
        else {
            isActive = false
            return
        }

        self.halflife = halflife
        resize(jointCount: jointCount)

        let useSourceVelocity = hasSourcePrevious
            && sourcePrevious.jointCount == jointCount
            && sourceDeltaTime > 0

        for index in 0 ..< jointCount {
            translationOffsets[index] = sourcePose.translations[index] - targetPose.translations[index]
            rotationOffsets[index] = toScaledAngleAxis(
                sourcePose.rotations[index] * targetPose.rotations[index].inverse
            )

            let targetVelocity = (targetNext.translations[index] - targetPose.translations[index]) / targetDeltaTime
            let targetAngular = toScaledAngleAxis(
                targetNext.rotations[index] * targetPose.rotations[index].inverse
            ) / targetDeltaTime

            if useSourceVelocity {
                let sourceVelocity = (sourcePose.translations[index] - sourcePrevious.translations[index]) / sourceDeltaTime
                let sourceAngular = toScaledAngleAxis(
                    sourcePose.rotations[index] * sourcePrevious.rotations[index].inverse
                ) / sourceDeltaTime
                translationVelocities[index] = sourceVelocity - targetVelocity
                rotationVelocities[index] = sourceAngular - targetAngular
            } else {
                translationVelocities[index] = -targetVelocity
                rotationVelocities[index] = -targetAngular
            }
        }

        isActive = true
    }

    /// Decays the offsets by `deltaTime` and adds them on top of the
    /// incoming clip's sampled pose. Deactivates itself once every offset
    /// is visually zero.
    mutating func apply(to pose: inout PoseBuffer, deltaTime: Float) {
        guard isActive, pose.jointCount == translationOffsets.count else { return }

        var maxSquaredMagnitude: Float = 0
        for index in 0 ..< pose.jointCount {
            decaySpringDamper(
                &translationOffsets[index], &translationVelocities[index],
                halflife: halflife, deltaTime: deltaTime
            )
            decaySpringDamper(
                &rotationOffsets[index], &rotationVelocities[index],
                halflife: halflife, deltaTime: deltaTime
            )

            pose.translations[index] += translationOffsets[index]
            pose.rotations[index] = simd_normalize(
                fromScaledAngleAxis(rotationOffsets[index]) * pose.rotations[index]
            )

            maxSquaredMagnitude = max(
                maxSquaredMagnitude,
                simd_length_squared(translationOffsets[index]),
                simd_length_squared(rotationOffsets[index])
            )
        }

        if maxSquaredMagnitude < Self.doneThreshold {
            isActive = false
        }
    }

    mutating func cancel() {
        isActive = false
    }

    private mutating func resize(jointCount: Int) {
        guard translationOffsets.count != jointCount else { return }
        translationOffsets = [simd_float3](repeating: .zero, count: jointCount)
        translationVelocities = [simd_float3](repeating: .zero, count: jointCount)
        rotationOffsets = [simd_float3](repeating: .zero, count: jointCount)
        rotationVelocities = [simd_float3](repeating: .zero, count: jointCount)
    }
}

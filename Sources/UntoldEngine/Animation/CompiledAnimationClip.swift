//
//  CompiledAnimationClip.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd

/// An `AnimationClip` resolved against a specific `Skeleton` for fast
/// per-frame sampling.
///
/// `AnimationClip` keys channels by joint string path, which forces a
/// dictionary lookup per joint per frame. Compilation performs that
/// resolution once: channels land in arrays index-aligned with
/// `Skeleton.jointPaths`, and joints the clip does not animate get their
/// rest-pose fallback precomputed. After compilation, sampling touches only
/// flat arrays.
///
/// Instances are immutable snapshots of the clip's keyframe data; live
/// per-play values (`duration`, `speed`) are passed at sample time so
/// behavior tracks the source clip exactly.
///
/// See docs/Architecture/animationPoseLayer.md.
final class CompiledAnimationClip {
    struct Channel {
        /// Whether the source clip authored a channel for this joint.
        /// Unanimated joints sample straight from the rest-pose fallbacks.
        let animated: Bool
        let repeats: Bool
        let rotationTimes: [Float]
        let rotationValues: [simd_quatf]
        let translationTimes: [Float]
        let translationValues: [simd_float3]

        static let unanimated = Channel(
            animated: false,
            repeats: true,
            rotationTimes: [],
            rotationValues: [],
            translationTimes: [],
            translationValues: []
        )
    }

    let name: String
    let jointCount: Int

    /// Index-aligned with `Skeleton.jointPaths`.
    let channels: [Channel]

    /// Decomposed local rest pose, used as the per-channel fallback and as
    /// the constant local scale folded back in during matrix construction.
    let restTranslations: [simd_float3]
    let restRotations: [simd_quatf]
    let restScales: [simd_float3]

    init(clip: AnimationClip, skeleton: Skeleton) {
        name = clip.name
        jointCount = skeleton.jointPaths.count

        var channels: [Channel] = []
        var restTranslations: [simd_float3] = []
        var restRotations: [simd_quatf] = []
        var restScales: [simd_float3] = []
        channels.reserveCapacity(jointCount)
        restTranslations.reserveCapacity(jointCount)
        restRotations.reserveCapacity(jointCount)
        restScales.reserveCapacity(jointCount)

        for (index, jointPath) in skeleton.jointPaths.enumerated() {
            let rest = skeleton.restTransform[index]
            let scale = AnimationClip.localScale(from: rest)
            restScales.append(scale)
            restRotations.append(AnimationClip.localRotation(from: rest, scale: scale))
            restTranslations.append(simd_float3(rest.columns.3.x, rest.columns.3.y, rest.columns.3.z))

            if let animation = clip.jointAnimation[jointPath] {
                channels.append(Channel(
                    animated: true,
                    repeats: animation.repeatAnimation,
                    rotationTimes: animation.rotations.map(\.time),
                    rotationValues: animation.rotations.map(\.value),
                    translationTimes: animation.translations.map(\.time),
                    translationValues: animation.translations.map(\.value)
                ))
            } else {
                channels.append(.unanimated)
            }
        }

        self.channels = channels
        self.restTranslations = restTranslations
        self.restRotations = restRotations
        self.restScales = restScales
    }
}

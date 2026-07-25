//
//  PoseBuffer.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd

/// A local-space skeleton pose in structure-of-arrays form, indexed by
/// skeleton joint index (same order as `Skeleton.jointPaths`).
///
/// This is the canonical runtime pose representation: rotations stay as
/// quaternions and translations as vectors so poses can be blended and
/// offset without decomposing matrices. The rest-pose local scale is not
/// stored here; it is folded in when world matrices are built
/// (see `Skeleton.updateWorldPose(from:localScales:)`), matching the
/// runtime animation format, which carries no scale channels.
///
/// See docs/Architecture/animationPoseLayer.md.
struct PoseBuffer {
    var translations: [simd_float3] = []
    var rotations: [simd_quatf] = []

    var jointCount: Int {
        translations.count
    }

    /// Ensures storage for `jointCount` joints. Reuses existing storage when
    /// the count already matches, so steady-state sampling never allocates.
    mutating func resize(jointCount: Int) {
        guard translations.count != jointCount else { return }
        translations = [simd_float3](repeating: .zero, count: jointCount)
        rotations = [simd_quatf](repeating: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), count: jointCount)
    }
}

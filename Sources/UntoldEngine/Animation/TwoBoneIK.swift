//
//  TwoBoneIK.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

// Analytic two-bone inverse kinematics (Daniel Holden, "Simple Two Joint
// IK"): given a chain of three joints — hip a, knee b, ankle c — and a
// target t, adjust the local rotations of a and b so c lands on t. Closed
// form, no iteration: the knee angle comes from the law of cosines and the
// hip is rotated to aim the chain, both applied about axes expressed in
// each joint's own local space.

/// Solves the two-bone chain in place.
///
/// - `a`, `b`, `c`: current model-space positions of hip, knee, ankle.
/// - `target`: desired model-space ankle position (clamped to reach).
/// - `bendHint`: model-space direction the knee should bow toward when the
///   chain is fully straight and the bend plane is ambiguous.
/// - `aGlobalRotation`/`bGlobalRotation`: current model-space rotations of
///   hip and knee.
/// - `aLocalRotation`/`bLocalRotation`: local rotations to adjust.
func solveTwoBoneIK(
    a: simd_float3,
    b: simd_float3,
    c: simd_float3,
    target: simd_float3,
    bendHint: simd_float3,
    aGlobalRotation: simd_quatf,
    bGlobalRotation: simd_quatf,
    aLocalRotation: inout simd_quatf,
    bLocalRotation: inout simd_quatf
) {
    let epsilon: Float = 1e-5

    let upperLength = simd_length(b - a)
    let lowerLength = simd_length(c - b)
    guard upperLength > epsilon, lowerLength > epsilon else { return }

    let targetLength = simd_clamp(
        simd_length(target - a),
        epsilon,
        upperLength + lowerLength - epsilon
    )

    let currentAC = simd_normalize(c - a)
    let currentAB = simd_normalize(b - a)
    let currentBA = simd_normalize(a - b)
    let currentBC = simd_normalize(c - b)
    let toTarget = simd_normalize(target - a)

    let angleACAB0 = acos(simd_clamp(simd_dot(currentAC, currentAB), -1, 1))
    let angleBABC0 = acos(simd_clamp(simd_dot(currentBA, currentBC), -1, 1))
    let angleACAT0 = acos(simd_clamp(simd_dot(currentAC, toTarget), -1, 1))

    let angleACAB1 = acos(simd_clamp(
        (lowerLength * lowerLength - upperLength * upperLength - targetLength * targetLength)
            / (-2 * upperLength * targetLength),
        -1, 1
    ))
    let angleBABC1 = acos(simd_clamp(
        (targetLength * targetLength - upperLength * upperLength - lowerLength * lowerLength)
            / (-2 * upperLength * lowerLength),
        -1, 1
    ))

    // Bend-plane axis. When the chain is (nearly) straight the cross
    // product vanishes and the plane is ambiguous — fall back to the hint.
    var bendAxis = simd_cross(c - a, b - a)
    if simd_length_squared(bendAxis) < epsilon {
        bendAxis = simd_cross(c - a, bendHint)
    }
    guard simd_length_squared(bendAxis) > epsilon else { return }
    bendAxis = simd_normalize(bendAxis)

    // Aim axis. Vanishes when the chain already points at the target — the
    // aim rotation is then zero and any valid axis works.
    var aimAxis = simd_cross(c - a, target - a)
    if simd_length_squared(aimAxis) < epsilon {
        aimAxis = bendAxis
    }
    aimAxis = simd_normalize(aimAxis)

    // Express the world-space axes in each joint's local space and
    // post-multiply onto the local rotations. With both axes converted via
    // the ORIGINAL global rotation g, `l * A * B` composes to
    // p⁻¹·A_world·B_world·g — so the bend must come last to be applied
    // first in world space, then the aim swings the whole chain onto the
    // target. (The wrong order is invisible when bend and aim axes
    // coincide, which they do whenever hint, chain, and target are
    // coplanar — test coverage includes the non-coplanar case.)
    let aInverse = aGlobalRotation.inverse
    let bInverse = bGlobalRotation.inverse

    let hipBend = simd_quatf(angle: angleACAB1 - angleACAB0, axis: simd_normalize(aInverse.act(bendAxis)))
    let kneeBend = simd_quatf(angle: angleBABC1 - angleBABC0, axis: simd_normalize(bInverse.act(bendAxis)))
    let hipAim = simd_quatf(angle: angleACAT0, axis: simd_normalize(aInverse.act(aimAxis)))

    aLocalRotation = simd_normalize(aLocalRotation * hipAim * hipBend)
    bLocalRotation = simd_normalize(bLocalRotation * kneeBend)
}

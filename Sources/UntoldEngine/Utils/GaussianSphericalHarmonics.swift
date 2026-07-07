//
//  GaussianSphericalHarmonics.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd

private let gaussianSHC1: Float = 0.4886025119029199
private let gaussianSHC2: [Float] = [
    1.0925484305920792,
    -1.0925484305920792,
    0.31539156525252005,
    -1.0925484305920792,
    0.5462742152960396,
]
private let gaussianSHC3: [Float] = [
    -0.5900435899266435,
    2.890611442640554,
    -0.4570457994644658,
    0.3731763325901154,
    -0.4570457994644658,
    1.445305721320277,
    -0.5900435899266435,
]

/// Decodes the display-referred RGB values represented by standard 3DGS SH
/// coefficients before they enter the engine's linear working color space.
func gaussianSRGBToLinear(_ color: simd_float3) -> simd_float3 {
    let nonnegative = simd_max(color, .zero)
    return simd_float3(
        nonnegative.x <= 0.04045
            ? nonnegative.x / 12.92
            : pow((nonnegative.x + 0.055) / 1.055, 2.4),
        nonnegative.y <= 0.04045
            ? nonnegative.y / 12.92
            : pow((nonnegative.y + 0.055) / 1.055, 2.4),
        nonnegative.z <= 0.04045
            ? nonnegative.z / 12.92
            : pow((nonnegative.z + 0.055) / 1.055, 2.4)
    )
}

/// Converts a world-space camera position to the Gaussian asset's local space.
func gaussianLocalCameraPosition(
    cameraWorldPosition: simd_float3,
    modelMatrix: simd_float4x4
) -> simd_float3 {
    let local = modelMatrix.inverse * simd_float4(cameraWorldPosition, 1)
    return simd_float3(local.x, local.y, local.z)
}

/// CPU reference for the degree 1–3 terms used by `Gaussians.metal`.
/// The DC contribution and 0.5 bias must already be present in `baseColor`.
func evaluateGaussianSphericalHarmonics(
    baseColor: simd_float3,
    higherOrderCoefficients: [Float],
    degree: Int,
    direction: simd_float3
) -> simd_float3 {
    guard degree > 0 else { return baseColor }

    let coefficientsPerChannel = (degree + 1) * (degree + 1) - 1
    guard (1 ... 3).contains(degree),
          higherOrderCoefficients.count == coefficientsPerChannel * 3
    else {
        return baseColor
    }

    let directionLengthSquared = simd_length_squared(direction)
    guard directionLengthSquared > Float.ulpOfOne else { return baseColor }
    let d = direction * simd_rsqrt(directionLengthSquared)
    let x = d.x
    let y = d.y
    let z = d.z

    func coefficient(_ index: Int) -> simd_float3 {
        let offset = index - 1
        return simd_float3(
            higherOrderCoefficients[offset],
            higherOrderCoefficients[coefficientsPerChannel + offset],
            higherOrderCoefficients[2 * coefficientsPerChannel + offset]
        )
    }

    var result = baseColor
    result += gaussianSHC1 * (-y * coefficient(1) + z * coefficient(2) - x * coefficient(3))

    if degree > 1 {
        let xx = x * x
        let yy = y * y
        let zz = z * z
        let basis4 = gaussianSHC2[0] * x * y
        let basis5 = gaussianSHC2[1] * y * z
        let basis6 = gaussianSHC2[2] * (2 * zz - xx - yy)
        let basis7 = gaussianSHC2[3] * x * z
        let basis8 = gaussianSHC2[4] * (xx - yy)
        result += basis4 * coefficient(4)
        result += basis5 * coefficient(5)
        result += basis6 * coefficient(6)
        result += basis7 * coefficient(7)
        result += basis8 * coefficient(8)

        if degree > 2 {
            let basis9 = gaussianSHC3[0] * y * (3 * xx - yy)
            let basis10 = gaussianSHC3[1] * x * y * z
            let basis11 = gaussianSHC3[2] * y * (4 * zz - xx - yy)
            let basis12 = gaussianSHC3[3] * z * (2 * zz - 3 * xx - 3 * yy)
            let basis13 = gaussianSHC3[4] * x * (4 * zz - xx - yy)
            let basis14 = gaussianSHC3[5] * z * (xx - yy)
            let basis15 = gaussianSHC3[6] * x * (xx - 3 * yy)
            result += basis9 * coefficient(9)
            result += basis10 * coefficient(10)
            result += basis11 * coefficient(11)
            result += basis12 * coefficient(12)
            result += basis13 * coefficient(13)
            result += basis14 * coefficient(14)
            result += basis15 * coefficient(15)
        }
    }

    return simd_max(result, .zero)
}

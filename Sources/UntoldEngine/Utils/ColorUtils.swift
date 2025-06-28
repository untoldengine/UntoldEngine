//
//  ColorUtils.swift
//
//
//  Created by Harold Serrano on 6/6/25.
//

import Foundation
import simd

func standardIlluminantY(x: Float) -> Float {
    2.87 * x - 3 * x * x - 0.27509507
}

func CIExyToLMS(x: Float, y: Float) -> simd_float3 {
    let Y: Float = 1
    let X: Float = Y * x / y
    let Z: Float = Y * (1 - x - y) / y

    let L: Float = 0.7328 * X + 0.4296 * Y - 0.1624 * Z
    let M: Float = -0.7036 * X + 1.6975 * Y + 0.0061 * Z
    let S: Float = 0.0030 * X + 0.0136 * Y + 0.9834 * Z

    return simd_float3(L, M, S)
}

func colorBalanceToLMSCoeffs(temperature: Float, tint: Float) -> simd_float3 {
    let t1: Float = temperature / 65
    let t2: Float = tint / 65

    // Get the CIE xy chromaticity of the reference white point.
    // Note: 0.31271 = x value on the D65 white point
    let x: Float = 0.31271 - t1 * (t1 < 0 ? 0.1 : 0.05)
    let y: Float = standardIlluminantY(x: x) + t2 * 0.05

    // Calculate the coefficients in the LMS space.
    let w1 = simd_float3(0.949237, 1.03542, 1.08728) // D65 white point
    let w2: simd_float3 = CIExyToLMS(x: x, y: y)
    return simd_float3(w1.x / w2.x, w1.y / w2.y, w1.z / w2.z)
}

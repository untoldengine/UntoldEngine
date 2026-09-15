//
//  UntoldGSHarmonicRotation.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Rotates a splat's higher-order spherical-harmonic coefficients the way the cook rotates
//  its position and orientation, so the view-dependent colour is read off the right
//  direction in the cooked frame.

import Foundation
import simd

/// The cook's rotation applied to spherical-harmonic coefficients.
///
/// The renderer evaluates a splat's harmonics with the direction from the camera to the
/// splat in the cooked (entity) frame. Coefficients fitted in the capture frame therefore
/// have to be expressed in the cooked frame, or every view-dependent term is read off a
/// rotated direction: under the −Y-up fix (a half turn about X) a car body's sky-facing
/// highlight lands underneath it. Per band l the real basis is closed under rotation,
/// Y_l(R d) = M_l Y_l(d) for an orthogonal (2l+1)×(2l+1) M_l, and the colour c·Y(d) is
/// preserved by c' = M_l c: c'·Y(R d) = c·M_lᵀ M_l Y(d) = c·Y(d). M_l is fitted by least
/// squares from the renderer's own basis (`basis(direction:)`, the constants and signs of
/// Gaussians.metal) sampled on a fixed set of directions, so the basis convention is honoured
/// exactly and every band up to the format's degree 3 is covered.
struct UntoldGSHarmonicRotation {
    /// Row-major band matrices for l = 1, 2, 3 (3×3, 5×5, 7×7).
    let bands: [[Float]]

    static let bandSizes = [3, 5, 7]
    /// Offset of each band's first coefficient among the 15 higher-order values of a channel.
    static let bandOffsets = [0, 3, 8]

    /// Nil for the identity rotation: nothing to do.
    init?(rotation: simd_quatf) {
        let q = simd_normalize(rotation)
        // The identity up to float noise: an angle below a hundredth of a degree.
        if abs(q.real) >= 1 - 1e-9 || q.angle < 1e-4 {
            return nil
        }
        let r = simd_float3x3(q)
        let directions = Self.sampleDirections()
        let count = directions.count
        var bands: [[Float]] = []
        for (band, size) in Self.bandSizes.enumerated() {
            let offset = Self.bandOffsets[band]
            // p: the band's basis on the directions (size × count); pr: on the rotated directions.
            var p = [[Double]](repeating: [Double](repeating: 0, count: count), count: size)
            var pr = p
            for (i, d) in directions.enumerated() {
                let y = Self.basis(direction: d)
                let yr = Self.basis(direction: r * d)
                for k in 0 ..< size {
                    p[k][i] = Double(y[offset + k])
                    pr[k][i] = Double(yr[offset + k])
                }
            }
            // M = pr pᵀ (p pᵀ)⁻¹
            var ppt = [[Double]](repeating: [Double](repeating: 0, count: size), count: size)
            var prpt = ppt
            for a in 0 ..< size {
                for b in 0 ..< size {
                    var s1 = 0.0
                    var s2 = 0.0
                    for i in 0 ..< count {
                        s1 += p[a][i] * p[b][i]
                        s2 += pr[a][i] * p[b][i]
                    }
                    ppt[a][b] = s1
                    prpt[a][b] = s2
                }
            }
            let inverse = Self.inverted(ppt)
            var m = [Float](repeating: 0, count: size * size)
            for a in 0 ..< size {
                for b in 0 ..< size {
                    var s = 0.0
                    for c in 0 ..< size {
                        s += prpt[a][c] * inverse[c][b]
                    }
                    m[a * size + b] = Float(s)
                }
            }
            bands.append(m)
        }
        self.bands = bands
    }

    /// Rotates the higher-order coefficients of one channel in place: 3, 8 or 15 values
    /// (degree 1, 2 or 3) in the renderer's slot order.
    func rotate(_ coefficients: inout [Float]) {
        var scratch = [Float](repeating: 0, count: 7)
        for (band, size) in Self.bandSizes.enumerated() {
            let offset = Self.bandOffsets[band]
            guard offset + size <= coefficients.count else { break }
            let m = bands[band]
            for a in 0 ..< size {
                var s: Float = 0
                for b in 0 ..< size {
                    s += m[a * size + b] * coefficients[offset + b]
                }
                scratch[a] = s
            }
            for a in 0 ..< size {
                coefficients[offset + a] = scratch[a]
            }
        }
    }

    // MARK: - The renderer's basis

    static let c1: Float = 0.4886025119029199
    static let c2: [Float] = [1.0925484305920792, -1.0925484305920792, 0.31539156525252005, -1.0925484305920792, 0.5462742152960396]
    static let c3: [Float] = [-0.5900435899266435, 2.890611442640554, -0.4570457994644658, 0.3731763325901154, -0.4570457994644658, 1.445305721320277, -0.5900435899266435]

    /// The 15 higher-order basis functions at a unit direction, in the slot order and with the
    /// signs `evaluateGaussianSphericalHarmonics` (Gaussians.metal) multiplies the coefficients by.
    static func basis(direction d: SIMD3<Float>) -> [Float] {
        let x = d.x, y = d.y, z = d.z
        let xx = x * x, yy = y * y, zz = z * z
        return [
            -c1 * y, c1 * z, -c1 * x,
            c2[0] * x * y, c2[1] * y * z, c2[2] * (2 * zz - xx - yy), c2[3] * x * z, c2[4] * (xx - yy),
            c3[0] * y * (3 * xx - yy), c3[1] * x * y * z, c3[2] * y * (4 * zz - xx - yy), c3[3] * z * (2 * zz - 3 * xx - 3 * yy),
            c3[4] * x * (4 * zz - xx - yy), c3[5] * z * (xx - yy), c3[6] * x * (xx - 3 * yy),
        ]
    }

    /// The colour one channel's coefficients give at a direction: the DC term plus the higher
    /// orders, as the shader sums them.
    static func evaluate(dc: Float, higherOrders: [Float], direction: SIMD3<Float>) -> Float {
        let y = basis(direction: direction)
        var sum = dc
        for k in 0 ..< min(higherOrders.count, y.count) {
            sum += higherOrders[k] * y[k]
        }
        return sum
    }

    /// 32 fixed, well-spread unit directions (a Fibonacci sphere): more than the 7 the largest
    /// band needs, so the fit is well conditioned.
    static func sampleDirections() -> [SIMD3<Float>] {
        let n = 32
        let golden = Float.pi * (3 - Float(5).squareRoot())
        return (0 ..< n).map { i in
            let y = 1 - (Float(i) + 0.5) * 2 / Float(n)
            let radius = max(0, 1 - y * y).squareRoot()
            let theta = golden * Float(i)
            return SIMD3<Float>(cos(theta) * radius, y, sin(theta) * radius)
        }
    }

    /// Gauss–Jordan inverse of a small matrix (the bands' Gram matrices, at most 7×7).
    static func inverted(_ matrix: [[Double]]) -> [[Double]] {
        let n = matrix.count
        var a = matrix
        var inverse = (0 ..< n).map { i in (0 ..< n).map { $0 == i ? 1.0 : 0.0 } }
        for column in 0 ..< n {
            var pivot = column
            for row in column + 1 ..< n where abs(a[row][column]) > abs(a[pivot][column]) {
                pivot = row
            }
            if pivot != column {
                a.swapAt(column, pivot)
                inverse.swapAt(column, pivot)
            }
            let scale = a[column][column]
            guard scale != 0 else { continue }
            for k in 0 ..< n {
                a[column][k] /= scale
                inverse[column][k] /= scale
            }
            for row in 0 ..< n where row != column {
                let factor = a[row][column]
                guard factor != 0 else { continue }
                for k in 0 ..< n {
                    a[row][k] -= factor * a[column][k]
                    inverse[row][k] -= factor * inverse[column][k]
                }
            }
        }
        return inverse
    }
}

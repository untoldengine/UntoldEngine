//
//  UntoldGSHarmonicRotationTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import simd
@testable import UntoldEngine
import XCTest

/// The cook turns a splat's higher-order harmonics with the splat: the colour a direction gave
/// in the capture frame is the colour the rotated direction gives in the cooked frame.
final class UntoldGSHarmonicRotationTests: XCTestCase {
    private struct SplitMix64 {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }

        mutating func value(in range: ClosedRange<Float>) -> Float {
            let unit = Float(next() >> 40) / Float(1 << 24)
            return range.lowerBound + unit * (range.upperBound - range.lowerBound)
        }

        mutating func direction() -> SIMD3<Float> {
            simd_normalize(SIMD3<Float>(value(in: -1 ... 1), value(in: -1 ... 1), value(in: -1 ... 1)))
        }
    }

    func test_identityNeedsNoRotation() {
        XCTAssertNil(UntoldGSHarmonicRotation(rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))))
        XCTAssertNil(UntoldGSHarmonicRotation(rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)))
        XCTAssertNotNil(UntoldGSHarmonicRotation(rotation: simd_quatf(angle: 0.01, axis: SIMD3<Float>(0, 1, 0))))
    }

    func test_rotatedCoefficientsGiveTheSameColourOnRotatedDirections() throws {
        var random = SplitMix64(state: 0x5EED_0042)
        for trial in 0 ..< 24 {
            let quaternion = simd_quatf(angle: random.value(in: 0.05 ... Float.pi), axis: random.direction())
            let rotation = try XCTUnwrap(UntoldGSHarmonicRotation(rotation: quaternion))
            let coefficients = (0 ..< 15).map { _ in random.value(in: -0.5 ... 0.5) }
            var rotated = coefficients
            rotation.rotate(&rotated)
            let matrix = simd_float3x3(quaternion)
            for _ in 0 ..< 12 {
                let direction = random.direction()
                let before = UntoldGSHarmonicRotation.evaluate(dc: 0.5, higherOrders: coefficients, direction: direction)
                let after = UntoldGSHarmonicRotation.evaluate(dc: 0.5, higherOrders: rotated, direction: matrix * direction)
                XCTAssertEqual(after, before, accuracy: 2e-4, "trial \(trial): the rotated coefficients read the same colour off the rotated direction")
            }
            // A degree-1 or degree-2 channel rotates band by band the same way.
            var degree1 = Array(coefficients[0 ..< 3])
            rotation.rotate(&degree1)
            XCTAssertEqual(degree1, Array(rotated[0 ..< 3]))
            var degree2 = Array(coefficients[0 ..< 8])
            rotation.rotate(&degree2)
            XCTAssertEqual(degree2, Array(rotated[0 ..< 8]))
        }
    }

    func test_bandMatricesAreOrthogonal() throws {
        let rotation = try XCTUnwrap(UntoldGSHarmonicRotation(rotation: simd_quatf(angle: 1.1, axis: simd_normalize(SIMD3<Float>(0.3, 1, -0.2)))))
        for (band, size) in UntoldGSHarmonicRotation.bandSizes.enumerated() {
            let m = rotation.bands[band]
            for a in 0 ..< size {
                for b in 0 ..< size {
                    var dot: Float = 0
                    for k in 0 ..< size {
                        dot += m[a * size + k] * m[b * size + k]
                    }
                    XCTAssertEqual(dot, a == b ? 1 : 0, accuracy: 1e-4, "band \(band + 1): rows \(a) and \(b)")
                }
            }
        }
    }

    /// The basis the rotation is fitted from is the renderer's: it agrees with the CPU evaluator
    /// pinned to Gaussians.metal, channel by channel, so a transcription error in either shows.
    /// The evaluator clamps a negative colour at zero, as the shader's caller does.
    func test_basisMatchesTheRendererCPUEvaluator() {
        var random = SplitMix64(state: 0x5EED_0B45)
        for trial in 0 ..< 16 {
            let base = simd_float3(random.value(in: 0 ... 1), random.value(in: 0 ... 1), random.value(in: 0 ... 1))
            let channels = (0 ..< 3).map { _ in (0 ..< 15).map { _ in random.value(in: -0.5 ... 0.5) } }
            let direction = random.direction() * random.value(in: 0.5 ... 3)
            let expected = evaluateGaussianSphericalHarmonics(baseColor: base, higherOrderCoefficients: channels.flatMap { $0 }, degree: 3, direction: direction)
            let unit = simd_normalize(direction)
            for channel in 0 ..< 3 {
                let ours = UntoldGSHarmonicRotation.evaluate(dc: base[channel], higherOrders: channels[channel], direction: unit)
                XCTAssertEqual(max(ours, 0), expected[channel], accuracy: 1e-5, "trial \(trial), channel \(channel)")
            }
        }
    }

    func test_halfTurnAboutXFlipsTheOddBasisFunctions() throws {
        // (x, y, z) → (x, −y, −z), the −Y-up fix: every basis function odd in y and z together flips.
        let rotation = try XCTUnwrap(UntoldGSHarmonicRotation(rotation: simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))))
        let expectedSigns: [Float] = [-1, -1, 1, -1, 1, 1, -1, 1, -1, 1, -1, -1, 1, -1, 1]
        let original = (0 ..< 15).map { Float($0 + 1) * 0.01 }
        var values = original
        rotation.rotate(&values)
        for k in 0 ..< 15 {
            XCTAssertEqual(values[k], original[k] * expectedSigns[k], accuracy: 1e-5, "slot \(k)")
        }
    }

    func test_cookRotatesTheHarmonicsWithTheSplats() throws {
        let splat = GaussianSplat(center: SIMD4<Float>(0, 1, 2, 1), scale: SIMD4<Float>(0.1, 0.1, 0.1, 1), color: SIMD4<Float>(0.5, 0.5, 0.5, 1), quat: SIMD4<Float>(1, 0, 0, 0), opacity: 0.9)
        var coefficients: [Float] = []
        for channel in 0 ..< 3 {
            // DC then the degree-1 slots (y, z, x), scaled per channel.
            coefficients += [0.5, 0.1, 0.2, 0.3].map { $0 * Float(channel + 1) }
        }
        let asset = GaussianSplatAsset(splats: [splat], sphericalHarmonics: GaussianSphericalHarmonics(degree: 1, coefficientsPerChannel: 4, coefficients: coefficients))

        var options = UntoldGSCookOptions()
        options.transform = UntoldGSCookOptions.transform(upAxis: .negativeY)
        let cooked = try UntoldGSCooker.cook(asset: asset, options: options)
        let harmonics = try XCTUnwrap(cooked.asset.sphericalHarmonics)
        XCTAssertEqual(harmonics.coefficientsPerChannel, 4)
        for channel in 0 ..< 3 {
            let base = channel * 4
            let scale = Float(channel + 1)
            XCTAssertEqual(harmonics.coefficients[base], 0.5 * scale, accuracy: 1e-6, "the DC term is untouched")
            XCTAssertEqual(harmonics.coefficients[base + 1], -0.1 * scale, accuracy: 1e-5, "the y term flips under the half turn about X")
            XCTAssertEqual(harmonics.coefficients[base + 2], -0.2 * scale, accuracy: 1e-5, "the z term flips")
            XCTAssertEqual(harmonics.coefficients[base + 3], 0.3 * scale, accuracy: 1e-5, "the x term stays")
        }

        let plain = try UntoldGSCooker.cook(asset: asset, options: UntoldGSCookOptions())
        XCTAssertEqual(plain.asset.sphericalHarmonics?.coefficients ?? [], coefficients, "the identity cook leaves the harmonics alone")
    }
}

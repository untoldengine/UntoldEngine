//
//  GaussianSphericalHarmonicsTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

final class GaussianSphericalHarmonicsTests: XCTestCase {
    func testSRGBGaussianColorIsDecodedIntoLinearWorkingSpace() {
        let result = gaussianSRGBToLinear(simd_float3(0, 0.04045, 0.5))

        XCTAssertEqual(result.x, 0, accuracy: 1e-7)
        XCTAssertEqual(result.y, 0.0031308, accuracy: 1e-7)
        XCTAssertEqual(result.z, 0.21404114, accuracy: 1e-7)
        XCTAssertEqual(gaussianSRGBToLinear(simd_float3(repeating: 1)), simd_float3(repeating: 1))
    }

    func testSRGBGaussianColorClampsNegativeSHResultsBeforeDecode() {
        XCTAssertEqual(
            gaussianSRGBToLinear(simd_float3(-1, -0.1, -.ulpOfOne)),
            .zero
        )
    }

    func testDegreeZeroReturnsBaseColorExactly() {
        let base = simd_float3(0.2, 0.4, 0.6)
        XCTAssertEqual(
            evaluateGaussianSphericalHarmonics(
                baseColor: base,
                higherOrderCoefficients: [],
                degree: 0,
                direction: simd_float3(1, 0, 0)
            ),
            base
        )
    }

    func testDegreeOneUsesStandardRealSHBasis() {
        var coefficients = [Float](repeating: 0, count: 9)
        coefficients[0] = 1 // Red coefficient 1: -C1 * y
        let result = evaluateGaussianSphericalHarmonics(
            baseColor: simd_float3(repeating: 1),
            higherOrderCoefficients: coefficients,
            degree: 1,
            direction: simd_float3(0, 2, 0)
        )

        XCTAssertEqual(result.x, 1 - 0.4886025119, accuracy: 1e-6)
        XCTAssertEqual(result.y, 1, accuracy: 1e-6)
        XCTAssertEqual(result.z, 1, accuracy: 1e-6)
    }

    func testDegreeTwoUsesChannelMajorCoefficientSix() {
        var coefficients = [Float](repeating: 0, count: 24)
        coefficients[2 * 8 + 5] = 1 // Blue coefficient 6
        let result = evaluateGaussianSphericalHarmonics(
            baseColor: simd_float3(repeating: 0.5),
            higherOrderCoefficients: coefficients,
            degree: 2,
            direction: simd_float3(0, 0, 1)
        )

        XCTAssertEqual(result.x, 0.5, accuracy: 1e-6)
        XCTAssertEqual(result.y, 0.5, accuracy: 1e-6)
        XCTAssertEqual(result.z, 0.5 + 2 * 0.3153915653, accuracy: 1e-6)
    }

    func testDegreeThreeUsesChannelMajorCoefficientTwelve() {
        var coefficients = [Float](repeating: 0, count: 45)
        coefficients[15 + 11] = 1 // Green coefficient 12
        let result = evaluateGaussianSphericalHarmonics(
            baseColor: simd_float3(repeating: 0.5),
            higherOrderCoefficients: coefficients,
            degree: 3,
            direction: simd_float3(0, 0, 1)
        )

        XCTAssertEqual(result.x, 0.5, accuracy: 1e-6)
        XCTAssertEqual(result.y, 0.5 + 2 * 0.3731763326, accuracy: 1e-6)
        XCTAssertEqual(result.z, 0.5, accuracy: 1e-6)
    }

    func testLocalCameraPositionAccountsForEntityTransform() {
        let rotation = simd_float4x4(simd_quatf(angle: .pi / 2, axis: simd_float3(0, 0, 1)))
        let scale = simd_float4x4(diagonal: simd_float4(2, 3, 4, 1))
        var translation = matrix_identity_float4x4
        translation.columns.3 = simd_float4(10, -5, 7, 1)
        let model = translation * rotation * scale
        let expectedLocal = simd_float3(1, 2, 3)
        let cameraWorld4 = model * simd_float4(expectedLocal, 1)

        let actual = gaussianLocalCameraPosition(
            cameraWorldPosition: simd_float3(cameraWorld4.x, cameraWorld4.y, cameraWorld4.z),
            modelMatrix: model
        )

        XCTAssertEqual(actual.x, expectedLocal.x, accuracy: 1e-5)
        XCTAssertEqual(actual.y, expectedLocal.y, accuracy: 1e-5)
        XCTAssertEqual(actual.z, expectedLocal.z, accuracy: 1e-5)
    }
}

//
//  BaseColorShadingTests.swift
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

/// The base color a material gives, with and without a texture.
final class BaseColorShadingTests: MaterialShadingTestCase {
    private func material(base: simd_float3, texture: URL? = nil, alpha: Float = 1.0, blended: Bool = false) -> RuntimeMaterialSource {
        RuntimeMaterialSource(
            baseColorFactor: simd_float4(base, alpha),
            metallicFactor: 0.0,
            roughnessFactor: 1.0,
            flags: blended ? 2 : 0,
            baseColorTexture: texture.map { RuntimeTextureReference(name: $0.lastPathComponent, sourceURL: $0, isSRGB: true) }
        )
    }

    /// A base color of zero used to be taken for "not set" and drawn white: a black
    /// oven came out as a white one.
    func testABlackBaseColorIsDrawnBlack() throws {
        let white = try shade(material(base: simd_float3(1, 1, 1)))
        let black = try shade(material(base: simd_float3(0, 0, 0)))
        XCTAssertGreaterThan(white.y, 0.1, "the face is lit")
        XCTAssertLessThan(black.y, white.y * 0.05)
    }

    func testABlackBlendedMaterialIsDrawnBlack() throws {
        // Half see-through over the background: the darker the surface, the darker the pixel.
        let white = try shade(material(base: simd_float3(1, 1, 1), alpha: 0.5, blended: true))
        let black = try shade(material(base: simd_float3(0, 0, 0), alpha: 0.5, blended: true))
        XCTAssertLessThan(black.y, white.y * 0.8)
    }

    /// With a texture, a base color factor left at zero still means "show the texture".
    func testATexturedMaterialWithAnUnsetBaseColorShowsItsTexture() throws {
        let texture = try writeTexture(red: 200, green: 100, blue: 50)
        let tinted = try shade(material(base: simd_float3(1, 1, 1), texture: texture))
        let unset = try shade(material(base: simd_float3(0, 0, 0), texture: texture))
        XCTAssertGreaterThan(tinted.x, 0.05)
        for channel in 0 ..< 3 {
            XCTAssertEqual(unset[channel], tinted[channel], accuracy: tinted[channel] * 0.03)
        }
        XCTAssertGreaterThan(tinted.x, tinted.z * 1.5, "the texture's orange shows")
    }
}

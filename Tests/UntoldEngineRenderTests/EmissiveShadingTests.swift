//
//  EmissiveShadingTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import ModelIO
import simd
@testable import UntoldEngine
import XCTest

/// The light a material gives off: its emissive color, its emissive texture, and both
/// on a material that is blended over what is behind it.
final class EmissiveShadingTests: MaterialShadingTestCase {
    /// A black surface, so that all it shows is what it gives off.
    private func material(emissive: simd_float3, texture: URL? = nil, alpha: Float = 1.0, blended: Bool = false) -> RuntimeMaterialSource {
        RuntimeMaterialSource(
            baseColorFactor: simd_float4(0, 0, 0, alpha),
            emissiveFactor: emissive,
            metallicFactor: 0.0,
            roughnessFactor: 1.0,
            flags: blended ? 2 : 0,
            emissiveTexture: texture.map { RuntimeTextureReference(name: $0.lastPathComponent, sourceURL: $0, isSRGB: true) }
        )
    }

    /// How much of a glow a cube that is half there shows. The glow fades with the
    /// surface, so its front face gives half of it; a blended cube also shows its back
    /// face, which gives half again, seen through the front: 0.5 + 0.5 x 0.5.
    private static let halfThereTwice: Float = 0.75

    /// The 8-bit value of an sRGB texture, as the linear value a shader reads from it.
    private func linear(_ value: UInt8) -> Float {
        let encoded = Float(value) / 255.0
        return encoded <= 0.04045 ? encoded / 12.92 : pow((encoded + 0.055) / 1.055, 2.4)
    }

    /// An emissive texture was loaded and never drawn: a lit sign showed the flat color
    /// of its emissive factor, white, in place of what is painted on it.
    func testAnEmissiveTextureColorsTheGlow() throws {
        try buildScene(towardsLight: nil)
        let dark = try shade(material(emissive: .zero))
        let plain = try shade(material(emissive: simd_float3(1, 1, 1)))
        let texture = try writeTexture(red: 200, green: 100, blue: 50)
        let painted = try shade(material(emissive: simd_float3(1, 1, 1), texture: texture))

        XCTAssertEqual(plain.x - dark.x, 1.0, accuracy: 0.02, "without a texture, the emissive color is what glows")
        let expected = simd_float3(linear(200), linear(100), linear(50))
        for channel in 0 ..< 3 {
            XCTAssertEqual(painted[channel] - dark[channel], expected[channel], accuracy: 0.02)
        }
    }

    func testTheEmissiveColorScalesTheTexture() throws {
        try buildScene(towardsLight: nil)
        let dark = try shade(material(emissive: .zero))
        let texture = try writeTexture(red: 200, green: 100, blue: 50)
        let full = try shade(material(emissive: simd_float3(1, 1, 1), texture: texture)) - dark
        let half = try shade(material(emissive: simd_float3(0.5, 0.5, 0.5), texture: texture)) - dark
        let twice = try shade(material(emissive: simd_float3(2, 2, 2), texture: texture)) - dark
        let none = try shade(material(emissive: .zero, texture: texture)) - dark

        XCTAssertGreaterThan(full.x, 0.3)
        XCTAssertEqual(half.x, full.x * 0.5, accuracy: 0.02)
        XCTAssertEqual(twice.x, full.x * 2.0, accuracy: 0.03)
        XCTAssertEqual(none.x, 0.0, accuracy: 0.01, "an emissive color of zero gives off nothing, with or without a texture")
    }

    /// A blended material gave off nothing: a lit, see-through panel was drawn unlit.
    func testABlendedMaterialGlows() throws {
        try buildScene(towardsLight: nil)
        let dark = try shade(material(emissive: .zero, alpha: 0.5, blended: true))
        let glowing = try shade(material(emissive: simd_float3(1.0, 0.5, 0.0), alpha: 0.5, blended: true))

        for channel in 0 ..< 3 {
            XCTAssertEqual(glowing[channel] - dark[channel], simd_float3(1.0, 0.5, 0.0)[channel] * Self.halfThereTwice, accuracy: 0.02)
        }
    }

    func testABlendedMaterialShowsItsEmissiveTexture() throws {
        try buildScene(towardsLight: nil)
        let dark = try shade(material(emissive: .zero, alpha: 0.5, blended: true))
        let texture = try writeTexture(red: 50, green: 100, blue: 200)
        let painted = try shade(material(emissive: simd_float3(1, 1, 1), texture: texture, alpha: 0.5, blended: true))

        let expected = simd_float3(linear(50), linear(100), linear(200)) * Self.halfThereTwice
        for channel in 0 ..< 3 {
            XCTAssertEqual(painted[channel] - dark[channel], expected[channel], accuracy: 0.02)
        }
    }

    /// A material read from a USD file has the texture and no color to go with it: it
    /// shows the texture as painted.
    func testAUSDMaterialWithAnEmissiveTextureGlowsWithIt() throws {
        let texture = try writeTexture(red: 200, green: 100, blue: 50)
        let withTexture = MDLMaterial(name: "sign", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        withTexture.setProperty(MDLMaterialProperty(name: "emission", semantic: .emission, url: texture))
        let without = MDLMaterial(name: "wall", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())

        let textureLoader = TextureLoader(device: renderInfo.device)
        let sign = Material(mdlMaterial: withTexture, textureLoader: textureLoader, name: "sign")
        let wall = Material(mdlMaterial: without, textureLoader: textureLoader, name: "wall")

        XCTAssertTrue(sign.hasEmissiveMap)
        XCTAssertEqual(sign.emissiveValue, simd_float3(1, 1, 1))
        XCTAssertFalse(wall.hasEmissiveMap)
        XCTAssertEqual(wall.emissiveValue, .zero)
    }
}

//
//  BaseColorShadingTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import MetalKit
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

    /// A color texture whose red, green and blue are the same is stored with one channel.
    /// It was read as linear values where a color texture holds sRGB ones: a mid gray
    /// came out more than twice as bright as the same gray stored with three channels.
    func testAGrayscaleColorTextureIsAsBrightAsTheSameGrayInThreeChannels() throws {
        let threeChannels = try shade(material(base: simd_float3(1, 1, 1), texture: writeTexture(red: 128, green: 128, blue: 128)))
        let oneChannel = try shade(material(base: simd_float3(1, 1, 1), texture: writeGrayscaleTexture(value: 128)))
        XCTAssertGreaterThan(threeChannels.y, 0.01, "the face is lit")
        for channel in 0 ..< 3 {
            XCTAssertEqual(oneChannel[channel], threeChannels[channel], accuracy: threeChannels[channel] * 0.03)
        }
    }

    /// The texture comes back in the pixel format of what it holds, so that whatever reads
    /// it decodes it the same way: the shaders, and the texture streaming system when it
    /// builds a smaller copy (it loads through the same function).
    func testAGrayscaleTextureLoadsInTheFormatOfWhatItHolds() throws {
        let loader = MTKTextureLoader(device: renderInfo.device)
        func options(isSRGB: Bool) -> [MTKTextureLoader.Option: Any] {
            [
                .textureUsage: NSNumber(value: MTLTextureUsage([.shaderRead, .pixelFormatView]).rawValue),
                .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
                .SRGB: NSNumber(value: isSRGB),
                .generateMipmaps: NSNumber(value: true),
            ]
        }
        let gray = try writeGrayscaleTexture(value: 128)

        let colors = try XCTUnwrap(loadGrayscaleTextureAsRGBA(url: gray, isSRGB: true, loader: loader, options: options(isSRGB: true)))
        XCTAssertEqual(colors.pixelFormat, .rgba8Unorm_srgb)
        XCTAssertGreaterThan(colors.mipmapLevelCount, 1)

        let values = try XCTUnwrap(loadGrayscaleTextureAsRGBA(url: gray, isSRGB: false, loader: loader, options: options(isSRGB: false)))
        XCTAssertEqual(values.pixelFormat, .rgba8Unorm)

        let threeChannels = try writeTexture(red: 128, green: 128, blue: 128)
        XCTAssertNil(
            loadGrayscaleTextureAsRGBA(url: threeChannels, isSRGB: true, loader: loader, options: options(isSRGB: true)),
            "an image with three channels is left to the ordinary load"
        )
    }

    /// A texture of values, not of colors, is read as it is stored, with one channel or three.
    func testAGrayscaleValueTextureIsReadAsStored() throws {
        func rough(_ texture: URL) -> RuntimeMaterialSource {
            RuntimeMaterialSource(
                baseColorFactor: simd_float4(1, 1, 1, 1),
                metallicFactor: 1.0,
                roughnessFactor: 1.0,
                metallicTexture: RuntimeTextureReference(name: texture.lastPathComponent, sourceURL: texture),
                roughnessTexture: RuntimeTextureReference(name: texture.lastPathComponent, sourceURL: texture)
            )
        }
        let threeChannels = try shade(rough(writeTexture(red: 128, green: 128, blue: 128)))
        let oneChannel = try shade(rough(writeGrayscaleTexture(value: 128)))
        XCTAssertGreaterThan(threeChannels.y, 0.01, "the face is lit")
        for channel in 0 ..< 3 {
            XCTAssertEqual(oneChannel[channel], threeChannels[channel], accuracy: threeChannels[channel] * 0.03)
        }
    }
}

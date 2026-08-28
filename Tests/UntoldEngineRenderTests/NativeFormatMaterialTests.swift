//
//  NativeFormatMaterialTests.swift
//  UntoldEngine
//
//  Verifies that `.untold` runtime materials preserve emissive
//  texture references when constructing engine `Material` instances.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import ImageIO
import MetalKit
import UniformTypeIdentifiers
@testable import UntoldEngine
import XCTest

final class NativeFormatMaterialTests: XCTestCase {
    func testRuntimeMaterialLoadsEmissiveTexture() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device unavailable")
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let emissiveURL = tempDir.appendingPathComponent("emissive.png")
        try writeMinimalPNG(to: emissiveURL, rgba: (255, 64, 32, 255))

        let runtimeMaterial = RuntimeMaterialSource(
            name: "RuntimeMaterial",
            emissiveFactor: SIMD3<Float>(0.25, 0.5, 0.75),
            emissiveTexture: RuntimeTextureReference(
                name: "emissive",
                sourceURL: emissiveURL,
                isSRGB: true,
                width: 1,
                height: 1,
                mipCount: 1
            )
        )

        let material = Material(runtimeMaterial: runtimeMaterial, device: device)

        XCTAssertNotNil(material.emissive.texture)
        XCTAssertEqual(material.emissiveURL, emissiveURL)
        XCTAssertEqual(material.emissiveSourceDimensions, simd_int2(1, 1))
        XCTAssertEqual(material.emissiveValue, SIMD3<Float>(0.25, 0.5, 0.75))
        XCTAssertTrue(material.hasEmissiveMap)
    }

    func testRuntimeMaterialLoadsHeightTexture() throws {
        // Companion to testRuntimeMaterialLoadsEmissiveTexture, for the height-map/POM
        // material fields: hasHeightMap (Mesh.swift) and the RuntimeMaterialSource ->
        // Material height field pass-through had no test coverage anywhere.
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device unavailable")
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let heightURL = tempDir.appendingPathComponent("height.png")
        try writeMinimalPNG(to: heightURL, rgba: (128, 128, 128, 255))

        let runtimeMaterial = RuntimeMaterialSource(
            name: "RuntimeMaterial",
            heightTexture: RuntimeTextureReference(
                name: "height",
                sourceURL: heightURL,
                isSRGB: false,
                width: 1,
                height: 1,
                mipCount: 1
            ),
            heightScale: 0.08,
            heightMidlevel: 0.65,
            heightRemapMin: 0.1,
            heightRemapMax: 0.9
        )

        let material = Material(runtimeMaterial: runtimeMaterial, device: device)

        XCTAssertNotNil(material.height.texture)
        XCTAssertEqual(material.heightURL, heightURL)
        XCTAssertEqual(material.heightScale, 0.08, accuracy: 0.0001)
        XCTAssertEqual(material.heightMidlevel, 0.65, accuracy: 0.0001)
        XCTAssertEqual(material.heightRemapMin, 0.1, accuracy: 0.0001)
        XCTAssertEqual(material.heightRemapMax, 0.9, accuracy: 0.0001)
        XCTAssertTrue(material.hasHeightMap)
    }

    func testRuntimeMaterialWithoutHeightTextureReportsNoHeightMap() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device unavailable")
        }

        let runtimeMaterial = RuntimeMaterialSource(name: "PlainMaterial")
        let material = Material(runtimeMaterial: runtimeMaterial, device: device)

        XCTAssertNil(material.height.texture)
        XCTAssertFalse(material.hasHeightMap)
        XCTAssertEqual(material.heightScale, 0.05, accuracy: 0.0001, "should be the documented default")
        XCTAssertEqual(material.heightMidlevel, 0.5, accuracy: 0.0001, "should be the documented default")
    }

    private func writeMinimalPNG(to url: URL, rgba: (UInt8, UInt8, UInt8, UInt8)) throws {
        let bytes = [rgba.0, rgba.1, rgba.2, rgba.3]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Failed to create CGContext for PNG test fixture")
            return
        }

        bytes.withUnsafeBytes { rawBuffer in
            if let src = rawBuffer.baseAddress {
                memcpy(context.data, src, 4)
            }
        }

        guard let image = context.makeImage() else {
            XCTFail("Failed to create CGImage for PNG test fixture")
            return
        }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            XCTFail("Failed to create image destination for PNG test fixture")
            return
        }

        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination), "Failed to finalize PNG test fixture")
    }
}

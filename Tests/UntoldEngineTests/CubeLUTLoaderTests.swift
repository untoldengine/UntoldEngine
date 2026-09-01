//
//  CubeLUTLoaderTests.swift
//  UntoldEngineTests
//
//  Unit tests for CubeLUTParser (pure text parsing, no GPU) and CubeLUTLoader's
//  Metal 3D texture upload.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal
@testable import UntoldEngine
import XCTest

private let minimalCubeLUT = """
    TITLE "Test LUT"
    # a comment line
    LUT_3D_SIZE 2
    0.0 0.0 0.0
    1.0 0.0 0.0
    0.0 1.0 0.0
    1.0 1.0 0.0
    0.0 0.0 1.0
    1.0 0.0 1.0
    0.0 1.0 1.0
    1.0 1.0 1.0
    """

final class CubeLUTParserTests: XCTestCase {
    func testParsesLUT3DSizeAndDefaultDomain() throws {
        let parsed = try CubeLUTParser.parse(minimalCubeLUT)
        XCTAssertEqual(parsed.size, 2)
        XCTAssertEqual(parsed.domainMin, SIMD3<Float>(0, 0, 0))
        XCTAssertEqual(parsed.domainMax, SIMD3<Float>(1, 1, 1))
        XCTAssertEqual(parsed.data.count, 8)
    }

    func testDataOrderIsRedFastestThenGreenThenBlue() throws {
        let parsed = try CubeLUTParser.parse(minimalCubeLUT)
        // Row order in the fixture above is exactly the .cube spec's canonical
        // order: r varies fastest, then g, then b.
        XCTAssertEqual(parsed.data[0], SIMD3<Float>(0, 0, 0))
        XCTAssertEqual(parsed.data[1], SIMD3<Float>(1, 0, 0))
        XCTAssertEqual(parsed.data[2], SIMD3<Float>(0, 1, 0))
        XCTAssertEqual(parsed.data[4], SIMD3<Float>(0, 0, 1))
        XCTAssertEqual(parsed.data[7], SIMD3<Float>(1, 1, 1))
    }

    func testParsesCustomDomain() throws {
        let text = """
        LUT_3D_SIZE 2
        DOMAIN_MIN -1.0 -1.0 -1.0
        DOMAIN_MAX 2.0 2.0 2.0
        \(Array(repeating: "0.0 0.0 0.0", count: 8).joined(separator: "\n"))
        """
        let parsed = try CubeLUTParser.parse(text)
        XCTAssertEqual(parsed.domainMin, SIMD3<Float>(-1, -1, -1))
        XCTAssertEqual(parsed.domainMax, SIMD3<Float>(2, 2, 2))
    }

    func testHandlesCRLFLineEndings() throws {
        let crlf = minimalCubeLUT.replacingOccurrences(of: "\n", with: "\r\n")
        let parsed = try CubeLUTParser.parse(crlf)
        XCTAssertEqual(parsed.size, 2)
        XCTAssertEqual(parsed.data.count, 8)
    }

    func testRejectsMissingLUT3DSize() {
        XCTAssertThrowsError(try CubeLUTParser.parse("TITLE \"bad\"\n0.0 0.0 0.0\n")) { error in
            guard case CubeLUTError.missingLUT3DSize = error else {
                return XCTFail("Expected missingLUT3DSize, got \(error)")
            }
        }
    }

    func testRejects1DLUT() {
        XCTAssertThrowsError(try CubeLUTParser.parse("LUT_1D_SIZE 16\n")) { error in
            guard case CubeLUTError.unsupported1DLUT = error else {
                return XCTFail("Expected unsupported1DLUT, got \(error)")
            }
        }
    }

    func testRejectsOutOfRangeSize() {
        XCTAssertThrowsError(try CubeLUTParser.parse("LUT_3D_SIZE 1\n0.0 0.0 0.0\n")) { error in
            guard case CubeLUTError.invalidSize = error else {
                return XCTFail("Expected invalidSize, got \(error)")
            }
        }
    }

    func testRejectsDataCountMismatch() {
        // LUT_3D_SIZE 2 expects 8 rows; only 4 are provided.
        let text = "LUT_3D_SIZE 2\n" + Array(repeating: "0.0 0.0 0.0", count: 4).joined(separator: "\n")
        XCTAssertThrowsError(try CubeLUTParser.parse(text)) { error in
            guard case CubeLUTError.dataCountMismatch = error else {
                return XCTFail("Expected dataCountMismatch, got \(error)")
            }
        }
    }

    func testParseFromFileURLRejectsMissingFile() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString).cube")
        XCTAssertThrowsError(try CubeLUTParser.parse(contentsOf: missing)) { error in
            guard case CubeLUTError.fileNotReadable = error else {
                return XCTFail("Expected fileNotReadable, got \(error)")
            }
        }
    }
}

final class CubeLUTLoaderTests: XCTestCase {
    private var device: MTLDevice!

    override func setUp() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Failed to create Metal device")
            return
        }
        self.device = device
    }

    func testMakesA3DTextureWithExpectedDimensionsAndFormat() throws {
        let parsed = try CubeLUTParser.parse(minimalCubeLUT)
        let texture = try CubeLUTLoader.makeTexture(device: device, parsed: parsed)
        XCTAssertEqual(texture.textureType, .type3D)
        XCTAssertEqual(texture.pixelFormat, .rgba16Float)
        XCTAssertEqual(texture.width, 2)
        XCTAssertEqual(texture.height, 2)
        XCTAssertEqual(texture.depth, 2)
    }

    func testUploadedTexelsMatchParsedData() throws {
        let parsed = try CubeLUTParser.parse(minimalCubeLUT)
        let texture = try CubeLUTLoader.makeTexture(device: device, parsed: parsed)

        var readback = [Float16](repeating: 0, count: 2 * 2 * 2 * 4)
        readback.withUnsafeMutableBytes { raw in
            texture.getBytes(
                raw.baseAddress!,
                bytesPerRow: 2 * 4 * MemoryLayout<Float16>.stride,
                bytesPerImage: 2 * 2 * 4 * MemoryLayout<Float16>.stride,
                from: MTLRegionMake3D(0, 0, 0, 2, 2, 2),
                mipmapLevel: 0,
                slice: 0
            )
        }

        // Texel at (r=1, g=0, b=0) is data[1] = (1, 0, 0) per the fixture.
        let texel1Base = 1 * 4
        XCTAssertEqual(Float(readback[texel1Base]), 1.0, accuracy: 0.01)
        XCTAssertEqual(Float(readback[texel1Base + 1]), 0.0, accuracy: 0.01)
        XCTAssertEqual(Float(readback[texel1Base + 2]), 0.0, accuracy: 0.01)
        XCTAssertEqual(Float(readback[texel1Base + 3]), 1.0, accuracy: 0.01, "alpha must default to 1.0")
    }
}

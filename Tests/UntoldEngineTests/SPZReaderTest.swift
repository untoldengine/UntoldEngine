//
//  SPZReaderTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Compression
import CShaderTypes
import Foundation
import simd
@testable import UntoldEngine
import XCTest

/// Fixtures build a *real* gzip envelope (header + raw-DEFLATE body via `compression_encode_buffer`
/// + trailer) around a hand-built legacy SPZ payload, then round-trip it through `SPZReader`'s
/// actual gzip unwrapper — not a mocked decompression step. This is deliberate: a previous pass at
/// this reader had a bug where the gzip trailer's ISIZE field (the uncompressed size, the *last* 4
/// bytes of the file) was read from the wrong offset (the CRC32 field, the *first* 4 of the 8-byte
/// trailer), and only a fixture that exercises the real gzip envelope catches that class of bug.
@MainActor
final class SPZReaderTest: XCTestCase {
    var tempFileURL: URL?

    override func tearDown() async throws {
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Position / coordinate flip

    func test_readGaussianAsset_decodesPositionWithRUBtoRDFFlip() throws {
        let payload = makeLegacyPayload(
            version: 2, numPoints: 1, shDegree: 0, fractionalBits: 0,
            positions: encode24BitPosition(x: 5, y: 7, z: -3),
            alphas: [255],
            colors: [128, 128, 128],
            scales: [160, 160, 160],
            rotations: [127, 127, 127],
            sh: []
        )
        let url = writeGzippedFixture(payload)
        tempFileURL = url

        let asset = try SPZReader.readGaussianAsset(from: url)
        XCTAssertEqual(asset.splats.count, 1)
        let splat = asset.splats[0]

        // RUB -> RDF: X unchanged, Y and Z negated.
        XCTAssertEqual(splat.center.x, 5.0, accuracy: 1e-5)
        XCTAssertEqual(splat.center.y, -7.0, accuracy: 1e-5)
        XCTAssertEqual(splat.center.z, 3.0, accuracy: 1e-5)
        XCTAssertEqual(splat.center.w, 1.0, accuracy: 1e-5)

        // scale byte 160 -> logScale = 160/16 - 10 = 0 -> exp(0) = 1
        XCTAssertEqual(splat.scale.x, 1.0, accuracy: 1e-4)
        XCTAssertEqual(splat.scale.y, 1.0, accuracy: 1e-4)
        XCTAssertEqual(splat.scale.z, 1.0, accuracy: 1e-4)
    }

    // MARK: - Rotation decoding

    /// Version 2 uses `packQuaternionFirstThree` (3 bytes: xyz only, w reconstructed and clamped
    /// non-negative). Byte values are chosen so x, y, z decode to exact binary fractions
    /// (153/127.5 - 1 = 0.2, 255/127.5 - 1 = 1.0, 0/127.5 - 1 = -1.0), including the clamp-to-zero
    /// path for w since y and z alone already exceed unit length.
    func test_readGaussianAsset_version2FirstThreeQuaternion_decodesExactValues() throws {
        let payload = makeLegacyPayload(
            version: 2, numPoints: 1, shDegree: 0, fractionalBits: 0,
            positions: encode24BitPosition(x: 0, y: 0, z: 0),
            alphas: [255],
            colors: [128, 128, 128],
            scales: [160, 160, 160],
            rotations: [153, 255, 0],
            sh: []
        )
        let url = writeGzippedFixture(payload)
        tempFileURL = url

        let asset = try SPZReader.readGaussianAsset(from: url)
        let splat = try XCTUnwrap(asset.splats.first)

        let x: Float = 153.0 / 127.5 - 1.0
        let y: Float = 255.0 / 127.5 - 1.0
        let z: Float = 0.0 / 127.5 - 1.0
        let w: Float = 0.0 // sqrt(max(0, 1 - (x*x+y*y+z*z))): y and z alone already exceed 1

        // Engine convention: quat.x is the real (w) part; .y/.z/.w are the imaginary x/y/z parts
        // (see UntoldGSPacking.swift's simd_quatf(ix: .y, iy: .z, iz: .w, r: .x)). flipQ negates
        // the imaginary y and z parts, not x.
        XCTAssertEqual(splat.quat.x, w, accuracy: 1e-5)
        XCTAssertEqual(splat.quat.y, x, accuracy: 1e-5)
        XCTAssertEqual(splat.quat.z, -y, accuracy: 1e-5)
        XCTAssertEqual(splat.quat.w, -z, accuracy: 1e-5)
    }

    /// Version 3 uses `packQuaternionSmallestThree` (4 bytes: 2-bit largest-component index + three
    /// signed 9-bit magnitudes). `comp = 0xC0000000` selects index 3 (w) as the reconstructed
    /// component with the other three magnitudes all zero, decoding to an exact identity
    /// quaternion -- and an identity quaternion's zero components are unaffected by the RUB->RDF
    /// sign flip, so this is a fully deterministic round-trip with no quantization tolerance needed.
    func test_readGaussianAsset_version3SmallestThreeQuaternion_decodesExactIdentity() throws {
        let payload = makeLegacyPayload(
            version: 3, numPoints: 1, shDegree: 0, fractionalBits: 0,
            positions: encode24BitPosition(x: 0, y: 0, z: 0),
            alphas: [255],
            colors: [128, 128, 128],
            scales: [160, 160, 160],
            rotations: [0x00, 0x00, 0x00, 0xC0],
            sh: []
        )
        let url = writeGzippedFixture(payload)
        tempFileURL = url

        let asset = try SPZReader.readGaussianAsset(from: url)
        let splat = try XCTUnwrap(asset.splats.first)

        XCTAssertEqual(splat.quat.x, 1.0, accuracy: 1e-6, "real part")
        XCTAssertEqual(splat.quat.y, 0.0, accuracy: 1e-6)
        XCTAssertEqual(splat.quat.z, 0.0, accuracy: 1e-6)
        XCTAssertEqual(splat.quat.w, 0.0, accuracy: 1e-6)
    }

    // MARK: - Spherical harmonics: coefficient-major -> channel-major transpose + flip

    /// SPZ stores SH bytes on disk coefficient-major/channel-minor (an R,G,B triple per
    /// coefficient); the engine's `GaussianSphericalHarmonics.coefficients` (matching PLYReader)
    /// is channel-major (all of R, then all of G, then all of B). Distinct byte values per
    /// (coefficient, channel) make a transposition bug show up as a wrong value rather than a
    /// coincidentally-matching one.
    func test_readGaussianAsset_sphericalHarmonics_transposesAndFlipsCorrectly() throws {
        let shBytes: [UInt8] = [136, 137, 138, 140, 141, 142, 144, 145, 146] // coeff-major: c0(R,G,B), c1(R,G,B), c2(R,G,B)
        let payload = makeLegacyPayload(
            version: 3, numPoints: 1, shDegree: 1, fractionalBits: 0,
            positions: encode24BitPosition(x: 0, y: 0, z: 0),
            alphas: [255],
            colors: [0, 0, 0],
            scales: [160, 160, 160],
            rotations: [0x00, 0x00, 0x00, 0xC0],
            sh: shBytes
        )
        let url = writeGzippedFixture(payload)
        tempFileURL = url

        let asset = try SPZReader.readGaussianAsset(from: url)
        let sh = try XCTUnwrap(asset.sphericalHarmonics)
        XCTAssertEqual(sh.degree, 1)
        XCTAssertEqual(sh.coefficientsPerChannel, 4) // 1 DC + 3 rest, dimForDegree(1) == 3
        XCTAssertEqual(sh.coefficients.count, 12)

        let dc: Float = (0.0 / 255.0 - 0.5) / 0.15
        func unquantize(_ byte: UInt8) -> Float {
            (Float(byte) - 128.0) / 128.0
        }
        // flipSh for indices 0, 1, 2 (RUB -> RDF, x=1,y=-1,z=-1 substituted into Niantic's table).
        let flip: [Float] = [-1, -1, 1]

        let expected: [Float] = [
            dc, unquantize(136) * flip[0], unquantize(140) * flip[1], unquantize(144) * flip[2], // R: dc, c0, c1, c2
            dc, unquantize(137) * flip[0], unquantize(141) * flip[1], unquantize(145) * flip[2], // G
            dc, unquantize(138) * flip[0], unquantize(142) * flip[1], unquantize(146) * flip[2], // B
        ]
        for (index, value) in expected.enumerated() {
            XCTAssertEqual(sh.coefficients[index], value, accuracy: 1e-6, "coefficient index \(index)")
        }
    }

    func test_readGaussianAsset_shDegreeZero_stillProducesDCOnlySphericalHarmonics() throws {
        let payload = makeLegacyPayload(
            version: 2, numPoints: 1, shDegree: 0, fractionalBits: 0,
            positions: encode24BitPosition(x: 0, y: 0, z: 0),
            alphas: [255],
            colors: [200, 100, 50],
            scales: [160, 160, 160],
            rotations: [127, 127, 127],
            sh: []
        )
        let url = writeGzippedFixture(payload)
        tempFileURL = url

        let asset = try SPZReader.readGaussianAsset(from: url)
        let sh = try XCTUnwrap(asset.sphericalHarmonics)
        XCTAssertEqual(sh.degree, 0)
        XCTAssertEqual(sh.coefficientsPerChannel, 1)
        XCTAssertEqual(sh.coefficients.count, 3)

        let C0: Float = 0.28209479177387814
        let dcR: Float = (200.0 / 255.0 - 0.5) / 0.15
        XCTAssertEqual(sh.coefficients[0], dcR, accuracy: 1e-6)
        XCTAssertEqual(asset.splats[0].color.x, dcR * C0 + 0.5, accuracy: 1e-6)
    }

    // MARK: - Negligible-opacity culling parity with PLYReader

    func test_readGaussianAsset_dropsNegligibleOpacitySplats() throws {
        let payload = makeLegacyPayload(
            version: 2, numPoints: 3, shDegree: 0, fractionalBits: 0,
            positions: encode24BitPosition(x: 0, y: 0, z: 0)
                + encode24BitPosition(x: 1, y: 0, z: 0)
                + encode24BitPosition(x: 2, y: 0, z: 0),
            alphas: [0, 128, 128], // first splat's opacity (0/255) is below the 1/255 retention threshold
            colors: [128, 128, 128, 128, 128, 128, 128, 128, 128],
            scales: [160, 160, 160, 160, 160, 160, 160, 160, 160],
            rotations: [127, 127, 127, 127, 127, 127, 127, 127, 127],
            sh: []
        )
        let url = writeGzippedFixture(payload)
        tempFileURL = url

        let asset = try SPZReader.readGaussianAsset(from: url)
        XCTAssertEqual(asset.splats.count, 2, "The negligible-opacity splat should be dropped")
        XCTAssertEqual(asset.splats[0].center.x, 1.0, accuracy: 1e-5, "Surviving splats keep their original order")
        XCTAssertEqual(asset.splats[1].center.x, 2.0, accuracy: 1e-5)
        for splat in asset.splats {
            XCTAssertGreaterThan(splat.opacity, 1.0 / 255.0)
        }
    }

    // MARK: - Format rejection

    func test_readGaussianAsset_rejectsVersion1() throws {
        try assertRejects(version: 1) { error in
            guard case SPZError.unsupportedVersion(1) = error else {
                XCTFail("Expected unsupportedVersion(1), got \(error)"); return
            }
        }
    }

    func test_readGaussianAsset_rejectsVersionAboveLegacyRange() throws {
        try assertRejects(version: 5) { error in
            guard case SPZError.unsupportedVersion(5) = error else {
                XCTFail("Expected unsupportedVersion(5), got \(error)"); return
            }
        }
    }

    func test_readGaussianAsset_rejectsRawNGSPv4Container() throws {
        // The raw (un-gzipped) NGSP magic at the start of the file signals a v4/ZSTD container --
        // a different format entirely, out of scope here even though it shares the magic number
        // with the legacy gzip payload's embedded header.
        var bytes: [UInt8] = []
        appendUInt32LE(0x5053_474E, to: &bytes)
        bytes.append(contentsOf: [UInt8](repeating: 0, count: 28)) // pad to a plausible NgspFileHeader size
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).spz")
        try Data(bytes).write(to: url)
        tempFileURL = url

        XCTAssertThrowsError(try SPZReader.readGaussianAsset(from: url)) { error in
            guard case SPZError.unsupportedVersion(4) = error else {
                XCTFail("Expected unsupportedVersion(4), got \(error)"); return
            }
        }
    }

    func test_readGaussianAsset_rejectsUnrecognizedBytes() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).spz")
        try Data([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]).write(to: url)
        tempFileURL = url

        XCTAssertThrowsError(try SPZReader.readGaussianAsset(from: url)) { error in
            guard case SPZError.invalidFormat = error else {
                XCTFail("Expected invalidFormat, got \(error)"); return
            }
        }
    }

    func test_readGaussianAsset_rejectsSHDegreeAboveThree() throws {
        try assertRejects(version: 2, shDegree: 4) { error in
            guard case SPZError.unsupportedSHDegree(4) = error else {
                XCTFail("Expected unsupportedSHDegree(4), got \(error)"); return
            }
        }
    }

    func test_readGaussianAsset_rejectsTruncatedStream() throws {
        // numPoints = 2, but the positions stream is one byte short of the 18 the header's point
        // count requires, and nothing follows it -- the bounds check on the very first stream
        // read is guaranteed to be what fails, regardless of any later stream's size.
        let twoPointPositions = encode24BitPosition(x: 0, y: 0, z: 0) + encode24BitPosition(x: 1, y: 0, z: 0)
        let payload = makeLegacyPayload(
            version: 2, numPoints: 2, shDegree: 0, fractionalBits: 0,
            positions: Array(twoPointPositions.dropLast()),
            alphas: [], colors: [], scales: [], rotations: [], sh: []
        )
        let url = writeGzippedFixture(payload)
        tempFileURL = url

        XCTAssertThrowsError(try SPZReader.readGaussianAsset(from: url)) { error in
            guard case let SPZError.invalidData(message) = error else {
                XCTFail("Expected invalidData, got \(error)"); return
            }
            XCTAssertTrue(message.contains("positions"), "Should name the truncated stream")
        }
    }

    // MARK: - External diagnostic (opt-in)

    func test_externalGaussianDiagnosticAsset() throws {
        guard let path = ProcessInfo.processInfo.environment["UNTOLD_GAUSSIAN_DIAGNOSTIC_SPZ"] else {
            throw XCTSkip("Set UNTOLD_GAUSSIAN_DIAGNOSTIC_SPZ to audit a production .spz capture")
        }
        let asset = try SPZReader.readGaussianAsset(from: URL(fileURLWithPath: path))
        XCTAssertGreaterThan(asset.splats.count, 0)
        print("SPZ diagnostic: splats=\(asset.splats.count), degree=\(asset.sphericalHarmonics?.degree ?? -1), "
            + "coefficients=\(asset.sphericalHarmonics?.coefficients.count ?? 0)")
    }

    // MARK: - Fixture helpers

    private func assertRejects(
        version: UInt32,
        shDegree: Int = 0,
        _ verify: (Error) -> Void
    ) throws {
        let payload = makeLegacyPayload(
            version: version, numPoints: 1, shDegree: shDegree, fractionalBits: 0,
            positions: [], alphas: [], colors: [], scales: [], rotations: [], sh: []
        )
        let url = writeGzippedFixture(payload)
        tempFileURL = url
        XCTAssertThrowsError(try SPZReader.readGaussianAsset(from: url), "", verify)
    }

    /// A single 24-bit little-endian two's-complement fixed-point axis value, times three (x, y, z).
    private func encode24BitPosition(x: Int32, y: Int32, z: Int32) -> [UInt8] {
        [x, y, z].flatMap { value -> [UInt8] in
            let unsigned = UInt32(bitPattern: value) & 0x00FF_FFFF
            return [UInt8(unsigned & 0xFF), UInt8((unsigned >> 8) & 0xFF), UInt8((unsigned >> 16) & 0xFF)]
        }
    }

    private func appendUInt32LE(_ value: UInt32, to bytes: inout [UInt8]) {
        bytes.append(UInt8(value & 0xFF))
        bytes.append(UInt8((value >> 8) & 0xFF))
        bytes.append(UInt8((value >> 16) & 0xFF))
        bytes.append(UInt8((value >> 24) & 0xFF))
    }

    /// The 16-byte legacy header (magic, version, numPoints, shDegree, fractionalBits, flags,
    /// reserved) followed by the six streams in the exact order `serializePackedGaussians` writes
    /// them: positions, alphas, colors, scales, rotations, sh.
    private func makeLegacyPayload(
        version: UInt32,
        numPoints: Int,
        shDegree: Int,
        fractionalBits: UInt8,
        positions: [UInt8],
        alphas: [UInt8],
        colors: [UInt8],
        scales: [UInt8],
        rotations: [UInt8],
        sh: [UInt8],
        flags: UInt8 = 0
    ) -> [UInt8] {
        var bytes: [UInt8] = []
        appendUInt32LE(0x5053_474E, to: &bytes) // "NGSP"
        appendUInt32LE(version, to: &bytes)
        appendUInt32LE(UInt32(numPoints), to: &bytes)
        bytes.append(UInt8(shDegree))
        bytes.append(fractionalBits)
        bytes.append(flags)
        bytes.append(0) // reserved
        bytes.append(contentsOf: positions)
        bytes.append(contentsOf: alphas)
        bytes.append(contentsOf: colors)
        bytes.append(contentsOf: scales)
        bytes.append(contentsOf: rotations)
        bytes.append(contentsOf: sh)
        return bytes
    }

    /// Compresses `payload` with raw DEFLATE via `compression_encode_buffer` (mirroring
    /// `SPZReader`'s own use of `compression_decode_buffer`) and wraps it in a real minimal gzip
    /// envelope (10-byte header, no optional fields; 8-byte trailer with a zeroed CRC32 -- the
    /// reader never validates it -- and the true ISIZE), then writes it to a temp file.
    private func writeGzippedFixture(_ payload: [UInt8]) -> URL {
        let deflated = rawDeflate(payload)
        var bytes: [UInt8] = [0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF]
        bytes.append(contentsOf: deflated)
        bytes.append(contentsOf: [0, 0, 0, 0]) // CRC32, unchecked by SPZReader
        appendUInt32LE(UInt32(payload.count), to: &bytes) // ISIZE: the *last* 4 bytes of the file
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).spz")
        try? Data(bytes).write(to: url)
        return url
    }

    private func rawDeflate(_ data: [UInt8]) -> [UInt8] {
        guard !data.isEmpty else { return [] }
        let destinationCapacity = data.count * 2 + 128
        var destination = [UInt8](repeating: 0, count: destinationCapacity)
        let written = destination.withUnsafeMutableBytes { destBuffer -> Int in
            data.withUnsafeBytes { sourceBuffer -> Int in
                compression_encode_buffer(
                    destBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    destinationCapacity,
                    sourceBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        precondition(written > 0, "compression_encode_buffer failed to compress the fixture payload")
        return Array(destination.prefix(written))
    }
}

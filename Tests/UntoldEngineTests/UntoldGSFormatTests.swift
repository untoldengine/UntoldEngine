//
//  UntoldGSFormatTests.swift
//  UntoldEngineTests
//
//  Tests for the version-3 .untoldgs Gaussian splat container: record sizes,
//  quantisation error bounds, Morton ordering, CRC, write → range-read → decode
//  roundtrips, and the whole-asset read the runtime uses.
//
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

final class UntoldGSFormatTests: XCTestCase {
    private var temporaryFiles: [URL] = []

    override func tearDown() {
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        super.tearDown()
    }

    // MARK: - Record sizes

    func testHeaderEncodesTwoHundredFiftySixBytes() throws {
        let header = makeHeader()
        let writer = UntoldBinaryWriter()
        header.encode(to: writer)
        XCTAssertEqual(writer.count, UntoldGSFormat.headerSize)
        XCTAssertEqual(Array(writer.data.prefix(4)), UntoldGSFormat.magicBytes)
        XCTAssertEqual(try UntoldGSHeaderV3.decode(from: UntoldBinaryReader(data: writer.data)), header)
    }

    func testChunkEntryEncodesSixtyFourBytes() throws {
        let entry = UntoldGSChunkEntry(
            payloadOffset: 65536, payloadBytes: 16384, coreBytes: 16 * 100, splatCount: 100,
            lodLevel: 2, nodeId: 7, aabbMin: [-1, -2, -3], aabbMax: [1, 2, 3],
            logScaleMin: -5, logScaleMax: -1, crc32: 0xDEAD_BEEF
        )
        let writer = UntoldBinaryWriter()
        entry.encode(to: writer)
        XCTAssertEqual(writer.count, UntoldGSFormat.chunkEntrySize)
        XCTAssertEqual(try UntoldGSChunkEntry.decode(from: UntoldBinaryReader(data: writer.data)), entry)
    }

    func testTreeNodeEncodesFortyEightBytes() throws {
        let node = UntoldGSTreeNode(aabbMin: [0, 0, 0], aabbMax: [1, 1, 1], child0: 1, child1: 2, firstChunk: 0, chunkCount: 9, geometricError: 0.5)
        let writer = UntoldBinaryWriter()
        node.encode(to: writer)
        XCTAssertEqual(writer.count, UntoldGSFormat.treeNodeSize)
        XCTAssertEqual(try UntoldGSTreeNode.decode(from: UntoldBinaryReader(data: writer.data)), node)
    }

    func testSHCoefficientCountsMatchTheGPUContract() {
        XCTAssertEqual(UntoldGSFormat.shCoefficientCount(degree: 0), 0)
        XCTAssertEqual(UntoldGSFormat.shCoefficientCount(degree: 1), 9)
        XCTAssertEqual(UntoldGSFormat.shCoefficientCount(degree: 2), 24)
        XCTAssertEqual(UntoldGSFormat.shCoefficientCount(degree: 3), 45)
        var header = makeHeader()
        header.flags = UntoldGSFlags.hasSphericalHarmonics
        header.shDegree = 2
        XCTAssertEqual(header.shMetadata?.coefficientsPerChannel, 9)
        XCTAssertEqual(header.shMetadata?.higherOrderCoefficientsPerSplat, 24)
        header.flags = 0
        XCTAssertNil(header.shMetadata)
    }

    // MARK: - Packing

    func testPositionPackingErrorIsWithinHalfAStep() {
        var rng = SplitMix64(seed: 1)
        for _ in 0 ..< 2000 {
            let t = SIMD3<Float>(rng.nextUnitFloat(), rng.nextUnitFloat(), rng.nextUnitFloat())
            let back = UntoldGSPacking.unpack11_10_11(UntoldGSPacking.pack11_10_11(t))
            XCTAssertLessThanOrEqual(abs(back.x - t.x), 0.5 / 2047 + 1e-6)
            XCTAssertLessThanOrEqual(abs(back.y - t.y), 0.5 / 1023 + 1e-6)
            XCTAssertLessThanOrEqual(abs(back.z - t.z), 0.5 / 2047 + 1e-6)
        }
        XCTAssertEqual(UntoldGSPacking.pack11_10_11([0, 0, 0]), 0)
        XCTAssertEqual(UntoldGSPacking.pack11_10_11([1, 1, 1]), 0xFFFF_FFFF)
    }

    func testRotationPackingPreservesOrientation() {
        var rng = SplitMix64(seed: 2)
        for _ in 0 ..< 2000 {
            let q = rng.nextUnitQuaternion()
            let back = UntoldGSPacking.unpackRotation(UntoldGSPacking.packRotation(q))
            let relative = q.inverse * back
            let angle = 2 * acos(min(1, abs(relative.real)))
            XCTAssertLessThan(angle, 0.005, "orientation error \(angle) rad for \(q)")
            XCTAssertEqual(simd_length(back.vector), 1, accuracy: 1e-3)
        }
        for q in [simd_quatf(vector: [1, 0, 0, 0]), simd_quatf(vector: [0, 1, 0, 0]), simd_quatf(vector: [0, 0, 1, 0]), simd_quatf(vector: [0, 0, 0, -1])] {
            let back = UntoldGSPacking.unpackRotation(UntoldGSPacking.packRotation(q))
            XCTAssertEqual(abs((q.inverse * back).real), 1, accuracy: 1e-3)
        }
    }

    func testColorPackingRoundtrip() {
        let packed = UntoldGSPacking.packRGBA(color: [1, 0.5, 0], opacity: 0.25)
        XCTAssertEqual(packed >> 24, 255)
        XCTAssertEqual((packed >> 16) & 0xFF, 128)
        XCTAssertEqual((packed >> 8) & 0xFF, 0)
        XCTAssertEqual(packed & 0xFF, 64)
        let back = UntoldGSPacking.unpackRGBA(packed)
        XCTAssertEqual(back.color.y, 128 / 255, accuracy: 1e-6)
        XCTAssertEqual(back.opacity, 64 / 255, accuracy: 1e-6)
    }

    func testSHPackingUsesTheRendererByteContract() {
        // Same byte the runtime PLY path writes, dequantised the way Gaussians.metal does.
        XCTAssertEqual(UntoldGSPacking.packSHCoefficient(0.5), quantizeGaussianSHCoefficient(0.5))
        XCTAssertEqual(UntoldGSPacking.unpackSHCoefficient(128), 0)
        XCTAssertEqual(UntoldGSPacking.unpackSHCoefficient(255), 127 / 128)
        XCTAssertEqual(UntoldGSPacking.packSHCoefficient(3), 255) // clamped
    }

    func testMortonSpreadAndOrdering() {
        XCTAssertEqual(UntoldGSPacking.spread21(0b111), 0b1001001)
        XCTAssertEqual(UntoldGSPacking.spread21(0x1FFFFF), 0x1249_2492_4924_9249)

        let boundsMin = SIMD3<Float>(repeating: -1)
        let boundsMax = SIMD3<Float>(repeating: 1)
        var rng = SplitMix64(seed: 3)
        let splats = (0 ..< 500).map { _ in rng.nextSplat(boundsMin: boundsMin, boundsMax: boundsMax, shCount: 0) }
        let order = UntoldGSFormat.mortonOrder(splats, boundsMin: boundsMin, boundsMax: boundsMax)
        XCTAssertEqual(Set(order).count, splats.count)
        let keys = order.map { UntoldGSPacking.mortonKey(splats[$0].position, boundsMin: boundsMin, boundsMax: boundsMax) }
        for index in 1 ..< keys.count {
            XCTAssertLessThanOrEqual(keys[index - 1], keys[index])
        }
    }

    func testCRC32KnownVector() {
        XCTAssertEqual(UntoldGSCRC32.checksum(Data("123456789".utf8)), 0xCBF4_3926)
        XCTAssertEqual(UntoldGSCRC32.checksum(Data()), 0)
    }

    func testImporterConversionAndEncodedLayout() {
        // PLY order (w, x, y, z): a 90° rotation about Y.
        let half = Float(0.5).squareRoot()
        let source = GaussianSplat(center: [1, 2, 3, 1], scale: [0.1, 0.2, 0.3, 1], color: [0.5, 0.6, 0.7, 0.9], quat: [half, 0, half, 0], opacity: 0.9)
        let splat = UntoldGSSplat(source, sphericalHarmonics: [1, 2, 3])
        XCTAssertEqual(splat.position, [1, 2, 3])
        XCTAssertEqual(splat.scale, [0.1, 0.2, 0.3])
        XCTAssertEqual(splat.color, [0.5, 0.6, 0.7])
        XCTAssertEqual(splat.opacity, 0.9)
        XCTAssertEqual(splat.sphericalHarmonics, [1, 2, 3])
        let rotated = splat.rotation.act(SIMD3<Float>(1, 0, 0))
        XCTAssertEqual(rotated.z, -1, accuracy: 1e-5)

        let encoded = splat.encodedForTBDR()
        XCTAssertEqual(encoded.position, [1, 2, 3])
        XCTAssertEqual(Float(encoded.colorAndOpacity.w), 0.9, accuracy: 1e-3)
        // Covariance of an axis-aligned splat yawed by 90°: x and z variances swap.
        XCTAssertEqual(Float(encoded.covA.x), 0.09, accuracy: 2e-3)
        XCTAssertEqual(Float(encoded.covB.z), 0.01, accuracy: 2e-3)
        XCTAssertEqual(Float(encoded.covB.x), 0.04, accuracy: 2e-3)
    }

    // MARK: - Write / read roundtrip

    func testWriteAndRangeReadRoundtrip() throws {
        let boundsMin = SIMD3<Float>(-0.8, 0, -0.4)
        let boundsMax = SIMD3<Float>(0.8, 0.9, 0.4)
        var rng = SplitMix64(seed: 4)
        let splats = (0 ..< 5000).map { _ in rng.nextSplat(boundsMin: boundsMin, boundsMax: boundsMax, shCount: 0) }

        var options = UntoldGSWriteOptions()
        options.log2ChunkSplats = 8 // 256 per chunk → 20 chunks
        options.sortByImportanceWithinChunk = false
        options.leafMaxChunks = 4
        options.meanSquaredSplatExtent = 0.0123
        let fileData = try UntoldGSFormat.write(splats: splats, options: options)
        let file = try UntoldGSFile(url: writeTemporaryFile(fileData))
        let header = file.header
        XCTAssertEqual(header.version, 3)
        XCTAssertEqual(header.splatCount, 5000)
        XCTAssertEqual(header.chunkCount, 20)
        XCTAssertEqual(header.lodLevels, 1)
        XCTAssertEqual(header.fileSize, UInt64(fileData.count))
        XCTAssertEqual(header.meanSquaredSplatExtent, 0.0123)
        XCTAssertFalse(header.hasSphericalHarmonics)
        // Default bounding box: centre bounds expanded by the largest scale.
        XCTAssertLessThan(header.boundingBoxMin.x, header.boundsMin.x)
        XCTAssertGreaterThan(header.boundingBoxMax.y, header.boundsMax.y)

        let page = UInt64(UntoldGSFormat.pageAlignment)
        XCTAssertEqual(header.chunkIndexOffset % page, 0)
        XCTAssertEqual(header.nodeTreeOffset % page, 0)
        XCTAssertEqual(header.payloadOffset % page, 0)
        XCTAssertEqual(header.fileSize % page, 0)
        for chunk in file.index.chunks {
            XCTAssertEqual(chunk.payloadOffset % page, 0)
            XCTAssertEqual(UInt64(chunk.payloadBytes) % page, 0)
            XCTAssertEqual(chunk.coreBytes, chunk.splatCount * 16)
        }

        let order = UntoldGSFormat.mortonOrder(splats, boundsMin: header.boundsMin, boundsMax: header.boundsMax)
        let decoded = try file.decodeAll()
        XCTAssertEqual(decoded.count, splats.count)

        var cursor = 0
        for chunk in file.index.chunks {
            let extent = chunk.aabbMax - chunk.aabbMin
            for _ in 0 ..< Int(chunk.splatCount) {
                let original = splats[order[cursor]]
                let back = decoded[cursor]
                cursor += 1
                XCTAssertLessThanOrEqual(abs(back.position.x - original.position.x), extent.x * 0.5 / 2047 + 1e-5)
                XCTAssertLessThanOrEqual(abs(back.position.y - original.position.y), extent.y * 0.5 / 1023 + 1e-5)
                XCTAssertLessThanOrEqual(abs(back.position.z - original.position.z), extent.z * 0.5 / 2047 + 1e-5)
                for axis in 0 ..< 3 {
                    let step = (chunk.logScaleMax - chunk.logScaleMin) / (axis == 1 ? 1023 : 2047)
                    XCTAssertLessThanOrEqual(abs(log(back.scale[axis]) - log(original.scale[axis])), step * 0.5 + 1e-4)
                }
                XCTAssertEqual(back.opacity, original.opacity, accuracy: 0.5 / 255 + 1e-5)
                XCTAssertEqual(back.color.x, original.color.x, accuracy: 0.5 / 255 + 1e-5)
                XCTAssertLessThan(2 * acos(min(1, abs((original.rotation.inverse * back.rotation).real))), 0.005)
            }
        }
        XCTAssertEqual(cursor, splats.count)
    }

    func testSphericalHarmonicsBlockRoundtrip() throws {
        var rng = SplitMix64(seed: 5)
        let shCount = UntoldGSFormat.shCoefficientCount(degree: 1)
        let splats = (0 ..< 1200).map { _ in rng.nextSplat(boundsMin: [-2, -2, -2], boundsMax: [2, 2, 2], shCount: shCount) }

        var options = UntoldGSWriteOptions()
        options.shDegree = 1
        options.log2ChunkSplats = 9
        options.sortByImportanceWithinChunk = false
        let file = try UntoldGSFile(url: writeTemporaryFile(UntoldGSFormat.write(splats: splats, options: options)))
        XCTAssertTrue(file.header.hasSphericalHarmonics)
        XCTAssertEqual(file.header.shBytesPerSplat, 9)
        XCTAssertEqual(file.index.chunks.count, 3)

        let order = UntoldGSFormat.mortonOrder(splats, boundsMin: file.header.boundsMin, boundsMax: file.header.boundsMax)
        let decoded = try file.decodeAll()
        for (cursor, back) in decoded.enumerated() {
            let original = splats[order[cursor]].sphericalHarmonics
            XCTAssertEqual(back.sphericalHarmonics.count, shCount)
            for (a, b) in zip(original, back.sphericalHarmonics) {
                // The renderer's contract truncates at ×127 and dequantises at ÷128 (see
                // quantizeGaussianSHCoefficient), so the worst case is one step of each.
                XCTAssertLessThanOrEqual(abs(a - b), 1.0 / 127 + 1.0 / 128 + 1e-4)
            }
        }
    }

    func testReadProducesTheRuntimeLayout() throws {
        var rng = SplitMix64(seed: 6)
        let shCount = UntoldGSFormat.shCoefficientCount(degree: 2)
        let splats = (0 ..< 700).map { _ in rng.nextSplat(boundsMin: [0, 0, 0], boundsMax: [1, 1, 1], shCount: shCount) }
        var options = UntoldGSWriteOptions()
        options.shDegree = 2
        options.log2ChunkSplats = 8
        options.boundingBoxMin = [-9, -9, -9]
        options.boundingBoxMax = [9, 9, 9]
        options.meanSquaredSplatExtent = 0.5
        let url = try writeTemporaryFile(UntoldGSFormat.write(splats: splats, options: options))

        let asset = try UntoldGSFormat.read(from: url)
        XCTAssertEqual(asset.splatCount, 700)
        XCTAssertEqual(asset.shCoefficients.count, 700 * 24)
        XCTAssertEqual(asset.shMetadata?.degree, 2)
        XCTAssertEqual(asset.shMetadata?.coefficientsPerChannel, 9)
        XCTAssertEqual(asset.shMetadata?.higherOrderCoefficientsPerSplat, 24)
        XCTAssertEqual(asset.meanSquaredSplatExtent, 0.5)
        XCTAssertEqual(asset.boundingBoxMin, [-9, -9, -9])
        XCTAssertEqual(asset.boundingBoxMax, [9, 9, 9])

        let header = try UntoldGSFormat.readHeader(from: url)
        XCTAssertEqual(header.boundingBoxMin, [-9, -9, -9])
        XCTAssertEqual(header.boundingBoxMax, [9, 9, 9])

        // Encoded splats correspond to the decoded ones: same positions, SH bytes byte-identical.
        let file = try UntoldGSFile(url: url)
        let decoded = try file.decodeAll()
        for (encoded, splat) in zip(asset.encodedSplats, decoded) {
            XCTAssertEqual(encoded.position, splat.position)
        }
        let firstChunkPayload = try file.chunkPayload(at: 0)
        let firstChunk = file.index.chunks[0]
        let shStart = Int(firstChunk.coreBytes)
        XCTAssertEqual(Array(firstChunkPayload[shStart ..< shStart + 24]), Array(asset.shCoefficients.prefix(24)))
    }

    func testWriterRejectsBadInput() {
        var rng = SplitMix64(seed: 7)
        var splats = (0 ..< 10).map { _ in rng.nextSplat(boundsMin: [0, 0, 0], boundsMax: [1, 1, 1], shCount: 9) }
        splats[3].sphericalHarmonics = []
        var options = UntoldGSWriteOptions()
        options.shDegree = 1
        XCTAssertThrowsError(try UntoldGSFormat.write(splats: splats, options: options)) { error in
            guard case UntoldGSError.invalidInput? = error as? UntoldGSError else {
                return XCTFail("unexpected error \(error)")
            }
        }
        XCTAssertThrowsError(try UntoldGSFormat.write(splats: [])) { error in
            guard case UntoldGSError.invalidInput? = error as? UntoldGSError else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    /// A NaN or infinite value in one splat — a scale that overflowed through exp() on import, a
    /// NaN colour — must fail the bake with an error, not trap inside an integer conversion.
    func testWriterRejectsNonFiniteSplatsInsteadOfTrapping() {
        var rng = SplitMix64(seed: 11)
        let base = (0 ..< 8).map { _ in rng.nextSplat(boundsMin: [0, 0, 0], boundsMax: [1, 1, 1], shCount: 0) }

        var nanPosition = base
        nanPosition[2].position.y = .nan
        var infiniteScale = base
        infiniteScale[5].scale.x = .infinity
        var zeroScale = base
        zeroScale[1].scale.z = 0
        var nanOpacity = base
        nanOpacity[0].opacity = .nan
        var nanRotation = base
        nanRotation[4].rotation = simd_quatf(ix: .nan, iy: 0, iz: 0, r: 1)
        var nanColor = base
        nanColor[7].color.z = .nan

        for (name, splats) in [("position", nanPosition), ("scale", infiniteScale), ("zero scale", zeroScale), ("opacity", nanOpacity), ("rotation", nanRotation), ("colour", nanColor)] {
            XCTAssertThrowsError(try UntoldGSFormat.write(splats: splats), name) { error in
                guard case UntoldGSError.invalidInput? = error as? UntoldGSError else {
                    return XCTFail("\(name): unexpected error \(error)")
                }
            }
        }
        XCTAssertNoThrow(try UntoldGSFormat.write(splats: base), "The same set without the bad value writes")
    }

    func testNonFiniteValuesClampAndQuantiseInsteadOfTrapping() {
        XCTAssertEqual(UntoldGSPacking.clamp01(.nan), 0)
        XCTAssertEqual(UntoldGSPacking.clamp01(.infinity), 1)
        XCTAssertEqual(UntoldGSPacking.clamp01(-.infinity), 0)
        XCTAssertEqual(quantizeGaussianSHCoefficient(.nan), 128, "NaN quantises to zero (byte 128)")
        XCTAssertEqual(quantizeGaussianSHCoefficient(.infinity), 128)
        XCTAssertEqual(quantizeGaussianSHCoefficient(1), 255)
        XCTAssertEqual(quantizeGaussianSHCoefficient(-1), 1)
        XCTAssertEqual(UntoldGSPacking.packSHCoefficient(.nan), 128)
    }

    func testHeaderSectionsMustNotOverlap() {
        var header = makeHeader()
        XCTAssertNoThrow(try UntoldGSFormat.validate(header: header), "Sanity: the fixture header is valid")

        header.nodeTreeOffset = header.chunkIndexOffset
        XCTAssertThrowsError(try UntoldGSFormat.validate(header: header)) { error in
            guard case UntoldGSError.sizeMismatch? = error as? UntoldGSError else {
                return XCTFail("unexpected error \(error)")
            }
        }

        header = makeHeader()
        header.payloadOffset = header.nodeTreeOffset
        XCTAssertThrowsError(try UntoldGSFormat.validate(header: header), "The payload may not start inside the node tree")

        header = makeHeader()
        header.chunkIndexOffset = 0
        XCTAssertThrowsError(try UntoldGSFormat.validate(header: header), "The chunk index may not sit on the header")
    }

    /// Load-time cost of the v3 decode at a realistic splat count. v2 was one memcpy; v3 verifies
    /// a CRC per chunk and rebuilds each splat (bit-unpack, quaternion normalise, covariance),
    /// so the guard is relative to the cost of building the same GPU records straight from
    /// memory (`encodedForTBDR`, what the raw `.ply` path pays): a regression that makes the
    /// decode an order of magnitude heavier fails here on any machine, and the absolute ceiling
    /// catches a pathological one. Timings are printed for the record.
    func testHalfAMillionSplatsDecodeWithinABoundedMultipleOfTheInMemoryEncode() throws {
        var rng = SplitMix64(seed: 21)
        let count = 500_000
        let splats = (0 ..< count).map { _ in rng.nextSplat(boundsMin: [-5, -5, -5], boundsMax: [5, 5, 5], shCount: 9) }
        var options = UntoldGSWriteOptions()
        options.shDegree = 1

        let encodeStart = Date()
        let direct = splats.map { $0.encodedForTBDR() }
        let encodeSeconds = max(Date().timeIntervalSince(encodeStart), 1e-3)
        XCTAssertEqual(direct.count, count)

        let writeStart = Date()
        let data = try UntoldGSFormat.write(splats: splats, options: options)
        let writeSeconds = Date().timeIntervalSince(writeStart)
        let url = try writeTemporaryFile(data)

        let readStart = Date()
        let asset = try UntoldGSFormat.read(from: url)
        let readSeconds = Date().timeIntervalSince(readStart)

        XCTAssertEqual(asset.encodedSplats.count, count)
        print("[perf] \(count) splats: in-memory encode \(String(format: "%.3f", encodeSeconds)) s, v3 write \(String(format: "%.3f", writeSeconds)) s (\(data.count / 1024) KB), v3 read+decode \(String(format: "%.3f", readSeconds)) s")
        XCTAssertLessThan(readSeconds, 12 * encodeSeconds + 0.5, "v3 read+decode should stay within a small multiple of the in-memory encode")
        XCTAssertLessThan(readSeconds, 10, "Reading half a million splats should take well under ten seconds")
    }

    /// The importer path and the writer expand the bounding box by the same rule, through the
    /// one shared helper.
    func testImporterAndWriterBoundingBoxesAgree() {
        var rng = SplitMix64(seed: 5)
        let splats = (0 ..< 64).map { _ in rng.nextSplat(boundsMin: [-2, -1, 0], boundsMax: [3, 4, 5], shCount: 0) }
        let importerSplats = splats.map { splat in
            GaussianSplat(
                center: simd_float4(splat.position.x, splat.position.y, splat.position.z, 1),
                scale: simd_float4(splat.scale.x, splat.scale.y, splat.scale.z, 0),
                color: simd_float4(splat.color.x, splat.color.y, splat.color.z, 1),
                quat: simd_float4(splat.rotation.real, splat.rotation.imag.x, splat.rotation.imag.y, splat.rotation.imag.z),
                opacity: splat.opacity
            )
        }
        let writerBox = UntoldGSFormat.defaultBoundingBox(of: splats)
        let importerBox = computeGaussianSplatBoundingBox(importerSplats)
        XCTAssertEqual(writerBox.min, importerBox.min)
        XCTAssertEqual(writerBox.max, importerBox.max)
    }

    func testImportanceOrderKeepsOpaqueLargeSplatsFirst() throws {
        var rng = SplitMix64(seed: 8)
        let splats = (0 ..< 300).map { _ in rng.nextSplat(boundsMin: [0, 0, 0], boundsMax: [1, 1, 1], shCount: 0) }
        var options = UntoldGSWriteOptions()
        options.log2ChunkSplats = 9 // one chunk
        let file = try UntoldGSFile(url: writeTemporaryFile(UntoldGSFormat.write(splats: splats, options: options)))
        XCTAssertEqual(file.index.chunks.count, 1)
        let decoded = try file.decodeChunk(at: 0)
        let importance = decoded.map { $0.opacity * ($0.scale.x * $0.scale.y + $0.scale.y * $0.scale.z + $0.scale.z * $0.scale.x) }
        XCTAssertGreaterThan(importance.first ?? 0, importance.last ?? 1)
        XCTAssertGreaterThan(importance.prefix(30).reduce(0, +), importance.suffix(30).reduce(0, +))
    }

    // MARK: - Tree

    func testTreeCoversEveryChunkExactlyOnce() throws {
        var rng = SplitMix64(seed: 9)
        let splats = (0 ..< 4000).map { _ in rng.nextSplat(boundsMin: [-3, -1, -3], boundsMax: [3, 1, 3], shCount: 0) }
        var options = UntoldGSWriteOptions()
        options.log2ChunkSplats = 7 // 128 per chunk → 32 chunks
        options.leafMaxChunks = 3
        let index = try UntoldGSFile(url: writeTemporaryFile(UntoldGSFormat.write(splats: splats, options: options))).index

        let root = index.nodes[0]
        XCTAssertEqual(root.firstChunk, 0)
        XCTAssertEqual(root.chunkCount, UInt32(index.chunks.count))
        XCTAssertEqual(root.aabbMin, index.header.boundsMin)
        XCTAssertEqual(root.aabbMax, index.header.boundsMax)

        var coverage = [Int](repeating: 0, count: index.chunks.count)
        for (nodeIndex, node) in index.nodes.enumerated() {
            for child in [node.child0, node.child1] where child != UntoldGSFormat.invalidNode {
                let childNode = index.nodes[Int(child)]
                XCTAssertGreaterThanOrEqual(childNode.firstChunk, node.firstChunk)
                XCTAssertLessThanOrEqual(childNode.firstChunk + childNode.chunkCount, node.firstChunk + node.chunkCount)
            }
            guard node.isLeaf else { continue }
            XCTAssertLessThanOrEqual(Int(node.chunkCount), options.leafMaxChunks)
            for chunkIndex in Int(node.firstChunk) ..< Int(node.firstChunk + node.chunkCount) {
                coverage[chunkIndex] += 1
                XCTAssertEqual(Int(index.chunks[chunkIndex].nodeId), nodeIndex)
            }
        }
        XCTAssertEqual(coverage, [Int](repeating: 1, count: index.chunks.count))
    }

    // MARK: - Validation

    func testIndexParsesFromPrefixOnly() throws {
        var rng = SplitMix64(seed: 10)
        let splats = (0 ..< 700).map { _ in rng.nextSplat(boundsMin: [0, 0, 0], boundsMax: [1, 1, 1], shCount: 0) }
        var options = UntoldGSWriteOptions()
        options.log2ChunkSplats = 8
        let fileData = try UntoldGSFormat.write(splats: splats, options: options)
        let header = try UntoldGSFormat.readHeaderV3(from: fileData.prefix(UntoldGSFormat.headerSize))
        let prefix = fileData.prefix(UntoldGSIndex.prefixSize(header: header))
        XCTAssertLessThan(prefix.count, fileData.count)

        let index = try UntoldGSFormat.readIndex(from: prefix)
        XCTAssertEqual(index.chunks.count, 3)
        XCTAssertEqual(index, try UntoldGSFormat.readIndex(from: fileData))
        XCTAssertThrowsError(try UntoldGSFormat.readIndex(from: fileData.prefix(prefix.count - 1)))
    }

    func testCorruptedChunkFailsCRC() throws {
        var rng = SplitMix64(seed: 11)
        let splats = (0 ..< 600).map { _ in rng.nextSplat(boundsMin: [0, 0, 0], boundsMax: [1, 1, 1], shCount: 0) }
        var options = UntoldGSWriteOptions()
        options.log2ChunkSplats = 8
        var fileData = try UntoldGSFormat.write(splats: splats, options: options)
        let index = try UntoldGSFormat.readIndex(from: fileData)
        fileData[Int(index.chunks[1].payloadOffset) + 5] ^= 0xFF

        let file = try UntoldGSFile(url: writeTemporaryFile(fileData))
        XCTAssertNoThrow(try file.chunkPayload(at: 0))
        XCTAssertThrowsError(try file.chunkPayload(at: 1)) { error in
            guard case UntoldGSError.corrupt? = error as? UntoldGSError else {
                return XCTFail("unexpected error \(error)")
            }
        }
        XCTAssertNoThrow(try file.chunkPayload(at: 1, verify: false))
        XCTAssertThrowsError(try UntoldGSFormat.read(from: file.url))
    }

    func testRejectsInvalidMagicOlderVersionsAndTruncation() throws {
        var rng = SplitMix64(seed: 12)
        let splats = (0 ..< 50).map { _ in rng.nextSplat(boundsMin: [0, 0, 0], boundsMax: [1, 1, 1], shCount: 0) }
        let fileData = try UntoldGSFormat.write(splats: splats)

        var badMagic = fileData
        badMagic[0] = 0x58
        XCTAssertEqual(try thrownError(UntoldGSFormat.readHeaderV3(from: badMagic)), .badMagic)

        var version2 = fileData
        version2[4] = 2
        XCTAssertEqual(try thrownError(UntoldGSFormat.readHeaderV3(from: version2)), .unsupportedVersion(2))
        XCTAssertEqual(try thrownError(UntoldGSFormat.read(from: writeTemporaryFile(version2))), .unsupportedVersion(2))

        XCTAssertEqual(try thrownError(UntoldGSFormat.readHeaderV3(from: fileData.prefix(6))), .truncated)
        XCTAssertEqual(try thrownError(UntoldGSFormat.readHeaderV3(from: fileData.prefix(100))), .truncated)

        let truncated = Data(fileData.prefix(fileData.count - UntoldGSFormat.pageAlignment))
        guard case .sizeMismatch? = try thrownError(UntoldGSFile(url: writeTemporaryFile(truncated))) else {
            return XCTFail("expected sizeMismatch for a truncated file")
        }
    }

    func testOverflowingHeaderCountsThrowInsteadOfTrapping() throws {
        var header = makeHeader()
        header.chunkCount = UInt32.max
        header.nodeCount = UInt32.max
        let writer = UntoldBinaryWriter()
        header.encode(to: writer)
        guard case .sizeMismatch? = try thrownError(UntoldGSFormat.readHeaderV3(from: writer.data)) else {
            return XCTFail("expected sizeMismatch")
        }
    }

    // MARK: - Helpers

    private func thrownError(_ body: @autoclosure () throws -> some Any) -> UntoldGSError? {
        do {
            _ = try body()
            return nil
        } catch {
            return error as? UntoldGSError
        }
    }

    private func makeHeader() -> UntoldGSHeaderV3 {
        UntoldGSHeaderV3(
            flags: UntoldGSFlags.antialiased,
            shDegree: 0,
            log2ChunkSplats: 10,
            splatCount: 123_456,
            chunkCount: 121,
            nodeCount: 31,
            lodLevels: 1,
            boundsMin: [-1, -2, -3],
            boundsMax: [4, 5, 6],
            boundingBoxMin: [-1.5, -2.5, -3.5],
            boundingBoxMax: [4.5, 5.5, 6.5],
            meanSquaredSplatExtent: 0.02,
            captureExposureEV: -1.5,
            captureWhiteBalance: [1.1, 1.0, 0.9],
            splatToMesh: simd_float4x4(diagonal: [2, 2, 2, 1]),
            chunkIndexOffset: 16384,
            nodeTreeOffset: 32768,
            paletteOffset: 0,
            payloadOffset: 49152,
            fileSize: 1_048_576
        )
    }

    private func writeTemporaryFile(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("UntoldGSFormatTests-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")
        try data.write(to: url)
        temporaryFiles.append(url)
        return url
    }
}

/// Deterministic generator so failures reproduce.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func nextUnitFloat() -> Float {
        Float(next() >> 40) / Float(1 << 24)
    }

    mutating func nextFloat(in range: ClosedRange<Float>) -> Float {
        range.lowerBound + nextUnitFloat() * (range.upperBound - range.lowerBound)
    }

    mutating func nextUnitQuaternion() -> simd_quatf {
        let v = SIMD4<Float>(nextFloat(in: -1 ... 1), nextFloat(in: -1 ... 1), nextFloat(in: -1 ... 1), nextFloat(in: -1 ... 1))
        return simd_quatf(vector: simd_normalize(v))
    }

    mutating func nextSplat(boundsMin: SIMD3<Float>, boundsMax: SIMD3<Float>, shCount: Int) -> UntoldGSSplat {
        let t = SIMD3<Float>(nextUnitFloat(), nextUnitFloat(), nextUnitFloat())
        let scale = SIMD3<Float>(exp(nextFloat(in: -7 ... -2)), exp(nextFloat(in: -7 ... -2)), exp(nextFloat(in: -7 ... -2)))
        return UntoldGSSplat(
            position: boundsMin + t * (boundsMax - boundsMin),
            scale: scale,
            rotation: nextUnitQuaternion(),
            color: SIMD3<Float>(nextUnitFloat(), nextUnitFloat(), nextUnitFloat()),
            opacity: nextUnitFloat(),
            sphericalHarmonics: (0 ..< shCount).map { _ in nextFloat(in: -1 ... 1) }
        )
    }
}

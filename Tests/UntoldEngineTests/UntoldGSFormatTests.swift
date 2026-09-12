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

    func testChunkWriteFailureIsThrownAsTheSinkThrewIt() throws {
        // A chunk's write failing in the parallel loop — a full disk — must reach the caller as
        // the sink's own POSIX error, not re-labelled as invalid input.
        var rng = SplitMix64(seed: 7)
        let splats = (0 ..< 40).map { _ in rng.nextSplat(boundsMin: [-1, -1, -1], boundsMax: [1, 1, 1], shCount: 0) }
        var options = UntoldGSWriteOptions()
        options.log2ChunkSplats = 3
        options.coarseLevelsAutomatic = false
        let store = try UntoldGSFormat.makeStore(splats, options: options)
        let sink = FailingSink(failAtOrAfter: 4096)
        XCTAssertThrowsError(
            try UntoldGSFormat.writeStore(UntoldGSStoreView(store: store), options: options, sink: sink, serialChunks: false, progress: nil)
        ) { error in
            XCTAssertNil(error as? UntoldGSError, "not re-typed by the chunk loop")
            let posix = error as NSError
            XCTAssertEqual(posix.domain, NSPOSIXErrorDomain)
            XCTAssertEqual(posix.code, Int(ENOSPC))
        }
    }

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

    /// The reference the slicing loop is checked against: the byte-wise table loop the format
    /// shipped with.
    private func byteWiseCRC32(_ bytes: [UInt8]) -> UInt32 {
        let table: [UInt32] = (0 ..< 256).map { index -> UInt32 in
            var crc = UInt32(index)
            for _ in 0 ..< 8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
            return crc
        }
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }

    /// Slicing by eight equals the byte-wise loop for every length and alignment, and a
    /// streamed `update` over random pieces equals the whole checksum.
    func testCRC32SlicingMatchesTheByteWiseLoop() {
        var generator = SystemRandomNumberGenerator()
        var lengthsSeen = Set<Int>()
        for iteration in 0 ..< 1000 {
            let length = iteration < 32 ? iteration : Int.random(in: 0 ... 70000, using: &generator)
            let offset = Int.random(in: 0 ... 7, using: &generator)
            lengthsSeen.insert(length)
            var storage = [UInt8](repeating: 0, count: offset + length)
            for index in storage.indices {
                storage[index] = UInt8.random(in: 0 ... 255, using: &generator)
            }
            let bytes = Array(storage[offset...])
            let expected = byteWiseCRC32(bytes)
            // Whole, at the chosen alignment.
            let whole = storage.withUnsafeBytes { buffer -> UInt32 in
                var crc = UntoldGSCRC32.initialValue
                UntoldGSCRC32.update(&crc, UnsafeRawBufferPointer(rebasing: buffer[offset...]))
                return UntoldGSCRC32.finalize(crc)
            }
            XCTAssertEqual(whole, expected, "length \(length) at offset \(offset)")
            XCTAssertEqual(UntoldGSCRC32.checksum(Data(bytes)), expected)
            // Streamed in random pieces.
            var crc = UntoldGSCRC32.initialValue
            var start = 0
            storage.withUnsafeBytes { buffer in
                while start < length {
                    let piece = min(length - start, Int.random(in: 1 ... max(1, length / 3 + 1), using: &generator))
                    UntoldGSCRC32.update(&crc, UnsafeRawBufferPointer(rebasing: buffer[(offset + start) ..< (offset + start + piece)]))
                    start += piece
                }
            }
            XCTAssertEqual(UntoldGSCRC32.finalize(crc), expected, "streamed, length \(length) at offset \(offset)")
        }
        XCTAssertGreaterThan(lengthsSeen.count, 500)
        XCTAssertEqual(UntoldGSCRC32.finalize(UntoldGSCRC32.initialValue), 0, "no bytes: the empty checksum")
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

    // MARK: - Coarse levels

    /// Two levels at ratios [2, 4] on 16-splat chunks: 64 splats → 4 chunks, 4 + 1 records each.
    private func coarseOptions() -> UntoldGSCoarseLevelOptions {
        var levels = UntoldGSCoarseLevelOptions()
        levels.levelCount = 2
        levels.ratioLog2 = [2, 4]
        levels.minimumChunkSplats = 16
        return levels
    }

    private func levelledSplats(count: Int = 64, seed: UInt64 = 20) -> [UntoldGSSplat] {
        var rng = SplitMix64(seed: seed)
        return (0 ..< count).map { _ in rng.nextSplat(boundsMin: [0, 0, 0], boundsMax: [1, 1, 1], shCount: 0) }
    }

    private func levelledWriteOptions(levels: UntoldGSCoarseLevelOptions? = nil) -> UntoldGSWriteOptions {
        var options = UntoldGSWriteOptions()
        options.log2ChunkSplats = 4
        options.coarseLevels = levels ?? coarseOptions()
        options.coarseLevelsAutomatic = false // four chunks: asked for, not automatic
        return options
    }

    private func patch(_ data: inout Data, at offset: Int, _ value: some FixedWidthInteger) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { bytes in
            for (index, byte) in bytes.enumerated() {
                data[offset + index] = byte
            }
        }
    }

    func testCoarseHeaderFieldOffsetsArePinned() throws {
        XCTAssertEqual(UntoldGSHeaderV3.reserved1Size, 28)
        XCTAssertEqual(UntoldGSFlags.hasCoarseLevels, 1 << 4)
        XCTAssertEqual(UntoldGSFormat.maxCoarseLevels, 2)
        XCTAssertEqual(UntoldGSFormat.coarseIndexEntrySize, 64)
        var header = makeHeader()
        header.flags |= UntoldGSFlags.hasCoarseLevels
        header.coarseIndexOffset = 0x0000_0001_0002_0000
        header.coarsePayloadOffset = 0x0000_0001_0002_4000
        header.coarseRecordCount = 0x0A0B_0C0D
        header.coarseLevelCount = 2
        header.coarseRatioLog2 = [3, 6]
        header.coarseFlags = 0
        let writer = UntoldBinaryWriter()
        header.encode(to: writer)
        let bytes = [UInt8](writer.data)
        XCTAssertEqual(bytes.count, 256)
        XCTAssertEqual(Array(bytes[204 ..< 212]), [0x00, 0x00, 0x02, 0x00, 0x01, 0x00, 0x00, 0x00])
        XCTAssertEqual(Array(bytes[212 ..< 220]), [0x00, 0x40, 0x02, 0x00, 0x01, 0x00, 0x00, 0x00])
        XCTAssertEqual(Array(bytes[220 ..< 224]), [0x0D, 0x0C, 0x0B, 0x0A])
        XCTAssertEqual(bytes[224], 2)
        XCTAssertEqual(Array(bytes[225 ..< 227]), [3, 6])
        XCTAssertEqual(bytes[227], 0)
        XCTAssertEqual(Array(bytes[228 ..< 256]), [UInt8](repeating: 0, count: 28))
        XCTAssertEqual(bytes[8] & 0x10, 0x10, "flag bit 4")
        let decoded = try UntoldGSHeaderV3.decode(from: UntoldBinaryReader(data: writer.data))
        XCTAssertEqual(decoded, header)
        XCTAssertTrue(decoded.hasCoarseLevels)
    }

    func testCoarseIndexIsLevelMajorChunkEntries() throws {
        let splats = levelledSplats()
        let (fileData, report) = try UntoldGSFormat.writeReporting(splats: splats, options: levelledWriteOptions())
        let index = try UntoldGSFormat.readIndex(from: fileData)
        let header = index.header
        XCTAssertTrue(header.hasCoarseLevels)
        XCTAssertEqual(index.chunks.count, 4)
        XCTAssertEqual(header.coarseLevelCount, 2)
        XCTAssertEqual(header.coarseRatioLog2, [2, 4])
        XCTAssertEqual(index.coarseRatioLog2, [2, 4])
        XCTAssertEqual(index.coarse.count, 8)
        XCTAssertEqual(header.splatCount, 64, "the fine count is untouched by the section")
        let page = UInt64(UntoldGSFormat.pageAlignment)
        XCTAssertEqual(header.coarseIndexOffset % page, 0)
        XCTAssertEqual(header.coarsePayloadOffset % page, 0)
        XCTAssertEqual(header.fileSize % page, 0)
        XCTAssertEqual(header.fileSize, UInt64(fileData.count))
        let lastFineEnd = try XCTUnwrap(index.chunks.map { $0.payloadOffset + UInt64($0.payloadBytes) }.max())
        XCTAssertEqual(header.coarseIndexOffset, lastFineEnd)
        XCTAssertEqual(header.coarsePayloadOffset, header.coarseIndexOffset + page)
        XCTAssertEqual(header.lodLevels, 1, "whole-file tiers are a different notion; the byte stays 1")

        var total: UInt32 = 0
        for level in 1 ... 2 {
            for chunk in 0 ..< 4 {
                let entry = index.coarse[(level - 1) * 4 + chunk]
                XCTAssertEqual(Int(entry.lodLevel), level)
                XCTAssertEqual(Int(entry.reserved0), chunk)
                XCTAssertEqual(entry.nodeId, index.chunks[chunk].nodeId)
                XCTAssertEqual(entry.splatCount, level == 1 ? 4 : 1)
                XCTAssertEqual(entry.coreBytes, entry.splatCount * 16)
                XCTAssertEqual(entry.payloadBytes, entry.coreBytes, "unpadded")
                XCTAssertEqual(entry.payloadOffset % 16, 0)
                XCTAssertGreaterThanOrEqual(entry.payloadOffset, header.coarsePayloadOffset)
                XCTAssertLessThanOrEqual(entry.payloadOffset + UInt64(entry.payloadBytes), header.fileSize)
                XCTAssertEqual(index.coarseEntry(level: level, chunk: chunk), entry)
                total += entry.splatCount
            }
        }
        XCTAssertEqual(header.coarseRecordCount, total)
        XCTAssertEqual(total, 20)
        // Coarsest level first, each level one contiguous range in chunk order.
        let l2 = try XCTUnwrap(index.coarseLevelRange(level: 2))
        let l1 = try XCTUnwrap(index.coarseLevelRange(level: 1))
        XCTAssertEqual(l2.lowerBound, header.coarsePayloadOffset)
        XCTAssertEqual(l2.upperBound - l2.lowerBound, 4 * 16)
        XCTAssertEqual(l1.lowerBound, l2.upperBound)
        XCTAssertEqual(l1.upperBound - l1.lowerBound, 16 * 16)
        XCTAssertNil(index.coarseLevelRange(level: 3))
        XCTAssertEqual(index.coarseRecordIndex(level: 2, chunk: 3), 3)
        XCTAssertEqual(index.coarseRecordIndex(level: 1, chunk: 0), 4)
        XCTAssertEqual(index.coarseRecordIndex(level: 1, chunk: 2), 12)
        for chunk in 0 ..< 3 {
            let a = try XCTUnwrap(index.coarseEntry(level: 1, chunk: chunk))
            let b = index.coarseEntry(level: 1, chunk: chunk + 1)!
            XCTAssertEqual(a.payloadOffset + UInt64(a.payloadBytes), b.payloadOffset)
        }

        let coarse = try XCTUnwrap(report.coarse)
        XCTAssertEqual(coarse.levelCount, 2)
        XCTAssertEqual(coarse.ratioLog2, [2, 4])
        XCTAssertEqual(coarse.recordsPerLevel, [16, 4])
        XCTAssertEqual(coarse.recordCount, 20)
        XCTAssertEqual(coarse.chunksWithoutLevels, 0)
        XCTAssertEqual(coarse.bytes, Int(header.fileSize - header.coarseIndexOffset))
        XCTAssertEqual(report.chunkCount, 4)
    }

    func testCoarseSectionRoundTrip() throws {
        let splats = levelledSplats(count: 200, seed: 21)
        var options = levelledWriteOptions()
        options.log2ChunkSplats = 5 // 32 per chunk → 7 chunks, the last of 8 (below the minimum)
        let fileData = try UntoldGSFormat.write(splats: splats, options: options)
        let file = try UntoldGSFile(url: writeTemporaryFile(fileData))
        XCTAssertEqual(file.index.chunks.count, 7)
        XCTAssertNil(file.index.coarseEntry(level: 1, chunk: 6), "an 8-splat chunk has no level")
        XCTAssertEqual(try file.decodeCoarseLevel(level: 1, chunk: 6), [])
        XCTAssertEqual(try file.coarsePayload(level: 2, chunk: 6).count, 0)

        // The writer's chunks in Morton order, coarsened again, are what the file decodes to.
        let bounds = UntoldGSFormat.bounds(of: splats)
        let order = UntoldGSFormat.mortonOrder(splats, boundsMin: bounds.min, boundsMax: bounds.max)
        for chunk in 0 ..< 7 {
            let members = Array(order[chunk * 32 ..< min(chunk * 32 + 32, order.count)]).map { splats[$0] }
            let expected = try UntoldGSCoarsener.coarsen(members, options: coarseOptions())
            for level in 1 ... 2 {
                let want = expected.level(level)
                let got = try file.decodeCoarseLevel(level: level, chunk: chunk)
                XCTAssertEqual(got.count, want.count)
                XCTAssertEqual(got.count, chunk == 6 ? 0 : (level == 1 ? 8 : 2))
                guard let entry = file.index.coarseEntry(level: level, chunk: chunk) else { continue }
                let extent = entry.aabbMax - entry.aabbMin
                for (a, b) in zip(want, got) {
                    XCTAssertLessThanOrEqual(abs(a.position.x - b.position.x), extent.x / 2048 + 1e-6)
                    XCTAssertLessThanOrEqual(abs(a.position.y - b.position.y), extent.y / 1024 + 1e-6)
                    XCTAssertLessThanOrEqual(abs(a.position.z - b.position.z), extent.z / 2048 + 1e-6)
                    for axis in 0 ..< 3 {
                        let step = (entry.logScaleMax - entry.logScaleMin) / (axis == 1 ? 1023 : 2047)
                        XCTAssertLessThanOrEqual(abs(log(a.scale[axis]) - log(b.scale[axis])), step * 0.5 + 1e-4)
                    }
                    XCTAssertEqual(a.opacity, b.opacity, accuracy: 0.5 / 255 + 1e-5)
                    for channel in 0 ..< 3 {
                        XCTAssertEqual(a.color[channel], b.color[channel], accuracy: 0.5 / 255 + 1e-5)
                    }
                    XCTAssertLessThan(2 * acos(min(1, abs((a.rotation.inverse * b.rotation).real))), 0.01)
                }
            }
        }
    }

    /// The reader that predates the section, emulated at the byte level: without the flag and the
    /// coarse header words the file is a plain version-3 file whose payload range happens to hold
    /// unclaimed bytes, and it parses and decodes fine-only.
    func testOldReaderSeesFineOnly() throws {
        let splats = levelledSplats()
        let flagged = try UntoldGSFormat.write(splats: splats, options: levelledWriteOptions())
        var plainOptions = levelledWriteOptions()
        plainOptions.coarseLevels = nil
        plainOptions.coarseLevelsAutomatic = false
        let plain = try UntoldGSFormat.write(splats: splats, options: plainOptions)
        XCTAssertGreaterThan(flagged.count, plain.count)

        var emulated = flagged
        emulated[8] &= ~UInt8(0x10)
        for offset in 204 ..< 228 {
            emulated[offset] = 0
        }
        let index = try UntoldGSFormat.readIndex(from: emulated)
        XCTAssertFalse(index.header.hasCoarseLevels)
        XCTAssertEqual(index.coarse, [])
        XCTAssertEqual(index.coarseLevelCount, 0)
        XCTAssertEqual(index.header.fileSize, UInt64(flagged.count), "the size still covers the section")
        let plainIndex = try UntoldGSFormat.readIndex(from: plain)
        XCTAssertEqual(index.chunks, plainIndex.chunks, "the fine entries are the section-free bake's")
        XCTAssertEqual(index.nodes, plainIndex.nodes)
        for chunk in index.chunks {
            let range = Int(chunk.payloadOffset) ..< Int(chunk.payloadOffset) + Int(chunk.payloadBytes)
            XCTAssertEqual(emulated.subdata(in: range), plain.subdata(in: range), "byte-identical fine payloads")
        }
        let file = try UntoldGSFile(url: writeTemporaryFile(emulated))
        XCTAssertEqual(try file.decodeAll(), try UntoldGSFile(url: writeTemporaryFile(plain)).decodeAll())
        let emulatedAsset = try UntoldGSFormat.read(from: file.url)
        let plainAsset = try UntoldGSFormat.read(from: writeTemporaryFile(plain))
        XCTAssertEqual(emulatedAsset.splatCount, plainAsset.splatCount)
        for (a, b) in zip(emulatedAsset.encodedSplats, plainAsset.encodedSplats) {
            XCTAssertEqual(a.position, b.position)
            XCTAssertEqual(a.colorAndOpacity, b.colorAndOpacity)
        }
        XCTAssertEqual(file.thrownCoarse(), .sizeMismatch("coarse level 1 of 0"))
    }

    func testNewReaderOnOldFile() throws {
        var options = levelledWriteOptions()
        options.coarseLevels = nil
        options.coarseLevelsAutomatic = false
        let fileData = try UntoldGSFormat.write(splats: levelledSplats(), options: options)
        let index = try UntoldGSFormat.readIndex(from: fileData)
        XCTAssertFalse(index.header.hasCoarseLevels)
        XCTAssertEqual(index.header.coarseLevelCount, 0)
        XCTAssertEqual(index.header.coarseIndexOffset, 0)
        XCTAssertEqual(index.header.coarsePayloadOffset, 0)
        XCTAssertEqual(index.header.coarseRecordCount, 0)
        XCTAssertEqual(index.header.coarseRatioLog2, [0, 0])
        XCTAssertEqual(index.coarse, [])
        XCTAssertNil(index.coarseEntry(level: 1, chunk: 0))
        XCTAssertNil(index.coarseLevelRange(level: 1))
        XCTAssertNil(UntoldGSIndex.coarseIndexRange(header: index.header))
    }

    func testCoarseIndexIsReadFromDiskAndRequiresItsBytesFromData() throws {
        let fileData = try UntoldGSFormat.write(splats: levelledSplats(), options: levelledWriteOptions())
        let header = try UntoldGSFormat.readHeaderV3(from: fileData)
        let prefix = fileData.prefix(UntoldGSIndex.prefixSize(header: header))
        XCTAssertEqual(try thrownError(UntoldGSFormat.readIndex(from: prefix)), .truncated, "a prefix cannot hold the coarse index")
        let toIndexEnd = try fileData.prefix(Int(XCTUnwrap(UntoldGSIndex.coarseIndexRange(header: header)?.upperBound)))
        XCTAssertEqual(try UntoldGSFormat.readIndex(from: toIndexEnd), try UntoldGSFormat.readIndex(from: fileData))
        let url = try writeTemporaryFile(fileData)
        XCTAssertEqual(try UntoldGSFormat.readIndex(from: url), try UntoldGSFormat.readIndex(from: fileData))
        XCTAssertEqual(try UntoldGSFile(url: url).index, try UntoldGSFormat.readIndex(from: fileData))
    }

    /// The paged loader's byte source validates a flagged file exactly as `UntoldGSFile` does
    /// (header, size, prefix, coarse index) and serves the coarse ranges by `pread`.
    func testPageSourceReadsTheCoarseIndex() throws {
        let fileData = try UntoldGSFormat.write(splats: levelledSplats(), options: levelledWriteOptions())
        let expected = try UntoldGSFormat.readIndex(from: fileData)
        let source = try UntoldGSFilePageSource(url: writeTemporaryFile(fileData))
        defer { source.close() }
        XCTAssertEqual(source.index, expected)
        XCTAssertEqual(source.index.coarse.count, 8)
        let entry = try XCTUnwrap(source.index.coarseEntry(level: 1, chunk: 2))
        var bytes = [UInt8](repeating: 0, count: Int(entry.payloadBytes))
        try bytes.withUnsafeMutableBytes { buffer in
            try source.read(offset: entry.payloadOffset, count: buffer.count, into: buffer.baseAddress!)
        }
        XCTAssertEqual(Data(bytes), fileData.subdata(in: Int(entry.payloadOffset) ..< Int(entry.payloadOffset) + Int(entry.payloadBytes)))
        XCTAssertEqual(UntoldGSCRC32.checksum(Data(bytes)), entry.crc32)
        XCTAssertNoThrow(try source.reopen(), "a reopen re-reads both ranges and finds the same index")
    }

    func testCoarseSectionRejections() throws {
        let fileData = try UntoldGSFormat.write(splats: levelledSplats(), options: levelledWriteOptions())
        let index = try UntoldGSFormat.readIndex(from: fileData)
        let header = index.header
        let coarseIndex = Int(header.coarseIndexOffset)
        func entry(level: Int, chunk: Int) -> Int {
            coarseIndex + ((level - 1) * 4 + chunk) * 64
        }
        func expectCorrupt(_ data: Data, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
            guard case .corrupt? = try thrownError(UntoldGSFormat.readIndex(from: data)) else {
                return XCTFail("expected .corrupt: \(message)", file: file, line: line)
            }
        }
        func expectSizeMismatch(_ data: Data, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
            guard case .sizeMismatch? = try thrownError(UntoldGSFormat.readIndex(from: data)) else {
                return XCTFail("expected .sizeMismatch: \(message)", file: file, line: line)
            }
        }

        var data = fileData
        data[8] &= ~UInt8(0x10)
        expectCorrupt(data, "coarse fields without the flag")

        data = fileData
        patch(&data, at: 204, header.payloadOffset)
        expectSizeMismatch(data, "coarse index below the last fine payload")

        data = fileData
        patch(&data, at: 204, header.nodeTreeOffset)
        expectSizeMismatch(data, "coarse index over the tree")

        data = fileData
        patch(&data, at: 212, header.coarseIndexOffset)
        expectSizeMismatch(data, "coarse payload over the coarse index")

        data = fileData
        patch(&data, at: 204, header.coarseIndexOffset + 16)
        expectSizeMismatch(data, "misaligned coarse index")

        data = fileData
        data[225] = 4
        data[226] = 4
        expectCorrupt(data, "non-increasing ratios")

        data = fileData
        data[225] = 0
        expectCorrupt(data, "zero ratio")

        data = fileData
        data[226] = 5
        expectCorrupt(data, "ratio above log2ChunkSplats")

        data = fileData
        data[224] = 3
        expectCorrupt(data, "three levels")

        data = fileData
        data[227] = 1
        guard case .unsupported? = try thrownError(UntoldGSFormat.readIndex(from: data)) else {
            return XCTFail("coarse flags bit 0 is a reserved feature")
        }

        data = fileData
        patch(&data, at: entry(level: 1, chunk: 2) + 20, UInt16(2))
        expectCorrupt(data, "lodLevel != L")

        data = fileData
        patch(&data, at: entry(level: 2, chunk: 1) + 56, UInt32(0))
        expectCorrupt(data, "reserved0 != c")

        data = fileData
        patch(&data, at: entry(level: 1, chunk: 0) + 22, UInt16(index.chunks[0].nodeId &+ 1))
        expectCorrupt(data, "nodeId differs from the chunk's")

        data = fileData
        patch(&data, at: entry(level: 1, chunk: 3) + 16, UInt32(5))
        expectSizeMismatch(data, "splatCount above n >> ratio")

        data = fileData
        patch(&data, at: entry(level: 1, chunk: 0) + 16, UInt32(0))
        patch(&data, at: entry(level: 1, chunk: 0) + 12, UInt32(0))
        patch(&data, at: entry(level: 1, chunk: 0) + 8, UInt32(0))
        expectCorrupt(data, "level 2 without level 1")

        data = fileData
        patch(&data, at: entry(level: 1, chunk: 1) + 12, UInt32(48))
        expectSizeMismatch(data, "wrong coreBytes")

        data = fileData
        patch(&data, at: entry(level: 1, chunk: 1) + 8, UInt32(80))
        expectSizeMismatch(data, "payloadBytes != coreBytes")

        data = fileData
        patch(&data, at: entry(level: 2, chunk: 0), index.coarse[4].payloadOffset + 8)
        expectSizeMismatch(data, "misaligned payloadOffset")

        data = fileData
        patch(&data, at: entry(level: 1, chunk: 3), header.fileSize)
        expectSizeMismatch(data, "payload past fileSize")

        data = fileData
        patch(&data, at: entry(level: 1, chunk: 1), index.coarse[0].payloadOffset)
        expectSizeMismatch(data, "payloads overlapping")

        data = fileData
        patch(&data, at: entry(level: 1, chunk: 1) + 48, Float(10).bitPattern)
        expectCorrupt(data, "logScaleMin above logScaleMax")

        data = fileData
        patch(&data, at: 220, header.coarseRecordCount + 1)
        expectSizeMismatch(data, "Σ splatCount ≠ coarseRecordCount")

        data = fileData
        data[Int(index.coarse[1].payloadOffset) + 3] ^= 0xFF // level 1 of chunk 1
        let file = try UntoldGSFile(url: writeTemporaryFile(data))
        XCTAssertNoThrow(try file.coarsePayload(level: 1, chunk: 0))
        guard case .corrupt? = try thrownError(file.coarsePayload(level: 1, chunk: 1)) else {
            return XCTFail("a corrupt coarse CRC")
        }
        XCTAssertNoThrow(try file.coarsePayload(level: 1, chunk: 1, verify: false))
        XCTAssertNoThrow(try file.decodeAll(), "the fine chunks are untouched")
    }

    /// The pre-change bytes of two fixtures, recorded at 6bfa4cc6 (before the section existed):
    /// a 13-chunk bake and a 69-chunk bake with the levels off both reproduce them exactly, and
    /// `.automatic` below 64 chunks does too.
    func testWriteWithoutLevelsIsByteIdenticalToBefore() throws {
        var options = UntoldGSWriteOptions()
        options.log2ChunkSplats = 4
        XCTAssertTrue(options.coarseLevelsAutomatic)
        XCTAssertNil(options.coarseLevels)

        var rng = SplitMix64(seed: 0x600D_CAFE)
        let small = (0 ..< 200).map { _ in rng.nextGoldenSplat() }
        let smallData = try UntoldGSFormat.write(splats: small, options: options)
        XCTAssertEqual(smallData.count, 262_144)
        XCTAssertEqual(UntoldGSCRC32.checksum(smallData), 0xF81A_698B, "13 chunks under .automatic: no section")
        XCTAssertFalse(try UntoldGSFormat.readIndex(from: smallData).header.hasCoarseLevels)

        var rng2 = SplitMix64(seed: 0x600D_F00D)
        let large = (0 ..< 1100).map { _ in rng2.nextGoldenSplat() }
        let automatic = try UntoldGSFormat.write(splats: large, options: options)
        XCTAssertTrue(try UntoldGSFormat.readIndex(from: automatic).header.hasCoarseLevels, "69 chunks under .automatic: a section")
        XCTAssertEqual(try UntoldGSFormat.readIndex(from: automatic).coarseRatioLog2, [3, 4], "the default ratios clamped to log2ChunkSplats = 4")
        options.coarseLevelsAutomatic = false
        let largeData = try UntoldGSFormat.write(splats: large, options: options)
        XCTAssertEqual(largeData.count, 1_179_648)
        XCTAssertEqual(UntoldGSCRC32.checksum(largeData), 0x1C58_358A)
        // The section-free file is the flagged file's prefix with the header's coarse words clear.
        var emulated = automatic.prefix(largeData.count)
        emulated[8] &= ~UInt8(0x10)
        for offset in 196 ..< 228 {
            emulated[offset] = largeData[offset]
        }
        XCTAssertEqual(Data(emulated), largeData, "fine sections and payloads are byte-identical either way")
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

private extension UntoldGSFile {
    /// The error `coarsePayload` throws for level 1 of chunk 0, or nil.
    func thrownCoarse() -> UntoldGSError? {
        do {
            _ = try coarsePayload(level: 1, chunk: 0)
            return nil
        } catch {
            return error as? UntoldGSError
        }
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

    /// The fixture of `testWriteWithoutLevelsIsByteIdenticalToBefore`: its bytes are pinned, so
    /// this generator must never change.
    mutating func nextGoldenSplat() -> UntoldGSSplat {
        let t = SIMD3<Float>(nextUnitFloat(), nextUnitFloat(), nextUnitFloat())
        let scale = SIMD3<Float>(exp(nextFloat(in: -7 ... -2)), exp(nextFloat(in: -7 ... -2)), exp(nextFloat(in: -7 ... -2)))
        let v = SIMD4<Float>(nextFloat(in: -1 ... 1), nextFloat(in: -1 ... 1), nextFloat(in: -1 ... 1), nextFloat(in: -1 ... 1))
        return UntoldGSSplat(
            position: SIMD3<Float>(-1, 0, -1) + t * SIMD3<Float>(2, 1, 2),
            scale: scale,
            rotation: simd_quatf(vector: simd_normalize(v)),
            color: SIMD3<Float>(nextUnitFloat(), nextUnitFloat(), nextUnitFloat()),
            opacity: nextFloat(in: 0.2 ... 1)
        )
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

/// A sink whose writes at or past `failAtOrAfter` — the payload pages, not the header — fail
/// with `ENOSPC`, as `pwrite` on a full volume does.
private final class FailingSink: UntoldGSWriteSink, @unchecked Sendable {
    let failAtOrAfter: Int

    init(failAtOrAfter: Int) {
        self.failAtOrAfter = failAtOrAfter
    }

    func write(_: UnsafeRawBufferPointer, at offset: Int) throws {
        if offset >= failAtOrAfter {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC), userInfo: [NSFilePathErrorKey: "/full/volume/out.untoldgs"])
        }
    }

    func finish(fileSize _: Int) throws {}
}

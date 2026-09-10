//
//  UntoldAssetPatcherTests.swift
//  UntoldEngineTests
//
//  `UntoldAssetPatcher` rewrites the gaussianAsset table of a `.untold` file and nothing
//  else: every other chunk keeps its stored bytes, the string table only grows, offsets stay
//  16-byte aligned and the content hash follows.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Compression
import CryptoKit
import simd
@testable import UntoldEngine
import XCTest

final class UntoldAssetPatcherTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDown() {
        for url in temporaryDirectories {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryDirectories.removeAll()
        super.tearDown()
    }

    // MARK: - Setting a link

    func testSettingALinkAppendsTheRecordAndKeepsEveryOtherChunk() throws {
        let fixture = makeFixture(computeHash: true)
        let link = UntoldAssetPatcher.GaussianAssetLink(
            payloadPath: "Gaussians/chair.untoldgs",
            lodCount: 2,
            lodSplatCounts: [20000, 180_000],
            lodSwitchScreenHeights: [120, 720],
            occluderShrinkMeters: 0.03,
            exposureOffsetEV: -0.5,
            swapDistanceMeters: 12
        )

        let patched = try UntoldAssetPatcher.settingGaussianAsset(link, onEntity: 0, in: fixture.fileData)
        let decoded = try UntoldReader().readAsset(from: patched)

        XCTAssertEqual(decoded.gaussianAssets.count, 1)
        let record = try XCTUnwrap(decoded.gaussianAssets.first)
        XCTAssertEqual(record.entityId, 0)
        XCTAssertEqual(try decoded.string(at: record.payloadPathOffset), "Gaussians/chair.untoldgs")
        XCTAssertEqual(record.flags, UntoldGaussianAssetFlags.meshTwin)
        XCTAssertEqual(record.lodCount, 2)
        XCTAssertEqual(record.lodSplatCounts, [20000, 180_000, 0, 0])
        XCTAssertEqual(record.lodSwitchScreenHeights, [120, 720, 0, 0])
        XCTAssertEqual(record.occluderShrinkMeters, 0.03)
        XCTAssertEqual(record.exposureOffsetEV, -0.5)
        XCTAssertEqual(record.swapDistanceMeters, 12)
        XCTAssertEqual(decoded.header.chunkCount, UInt32(fixture.chunkEntries.count + 1))
        XCTAssertEqual(decoded.chunks.last?.chunkType, .gaussianAssetTable, "The new table is appended after the existing chunks")

        // The path was appended to the string table; everything that was there is untouched.
        XCTAssertEqual(decoded.stringTableData.prefix(fixture.stringTableData.count), fixture.stringTableData)
        XCTAssertEqual(try decoded.string(at: fixture.entity.nameOffset), "root_entity")

        assertOtherChunksPreserved(original: fixture.fileData, patched: patched, except: [.stringTable, .gaussianAssetTable])
        assertAligned(decoded.chunks)
        try assertContentHashValid(patched)
        XCTAssertEqual(try UntoldAssetPatcher.gaussianAssets(in: patched), [0: link])
    }

    func testSettingALinkReusesAnIdenticalString() throws {
        let fixture = makeFixture(extraStrings: ["chair.untoldgs"])
        let expectedOffset = try XCTUnwrap(fixture.stringOffsets["chair.untoldgs"])

        let patched = try UntoldAssetPatcher.settingGaussianAsset(
            UntoldAssetPatcher.GaussianAssetLink(payloadPath: "chair.untoldgs"),
            onEntity: 0,
            in: fixture.fileData
        )
        let decoded = try UntoldReader().readAsset(from: patched)

        XCTAssertEqual(decoded.gaussianAssets.first?.payloadPathOffset, expectedOffset)
        XCTAssertEqual(decoded.stringTableData, fixture.stringTableData, "No string appended")
        assertOtherChunksPreserved(original: fixture.fileData, patched: patched, except: [.gaussianAssetTable])
    }

    func testAStringMatchingTheTailOfAnotherIsNotReused() throws {
        let fixture = makeFixture(extraStrings: ["big_chair.untoldgs"])

        let patched = try UntoldAssetPatcher.settingGaussianAsset(
            UntoldAssetPatcher.GaussianAssetLink(payloadPath: "chair.untoldgs"),
            onEntity: 0,
            in: fixture.fileData
        )
        let decoded = try UntoldReader().readAsset(from: patched)

        XCTAssertEqual(decoded.gaussianAssets.first?.payloadPathOffset, UInt32(fixture.stringTableData.count), "Appended as its own entry")
        XCTAssertEqual(try decoded.string(at: decoded.gaussianAssets[0].payloadPathOffset), "chair.untoldgs")
    }

    func testAStringThatIsAPrefixOrHasAPrefixOfAnotherIsNotReused() throws {
        // Both directions: an entry the path starts ("chair.untoldgs.bak") and an entry that
        // starts the path ("chair"). Only a whole-entry match may be reused.
        let fixture = makeFixture(extraStrings: ["chair.untoldgs.bak", "chair"])

        let patched = try UntoldAssetPatcher.settingGaussianAsset(
            UntoldAssetPatcher.GaussianAssetLink(payloadPath: "chair.untoldgs"),
            onEntity: 0,
            in: fixture.fileData
        )
        let decoded = try UntoldReader().readAsset(from: patched)
        let record = try XCTUnwrap(decoded.gaussianAssets.first)
        XCTAssertEqual(record.payloadPathOffset, UInt32(fixture.stringTableData.count), "Appended as its own entry")
        XCTAssertEqual(try decoded.string(at: record.payloadPathOffset), "chair.untoldgs")

        // Offsets are byte offsets: a non-ASCII path lands after the bytes already written.
        let accented = "Möbel/stühle.untoldgs"
        let again = try UntoldAssetPatcher.settingGaussianAsset(
            UntoldAssetPatcher.GaussianAssetLink(payloadPath: accented),
            onEntity: 0,
            in: patched
        )
        let decodedAgain = try UntoldReader().readAsset(from: again)
        let accentedRecord = try XCTUnwrap(decodedAgain.gaussianAssets.first)
        XCTAssertEqual(accentedRecord.payloadPathOffset, UInt32(fixture.stringTableData.count + "chair.untoldgs\0".utf8.count))
        XCTAssertEqual(try decodedAgain.string(at: accentedRecord.payloadPathOffset), accented)
        XCTAssertEqual(decodedAgain.stringTableData.count, fixture.stringTableData.count + "chair.untoldgs\0".utf8.count + accented.utf8.count + 1)
    }

    func testSettingAgainReplacesTheRecordInPlace() throws {
        let fixture = makeFixture(entityCount: 2)
        let first = UntoldAssetPatcher.GaussianAssetLink(payloadPath: "a.untoldgs", swapDistanceMeters: 5)
        let other = UntoldAssetPatcher.GaussianAssetLink(payloadPath: "b.untoldgs")
        let replacement = UntoldAssetPatcher.GaussianAssetLink(payloadPath: "c.untoldgs", occluderShrinkMeters: 0.1, swapDistanceMeters: 7)

        let once = try UntoldAssetPatcher.settingGaussianAsset(first, onEntity: 0, in: fixture.fileData)
        XCTAssertEqual(
            try UntoldAssetPatcher.settingGaussianAsset(first, onEntity: 0, in: once),
            once,
            "Setting an identical link is byte-identical: the path the replaced record points at is reused"
        )

        var data = try UntoldAssetPatcher.settingGaussianAsset(other, onEntity: 1, in: once)
        data = try UntoldAssetPatcher.settingGaussianAsset(replacement, onEntity: 0, in: data)
        let decoded = try UntoldReader().readAsset(from: data)

        XCTAssertEqual(decoded.gaussianAssets.count, 2, "One record per entity")
        XCTAssertEqual(decoded.gaussianAssets.map(\.entityId), [0, 1], "The replaced record keeps its position")
        XCTAssertEqual(decoded.chunks.filter { $0.chunkType == .gaussianAssetTable }.count, 1)
        XCTAssertEqual(try UntoldAssetPatcher.gaussianAssets(in: data), [0: replacement, 1: other])

        // Append-only: the superseded path is still in the table, the others' offsets are intact,
        // and exactly one string per distinct path was appended across the four sets.
        let table = decoded.stringTableData
        XCTAssertNotNil(range(of: "a.untoldgs", in: table))
        XCTAssertEqual(table.count, fixture.stringTableData.count + "a.untoldgs\0b.untoldgs\0c.untoldgs\0".utf8.count)
        XCTAssertEqual(try decoded.string(at: fixture.entity.nameOffset), "root_entity")
        assertAligned(decoded.chunks)
    }

    func testALinkWithShortLODArraysRoundTripsEqual() throws {
        // validate() allows fewer entries than lodCount; the record pads to four slots and the
        // read-back keeps lodCount of them, so the link must already hold lodCount entries.
        let short = UntoldAssetPatcher.GaussianAssetLink(payloadPath: "a.untoldgs", lodCount: 2, lodSplatCounts: [1000])
        XCTAssertEqual(short.lodSplatCounts, [1000, 0])
        XCTAssertEqual(short.lodSwitchScreenHeights, [0, 0])
        XCTAssertNoThrow(try short.validate())
        XCTAssertEqual(
            UntoldAssetPatcher.GaussianAssetLink(record: short.record(entityId: 0, payloadPathOffset: 0), payloadPath: short.payloadPath),
            short
        )

        let fixture = makeFixture()
        let data = try UntoldAssetPatcher.settingGaussianAsset(short, onEntity: 0, in: fixture.fileData)
        XCTAssertEqual(try UntoldAssetPatcher.gaussianAssets(in: data), [0: short])

        let oneLevel = UntoldAssetPatcher.GaussianAssetLink(payloadPath: "a.untoldgs", lodCount: 1)
        XCTAssertEqual(oneLevel.lodSplatCounts, [0])
        let oneLevelData = try UntoldAssetPatcher.settingGaussianAsset(oneLevel, onEntity: 0, in: fixture.fileData)
        XCTAssertEqual(try UntoldAssetPatcher.gaussianAssets(in: oneLevelData), [0: oneLevel])

        // Longer arrays are not cut by the initializer; validate() still rejects them.
        let long = UntoldAssetPatcher.GaussianAssetLink(payloadPath: "a.untoldgs", lodCount: 1, lodSplatCounts: [1, 2])
        XCTAssertEqual(long.lodSplatCounts, [1, 2])
        XCTAssertThrowsError(try long.validate())
    }

    func testAlignmentRoundTripsThroughTheRecordAndTheFile() throws {
        let alignment = GaussianSplatAlignment(translation: SIMD3<Float>(0.1, 0, -0.3), yawDegrees: 90, scale: 1.02)
        let aligned = UntoldAssetPatcher.GaussianAssetLink(payloadPath: "chair.untoldgs", lodCount: 1, lodSplatCounts: [300], alignment: alignment)
        XCTAssertNoThrow(try aligned.validate())
        XCTAssertEqual(aligned.flags, UntoldGaussianAssetFlags.meshTwin, "the alignment flag is derived, not kept in flags")

        let record = aligned.record(entityId: 0, payloadPathOffset: 0)
        XCTAssertEqual(record.flags, UntoldGaussianAssetFlags.meshTwin | UntoldGaussianAssetFlags.alignment)
        XCTAssertEqual(record.alignment, alignment)
        XCTAssertEqual(UntoldAssetPatcher.GaussianAssetLink(record: record, payloadPath: "chair.untoldgs"), aligned)

        let fixture = makeFixture()
        let data = try UntoldAssetPatcher.settingGaussianAsset(aligned, onEntity: 0, in: fixture.fileData)
        XCTAssertEqual(try UntoldAssetPatcher.gaussianAssets(in: data), [0: aligned])
        XCTAssertEqual(try UntoldReader().readAsset(from: data).gaussianAssets.first?.alignment, alignment)

        // Setting the link again without an alignment clears the flag and the words.
        let plain = UntoldAssetPatcher.GaussianAssetLink(payloadPath: "chair.untoldgs", lodCount: 1, lodSplatCounts: [300])
        let cleared = try UntoldAssetPatcher.settingGaussianAsset(plain, onEntity: 0, in: data)
        XCTAssertEqual(try UntoldAssetPatcher.gaussianAssets(in: cleared), [0: plain])
        let clearedRecord = try XCTUnwrap(UntoldReader().readAsset(from: cleared).gaussianAssets.first)
        XCTAssertEqual(clearedRecord.flags, UntoldGaussianAssetFlags.meshTwin)
        XCTAssertEqual(clearedRecord.alignmentScale, 0)

        // A flags value carrying the bit without an alignment is not written as one.
        let flagOnly = UntoldAssetPatcher.GaussianAssetLink(payloadPath: "chair.untoldgs", flags: UntoldGaussianAssetFlags.meshTwin | UntoldGaussianAssetFlags.alignment)
        XCTAssertEqual(flagOnly.flags, UntoldGaussianAssetFlags.meshTwin)
        XCTAssertNil(flagOnly.record(entityId: 0, payloadPathOffset: 0).alignment)

        // Nor is one set on `flags` after the fact, or copied from an aligned record: the link
        // still validates, writes a record without the bit and reads back with no alignment
        // instead of failing the read-back with a zero scale.
        var mutated = plain
        mutated.flags |= UntoldGaussianAssetFlags.alignment
        XCTAssertEqual(mutated.flags, UntoldGaussianAssetFlags.meshTwin, "the bit is dropped as it is set")
        XCTAssertEqual(mutated, plain)
        var copiedFlags = plain
        copiedFlags.flags = record.flags
        XCTAssertEqual(copiedFlags.flags, UntoldGaussianAssetFlags.meshTwin)
        XCTAssertNoThrow(try copiedFlags.validate())
        XCTAssertEqual(copiedFlags.record(entityId: 0, payloadPathOffset: 0).flags, UntoldGaussianAssetFlags.meshTwin)
        XCTAssertNil(copiedFlags.record(entityId: 0, payloadPathOffset: 0).alignment)
        let written = try UntoldAssetPatcher.settingGaussianAsset(copiedFlags, onEntity: 0, in: data)
        XCTAssertEqual(try UntoldAssetPatcher.gaussianAssets(in: written), [0: plain])
        XCTAssertNil(try UntoldReader().readAsset(from: written).gaussianAssets.first?.alignment)
    }

    func testRecordOfAnInvalidLinkDoesNotTrap() {
        let negative = UntoldAssetPatcher.GaussianAssetLink(payloadPath: "a.untoldgs", lodCount: -1)
        XCTAssertEqual(negative.lodSplatCounts, [])
        XCTAssertThrowsError(try negative.validate())
        XCTAssertEqual(negative.record(entityId: 3, payloadPathOffset: 7).lodCount, 0)

        let tooMany = UntoldAssetPatcher.GaussianAssetLink(payloadPath: "a.untoldgs", lodCount: 9)
        XCTAssertEqual(tooMany.lodSplatCounts.count, UntoldGaussianAssetRecordV1.maxLODLevels)
        XCTAssertEqual(tooMany.record(entityId: 3, payloadPathOffset: 7).lodCount, 9)
    }

    func testSettingOnAFileWithAZeroHashKeepsItZero() throws {
        let fixture = makeFixture(computeHash: false)
        let patched = try UntoldAssetPatcher.settingGaussianAsset(
            UntoldAssetPatcher.GaussianAssetLink(payloadPath: "chair.untoldgs"),
            onEntity: 0,
            in: fixture.fileData
        )
        let decoded = try UntoldReader().readAsset(from: patched)
        XCTAssertEqual(decoded.header.contentHash, Array(repeating: 0, count: UntoldFormat.hashByteCount))
    }

    func testSettingRecomputesTheHashWhenTheInputHadOne() throws {
        let fixture = makeFixture(computeHash: true)
        let patched = try UntoldAssetPatcher.settingGaussianAsset(
            UntoldAssetPatcher.GaussianAssetLink(payloadPath: "chair.untoldgs"),
            onEntity: 0,
            in: fixture.fileData
        )
        let decoded = try UntoldReader().readAsset(from: patched)
        XCTAssertNotEqual(decoded.header.contentHash, fixture.header.contentHash, "The payloads changed, so did the hash")
        try assertContentHashValid(patched)

        // A flipped payload byte is caught by the reader, so the hash written is the one checked.
        var corrupted = patched
        let vertexChunk = try XCTUnwrap(decoded.chunks.first { $0.chunkType == .vertexData })
        corrupted[Int(vertexChunk.fileOffset)] ^= 0xFF
        XCTAssertThrowsError(try UntoldReader().readAsset(from: corrupted)) { error in
            XCTAssertEqual(error as? UntoldValidationError, .contentHashMismatch)
        }
    }

    func testSettingOnAFileThatAlreadyHasATableKeepsItsChunkPosition() throws {
        let existing = UntoldGaussianAssetRecordV1(entityId: 1, payloadPathOffset: 0, flags: 0, swapDistanceMeters: 3)
        let fixture = makeFixture(entityCount: 2, gaussianRecords: [existing], computeHash: true)
        let tableIndex = try XCTUnwrap(fixture.chunkEntries.firstIndex { $0.chunkType == .gaussianAssetTable })

        let patched = try UntoldAssetPatcher.settingGaussianAsset(
            UntoldAssetPatcher.GaussianAssetLink(payloadPath: "chair.untoldgs"),
            onEntity: 0,
            in: fixture.fileData
        )
        let decoded = try UntoldReader().readAsset(from: patched)

        XCTAssertEqual(fixture.chunkEntries.map(\.chunkType.rawValue), [1, 2, 25, 3, 4, 5, 6, 7], "The fixture's table sits mid-file")
        XCTAssertEqual(decoded.chunks.count, fixture.chunkEntries.count, "Replaced, not appended")
        XCTAssertEqual(decoded.chunks.map(\.chunkType), fixture.chunkEntries.map(\.chunkType), "Input chunk order preserved")
        XCTAssertEqual(decoded.chunks[tableIndex].chunkType, .gaussianAssetTable)
        XCTAssertEqual(decoded.chunks[tableIndex].elementCount, 2)
        XCTAssertEqual(decoded.gaussianAssets.map(\.entityId), [1, 0])
        XCTAssertEqual(decoded.gaussianAssets[0].swapDistanceMeters, 3, "The other entity's record is carried over")
        assertOtherChunksPreserved(original: fixture.fileData, patched: patched, except: [.stringTable, .gaussianAssetTable])
        assertAligned(decoded.chunks)
        try assertContentHashValid(patched)

        // Dropping the table from the middle keeps the others in order, hash still valid.
        var removed = try UntoldAssetPatcher.removingGaussianAsset(onEntity: 0, in: patched)
        removed = try UntoldAssetPatcher.removingGaussianAsset(onEntity: 1, in: removed)
        let decodedRemoved = try UntoldReader().readAsset(from: removed)
        XCTAssertEqual(decodedRemoved.chunks.map(\.chunkType.rawValue), [1, 2, 3, 4, 5, 6, 7])
        assertOtherChunksPreserved(original: fixture.fileData, patched: removed, except: [.stringTable, .gaussianAssetTable])
        try assertContentHashValid(removed)
    }

    // MARK: - Removing a link

    func testRemovingTheOnlyRecordDropsTheChunk() throws {
        let fixture = makeFixture(computeHash: true)
        let linked = try UntoldAssetPatcher.settingGaussianAsset(
            UntoldAssetPatcher.GaussianAssetLink(payloadPath: "chair.untoldgs"),
            onEntity: 0,
            in: fixture.fileData
        )

        let removed = try UntoldAssetPatcher.removingGaussianAsset(onEntity: 0, in: linked)
        let decoded = try UntoldReader().readAsset(from: removed)

        XCTAssertTrue(decoded.gaussianAssets.isEmpty)
        XCTAssertFalse(decoded.chunks.contains { $0.chunkType == .gaussianAssetTable })
        XCTAssertEqual(decoded.header.chunkCount, UInt32(fixture.chunkEntries.count))
        XCTAssertNotNil(range(of: "chair.untoldgs", in: decoded.stringTableData), "The string table is append-only")
        assertOtherChunksPreserved(original: fixture.fileData, patched: removed, except: [.stringTable])
        assertAligned(decoded.chunks)
        try assertContentHashValid(removed)
        XCTAssertEqual(try UntoldAssetPatcher.gaussianAssets(in: removed), [:])
    }

    func testRemovingOneOfTwoRecordsKeepsTheOther() throws {
        let fixture = makeFixture(entityCount: 2)
        var data = try UntoldAssetPatcher.settingGaussianAsset(.init(payloadPath: "a.untoldgs"), onEntity: 0, in: fixture.fileData)
        data = try UntoldAssetPatcher.settingGaussianAsset(.init(payloadPath: "b.untoldgs"), onEntity: 1, in: data)

        let removed = try UntoldAssetPatcher.removingGaussianAsset(onEntity: 0, in: data)
        let decoded = try UntoldReader().readAsset(from: removed)

        XCTAssertEqual(decoded.gaussianAssets.map(\.entityId), [1])
        XCTAssertEqual(decoded.chunks.first { $0.chunkType == .gaussianAssetTable }?.elementCount, 1)
        XCTAssertEqual(try UntoldAssetPatcher.gaussianAssets(in: removed), [1: .init(payloadPath: "b.untoldgs")])
    }

    func testRemovingWhenThereIsNoRecordReturnsTheInput() throws {
        let fixture = makeFixture(computeHash: true)
        XCTAssertEqual(try UntoldAssetPatcher.removingGaussianAsset(onEntity: 0, in: fixture.fileData), fixture.fileData)
    }

    // MARK: - Validation

    func testUnknownEntityThrows() throws {
        let fixture = makeFixture()
        XCTAssertThrowsError(try UntoldAssetPatcher.settingGaussianAsset(.init(payloadPath: "chair.untoldgs"), onEntity: 42, in: fixture.fileData)) { error in
            XCTAssertEqual(error as? UntoldAssetPatcher.Error, .unknownEntity(42))
        }
        XCTAssertThrowsError(try UntoldAssetPatcher.removingGaussianAsset(onEntity: 42, in: fixture.fileData)) { error in
            XCTAssertEqual(error as? UntoldAssetPatcher.Error, .unknownEntity(42))
        }
    }

    func testInvalidLinksThrow() throws {
        let fixture = makeFixture()
        var links: [UntoldAssetPatcher.GaussianAssetLink] = []
        links.append(.init(payloadPath: ""))
        links.append(.init(payloadPath: "chair\0.untoldgs"))
        links.append(.init(payloadPath: "chair.untoldgs", lodCount: 5))
        links.append(.init(payloadPath: "chair.untoldgs", lodCount: -1))
        links.append(.init(payloadPath: "chair.untoldgs", lodCount: 1, lodSplatCounts: [1, 2]))
        links.append(.init(payloadPath: "chair.untoldgs", lodCount: 1, lodSwitchScreenHeights: [1, 2]))
        links.append(.init(payloadPath: "chair.untoldgs", lodCount: 1, lodSwitchScreenHeights: [.nan]))
        links.append(.init(payloadPath: "chair.untoldgs", occluderShrinkMeters: -0.01))
        links.append(.init(payloadPath: "chair.untoldgs", occluderShrinkMeters: .infinity))
        links.append(.init(payloadPath: "chair.untoldgs", exposureOffsetEV: .nan))
        links.append(.init(payloadPath: "chair.untoldgs", swapDistanceMeters: -1))
        links.append(.init(payloadPath: "chair.untoldgs", swapDistanceMeters: .infinity))
        links.append(.init(payloadPath: "chair.untoldgs", alignment: GaussianSplatAlignment(scale: 0)))
        links.append(.init(payloadPath: "chair.untoldgs", alignment: GaussianSplatAlignment(scale: -1)))
        links.append(.init(payloadPath: "chair.untoldgs", alignment: GaussianSplatAlignment(yawDegrees: .nan)))
        links.append(.init(payloadPath: "chair.untoldgs", alignment: GaussianSplatAlignment(translation: SIMD3<Float>(0, 0, .infinity))))

        for link in links {
            XCTAssertThrowsError(try UntoldAssetPatcher.settingGaussianAsset(link, onEntity: 0, in: fixture.fileData), "\(link)") { error in
                guard case .invalidLink? = error as? UntoldAssetPatcher.Error else {
                    return XCTFail("unexpected error \(error) for \(link)")
                }
            }
        }

        // The edges of the ranges are fine.
        let edge = UntoldAssetPatcher.GaussianAssetLink(
            payloadPath: "chair.untoldgs",
            lodCount: 4,
            lodSplatCounts: [1, 2, 3, 4],
            lodSwitchScreenHeights: [1, 2, 3, 4],
            occluderShrinkMeters: 0,
            exposureOffsetEV: -4,
            swapDistanceMeters: 0,
            alignment: GaussianSplatAlignment(translation: SIMD3<Float>(-100, 0, 100), yawDegrees: 720, scale: 0.001)
        )
        XCTAssertNoThrow(try UntoldAssetPatcher.settingGaussianAsset(edge, onEntity: 0, in: fixture.fileData))
    }

    func testCorruptInputThrows() throws {
        let fixture = makeFixture()
        XCTAssertThrowsError(try UntoldAssetPatcher.settingGaussianAsset(.init(payloadPath: "chair.untoldgs"), onEntity: 0, in: fixture.fileData.prefix(100))) { error in
            guard case .corruptFile? = error as? UntoldAssetPatcher.Error else {
                return XCTFail("unexpected error \(error)")
            }
        }
        XCTAssertThrowsError(try UntoldAssetPatcher.gaussianAssets(in: Data("not an untold file".utf8))) { error in
            guard case .corruptFile? = error as? UntoldAssetPatcher.Error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    /// The reader ignores a chunk of an unknown core type and skips the hash on a zero-hash file,
    /// so it accepts entries the patcher then has to copy; sizes that do not fit an Int must throw,
    /// not trap.
    func testAnUnknownChunkPointingOutsideTheFileThrowsCorruptFile() throws {
        let unknown = UntoldChunkType(rawValue: 0x7FFF)
        let phantoms: [UntoldChunkEntryV1] = [
            .init(chunkType: unknown, fileOffset: 1 << 20, compressedSize: 16, uncompressedSize: 16),
            .init(chunkType: unknown, fileOffset: 0, compressedSize: .max, uncompressedSize: 0),
            .init(chunkType: unknown, fileOffset: 16, compressedSize: UInt64(Int.max), uncompressedSize: 0),
            .init(chunkType: unknown, fileOffset: 1 << 63, compressedSize: 0, uncompressedSize: 0),
        ]
        for phantom in phantoms {
            let fixture = makeFixture(phantomEntries: [phantom], computeHash: false)
            XCTAssertNoThrow(try UntoldReader().readAsset(from: fixture.fileData), "the reader accepts the entry")
            XCTAssertEqual(try UntoldAssetPatcher.gaussianAssets(in: fixture.fileData), [:])
            XCTAssertThrowsError(try UntoldAssetPatcher.settingGaussianAsset(.init(payloadPath: "chair.untoldgs"), onEntity: 0, in: fixture.fileData), "\(phantom)") { error in
                XCTAssertEqual(error as? UntoldAssetPatcher.Error, .corruptFile("chunk 32767 points outside the file"))
            }
            let linked = makeFixture(gaussianRecords: [.init(entityId: 0, payloadPathOffset: 0)], phantomEntries: [phantom])
            XCTAssertThrowsError(try UntoldAssetPatcher.removingGaussianAsset(onEntity: 0, in: linked.fileData), "\(phantom)") { error in
                XCTAssertEqual(error as? UntoldAssetPatcher.Error, .corruptFile("chunk 32767 points outside the file"))
            }
        }

        // An in-range entry of an unknown type is copied like any other chunk.
        let inRange = UntoldChunkEntryV1(chunkType: unknown, fileOffset: 0, compressedSize: 16, uncompressedSize: 16)
        let fixture = makeFixture(phantomEntries: [inRange])
        let patched = try UntoldAssetPatcher.settingGaussianAsset(.init(payloadPath: "chair.untoldgs"), onEntity: 0, in: fixture.fileData)
        let decoded = try UntoldReader().readAsset(from: patched)
        let copied = try XCTUnwrap(decoded.chunks.first { $0.chunkType == unknown })
        XCTAssertEqual(patched.subdata(in: Int(copied.fileOffset) ..< Int(copied.fileOffset) + 16), fixture.fileData.prefix(16))
    }

    // MARK: - Content hash

    func testContentHashMatchesTheExporterConvention() throws {
        let fixture = makeFixture(computeHash: true)
        let decoded = try UntoldReader().readAsset(from: fixture.fileData)
        let hash = try UntoldFormat.contentHash(of: decoded.chunks, in: fixture.fileData)
        XCTAssertEqual(Array(hash), fixture.header.contentHash)

        // Ascending chunk type, whatever the table order: the same hash from a shuffled table.
        let shuffled = try UntoldFormat.contentHash(of: decoded.chunks.reversed(), in: fixture.fileData)
        XCTAssertEqual(shuffled, hash)

        var outOfBounds = decoded.chunks
        outOfBounds[0].compressedSize = UInt64(fixture.fileData.count)
        XCTAssertThrowsError(try UntoldFormat.contentHash(of: outOfBounds, in: fixture.fileData))
        outOfBounds[0].compressedSize = .max
        XCTAssertThrowsError(try UntoldFormat.contentHash(of: outOfBounds, in: fixture.fileData), "sizes beyond Int throw, not trap")
        outOfBounds[0].compressedSize = 0
        outOfBounds[0].fileOffset = 1 << 63
        XCTAssertThrowsError(try UntoldFormat.contentHash(of: outOfBounds, in: fixture.fileData))
    }

    // MARK: - Through the loader

    func testPatchedFileLoadsWithTheLinkOnItsNode() throws {
        let directory = try makeTemporaryDirectory()
        let fixture = makeFixture(computeHash: true)
        let link = UntoldAssetPatcher.GaussianAssetLink(
            payloadPath: "Gaussians/chair.untoldgs",
            lodCount: 1,
            lodSplatCounts: [150_000],
            lodSwitchScreenHeights: [0],
            occluderShrinkMeters: 0.03,
            exposureOffsetEV: 0.5,
            swapDistanceMeters: 12
        )
        let patched = try UntoldAssetPatcher.settingGaussianAsset(link, onEntity: 0, in: fixture.fileData)
        let untoldURL = directory.appendingPathComponent("chair.untold")
        try patched.write(to: untoldURL)
        let payloadDirectory = directory.appendingPathComponent("Gaussians")
        try FileManager.default.createDirectory(at: payloadDirectory, withIntermediateDirectories: true)
        try Data([0]).write(to: payloadDirectory.appendingPathComponent("chair.untoldgs"))

        let asset = try NativeFormatLoader().loadAssetSync(from: untoldURL)
        let node = try XCTUnwrap(asset.nodes.first { $0.id == 0 })
        let runtimeLink = try XCTUnwrap(node.gaussianAsset)
        XCTAssertEqual(runtimeLink.payloadURL.standardizedFileURL, payloadDirectory.appendingPathComponent("chair.untoldgs").standardizedFileURL)
        XCTAssertEqual(runtimeLink.flags, UntoldGaussianAssetFlags.meshTwin)
        XCTAssertEqual(runtimeLink.lodCount, 1)
        XCTAssertEqual(runtimeLink.lodSplatCounts, [150_000])
        XCTAssertEqual(runtimeLink.lodSwitchScreenHeights, [0])
        XCTAssertEqual(runtimeLink.occluderShrinkMeters, 0.03)
        XCTAssertEqual(runtimeLink.exposureOffsetEV, 0.5)
        XCTAssertEqual(runtimeLink.swapDistanceMeters, 12)
    }

    /// A file the real exporter wrote (with a content hash) survives the round trip: every chunk
    /// but the two the patcher owns is byte-identical, the hash is valid and the loader sees the link.
    func testRealCookedFixtureRoundTrips() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("UntoldEngineRenderTests/Resources/Models/singlecube/singlecube.untold")
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw XCTSkip("cooked fixture not found at \(sourceURL.path)")
        }
        let original = try Data(contentsOf: sourceURL)
        let originalAsset = try UntoldReader().readAsset(from: original)
        XCTAssertTrue(originalAsset.header.contentHash.contains { $0 != 0 }, "The exporter writes a hash")
        XCTAssertTrue(originalAsset.gaussianAssets.isEmpty)
        let entityId = try XCTUnwrap(originalAsset.entities.first?.entityId)

        let link = UntoldAssetPatcher.GaussianAssetLink(payloadPath: "singlecube.untoldgs", lodCount: 1, lodSplatCounts: [4096], lodSwitchScreenHeights: [0], swapDistanceMeters: 8)
        let patched = try UntoldAssetPatcher.settingGaussianAsset(link, onEntity: entityId, in: original)
        let decoded = try UntoldReader().readAsset(from: patched)
        XCTAssertEqual(try UntoldAssetPatcher.gaussianAssets(in: patched), [entityId: link])
        XCTAssertEqual(decoded.entities, originalAsset.entities)
        XCTAssertEqual(decoded.meshes, originalAsset.meshes)
        XCTAssertEqual(decoded.materials, originalAsset.materials)
        XCTAssertEqual(decoded.textures, originalAsset.textures)
        assertOtherChunksPreserved(original: original, patched: patched, except: [.stringTable, .gaussianAssetTable])
        assertAligned(decoded.chunks)
        try assertContentHashValid(patched)

        let directory = try makeTemporaryDirectory()
        let untoldURL = directory.appendingPathComponent("singlecube.untold")
        try patched.write(to: untoldURL)
        let asset = try NativeFormatLoader().loadAssetSync(from: untoldURL)
        let node = try XCTUnwrap(asset.nodes.first { $0.id == entityId })
        XCTAssertEqual(node.gaussianAsset?.payloadURL.lastPathComponent, "singlecube.untoldgs")
        XCTAssertEqual(node.gaussianAsset?.swapDistanceMeters, 8)

        let removed = try UntoldAssetPatcher.removingGaussianAsset(onEntity: entityId, in: patched)
        XCTAssertEqual(try UntoldReader().readAsset(from: removed).chunks.count, originalAsset.chunks.count)
        try assertContentHashValid(removed)
    }

    // MARK: - Assertions

    /// Every chunk not in `except` has the same stored bytes (and entry fields other than the
    /// offset) before and after the patch.
    private func assertOtherChunksPreserved(original: Data, patched: Data, except: Set<UntoldChunkType>, file: StaticString = #filePath, line: UInt = #line) {
        guard let before = try? UntoldReader().readAsset(from: original), let after = try? UntoldReader().readAsset(from: patched) else {
            return XCTFail("both files must read", file: file, line: line)
        }
        for entry in before.chunks where !except.contains(entry.chunkType) {
            guard let counterpart = after.chunks.first(where: { $0.chunkType == entry.chunkType }) else {
                XCTFail("chunk \(entry.chunkType.rawValue) is missing after the patch", file: file, line: line)
                continue
            }
            XCTAssertEqual(counterpart.compressionType, entry.compressionType, "chunk \(entry.chunkType.rawValue)", file: file, line: line)
            XCTAssertEqual(counterpart.compressedSize, entry.compressedSize, "chunk \(entry.chunkType.rawValue)", file: file, line: line)
            XCTAssertEqual(counterpart.uncompressedSize, entry.uncompressedSize, "chunk \(entry.chunkType.rawValue)", file: file, line: line)
            XCTAssertEqual(counterpart.elementCount, entry.elementCount, "chunk \(entry.chunkType.rawValue)", file: file, line: line)
            let beforeBytes = original.subdata(in: Int(entry.fileOffset) ..< Int(entry.fileOffset + entry.compressedSize))
            let afterBytes = patched.subdata(in: Int(counterpart.fileOffset) ..< Int(counterpart.fileOffset + counterpart.compressedSize))
            XCTAssertEqual(afterBytes, beforeBytes, "stored bytes of chunk \(entry.chunkType.rawValue)", file: file, line: line)
        }
    }

    private func assertAligned(_ chunks: [UntoldChunkEntryV1], file: StaticString = #filePath, line: UInt = #line) {
        for chunk in chunks {
            XCTAssertEqual(chunk.fileOffset % UntoldFormat.fileAlignment, 0, "chunk \(chunk.chunkType.rawValue) at \(chunk.fileOffset)", file: file, line: line)
        }
    }

    /// The header hash is non-zero and is the SHA-256 the exporter convention defines, computed
    /// here independently of `UntoldFormat.contentHash`.
    private func assertContentHashValid(_ fileData: Data, file: StaticString = #filePath, line: UInt = #line) throws {
        let decoded = try UntoldReader().readAsset(from: fileData)
        XCTAssertTrue(decoded.header.contentHash.contains { $0 != 0 }, "hash present", file: file, line: line)
        var input = Data()
        for chunk in decoded.chunks.sorted(by: { $0.chunkType.rawValue < $1.chunkType.rawValue }) {
            input.append(fileData.subdata(in: Int(chunk.fileOffset) ..< Int(chunk.fileOffset + chunk.compressedSize)))
        }
        XCTAssertEqual(decoded.header.contentHash, Array(SHA256.hash(data: input)), file: file, line: line)
    }

    private func range(of string: String, in table: Data) -> Range<Data.Index>? {
        table.range(of: Data(string.utf8) + [0])
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("UntoldAssetPatcherTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        temporaryDirectories.append(url)
        return url
    }

    // MARK: - Fixture

    private struct Fixture {
        var fileData: Data
        var header: UntoldFileHeaderV1
        var chunkEntries: [UntoldChunkEntryV1]
        var stringTableData: Data
        var stringOffsets: [String: UInt32]
        var entity: UntoldEntityRecordV1
    }

    /// A tile with `entityCount` one-triangle entities, LZ4-compressed vertex and index chunks
    /// (to prove the patcher copies stored bytes rather than re-encoding), optional extra strings
    /// and an optional pre-existing gaussianAsset table. That table sits right after the entity
    /// table — chunk order [1, 2, 25, 3, 4, 5, 6, 7] — so the file order differs from the
    /// ascending-type order the hash uses and a patcher that re-sorted or appended would show.
    /// `phantomEntries` are chunk-table entries written without a payload (the reader ignores
    /// unknown core chunk types), for entries that point outside the file.
    private func makeFixture(
        entityCount: Int = 1,
        extraStrings: [String] = [],
        gaussianRecords: [UntoldGaussianAssetRecordV1] = [],
        phantomEntries: [UntoldChunkEntryV1] = [],
        computeHash: Bool = false
    ) -> Fixture {
        var strings = ["root_entity", "mesh_0", "mat_0", "albedo.ktx2"]
        strings.append(contentsOf: (1 ..< entityCount).map { "entity_\($0)" })
        strings.append(contentsOf: extraStrings)
        let stringTable = makeStringTable(strings)
        let bounds = UntoldAABB(min: SIMD3<Float>(-1, -1, -1), max: SIMD3<Float>(1, 1, 1))

        let vertexWriter = UntoldBinaryWriter()
        for position in [SIMD3<Float>(-1, -1, 0), SIMD3<Float>(1, -1, 0), SIMD3<Float>(0, 1, 0)] {
            UntoldPBRStaticVertexV1(
                position: position,
                normalPacked: UntoldVertexPacking.packNormal(SIMD3<Float>(0, 0, 1)),
                tangentPacked: UntoldVertexPacking.packTangent(SIMD3<Float>(1, 0, 0), handedness: 1)
            ).encode(to: vertexWriter)
        }
        let vertexData = vertexWriter.data
        let indexWriter = UntoldBinaryWriter()
        for index in [0, 1, 2] as [UInt16] {
            indexWriter.writeUInt16LE(index)
        }
        let indexData = indexWriter.data

        var entities: [UntoldEntityRecordV1] = []
        var meshes: [UntoldMeshRecordV1] = []
        for index in 0 ..< entityCount {
            let name = index == 0 ? "root_entity" : "entity_\(index)"
            entities.append(UntoldEntityRecordV1(
                entityId: UInt32(index),
                nameOffset: stringTable.offsets[name]!,
                firstMeshRecordIndex: UInt32(index),
                meshRecordCount: 1,
                localBounds: bounds,
                worldBounds: bounds
            ))
            meshes.append(UntoldMeshRecordV1(
                entityId: UInt32(index),
                meshNameOffset: stringTable.offsets["mesh_0"]!,
                materialIndex: 0,
                indexType: .uint16,
                vertexCount: 3,
                indexCount: 3,
                vertexStrideBytes: 32,
                vertexDataOffset: 0,
                indexDataOffset: 0,
                vertexDataSizeBytes: UInt64(vertexData.count),
                indexDataSizeBytes: UInt64(indexData.count),
                estimatedGPUBytes: UInt64(vertexData.count + indexData.count),
                localBounds: bounds
            ))
        }
        let material = UntoldMaterialRecordV1(nameOffset: stringTable.offsets["mat_0"]!, baseColorTextureIndex: 0)
        let texture = UntoldTextureRefRecordV1(
            nameOffset: stringTable.offsets["albedo.ktx2"]!,
            uriOffset: stringTable.offsets["albedo.ktx2"]!,
            textureFormat: .rgba8,
            width: 16,
            height: 16,
            mipCount: 1
        )

        var header = UntoldFileHeaderV1(
            fileType: .tile,
            chunkCount: 0,
            meshCount: UInt32(meshes.count),
            materialCount: 1,
            textureRefCount: 1,
            entityCount: UInt32(entities.count),
            vertexLayout: .pbrStaticV1,
            worldBounds: bounds
        )

        // (type, stored bytes, compression, uncompressed size, element count)
        var payloads: [(UntoldChunkType, Data, UntoldCompressionType, UInt64, UInt32)] = [
            (.stringTable, stringTable.data, .none, UInt64(stringTable.data.count), 0),
            (.entityTable, encodeRecords(entities), .none, UInt64(encodeRecords(entities).count), UInt32(entities.count)),
            (.meshTable, encodeRecords(meshes), .none, UInt64(encodeRecords(meshes).count), UInt32(meshes.count)),
            (.materialTable, encodeRecords([material]), .none, UInt64(encodeRecords([material]).count), 1),
            (.textureTable, encodeRecords([texture]), .none, UInt64(encodeRecords([texture]).count), 1),
            (.vertexData, lz4Compress(vertexData), .lz4, UInt64(vertexData.count), 0),
            (.indexData, lz4Compress(indexData), .lz4, UInt64(indexData.count), 0),
        ]
        if !gaussianRecords.isEmpty {
            let table = encodeRecords(gaussianRecords)
            payloads.insert((.gaussianAssetTable, table, .none, UInt64(table.count), UInt32(gaussianRecords.count)), at: 2)
        }
        header.chunkCount = UInt32(payloads.count + phantomEntries.count)
        if computeHash {
            let sorted = payloads.sorted { $0.0.rawValue < $1.0.rawValue }
            header.contentHash = Array(SHA256.hash(data: sorted.reduce(Data()) { $0 + $1.1 }))
        }

        let (fileData, entries) = buildFileData(header: header, payloads: payloads, phantomEntries: phantomEntries)
        return Fixture(
            fileData: fileData,
            header: header,
            chunkEntries: entries,
            stringTableData: stringTable.data,
            stringOffsets: stringTable.offsets,
            entity: entities[0]
        )
    }

    private func encodeRecords(_ records: [some UntoldBinaryEncodable]) -> Data {
        let writer = UntoldBinaryWriter()
        for record in records {
            record.encode(to: writer)
        }
        return writer.data
    }

    private func makeStringTable(_ strings: [String]) -> (data: Data, offsets: [String: UInt32]) {
        let writer = UntoldBinaryWriter()
        var offsets: [String: UInt32] = [:]
        for string in strings {
            offsets[string] = UInt32(writer.count)
            writer.writeNullTerminatedUTF8(string)
        }
        return (writer.data, offsets)
    }

    private func buildFileData(
        header: UntoldFileHeaderV1,
        payloads: [(UntoldChunkType, Data, UntoldCompressionType, UInt64, UInt32)],
        phantomEntries: [UntoldChunkEntryV1] = []
    ) -> (Data, [UntoldChunkEntryV1]) {
        let headerWriter = UntoldBinaryWriter()
        header.encode(to: headerWriter)
        let alignment = Int(UntoldFormat.fileAlignment)
        func aligned(_ value: Int) -> Int {
            let remainder = value % alignment
            return remainder == 0 ? value : value + (alignment - remainder)
        }

        var runningOffset = headerWriter.count + 40 * (payloads.count + phantomEntries.count)
        var entries: [UntoldChunkEntryV1] = []
        for (chunkType, storedBytes, compression, uncompressedSize, elementCount) in payloads {
            runningOffset = aligned(runningOffset)
            entries.append(UntoldChunkEntryV1(
                chunkType: chunkType,
                compressionType: compression,
                fileOffset: UInt64(runningOffset),
                compressedSize: UInt64(storedBytes.count),
                uncompressedSize: uncompressedSize,
                elementCount: elementCount
            ))
            runningOffset += storedBytes.count
        }
        entries.append(contentsOf: phantomEntries)

        let writer = UntoldBinaryWriter()
        header.encode(to: writer)
        for entry in entries {
            entry.encode(to: writer)
        }
        for (_, storedBytes, _, _, _) in payloads {
            writer.align(to: alignment)
            writer.writeData(storedBytes)
        }
        return (writer.data, entries)
    }

    /// COMPRESSION_LZ4_RAW, the algorithm the runtime decompresses.
    private func lz4Compress(_ input: Data) -> Data {
        let maxSize = max(input.count + 64, 128)
        var output = Data(count: maxSize)
        let written: Int = output.withUnsafeMutableBytes { outBuf in
            input.withUnsafeBytes { inBuf in
                compression_encode_buffer(
                    outBuf.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    maxSize,
                    inBuf.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    input.count,
                    nil,
                    COMPRESSION_LZ4_RAW
                )
            }
        }
        return output.prefix(written)
    }
}

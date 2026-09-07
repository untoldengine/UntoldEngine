//
//  GaussianLinkCommandTests.swift
//  UntoldEngineCLI
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import ArgumentParser
import Foundation
import simd
import UntoldEngine
@testable import UntoldEngineCLI
import XCTest

final class GaussianLinkCommandTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDown() {
        for url in temporaryDirectories {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryDirectories.removeAll()
        super.tearDown()
    }

    // MARK: - Stored path

    func testPayloadInsideTheAssetDirectoryIsStoredRelative() {
        let untold = URL(fileURLWithPath: "/Game/GameData/Models/Chair/chair.untold")
        XCTAssertEqual(
            GaussianLinkCommand.storedPayloadPath(payloadURL: URL(fileURLWithPath: "/Game/GameData/Models/Chair/chair.untoldgs"), untoldURL: untold).path,
            "chair.untoldgs"
        )
        let nested = GaussianLinkCommand.storedPayloadPath(payloadURL: URL(fileURLWithPath: "/Game/GameData/Models/Chair/Gaussians/chair.untoldgs"), untoldURL: untold)
        XCTAssertEqual(nested.path, "Gaussians/chair.untoldgs")
        XCTAssertTrue(nested.isRelative)
        let dotted = GaussianLinkCommand.storedPayloadPath(payloadURL: URL(fileURLWithPath: "/Game/GameData/Models/Chair/./Gaussians/../chair.untoldgs"), untoldURL: untold)
        XCTAssertEqual(dotted.path, "chair.untoldgs")
    }

    func testPayloadOutsideTheAssetDirectoryFallsBackToTheBasename() {
        let untold = URL(fileURLWithPath: "/Game/GameData/Models/Chair/chair.untold")
        let outside = GaussianLinkCommand.storedPayloadPath(payloadURL: URL(fileURLWithPath: "/Game/GameData/Gaussians/chair.untoldgs"), untoldURL: untold)
        XCTAssertEqual(outside.path, "chair.untoldgs")
        XCTAssertFalse(outside.isRelative)
        // A sibling directory whose name starts the same is not "inside".
        let lookalike = GaussianLinkCommand.storedPayloadPath(payloadURL: URL(fileURLWithPath: "/Game/GameData/Models/ChairOld/chair.untoldgs"), untoldURL: untold)
        XCTAssertFalse(lookalike.isRelative)
    }

    // MARK: - Argument validation

    func testArgumentCombinations() {
        XCTAssertNoThrow(try GaussianLinkCommand.parse(["--untold", "a.untold", "--entity", "0", "--payload", "a.untoldgs", "--in-place"]))
        XCTAssertNoThrow(try GaussianLinkCommand.parse(["--untold", "a.untold", "--entity", "0", "--remove", "--output", "b.untold"]))
        XCTAssertNoThrow(try GaussianLinkCommand.parse(["--untold", "a.untold", "--list"]))
        XCTAssertNoThrow(try GaussianLinkCommand.parse(["--untold", "a.untold", "--entity", "0", "--payload", "a.untoldgs", "--swap-distance", "8", "--exposure-offset=-0.5", "--output", "b.untold"]))

        XCTAssertThrowsError(try GaussianLinkCommand.parse(["--untold", "a.untold", "--entity", "0", "--payload", "a.untoldgs"]), "needs --in-place or --output")
        XCTAssertThrowsError(try GaussianLinkCommand.parse(["--untold", "a.untold", "--entity", "0", "--payload", "a.untoldgs", "--in-place", "--output", "b.untold"]), "not both")
        XCTAssertThrowsError(try GaussianLinkCommand.parse(["--untold", "a.untold", "--payload", "a.untoldgs", "--in-place"]), "needs --entity")
        XCTAssertThrowsError(try GaussianLinkCommand.parse(["--untold", "a.untold", "--entity", "0", "--in-place"]), "needs --payload or --remove")
        XCTAssertThrowsError(try GaussianLinkCommand.parse(["--untold", "a.untold", "--entity", "0", "--remove", "--payload", "a.untoldgs", "--in-place"]), "remove takes no payload")
        XCTAssertThrowsError(try GaussianLinkCommand.parse(["--untold", "a.untold", "--list", "--remove"]), "list is alone")
        XCTAssertThrowsError(try GaussianLinkCommand.parse(["--entity", "0", "--list"]), "untold is required")
    }

    // MARK: - Set, list, remove

    func testLinkSetListAndRemoveOnAFixture() throws {
        let directory = try makeTemporaryDirectory()
        let untoldURL = directory.appendingPathComponent("chair.untold")
        try makeUntoldFixture().write(to: untoldURL)
        let payloadURL = directory.appendingPathComponent("Gaussians").appendingPathComponent("chair.untoldgs")
        try FileManager.default.createDirectory(at: payloadURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try makePayload(splatCount: 300).write(to: payloadURL)

        XCTAssertEqual(try GaussianLinkCommand.listing(of: Data(contentsOf: untoldURL)), ["no gaussianAsset links"])

        let stored = GaussianLinkCommand.storedPayloadPath(payloadURL: payloadURL, untoldURL: untoldURL)
        XCTAssertEqual(stored.path, "Gaussians/chair.untoldgs")
        let link = try GaussianLinkCommand.makeLink(payloadURL: payloadURL, storedPath: stored.path, swapDistance: 8, occluderShrink: 0.03, exposureOffset: -0.5)
        XCTAssertEqual(link.lodCount, 1)
        XCTAssertEqual(link.lodSplatCounts, [300])
        XCTAssertEqual(link.lodSwitchScreenHeights, [0])
        XCTAssertEqual(link.flags, UntoldGaussianAssetFlags.meshTwin)

        let patched = try GaussianLinkCommand.setting(link, entity: 0, in: Data(contentsOf: untoldURL))
        XCTAssertEqual(try UntoldAssetPatcher.gaussianAssets(in: patched), [0: link])
        let lines = try GaussianLinkCommand.listing(of: patched)
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].hasPrefix("entity 0: Gaussians/chair.untoldgs [meshTwin] 1 level [300], swap 8.0 m"), lines[0])

        // The loader resolves the stored path next to the file.
        try patched.write(to: untoldURL)
        let asset = try NativeFormatLoader().loadAssetSync(from: untoldURL)
        XCTAssertEqual(asset.nodes.first { $0.id == 0 }?.gaussianAsset?.payloadURL.standardizedFileURL, payloadURL.standardizedFileURL)

        let removed = try GaussianLinkCommand.removing(entity: 0, from: patched)
        XCTAssertEqual(try GaussianLinkCommand.listing(of: removed), ["no gaussianAsset links"])

        XCTAssertThrowsError(try GaussianLinkCommand.setting(link, entity: 7, in: patched)) { error in
            XCTAssertEqual((error as? GaussianLinkError)?.errorDescription, "entity 7 is not in the entity table")
        }
    }

    func testAPayloadThatIsNotAVersion3UntoldgsIsRejected() throws {
        let directory = try makeTemporaryDirectory()
        let payloadURL = directory.appendingPathComponent("chair.untoldgs")
        var bytes = try makePayload(splatCount: 10)
        bytes.replaceSubrange(4 ..< 8, with: [2, 0, 0, 0])
        try bytes.write(to: payloadURL)

        XCTAssertThrowsError(try GaussianLinkCommand.makeLink(payloadURL: payloadURL, storedPath: "chair.untoldgs", swapDistance: 0, occluderShrink: 0.02, exposureOffset: 0)) { error in
            guard case .invalidPayload? = error as? GaussianLinkError else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    // MARK: - Fixtures

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("GaussianLinkCommandTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        temporaryDirectories.append(url)
        return url
    }

    private func makePayload(splatCount: Int) throws -> Data {
        let splats = (0 ..< splatCount).map { index in
            UntoldGSSplat(
                position: SIMD3<Float>(Float(index) * 0.01, Float(index % 7) * 0.02, 0),
                scale: SIMD3<Float>(repeating: 0.05),
                rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                color: SIMD3<Float>(0.5, 0.5, 0.5),
                opacity: 1
            )
        }
        var options = UntoldGSWriteOptions()
        options.log2ChunkSplats = 8
        return try UntoldGSFormat.write(splats: splats, options: options)
    }

    /// A one-entity, one-triangle tile with a zero content hash.
    private func makeUntoldFixture() -> Data {
        let stringWriter = UntoldBinaryWriter()
        var offsets: [String: UInt32] = [:]
        for string in ["root_entity", "mesh_0", "mat_0", "albedo.ktx2"] {
            offsets[string] = UInt32(stringWriter.count)
            stringWriter.writeNullTerminatedUTF8(string)
        }
        let bounds = UntoldAABB(min: SIMD3<Float>(-1, -1, -1), max: SIMD3<Float>(1, 1, 1))
        let entity = UntoldEntityRecordV1(entityId: 0, nameOffset: offsets["root_entity"]!, firstMeshRecordIndex: 0, meshRecordCount: 1, localBounds: bounds, worldBounds: bounds)
        let material = UntoldMaterialRecordV1(nameOffset: offsets["mat_0"]!, baseColorTextureIndex: 0)
        let texture = UntoldTextureRefRecordV1(nameOffset: offsets["albedo.ktx2"]!, uriOffset: offsets["albedo.ktx2"]!, textureFormat: .rgba8, width: 16, height: 16, mipCount: 1)
        let vertexWriter = UntoldBinaryWriter()
        for position in [SIMD3<Float>(-1, -1, 0), SIMD3<Float>(1, -1, 0), SIMD3<Float>(0, 1, 0)] {
            UntoldPBRStaticVertexV1(
                position: position,
                normalPacked: UntoldVertexPacking.packNormal(SIMD3<Float>(0, 0, 1)),
                tangentPacked: UntoldVertexPacking.packTangent(SIMD3<Float>(1, 0, 0), handedness: 1)
            ).encode(to: vertexWriter)
        }
        let indexWriter = UntoldBinaryWriter()
        for index in [0, 1, 2] as [UInt16] {
            indexWriter.writeUInt16LE(index)
        }
        let mesh = UntoldMeshRecordV1(
            entityId: 0,
            meshNameOffset: offsets["mesh_0"]!,
            materialIndex: 0,
            indexType: .uint16,
            vertexCount: 3,
            indexCount: 3,
            vertexStrideBytes: 32,
            vertexDataOffset: 0,
            indexDataOffset: 0,
            vertexDataSizeBytes: UInt64(vertexWriter.count),
            indexDataSizeBytes: UInt64(indexWriter.count),
            estimatedGPUBytes: UInt64(vertexWriter.count + indexWriter.count),
            localBounds: bounds
        )

        func encode(_ records: [some UntoldBinaryEncodable]) -> Data {
            let writer = UntoldBinaryWriter()
            for record in records {
                record.encode(to: writer)
            }
            return writer.data
        }
        let payloads: [(UntoldChunkType, Data, UInt32)] = [
            (.stringTable, stringWriter.data, 0),
            (.entityTable, encode([entity]), 1),
            (.meshTable, encode([mesh]), 1),
            (.materialTable, encode([material]), 1),
            (.textureTable, encode([texture]), 1),
            (.vertexData, vertexWriter.data, 0),
            (.indexData, indexWriter.data, 0),
        ]
        var header = UntoldFileHeaderV1(fileType: .tile, chunkCount: UInt32(payloads.count), meshCount: 1, materialCount: 1, textureRefCount: 1, entityCount: 1, vertexLayout: .pbrStaticV1, worldBounds: bounds)
        header.chunkCount = UInt32(payloads.count)

        let headerWriter = UntoldBinaryWriter()
        header.encode(to: headerWriter)
        let alignment = Int(UntoldFormat.fileAlignment)
        var runningOffset = headerWriter.count + 40 * payloads.count
        var entries: [UntoldChunkEntryV1] = []
        for (chunkType, data, elementCount) in payloads {
            if runningOffset % alignment != 0 {
                runningOffset += alignment - runningOffset % alignment
            }
            entries.append(UntoldChunkEntryV1(chunkType: chunkType, fileOffset: UInt64(runningOffset), compressedSize: UInt64(data.count), uncompressedSize: UInt64(data.count), elementCount: elementCount))
            runningOffset += data.count
        }
        let writer = UntoldBinaryWriter()
        header.encode(to: writer)
        for entry in entries {
            entry.encode(to: writer)
        }
        for (_, data, _) in payloads {
            writer.align(to: alignment)
            writer.writeData(data)
        }
        return writer.data
    }
}

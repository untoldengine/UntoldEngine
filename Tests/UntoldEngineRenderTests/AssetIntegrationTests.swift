//
//  AssetIntegrationTests.swift
//  UntoldEngine
//
//  Integration tests for reading real exported `.untold` assets from the
//  test resource bundle.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

final class AssetIntegrationTests: XCTestCase {
    func testReadsExportedRedplayerUntoldFile() throws {
        guard let url = Bundle.module.url(forResource: "redplayer", withExtension: "untold") else {
            XCTFail("Failed to locate redplayer.untold in test resources")
            return
        }

        let decoded = try UntoldReader().readAsset(from: url)

        XCTAssertGreaterThanOrEqual(decoded.header.formatVersion, UntoldFormat.minSupportedVersion)
        XCTAssertLessThanOrEqual(decoded.header.formatVersion, UntoldFormat.version)
        XCTAssertEqual(decoded.header.fileType, .tile)
        XCTAssertEqual(decoded.header.vertexLayout, .pbrStaticV1)

        XCTAssertFalse(decoded.chunks.isEmpty, "Expected at least one chunk")
        XCTAssertFalse(decoded.entities.isEmpty, "Expected at least one entity")
        XCTAssertFalse(decoded.meshes.isEmpty, "Expected at least one mesh")
        XCTAssertFalse(decoded.materials.isEmpty, "Expected at least one material")

        let requiredChunkTypes: Set<UntoldChunkType> = [
            .stringTable,
            .entityTable,
            .meshTable,
            .materialTable,
            .textureTable,
            .vertexData,
            .indexData,
        ]
        XCTAssertTrue(requiredChunkTypes.isSubset(of: Set(decoded.chunks.map(\.chunkType))))

        XCTAssertEqual(decoded.header.entityCount, UInt32(decoded.entities.count))
        XCTAssertEqual(decoded.header.meshCount, UInt32(decoded.meshes.count))
        XCTAssertEqual(decoded.header.materialCount, UInt32(decoded.materials.count))
        XCTAssertEqual(decoded.header.textureRefCount, UInt32(decoded.textures.count))

        for entity in decoded.entities {
            XCTAssertGreaterThanOrEqual(entity.meshRecordCount, 0)
            XCTAssertLessThanOrEqual(
                Int(entity.firstMeshRecordIndex + entity.meshRecordCount),
                decoded.meshes.count,
                "Entity mesh span must stay within mesh table bounds"
            )

            if entity.nameOffset != UntoldFormat.invalidIndex {
                let entityName = try decoded.string(at: entity.nameOffset)
                XCTAssertNotNil(entityName)
                XCTAssertFalse(entityName?.isEmpty ?? true)
            }
        }

        for mesh in decoded.meshes {
            XCTAssertLessThan(mesh.entityId, UInt32(decoded.entities.count), "Mesh entityId must reference an entity")
            XCTAssertEqual(mesh.vertexStrideBytes, 32, "V1 PBR static vertex layout must be 32 bytes")
            XCTAssertGreaterThan(mesh.vertexCount, 0)
            XCTAssertGreaterThan(mesh.indexCount, 0)
            XCTAssertGreaterThan(mesh.vertexDataSizeBytes, 0)
            XCTAssertGreaterThan(mesh.indexDataSizeBytes, 0)

            if mesh.meshNameOffset != UntoldFormat.invalidIndex {
                let meshName = try decoded.string(at: mesh.meshNameOffset)
                XCTAssertNotNil(meshName)
                XCTAssertFalse(meshName?.isEmpty ?? true)
            }

            if mesh.materialIndex != UntoldFormat.invalidIndex {
                XCTAssertLessThan(mesh.materialIndex, UInt32(decoded.materials.count))
            }
        }

        for material in decoded.materials {
            if material.nameOffset != UntoldFormat.invalidIndex {
                let materialName = try decoded.string(at: material.nameOffset)
                XCTAssertNotNil(materialName)
                XCTAssertFalse(materialName?.isEmpty ?? true)
            }
        }

        for texture in decoded.textures {
            if texture.uriOffset != UntoldFormat.invalidIndex {
                let uri = try decoded.string(at: texture.uriOffset)
                XCTAssertNotNil(uri)
                XCTAssertFalse(uri?.isEmpty ?? true)
            }
        }

        guard let vertexChunkEntry = decoded.chunks.first(where: { $0.chunkType == .vertexData }),
              let indexChunkEntry = decoded.chunks.first(where: { $0.chunkType == .indexData })
        else {
            XCTFail("Missing geometry chunks")
            return
        }

        let fileData = try Data(contentsOf: url)
        let vertexChunkStart = Int(vertexChunkEntry.fileOffset)
        let vertexChunkEnd = vertexChunkStart + Int(vertexChunkEntry.compressedSize)
        let vertexChunkData = fileData.subdata(in: vertexChunkStart ..< vertexChunkEnd)
        let vertexReader = UntoldBinaryReader(data: vertexChunkData)
        let firstVertex = try UntoldPBRStaticVertexV1.decode(from: vertexReader)

        XCTAssertTrue(firstVertex.position.x.isFinite)
        XCTAssertTrue(firstVertex.position.y.isFinite)
        XCTAssertTrue(firstVertex.position.z.isFinite)

        let unpackedNormal = UntoldVertexPacking.unpackNormal(firstVertex.normalPacked)
        let unpackedTangent = UntoldVertexPacking.unpackTangent(firstVertex.tangentPacked)
        XCTAssertGreaterThan(length(unpackedNormal), 0.5, "Decoded normal should be non-degenerate")
        XCTAssertGreaterThan(length(unpackedTangent.vector), 0.5, "Decoded tangent should be non-degenerate")
        XCTAssertTrue(abs(unpackedTangent.handedness) == 1.0)

        let indexChunkStart = Int(indexChunkEntry.fileOffset)
        let indexChunkEnd = indexChunkStart + Int(indexChunkEntry.compressedSize)
        let indexChunkData = fileData.subdata(in: indexChunkStart ..< indexChunkEnd)
        XCTAssertFalse(indexChunkData.isEmpty, "Index chunk should not be empty")

        let worldBounds = decoded.header.worldBounds
        XCTAssertLessThanOrEqual(worldBounds.min.x, worldBounds.max.x)
        XCTAssertLessThanOrEqual(worldBounds.min.y, worldBounds.max.y)
        XCTAssertLessThanOrEqual(worldBounds.min.z, worldBounds.max.z)
    }
}

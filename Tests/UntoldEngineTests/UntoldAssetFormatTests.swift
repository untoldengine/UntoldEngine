//
//  UntoldAssetFormatTests.swift
//  UntoldEngineTests
//
//  Golden-file roundtrip tests for the cooked `.untold` runtime asset container.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest
import simd
@testable import UntoldEngine

final class UntoldAssetFormatTests: XCTestCase {
    func testTinyUntoldGoldenFileRoundtrip() throws {
        let fixture = makeTinyFixture()
        let decoded = try UntoldReader().readAsset(from: fixture.fileData)

        XCTAssertEqual(decoded.header.fileType, .tile)
        XCTAssertEqual(decoded.header.chunkCount, UInt32(fixture.chunkPayloads.count))
        XCTAssertEqual(decoded.chunks, fixture.chunkEntries)
        XCTAssertEqual(decoded.entities, [fixture.entity])
        XCTAssertEqual(decoded.meshes, [fixture.mesh])
        XCTAssertEqual(decoded.materials, [fixture.material])
        XCTAssertEqual(decoded.textures, [fixture.texture])
        XCTAssertEqual(try decoded.string(at: fixture.entity.nameOffset), "root_entity")
        XCTAssertEqual(try decoded.string(at: fixture.mesh.meshNameOffset), "mesh_0")
        XCTAssertEqual(try decoded.string(at: fixture.material.nameOffset), "mat_0")

        guard let vertexChunkEntry = decoded.chunks.first(where: { $0.chunkType == .vertexData }) else {
            XCTFail("Missing vertex data chunk")
            return
        }
        let vertexChunkStart = Int(vertexChunkEntry.fileOffset)
        let vertexChunkEnd = vertexChunkStart + Int(vertexChunkEntry.compressedSize)
        let vertexChunkBytes = fixture.fileData.subdata(in: vertexChunkStart ..< vertexChunkEnd)
        let vertexReader = UntoldBinaryReader(data: vertexChunkBytes)
        let decodedVertex = try UntoldPBRStaticVertexV1.decode(from: vertexReader)
        XCTAssertEqual(decodedVertex, fixture.vertex)
    }

    func testRejectsInvalidMagic() throws {
        var fixture = makeTinyFixture()
        fixture.fileData[0] = 0x58

        XCTAssertThrowsError(try UntoldReader().readAsset(from: fixture.fileData)) { error in
            XCTAssertEqual(error as? UntoldValidationError, .invalidMagic)
        }
    }

    func testRejectsUnsupportedVersion() throws {
        let fixture = makeTinyFixture(mutator: { header, _, _, _, _, _, _ in
            header.formatVersion = 999
        })

        XCTAssertThrowsError(try UntoldReader().readAsset(from: fixture.fileData)) { error in
            XCTAssertEqual(error as? UntoldValidationError, .unsupportedVersion(999))
        }
    }

    func testRejectsMissingRequiredChunk() throws {
        let fixture = makeTinyFixture(removedChunkTypes: [.textureTable])

        XCTAssertThrowsError(try UntoldReader().readAsset(from: fixture.fileData)) { error in
            XCTAssertEqual(error as? UntoldValidationError, .missingRequiredChunk(.textureTable))
        }
    }

    func testRejectsMisalignedChunkOffset() throws {
        let fixture = makeTinyFixture(chunkEntryMutator: { entries in
            entries[0].fileOffset += 1
        })

        XCTAssertThrowsError(try UntoldReader().readAsset(from: fixture.fileData)) { error in
            XCTAssertEqual(error as? UntoldValidationError, .misalignedChunkOffset(fixture.chunkEntries[0].fileOffset))
        }
    }

    func testStringOffsetOutOfBoundsIsRejected() throws {
        let decoded = try UntoldReader().readAsset(from: makeTinyFixture().fileData)

        XCTAssertThrowsError(try decoded.string(at: 10_000)) { error in
            guard case let UntoldBinaryDecodingError.outOfBounds(offset, _, _) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(offset, 10_000)
        }
    }

    func testUnterminatedStringIsRejected() throws {
        let decoded = try UntoldReader().readAsset(from: makeTinyFixture().fileData)
        let badReader = UntoldBinaryReader(data: Data("unterminated".utf8))

        XCTAssertThrowsError(try badReader.readNullTerminatedUTF8String(at: 0)) { error in
            XCTAssertEqual(error as? UntoldBinaryDecodingError, .unterminatedString(offset: 0))
        }
        XCTAssertEqual(try decoded.string(at: UntoldFormat.invalidIndex), nil)
    }

    func testRejectsInvalidMaterialIndex() throws {
        let fixture = makeTinyFixture(meshMutator: { mesh in
            mesh.materialIndex = 99
        })

        XCTAssertThrowsError(try UntoldReader().readAsset(from: fixture.fileData)) { error in
            XCTAssertEqual(error as? UntoldValidationError, .invalidMaterialIndex(99))
        }
    }

    func testPackedNormalAndTangentRoundtripWithinTolerance() {
        let normal = simd_normalize(SIMD3<Float>(0.25, 0.9, -0.35))
        let tangent = simd_normalize(SIMD3<Float>(-0.7, 0.1, 0.7))

        let packedNormal = UntoldVertexPacking.packNormal(normal)
        let packedTangent = UntoldVertexPacking.packTangent(tangent, handedness: -1)

        let unpackedNormal = UntoldVertexPacking.unpackNormal(packedNormal)
        let unpackedTangent = UntoldVertexPacking.unpackTangent(packedTangent)

        XCTAssertLessThan(length(unpackedNormal - normal), 0.01)
        XCTAssertLessThan(length(unpackedTangent.vector - tangent), 0.01)
        XCTAssertEqual(unpackedTangent.handedness, -1)
    }

    func testRejectsInvalidIndexDataSize() throws {
        let fixture = makeTinyFixture(meshMutator: { mesh in
            mesh.indexDataSizeBytes = 4
        })

        XCTAssertThrowsError(try UntoldReader().readAsset(from: fixture.fileData)) { error in
            XCTAssertEqual(
                error as? UntoldValidationError,
                .invalidIndexDataSize(expected: 6, actual: 4)
            )
        }
    }

    func testMultipleEntitiesAndMeshesRoundtrip() throws {
        let fixture = makeTwoEntityFixture()
        let decoded = try UntoldReader().readAsset(from: fixture.fileData)

        XCTAssertEqual(decoded.entities.count, 2)
        XCTAssertEqual(decoded.meshes.count, 2)
        XCTAssertEqual(try decoded.string(at: decoded.entities[0].nameOffset), "entity_a")
        XCTAssertEqual(try decoded.string(at: decoded.entities[1].nameOffset), "entity_b")
    }

    private func encodeChunk<T: UntoldBinaryEncodable>(_ records: [T]) -> Data {
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

    private func align(_ value: Int, to alignment: Int) -> Int {
        guard alignment > 0 else { return value }
        let remainder = value % alignment
        return remainder == 0 ? value : value + (alignment - remainder)
    }

    private struct TinyFixture {
        var fileData: Data
        var chunkPayloads: [(type: UntoldChunkType, data: Data, elementCount: UInt32)]
        var chunkEntries: [UntoldChunkEntryV1]
        var entity: UntoldEntityRecordV1
        var mesh: UntoldMeshRecordV1
        var material: UntoldMaterialRecordV1
        var texture: UntoldTextureRefRecordV1
        var vertex: UntoldPBRStaticVertexV1
    }

    private func makeTinyFixture(
        removedChunkTypes: Set<UntoldChunkType> = [],
        mutator: ((inout UntoldFileHeaderV1, inout UntoldEntityRecordV1, inout UntoldMeshRecordV1, inout UntoldMaterialRecordV1, inout UntoldTextureRefRecordV1, inout UntoldPBRStaticVertexV1, inout Data) -> Void)? = nil,
        meshMutator: ((inout UntoldMeshRecordV1) -> Void)? = nil,
        chunkEntryMutator: ((inout [UntoldChunkEntryV1]) -> Void)? = nil
    ) -> TinyFixture {
        let strings = ["root_entity", "mesh_0", "mat_0", "albedo.ktx2"]
        let stringTable = makeStringTable(strings)
        let entityBounds = UntoldAABB(min: SIMD3<Float>(-1, -1, -1), max: SIMD3<Float>(1, 1, 1))

        var entity = UntoldEntityRecordV1(
            entityId: 0,
            parentEntityId: UntoldFormat.invalidIndex,
            nameOffset: stringTable.offsets["root_entity"] ?? UntoldFormat.invalidIndex,
            firstMeshRecordIndex: 0,
            meshRecordCount: 1,
            flags: 0,
            localBounds: entityBounds,
            worldBounds: entityBounds,
            localTransform: matrix_identity_float4x4
        )

        var material = UntoldMaterialRecordV1(
            nameOffset: stringTable.offsets["mat_0"] ?? UntoldFormat.invalidIndex,
            flags: 0,
            baseColorFactor: SIMD4<Float>(1, 0.5, 0.25, 1),
            emissiveFactor: SIMD3<Float>(0.1, 0.2, 0.3),
            normalScale: 1.0,
            metallicFactor: 0.9,
            roughnessFactor: 0.4,
            occlusionStrength: 1.0,
            alphaCutoff: 0.5,
            baseColorTextureIndex: 0,
            normalTextureIndex: UntoldFormat.invalidIndex,
            metallicTextureIndex: UntoldFormat.invalidIndex,
            roughnessTextureIndex: UntoldFormat.invalidIndex,
            emissiveTextureIndex: UntoldFormat.invalidIndex,
            occlusionTextureIndex: UntoldFormat.invalidIndex
        )

        var texture = UntoldTextureRefRecordV1(
            nameOffset: stringTable.offsets["albedo.ktx2"] ?? UntoldFormat.invalidIndex,
            uriOffset: stringTable.offsets["albedo.ktx2"] ?? UntoldFormat.invalidIndex,
            textureFormat: .rgba8,
            flags: 0,
            width: 512,
            height: 512,
            mipCount: 10
        )

        var vertex = UntoldPBRStaticVertexV1(
            position: SIMD3<Float>(1, 2, 3),
            normalPacked: UntoldVertexPacking.packNormal(SIMD3<Float>(0, 1, 0)),
            tangentPacked: UntoldVertexPacking.packTangent(SIMD3<Float>(1, 0, 0), handedness: 1),
            uv0: SIMD2<UInt16>(123, 456),
            uv1: SIMD2<UInt16>(0, 0),
            color0: SIMD4<UInt8>(255, 128, 64, 255)
        )

        let vertexWriter = UntoldBinaryWriter()
        vertex.encode(to: vertexWriter)
        var vertexData = vertexWriter.data

        let indexWriter = UntoldBinaryWriter()
        indexWriter.writeUInt16LE(0)
        indexWriter.writeUInt16LE(1)
        indexWriter.writeUInt16LE(2)
        let indexData = indexWriter.data

        var mesh = UntoldMeshRecordV1(
            entityId: 0,
            meshNameOffset: stringTable.offsets["mesh_0"] ?? UntoldFormat.invalidIndex,
            materialIndex: 0,
            indexType: .uint16,
            vertexCount: 1,
            indexCount: 3,
            vertexStrideBytes: 32,
            flags: 0,
            vertexDataOffset: 0,
            indexDataOffset: 0,
            vertexDataSizeBytes: UInt64(vertexData.count),
            indexDataSizeBytes: UInt64(indexData.count),
            estimatedGPUBytes: UInt64(vertexData.count + indexData.count),
            localBounds: entityBounds
        )

        meshMutator?(&mesh)

        var header = UntoldFileHeaderV1(
            fileType: .tile,
            chunkCount: 0,
            meshCount: 1,
            materialCount: 1,
            textureRefCount: 1,
            entityCount: 1,
            vertexLayout: .pbrStaticV1,
            worldBounds: entityBounds
        )

        mutator?(&header, &entity, &mesh, &material, &texture, &vertex, &vertexData)

        let chunkPayloads = buildChunkPayloads(
            stringTableData: stringTable.data,
            entities: [entity],
            meshes: [mesh],
            materials: [material],
            textures: [texture],
            vertexData: vertexData,
            indexData: indexData,
            removedChunkTypes: removedChunkTypes
        )

        header.chunkCount = UInt32(chunkPayloads.count)
        let (fileData, chunkEntries) = buildFileData(header: header, chunkPayloads: chunkPayloads, chunkEntryMutator: chunkEntryMutator)

        return TinyFixture(
            fileData: fileData,
            chunkPayloads: chunkPayloads,
            chunkEntries: chunkEntries,
            entity: entity,
            mesh: mesh,
            material: material,
            texture: texture,
            vertex: vertex
        )
    }

    private func makeTwoEntityFixture() -> TinyFixture {
        let stringTable = makeStringTable(["entity_a", "entity_b", "mesh_a", "mesh_b", "mat_0", "albedo.ktx2"])
        let bounds = UntoldAABB(min: SIMD3<Float>(-1, -1, -1), max: SIMD3<Float>(1, 1, 1))
        let entityA = UntoldEntityRecordV1(
            entityId: 0,
            nameOffset: stringTable.offsets["entity_a"]!,
            firstMeshRecordIndex: 0,
            meshRecordCount: 1,
            localBounds: bounds,
            worldBounds: bounds
        )
        let entityB = UntoldEntityRecordV1(
            entityId: 1,
            nameOffset: stringTable.offsets["entity_b"]!,
            firstMeshRecordIndex: 1,
            meshRecordCount: 1,
            localBounds: bounds,
            worldBounds: bounds
        )
        let material = UntoldMaterialRecordV1(nameOffset: stringTable.offsets["mat_0"]!, baseColorTextureIndex: 0)
        let texture = UntoldTextureRefRecordV1(
            nameOffset: stringTable.offsets["albedo.ktx2"]!,
            uriOffset: stringTable.offsets["albedo.ktx2"]!,
            textureFormat: .rgba8,
            width: 256,
            height: 256,
            mipCount: 1
        )
        let vertexA = UntoldPBRStaticVertexV1(
            position: SIMD3<Float>(0, 0, 0),
            normalPacked: UntoldVertexPacking.packNormal(SIMD3<Float>(0, 1, 0)),
            tangentPacked: UntoldVertexPacking.packTangent(SIMD3<Float>(1, 0, 0), handedness: 1)
        )
        let vertexB = UntoldPBRStaticVertexV1(
            position: SIMD3<Float>(1, 1, 1),
            normalPacked: UntoldVertexPacking.packNormal(SIMD3<Float>(0, 0, 1)),
            tangentPacked: UntoldVertexPacking.packTangent(SIMD3<Float>(1, 0, 0), handedness: 1)
        )
        let vertexWriter = UntoldBinaryWriter()
        vertexA.encode(to: vertexWriter)
        vertexB.encode(to: vertexWriter)
        let vertexData = vertexWriter.data
        let indexWriter = UntoldBinaryWriter()
        indexWriter.writeUInt16LE(0)
        indexWriter.writeUInt16LE(1)
        indexWriter.writeUInt16LE(2)
        indexWriter.writeUInt16LE(0)
        indexWriter.writeUInt16LE(1)
        indexWriter.writeUInt16LE(2)
        let indexData = indexWriter.data
        let meshA = UntoldMeshRecordV1(
            entityId: 0,
            meshNameOffset: stringTable.offsets["mesh_a"]!,
            materialIndex: 0,
            indexType: .uint16,
            vertexCount: 1,
            indexCount: 3,
            vertexStrideBytes: 32,
            vertexDataOffset: 0,
            indexDataOffset: 0,
            vertexDataSizeBytes: 32,
            indexDataSizeBytes: 6,
            estimatedGPUBytes: 38,
            localBounds: bounds
        )
        let meshB = UntoldMeshRecordV1(
            entityId: 1,
            meshNameOffset: stringTable.offsets["mesh_b"]!,
            materialIndex: 0,
            indexType: .uint16,
            vertexCount: 1,
            indexCount: 3,
            vertexStrideBytes: 32,
            vertexDataOffset: 32,
            indexDataOffset: 6,
            vertexDataSizeBytes: 32,
            indexDataSizeBytes: 6,
            estimatedGPUBytes: 38,
            localBounds: bounds
        )
        var header = UntoldFileHeaderV1(
            fileType: .tile,
            chunkCount: 0,
            meshCount: 2,
            materialCount: 1,
            textureRefCount: 1,
            entityCount: 2,
            vertexLayout: .pbrStaticV1,
            worldBounds: bounds
        )
        let chunkPayloads = buildChunkPayloads(
            stringTableData: stringTable.data,
            entities: [entityA, entityB],
            meshes: [meshA, meshB],
            materials: [material],
            textures: [texture],
            vertexData: vertexData,
            indexData: indexData
        )
        header.chunkCount = UInt32(chunkPayloads.count)
        let (fileData, chunkEntries) = buildFileData(header: header, chunkPayloads: chunkPayloads)
        return TinyFixture(fileData: fileData, chunkPayloads: chunkPayloads, chunkEntries: chunkEntries, entity: entityA, mesh: meshA, material: material, texture: texture, vertex: vertexA)
    }

    private func buildChunkPayloads(
        stringTableData: Data,
        entities: [UntoldEntityRecordV1],
        meshes: [UntoldMeshRecordV1],
        materials: [UntoldMaterialRecordV1],
        textures: [UntoldTextureRefRecordV1],
        vertexData: Data,
        indexData: Data,
        removedChunkTypes: Set<UntoldChunkType> = []
    ) -> [(type: UntoldChunkType, data: Data, elementCount: UInt32)] {
        let all: [(type: UntoldChunkType, data: Data, elementCount: UInt32)] = [
            (.stringTable, stringTableData, 0),
            (.entityTable, encodeChunk(entities), UInt32(entities.count)),
            (.meshTable, encodeChunk(meshes), UInt32(meshes.count)),
            (.materialTable, encodeChunk(materials), UInt32(materials.count)),
            (.textureTable, encodeChunk(textures), UInt32(textures.count)),
            (.vertexData, vertexData, 0),
            (.indexData, indexData, 0),
        ]
        return all.filter { !removedChunkTypes.contains($0.type) }
    }

    private func buildFileData(
        header: UntoldFileHeaderV1,
        chunkPayloads: [(type: UntoldChunkType, data: Data, elementCount: UInt32)],
        chunkEntryMutator: ((inout [UntoldChunkEntryV1]) -> Void)? = nil
    ) -> (Data, [UntoldChunkEntryV1]) {
        let headerWriter = UntoldBinaryWriter()
        header.encode(to: headerWriter)
        let headerData = headerWriter.data

        let chunkTableSize = MemoryLayout<UInt32>.size * 2 +
            MemoryLayout<UInt64>.size * 3 +
            MemoryLayout<UInt32>.size * 2
        let chunkTableBytes = chunkTableSize * chunkPayloads.count

        var runningOffset = headerData.count + chunkTableBytes
        var chunkEntries: [UntoldChunkEntryV1] = []
        chunkEntries.reserveCapacity(chunkPayloads.count)

        for chunk in chunkPayloads {
            runningOffset = align(runningOffset, to: Int(UntoldFormat.fileAlignment))
            chunkEntries.append(
                UntoldChunkEntryV1(
                    chunkType: chunk.type,
                    compressionType: .none,
                    fileOffset: UInt64(runningOffset),
                    compressedSize: UInt64(chunk.data.count),
                    uncompressedSize: UInt64(chunk.data.count),
                    elementCount: chunk.elementCount
                )
            )
            runningOffset += chunk.data.count
        }

        chunkEntryMutator?(&chunkEntries)

        let fileWriter = UntoldBinaryWriter()
        header.encode(to: fileWriter)
        for entry in chunkEntries {
            entry.encode(to: fileWriter)
        }
        for chunk in chunkPayloads {
            fileWriter.align(to: Int(UntoldFormat.fileAlignment))
            fileWriter.writeData(chunk.data)
        }
        return (fileWriter.data, chunkEntries)
    }
}

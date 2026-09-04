//
//  NativeFormatTests.swift
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

import Compression
import CryptoKit
import simd
@testable import UntoldEngine
import XCTest

final class NativeFormatTests: XCTestCase {
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

        XCTAssertThrowsError(try decoded.string(at: 10000)) { error in
            guard case let UntoldBinaryDecodingError.outOfBounds(offset, _, _) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(offset, 10000)
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

    func testOptionalArchitecturalEdgeIndexDataRoundtrip() throws {
        let edgeWriter = UntoldBinaryWriter()
        edgeWriter.writeUInt16LE(0)
        edgeWriter.writeUInt16LE(1)
        edgeWriter.writeUInt16LE(1)
        edgeWriter.writeUInt16LE(2)
        let edgeIndexData = edgeWriter.data

        let fixture = makeTinyFixture(
            edgeIndexData: edgeIndexData,
            meshMutator: { mesh in
                mesh.reserved0 = UInt64(4) << 32
            }
        )

        let decoded = try UntoldReader().readAsset(from: fixture.fileData)
        XCTAssertEqual(decoded.meshes[0].edgeIndexDataOffset, 0)
        XCTAssertEqual(decoded.meshes[0].edgeIndexCount, 4)

        let loaded = try NativeFormatLoader().loadAssetSync(from: writeFixtureToTemporaryFile(fixture.fileData))
        let primitive = try XCTUnwrap(loaded.nodes.first?.primitives.first)
        XCTAssertEqual(primitive.edgeIndexData, edgeIndexData)
        XCTAssertEqual(primitive.edgeIndexCount, 4)
    }

    func testMultipleEntitiesAndMeshesRoundtrip() throws {
        let fixture = makeTwoEntityFixture()
        let decoded = try UntoldReader().readAsset(from: fixture.fileData)

        XCTAssertEqual(decoded.entities.count, 2)
        XCTAssertEqual(decoded.meshes.count, 2)
        XCTAssertEqual(try decoded.string(at: decoded.entities[0].nameOffset), "entity_a")
        XCTAssertEqual(try decoded.string(at: decoded.entities[1].nameOffset), "entity_b")
    }

    func testLightAndCameraTablesRoundtripThroughRuntimeLoader() throws {
        let fixture = makeScenePayloadFixture()
        let decoded = try UntoldReader().readAsset(from: fixture.fileData)

        XCTAssertEqual(decoded.lights, [fixture.light, fixture.sunLight])
        XCTAssertEqual(decoded.cameras, [fixture.camera])
        XCTAssertEqual(try decoded.string(at: fixture.light.nameOffset), "Authored Spot")
        XCTAssertEqual(try decoded.string(at: fixture.sunLight.nameOffset), "Authored Sun")
        XCTAssertEqual(try decoded.string(at: fixture.camera.nameOffset), "Authored Camera")

        let loaded = try NativeFormatLoader().loadAssetSync(from: writeFixtureToTemporaryFile(fixture.fileData))
        let runtimeLight = try XCTUnwrap(loaded.lights.first)
        XCTAssertEqual(runtimeLight.name, "Authored Spot")
        XCTAssertEqual(runtimeLight.kind, .spot)
        XCTAssertEqual(runtimeLight.color, SIMD3<Float>(0.25, 0.5, 1.0))
        XCTAssertEqual(runtimeLight.intensity, 7.0, accuracy: 0.0001)
        XCTAssertEqual(runtimeLight.radius, 0.2, accuracy: 0.0001)
        XCTAssertEqual(runtimeLight.range, 18.0, accuracy: 0.0001)
        XCTAssertTrue(runtimeLight.castsShadow)
        XCTAssertTrue(runtimeLight.usesRadiometricUnits)
        XCTAssertEqual(runtimeLight.innerCone, 12.0, accuracy: 0.0001)
        XCTAssertEqual(runtimeLight.outerCone, 34.0, accuracy: 0.0001)

        let runtimeSun = try XCTUnwrap(loaded.lights.first(where: { $0.kind == .directional }))
        XCTAssertEqual(runtimeSun.name, "Authored Sun")
        XCTAssertEqual(runtimeSun.color, SIMD3<Float>(1.0, 0.95, 0.8))
        XCTAssertEqual(runtimeSun.intensity, 1000.0, accuracy: 0.0001, "sun strength (W/m\u{b2}) should round-trip unchanged")
        XCTAssertTrue(runtimeSun.castsShadow)
        XCTAssertTrue(runtimeSun.usesRadiometricUnits)

        let runtimeCamera = try XCTUnwrap(loaded.cameras.first)
        XCTAssertEqual(runtimeCamera.name, "Authored Camera")
        XCTAssertEqual(runtimeCamera.fovYDegrees, 58.0, accuracy: 0.0001)
        XCTAssertEqual(runtimeCamera.nearClip, 0.05, accuracy: 0.0001)
        XCTAssertEqual(runtimeCamera.farClip, 650.0, accuracy: 0.0001)
        XCTAssertEqual(runtimeCamera.aspectRatio, 1.6, accuracy: 0.0001)
    }

    func testColorManagementTableChunkDoesNotBreakLoading() throws {
        // The exporter emits a color_management_table chunk (LUT texture
        // reference + shaper params) that must round-trip correctly — an
        // unrecognized *chunk type* used to throw unsupportedEnumValue before
        // .colorManagementTable was added to UntoldChunkType, and this record
        // is what RegistrationSystem's scene-level LUT installation consumes.
        let record = UntoldColorManagementRecordV1(
            lutTextureIndex: UntoldFormat.invalidIndex, // no texture in this fixture
            viewTransformNameOffset: UntoldFormat.invalidIndex,
            lookNameOffset: UntoldFormat.invalidIndex,
            exposure: 0.25,
            gamma: 1.0,
            shaperMinStops: -10.0,
            shaperMaxStops: 6.0,
            lutSize: 32
        )
        let writer = UntoldBinaryWriter()
        record.encode(to: writer)

        let fixture = makeTinyFixture(colorManagementChunk: writer.data)
        let decoded = try UntoldReader().readAsset(from: fixture.fileData)

        XCTAssertTrue(decoded.chunks.contains(where: { $0.chunkType == .colorManagementTable }))
        XCTAssertEqual(decoded.colorManagement, record)
    }

    func testPluginExtensionChunkRoundtrip() throws {
        let pluginChunkType = UntoldChunkType(rawValue: UntoldChunkType.firstPluginChunkRawValue + 7)
        let metadata = UntoldPluginChunkMetadata(
            pluginID: "com.example.jolt",
            chunkKind: 42,
            chunkVersion: 3
        )
        let payload = Data([0xCA, 0xFE, 0xBA, 0xBE])
        let fixture = makeTinyFixture(pluginChunks: [
            (pluginChunkType, UntoldPluginChunkEnvelope.encode(metadata: metadata, payload: payload), 0),
        ])

        let decoded = try UntoldReader().readAsset(from: fixture.fileData)

        XCTAssertTrue(decoded.chunks.contains(where: { $0.chunkType == pluginChunkType }))
        XCTAssertEqual(decoded.pluginChunks.count, 1)
        XCTAssertEqual(decoded.pluginChunks[0].chunkType, pluginChunkType)
        XCTAssertEqual(decoded.pluginChunks[0].metadata, metadata)
        XCTAssertEqual(decoded.pluginChunks[0].payload, payload)
    }

    func testRejectsInvalidPluginExtensionChunkHeader() throws {
        let pluginChunkType = UntoldChunkType(rawValue: UntoldChunkType.firstPluginChunkRawValue)
        let fixture = makeTinyFixture(pluginChunks: [
            (pluginChunkType, Data(repeating: 0, count: 16), 0),
        ])

        XCTAssertThrowsError(try UntoldReader().readAsset(from: fixture.fileData)) { error in
            XCTAssertEqual(error as? UntoldValidationError, .invalidPluginChunkHeader)
        }
    }

    func testUnknownCoreChunkTypeIsIgnored() throws {
        // A core-range chunk type this runtime does not know (e.g. one added by a
        // newer format revision) must not prevent the rest of the asset from loading.
        let futureChunkType = UntoldChunkType(rawValue: 22)
        let fixture = makeTinyFixture(pluginChunks: [
            (futureChunkType, Data([0x01, 0x02, 0x03, 0x04]), 0),
        ])

        let decoded = try UntoldReader().readAsset(from: fixture.fileData)

        XCTAssertTrue(decoded.chunks.contains(where: { $0.chunkType == futureChunkType }))
        XCTAssertTrue(decoded.pluginChunks.isEmpty)
        XCTAssertEqual(decoded.meshes.count, 1)
        XCTAssertEqual(decoded.entities.count, 1)
    }

    func testColorManagementRoundtripsThroughRuntimeLoader() throws {
        // Reuses the tiny fixture's existing texture (index 0, "albedo.ktx2")
        // as the LUT reference, to exercise the same index -> URL resolution
        // path NativeFormatLoader uses for material textures.
        let record = UntoldColorManagementRecordV1(
            lutTextureIndex: 0,
            viewTransformNameOffset: UntoldFormat.invalidIndex,
            lookNameOffset: UntoldFormat.invalidIndex,
            exposure: 0.1,
            gamma: 1.0,
            shaperMinStops: -10.0,
            shaperMaxStops: 6.0,
            lutSize: 16
        )
        let writer = UntoldBinaryWriter()
        record.encode(to: writer)

        let fixture = makeTinyFixture(
            colorManagementChunk: writer.data,
            mutator: { _, _, _, _, texture, _, _ in
                texture.width = 16 * 16
                texture.height = 16
                texture.mipCount = 1
                texture.textureFormat = .rgba16Float
                texture.flags |= UntoldTextureFlags.lut
            }
        )
        let loaded = try NativeFormatLoader().loadAssetSync(from: writeFixtureToTemporaryFile(fixture.fileData))

        let colorManagement = try XCTUnwrap(loaded.colorManagement)
        XCTAssertEqual(colorManagement.exposure, 0.1, accuracy: 0.0001)
        XCTAssertEqual(colorManagement.shaperMinStops, -10.0, accuracy: 0.0001)
        XCTAssertEqual(colorManagement.shaperMaxStops, 6.0, accuracy: 0.0001)
        XCTAssertEqual(colorManagement.lutSize, 16)
        XCTAssertNotNil(colorManagement.lutTexture?.sourceURL)
        XCTAssertEqual(colorManagement.lutTexture?.isSRGB, false)
        XCTAssertEqual(colorManagement.lutTexture?.textureFormat, .rgba16Float)
    }

    func testColorManagementRejectsMismatchedTextureDimensions() throws {
        let record = UntoldColorManagementRecordV1(
            lutTextureIndex: 0,
            shaperMinStops: -10.0,
            shaperMaxStops: 6.0,
            lutSize: 16
        )
        let writer = UntoldBinaryWriter()
        record.encode(to: writer)
        let fixture = makeTinyFixture(
            colorManagementChunk: writer.data,
            mutator: { _, _, _, _, texture, _, _ in
                texture.mipCount = 1
                texture.textureFormat = .rgba16Float
                texture.flags |= UntoldTextureFlags.lut
            }
        )

        XCTAssertThrowsError(
            try NativeFormatLoader().loadAssetSync(from: writeFixtureToTemporaryFile(fixture.fileData))
        ) { error in
            XCTAssertEqual(
                error as? UntoldValidationError,
                .invalidColorManagementTextureDimensions(
                    expectedWidth: 256,
                    expectedHeight: 16,
                    actualWidth: 512,
                    actualHeight: 512
                )
            )
        }
    }

    func testColorManagementRejectsCompressedOrUntaggedTexture() throws {
        let record = UntoldColorManagementRecordV1(
            lutTextureIndex: 0,
            shaperMinStops: -10.0,
            shaperMaxStops: 6.0,
            lutSize: 16
        )
        let writer = UntoldBinaryWriter()
        record.encode(to: writer)
        let fixture = makeTinyFixture(
            colorManagementChunk: writer.data,
            mutator: { _, _, _, _, texture, _, _ in
                texture.width = 16 * 16
                texture.height = 16
                texture.mipCount = 1
                texture.textureFormat = .astc4x4
            }
        )

        XCTAssertThrowsError(
            try NativeFormatLoader().loadAssetSync(from: writeFixtureToTemporaryFile(fixture.fileData))
        ) { error in
            XCTAssertEqual(error as? UntoldValidationError, .invalidColorManagementRecord)
        }
    }

    func testColorManagementRejectsMultipleSceneWideRecords() throws {
        let record = UntoldColorManagementRecordV1(lutTextureIndex: 0, lutSize: 16)
        let writer = UntoldBinaryWriter()
        record.encode(to: writer)
        let fixture = makeTinyFixture(
            colorManagementChunk: writer.data,
            chunkEntryMutator: { entries in
                let index = entries.firstIndex(where: { $0.chunkType == .colorManagementTable })!
                entries[index].elementCount = 2
            }
        )

        XCTAssertThrowsError(try UntoldReader().readAsset(from: fixture.fileData)) { error in
            XCTAssertEqual(
                error as? UntoldValidationError,
                .invalidSingletonRecordCount(chunkType: .colorManagementTable, count: 2)
            )
        }
    }

    func testMaterialTextureChannelsRoundtripThroughRuntimeLoader() throws {
        let fixture = makeTinyFixture(mutator: { _, _, _, material, _, _, _ in
            material = UntoldMaterialRecordV1(
                nameOffset: material.nameOffset,
                flags: material.flags,
                baseColorFactor: material.baseColorFactor,
                emissiveFactor: material.emissiveFactor,
                normalScale: material.normalScale,
                metallicFactor: material.metallicFactor,
                roughnessFactor: material.roughnessFactor,
                occlusionStrength: material.occlusionStrength,
                alphaCutoff: material.alphaCutoff,
                baseColorTextureIndex: material.baseColorTextureIndex,
                normalTextureIndex: material.normalTextureIndex,
                metallicTextureIndex: material.metallicTextureIndex,
                roughnessTextureIndex: material.roughnessTextureIndex,
                emissiveTextureIndex: material.emissiveTextureIndex,
                occlusionTextureIndex: material.occlusionTextureIndex,
                roughnessTextureChannel: .g,
                metallicTextureChannel: .b
            )
        })

        let decoded = try UntoldReader().readAsset(from: fixture.fileData)
        XCTAssertEqual(decoded.materials[0].reserved0[0], UntoldMaterialRecordV1.packTextureChannels(roughness: .g, metallic: .b))
        XCTAssertEqual(decoded.materials[0].roughnessTextureChannel, .g)
        XCTAssertEqual(decoded.materials[0].metallicTextureChannel, .b)

        let loaded = try NativeFormatLoader().loadAssetSync(from: writeFixtureToTemporaryFile(fixture.fileData))
        let material = try XCTUnwrap(loaded.nodes.first?.primitives.first?.material)
        XCTAssertEqual(material.roughnessTextureChannel, .g)
        XCTAssertEqual(material.metallicTextureChannel, .b)
    }

    func testMaterialHeightAndRemapFieldsRoundtripThroughRuntimeLoader() throws {
        // Regression coverage: the height/remap fields (added for Parallax Occlusion
        // Mapping) previously flowed through every test only at their struct defaults —
        // nothing exercised the actual encode/decode of non-default values through the
        // current (>= minHeightRemapVersion) on-disk layout, nor NativeFormatLoader's
        // UntoldMaterialRecordV1 -> RuntimeMaterialSource wiring for them.
        let fixture = makeTinyFixture(mutator: { _, _, _, material, _, _, _ in
            material = UntoldMaterialRecordV1(
                nameOffset: material.nameOffset,
                flags: material.flags,
                baseColorFactor: material.baseColorFactor,
                emissiveFactor: material.emissiveFactor,
                normalScale: material.normalScale,
                metallicFactor: material.metallicFactor,
                roughnessFactor: material.roughnessFactor,
                occlusionStrength: material.occlusionStrength,
                alphaCutoff: material.alphaCutoff,
                baseColorTextureIndex: material.baseColorTextureIndex,
                normalTextureIndex: material.normalTextureIndex,
                metallicTextureIndex: material.metallicTextureIndex,
                roughnessTextureIndex: material.roughnessTextureIndex,
                emissiveTextureIndex: material.emissiveTextureIndex,
                occlusionTextureIndex: material.occlusionTextureIndex,
                heightTextureIndex: 0, // reuse the fixture's one texture record; only its
                // presence (resolving to a non-nil reference) matters for this test.
                heightScale: 0.08,
                heightMidlevel: 0.65,
                heightRemapMin: 0.1,
                heightRemapMax: 0.9
            )
        })

        let decoded = try UntoldReader().readAsset(from: fixture.fileData)
        let decodedMaterial = try XCTUnwrap(decoded.materials.first)
        XCTAssertEqual(decodedMaterial.heightTextureIndex, 0)
        XCTAssertEqual(decodedMaterial.heightScale, 0.08, accuracy: 0.0001)
        XCTAssertEqual(decodedMaterial.heightMidlevel, 0.65, accuracy: 0.0001)
        XCTAssertEqual(decodedMaterial.heightRemapMin, 0.1, accuracy: 0.0001)
        XCTAssertEqual(decodedMaterial.heightRemapMax, 0.9, accuracy: 0.0001)

        let loaded = try NativeFormatLoader().loadAssetSync(from: writeFixtureToTemporaryFile(fixture.fileData))
        let material = try XCTUnwrap(loaded.nodes.first?.primitives.first?.material)
        XCTAssertNotNil(material.heightTexture, "heightTextureIndex should resolve to a texture reference")
        XCTAssertEqual(material.heightScale, 0.08, accuracy: 0.0001)
        XCTAssertEqual(material.heightMidlevel, 0.65, accuracy: 0.0001)
        XCTAssertEqual(material.heightRemapMin, 0.1, accuracy: 0.0001)
        XCTAssertEqual(material.heightRemapMax, 0.9, accuracy: 0.0001)
    }

    func testDecodeLegacyWithHeightNoRemapDefaultsRemapFields() throws {
        // formatVersion in [minHeightMapVersion, minHeightRemapVersion) — height-map fields
        // are on disk, but height-remap fields were added later and are NOT: they must come
        // back at their identity defaults rather than reading garbage from adjacent bytes.
        let writer = UntoldBinaryWriter()
        writer.writeUInt32LE(7) // nameOffset
        writer.writeUInt32LE(0) // flags
        writer.writeFloat32LE(1) // baseColorFactor.x
        writer.writeFloat32LE(1) // baseColorFactor.y
        writer.writeFloat32LE(1) // baseColorFactor.z
        writer.writeFloat32LE(1) // baseColorFactor.w
        writer.writeFloat32LE(0) // emissiveFactor.x
        writer.writeFloat32LE(0) // emissiveFactor.y
        writer.writeFloat32LE(0) // emissiveFactor.z
        writer.writeFloat32LE(1) // normalScale
        writer.writeFloat32LE(0.9) // metallicFactor
        writer.writeFloat32LE(0.4) // roughnessFactor
        writer.writeFloat32LE(1) // occlusionStrength
        writer.writeFloat32LE(0.5) // alphaCutoff
        writer.writeUInt32LE(UntoldFormat.invalidIndex) // baseColorTextureIndex
        writer.writeUInt32LE(UntoldFormat.invalidIndex) // normalTextureIndex
        writer.writeUInt32LE(UntoldFormat.invalidIndex) // metallicTextureIndex
        writer.writeUInt32LE(UntoldFormat.invalidIndex) // roughnessTextureIndex
        writer.writeUInt32LE(UntoldFormat.invalidIndex) // emissiveTextureIndex
        writer.writeUInt32LE(UntoldFormat.invalidIndex) // occlusionTextureIndex
        writer.writeUInt32LE(3) // heightTextureIndex
        writer.writeFloat32LE(0.12) // heightScale
        writer.writeFloat32LE(0.42) // heightMidlevel
        // No heightRemapMin/Max on disk at this version.
        writer.writeUInt32LE(0) // reserved0[0]
        writer.writeUInt32LE(0) // reserved0[1]

        let reader = UntoldBinaryReader(data: writer.data)
        let record = try UntoldMaterialRecordV1.decodeLegacyWithHeightNoRemap(from: reader)

        XCTAssertEqual(record.heightTextureIndex, 3)
        XCTAssertEqual(record.heightScale, 0.12, accuracy: 0.0001)
        XCTAssertEqual(record.heightMidlevel, 0.42, accuracy: 0.0001)
        XCTAssertEqual(record.heightRemapMin, 0.0, "must default to identity, not read adjacent bytes")
        XCTAssertEqual(record.heightRemapMax, 1.0, "must default to identity, not read adjacent bytes")
    }

    func testDecodeLegacyWithoutHeightDefaultsAllHeightFields() throws {
        // formatVersion < minHeightMapVersion — no height-map or height-remap fields exist
        // on disk at all for these files, predating the whole feature.
        let writer = UntoldBinaryWriter()
        writer.writeUInt32LE(7) // nameOffset
        writer.writeUInt32LE(0) // flags
        writer.writeFloat32LE(1) // baseColorFactor.x
        writer.writeFloat32LE(1) // baseColorFactor.y
        writer.writeFloat32LE(1) // baseColorFactor.z
        writer.writeFloat32LE(1) // baseColorFactor.w
        writer.writeFloat32LE(0) // emissiveFactor.x
        writer.writeFloat32LE(0) // emissiveFactor.y
        writer.writeFloat32LE(0) // emissiveFactor.z
        writer.writeFloat32LE(1) // normalScale
        writer.writeFloat32LE(0.9) // metallicFactor
        writer.writeFloat32LE(0.4) // roughnessFactor
        writer.writeFloat32LE(1) // occlusionStrength
        writer.writeFloat32LE(0.5) // alphaCutoff
        writer.writeUInt32LE(UntoldFormat.invalidIndex) // baseColorTextureIndex
        writer.writeUInt32LE(UntoldFormat.invalidIndex) // normalTextureIndex
        writer.writeUInt32LE(UntoldFormat.invalidIndex) // metallicTextureIndex
        writer.writeUInt32LE(UntoldFormat.invalidIndex) // roughnessTextureIndex
        writer.writeUInt32LE(UntoldFormat.invalidIndex) // emissiveTextureIndex
        writer.writeUInt32LE(UntoldFormat.invalidIndex) // occlusionTextureIndex
        // No height fields on disk at all at this version.
        writer.writeUInt32LE(0) // reserved0[0]
        writer.writeUInt32LE(0) // reserved0[1]

        let reader = UntoldBinaryReader(data: writer.data)
        let record = try UntoldMaterialRecordV1.decodeLegacyWithoutHeight(from: reader)

        XCTAssertEqual(record.heightTextureIndex, UntoldFormat.invalidIndex, "hasHeightMap-equivalent should be false")
        XCTAssertEqual(record.heightScale, 0.05, accuracy: 0.0001)
        XCTAssertEqual(record.heightMidlevel, 0.5, accuracy: 0.0001)
        XCTAssertEqual(record.heightRemapMin, 0.0)
        XCTAssertEqual(record.heightRemapMax, 1.0)
    }

    private func encodeChunk(_ records: [some UntoldBinaryEncodable]) -> Data {
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

    private struct ScenePayloadFixture {
        var fileData: Data
        var light: UntoldLightRecordV1
        var sunLight: UntoldLightRecordV1
        var camera: UntoldCameraRecordV1
    }

    private func makeTinyFixture(
        removedChunkTypes: Set<UntoldChunkType> = [],
        computeHash: Bool = false,
        edgeIndexData: Data = Data(),
        colorManagementChunk: Data? = nil,
        pluginChunks: [(type: UntoldChunkType, data: Data, elementCount: UInt32)] = [],
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
            edgeIndexData: edgeIndexData,
            colorManagementChunk: colorManagementChunk,
            pluginChunks: pluginChunks,
            removedChunkTypes: removedChunkTypes
        )

        header.chunkCount = UInt32(chunkPayloads.count)
        let (fileData, chunkEntries) = buildFileData(header: header, chunkPayloads: chunkPayloads, computeHash: computeHash, chunkEntryMutator: chunkEntryMutator)

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

    private func makeScenePayloadFixture() -> ScenePayloadFixture {
        let fixture = makeTinyFixture()
        let stringTable = makeStringTable(["root_entity", "mesh_0", "mat_0", "albedo.ktx2", "Authored Spot", "Authored Sun", "Authored Camera"])
        var lightTransform = matrix_identity_float4x4
        lightTransform.columns.3 = SIMD4<Float>(2.0, 3.0, 4.0, 1.0)
        let light = UntoldLightRecordV1(
            entityId: 10,
            nameOffset: stringTable.offsets["Authored Spot"]!,
            lightType: .spot,
            flags: UntoldLightFlags.castsShadow | UntoldLightFlags.radiometric | UntoldLightFlags.customDistance,
            color: SIMD3<Float>(0.25, 0.5, 1.0),
            intensity: 7.0,
            position: SIMD3<Float>(2.0, 3.0, 4.0),
            radius: 0.2,
            direction: SIMD3<Float>(0.0, -1.0, 0.0),
            falloff: 18.0,
            innerCone: 12.0,
            outerCone: 34.0,
            localTransform: lightTransform
        )
        var sunTransform = matrix_identity_float4x4
        sunTransform.columns.3 = SIMD4<Float>(0.0, 10.0, 0.0, 1.0)
        let sunLight = UntoldLightRecordV1(
            entityId: 12,
            nameOffset: stringTable.offsets["Authored Sun"]!,
            lightType: .directional,
            flags: UntoldLightFlags.castsShadow | UntoldLightFlags.radiometric,
            color: SIMD3<Float>(1.0, 0.95, 0.8),
            intensity: 1000.0,
            direction: SIMD3<Float>(0.0, -1.0, 0.0),
            localTransform: sunTransform
        )
        var cameraTransform = matrix_identity_float4x4
        cameraTransform.columns.3 = SIMD4<Float>(0.0, 1.0, 6.0, 1.0)
        let camera = UntoldCameraRecordV1(
            entityId: 11,
            nameOffset: stringTable.offsets["Authored Camera"]!,
            position: SIMD3<Float>(0.0, 1.0, 6.0),
            fovYDegrees: 58.0,
            nearClip: 0.05,
            farClip: 650.0,
            aspectRatio: 1.6,
            localTransform: cameraTransform
        )

        var header = UntoldFileHeaderV1(
            fileType: .tile,
            chunkCount: 0,
            meshCount: 1,
            materialCount: 1,
            textureRefCount: 1,
            entityCount: 1,
            vertexLayout: .pbrStaticV1,
            worldBounds: fixture.entity.worldBounds
        )
        let chunkPayloads = buildChunkPayloads(
            stringTableData: stringTable.data,
            entities: [fixture.entity],
            meshes: [fixture.mesh],
            materials: [fixture.material],
            textures: [fixture.texture],
            vertexData: fixture.chunkPayloads.first(where: { $0.type == .vertexData })!.data,
            indexData: fixture.chunkPayloads.first(where: { $0.type == .indexData })!.data,
            lights: [light, sunLight],
            cameras: [camera]
        )
        header.chunkCount = UInt32(chunkPayloads.count)
        let (fileData, _) = buildFileData(header: header, chunkPayloads: chunkPayloads)
        return ScenePayloadFixture(fileData: fileData, light: light, sunLight: sunLight, camera: camera)
    }

    private func buildChunkPayloads(
        stringTableData: Data,
        entities: [UntoldEntityRecordV1],
        meshes: [UntoldMeshRecordV1],
        materials: [UntoldMaterialRecordV1],
        textures: [UntoldTextureRefRecordV1],
        vertexData: Data,
        indexData: Data,
        edgeIndexData: Data = Data(),
        lights: [UntoldLightRecordV1] = [],
        cameras: [UntoldCameraRecordV1] = [],
        colorManagementChunk: Data? = nil,
        pluginChunks: [(type: UntoldChunkType, data: Data, elementCount: UInt32)] = [],
        removedChunkTypes: Set<UntoldChunkType> = []
    ) -> [(type: UntoldChunkType, data: Data, elementCount: UInt32)] {
        var all: [(type: UntoldChunkType, data: Data, elementCount: UInt32)] = [
            (.stringTable, stringTableData, 0),
            (.entityTable, encodeChunk(entities), UInt32(entities.count)),
            (.meshTable, encodeChunk(meshes), UInt32(meshes.count)),
            (.materialTable, encodeChunk(materials), UInt32(materials.count)),
            (.textureTable, encodeChunk(textures), UInt32(textures.count)),
            (.vertexData, vertexData, 0),
            (.indexData, indexData, 0),
        ]
        if !edgeIndexData.isEmpty {
            all.append((.edgeIndexData, edgeIndexData, 0))
        }
        if !lights.isEmpty {
            all.append((.lightTable, encodeChunk(lights), UInt32(lights.count)))
        }
        if !cameras.isEmpty {
            all.append((.cameraTable, encodeChunk(cameras), UInt32(cameras.count)))
        }
        if let colorManagementChunk {
            all.append((.colorManagementTable, colorManagementChunk, 1))
        }
        all.append(contentsOf: pluginChunks)
        return all.filter { !removedChunkTypes.contains($0.type) }
    }

    /// Compute the content hash the same way the Python exporter does:
    /// SHA-256 of all chunk payloads concatenated in ascending chunk-type order,
    /// with no alignment padding between them.
    private func computeContentHash(
        for chunkPayloads: [(type: UntoldChunkType, data: Data, elementCount: UInt32)]
    ) -> [UInt8] {
        let sorted = chunkPayloads.sorted { $0.type.rawValue < $1.type.rawValue }
        let hashInput = sorted.reduce(Data()) { $0 + $1.data }
        return Array(SHA256.hash(data: hashInput))
    }

    private func buildFileData(
        header: UntoldFileHeaderV1,
        chunkPayloads: [(type: UntoldChunkType, data: Data, elementCount: UInt32)],
        computeHash: Bool = false,
        chunkEntryMutator: ((inout [UntoldChunkEntryV1]) -> Void)? = nil
    ) -> (Data, [UntoldChunkEntryV1]) {
        var header = header
        if computeHash {
            header.contentHash = computeContentHash(for: chunkPayloads)
        }
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

// MARK: - contentHash validation tests

extension NativeFormatTests {
    func testAnimationOnlyUntoldFileLoadsSuccessfully() throws {
        let fixture = try makeAnimationOnlyFixture()

        let decoded = try UntoldReader().readAsset(from: fixture.fileData)
        XCTAssertEqual(decoded.header.fileType, .animation)
        XCTAssertEqual(decoded.entities, [])
        XCTAssertEqual(decoded.meshes, [])
        XCTAssertEqual(decoded.materials, [])
        XCTAssertEqual(decoded.textures, [])
        XCTAssertEqual(decoded.animationClips, [fixture.clip])
        XCTAssertEqual(decoded.animationChannels, [fixture.channel])
        XCTAssertEqual(decoded.translationKeyframes, fixture.translationKeyframes)
        XCTAssertEqual(decoded.rotationKeyframes, fixture.rotationKeyframes)

        let runtimeAsset = try NativeFormatLoader().loadAssetSync(from: fixture.url)
        XCTAssertTrue(runtimeAsset.nodes.isEmpty)
        XCTAssertEqual(runtimeAsset.animationClips.count, 1)

        let runtimeClip = try XCTUnwrap(runtimeAsset.animationClips.first)
        XCTAssertEqual(runtimeClip.name, "running")
        XCTAssertEqual(runtimeClip.duration, 1.0, accuracy: 0.0001)
        XCTAssertEqual(runtimeClip.channels.count, 1)

        let runtimeChannel = try XCTUnwrap(runtimeClip.channels.first)
        XCTAssertEqual(runtimeChannel.jointPath, "/Hips")
        XCTAssertEqual(runtimeChannel.translations.count, 2)
        XCTAssertEqual(runtimeChannel.rotations.count, 2)
    }

    func testFileWithValidHashLoadsSuccessfully() throws {
        let fixture = makeTinyFixture(computeHash: true)
        // Should not throw — hash matches the chunk payloads.
        XCTAssertNoThrow(try UntoldReader().readAsset(from: fixture.fileData))
    }

    func testFileWithLZ4CompressedChunksLoadsMetadataCorrectly() throws {
        let (fileData, _, _) = makeLZ4CompressedFile()
        let decoded = try UntoldReader().readAsset(from: fileData)

        XCTAssertEqual(decoded.entities.count, 1)
        XCTAssertEqual(decoded.meshes.count, 1)
        XCTAssertEqual(try decoded.string(at: decoded.entities[0].nameOffset), "root_entity")
        XCTAssertEqual(try decoded.string(at: decoded.meshes[0].meshNameOffset), "mesh_0")
    }

    func testTamperedVertexDataRejectedByHashValidation() throws {
        let fixture = makeTinyFixture(computeHash: true)

        // Find the vertex data chunk and flip one byte inside its payload.
        guard let vertexEntry = fixture.chunkEntries.first(where: { $0.chunkType == .vertexData }) else {
            XCTFail("No vertex chunk in fixture")
            return
        }
        var tampered = fixture.fileData
        let flipOffset = Int(vertexEntry.fileOffset)
        tampered[flipOffset] ^= 0xFF

        XCTAssertThrowsError(try UntoldReader().readAsset(from: tampered)) { error in
            XCTAssertEqual(error as? UntoldValidationError, .contentHashMismatch)
        }
    }
}

// MARK: - LZ4 compression tests

extension NativeFormatTests {
    // MARK: Helpers

    /// Compress `input` with COMPRESSION_LZ4_RAW — the same algorithm the runtime uses to decompress.
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

    /// Builds a minimal .untold file whose vertexData and indexData chunks are LZ4 compressed.
    /// All metadata chunks remain uncompressed. When `inflateVertexUncompressedSize` is true,
    /// the vertex chunk's `uncompressedSize` field is set larger than the actual data, so the
    /// runtime decompressor will report a size mismatch.
    private func makeLZ4CompressedFile(
        inflateVertexUncompressedSize: Bool = false
    ) -> (fileData: Data, originalVertexData: Data, originalIndexData: Data) {
        let strings = ["root_entity", "mesh_0", "mat_0", "albedo.ktx2"]
        let stringTable = makeStringTable(strings)
        let bounds = UntoldAABB(min: SIMD3<Float>(-1, -1, -1), max: SIMD3<Float>(1, 1, 1))

        // One 32-byte PBR vertex
        let vertex = UntoldPBRStaticVertexV1(
            position: SIMD3<Float>(1, 2, 3),
            normalPacked: UntoldVertexPacking.packNormal(SIMD3<Float>(0, 1, 0)),
            tangentPacked: UntoldVertexPacking.packTangent(SIMD3<Float>(1, 0, 0), handedness: 1),
            uv0: SIMD2<UInt16>(100, 200),
            uv1: SIMD2<UInt16>(0, 0),
            color0: SIMD4<UInt8>(255, 128, 64, 255)
        )
        let vertexWriter = UntoldBinaryWriter()
        vertex.encode(to: vertexWriter)
        let originalVertexData = vertexWriter.data

        // One triangle: 3 × uint16 indices
        let indexWriter = UntoldBinaryWriter()
        indexWriter.writeUInt16LE(0)
        indexWriter.writeUInt16LE(1)
        indexWriter.writeUInt16LE(2)
        let originalIndexData = indexWriter.data

        let compressedVertex = lz4Compress(originalVertexData)
        let compressedIndex = lz4Compress(originalIndexData)

        let vertexUncompressedSize: UInt64 = inflateVertexUncompressedSize
            ? UInt64(originalVertexData.count) + 1000 // deliberately wrong
            : UInt64(originalVertexData.count)

        let entity = UntoldEntityRecordV1(
            entityId: 0,
            nameOffset: stringTable.offsets["root_entity"]!,
            firstMeshRecordIndex: 0,
            meshRecordCount: 1,
            localBounds: bounds,
            worldBounds: bounds
        )
        let material = UntoldMaterialRecordV1(
            nameOffset: stringTable.offsets["mat_0"]!,
            baseColorTextureIndex: 0
        )
        let texture = UntoldTextureRefRecordV1(
            nameOffset: stringTable.offsets["albedo.ktx2"]!,
            uriOffset: stringTable.offsets["albedo.ktx2"]!,
            textureFormat: .rgba8,
            width: 64,
            height: 64,
            mipCount: 1
        )
        let mesh = UntoldMeshRecordV1(
            entityId: 0,
            meshNameOffset: stringTable.offsets["mesh_0"]!,
            materialIndex: 0,
            indexType: .uint16,
            vertexCount: 1,
            indexCount: 3,
            vertexStrideBytes: 32,
            vertexDataOffset: 0,
            indexDataOffset: 0,
            vertexDataSizeBytes: UInt64(originalVertexData.count),
            indexDataSizeBytes: UInt64(originalIndexData.count),
            estimatedGPUBytes: UInt64(originalVertexData.count + originalIndexData.count),
            localBounds: bounds
        )

        var header = UntoldFileHeaderV1(
            fileType: .tile,
            chunkCount: 0,
            meshCount: 1,
            materialCount: 1,
            textureRefCount: 1,
            entityCount: 1,
            vertexLayout: .pbrStaticV1,
            worldBounds: bounds
        )

        // (storedBytes, compressionType, uncompressedSize, elementCount)
        let specs: [(UntoldChunkType, Data, UntoldCompressionType, UInt64, UInt32)] = [
            (.stringTable, stringTable.data, .none, UInt64(stringTable.data.count), 0),
            (.entityTable, encodeChunk([entity]), .none, UInt64(encodeChunk([entity]).count), 1),
            (.meshTable, encodeChunk([mesh]), .none, UInt64(encodeChunk([mesh]).count), 1),
            (.materialTable, encodeChunk([material]), .none, UInt64(encodeChunk([material]).count), 1),
            (.textureTable, encodeChunk([texture]), .none, UInt64(encodeChunk([texture]).count), 1),
            (.vertexData, compressedVertex, .lz4, vertexUncompressedSize, 0),
            (.indexData, compressedIndex, .lz4, UInt64(originalIndexData.count), 0),
        ]

        header.chunkCount = UInt32(specs.count)

        // Compute chunk table size (matches UntoldChunkEntryV1 binary layout: 2×u32 + 3×u64 + 2×u32 = 40 bytes)
        let chunkEntrySize = MemoryLayout<UInt32>.size * 2
            + MemoryLayout<UInt64>.size * 3
            + MemoryLayout<UInt32>.size * 2
        let headerWriter2 = UntoldBinaryWriter()
        header.encode(to: headerWriter2)
        let headerSize = headerWriter2.data.count

        var runningOffset = headerSize + chunkEntrySize * specs.count
        var entries: [UntoldChunkEntryV1] = []
        for (chunkType, storedBytes, compressionType, uncompressedSize, elementCount) in specs {
            runningOffset = align(runningOffset, to: Int(UntoldFormat.fileAlignment))
            entries.append(UntoldChunkEntryV1(
                chunkType: chunkType,
                compressionType: compressionType,
                fileOffset: UInt64(runningOffset),
                compressedSize: UInt64(storedBytes.count),
                uncompressedSize: uncompressedSize,
                elementCount: elementCount
            ))
            runningOffset += storedBytes.count
        }

        let fileWriter = UntoldBinaryWriter()
        header.encode(to: fileWriter)
        for entry in entries {
            entry.encode(to: fileWriter)
        }
        for (_, storedBytes, _, _, _) in specs {
            fileWriter.align(to: Int(UntoldFormat.fileAlignment))
            fileWriter.writeData(storedBytes)
        }

        return (fileWriter.data, originalVertexData, originalIndexData)
    }

    // MARK: Tests

    func testLZ4CompressedVertexAndIndexRoundtrip() throws {
        let (fileData, originalVertexData, originalIndexData) = makeLZ4CompressedFile()
        let reader = UntoldReader()
        let decoded = try reader.readAsset(from: fileData)

        let decompressedVertex = try reader.readChunkData(.vertexData, from: fileData, entries: decoded.chunks)
        let decompressedIndex = try reader.readChunkData(.indexData, from: fileData, entries: decoded.chunks)

        XCTAssertEqual(decompressedVertex, originalVertexData, "Decompressed vertex data must match original")
        XCTAssertEqual(decompressedIndex, originalIndexData, "Decompressed index data must match original")
    }

    func testLZ4CompressedChunkReportsCorrectSizeMetadata() throws {
        let (fileData, originalVertexData, originalIndexData) = makeLZ4CompressedFile()
        let decoded = try UntoldReader().readAsset(from: fileData)

        let vertexEntry = try XCTUnwrap(decoded.chunks.first { $0.chunkType == .vertexData })
        let indexEntry = try XCTUnwrap(decoded.chunks.first { $0.chunkType == .indexData })

        XCTAssertEqual(vertexEntry.compressionType, .lz4)
        XCTAssertEqual(vertexEntry.uncompressedSize, UInt64(originalVertexData.count))
        XCTAssertLessThanOrEqual(vertexEntry.compressedSize, vertexEntry.uncompressedSize + 64,
                                 "LZ4 compressed size should not wildly exceed original for small inputs")

        XCTAssertEqual(indexEntry.compressionType, .lz4)
        XCTAssertEqual(indexEntry.uncompressedSize, UInt64(originalIndexData.count))
    }

    func testLZ4CompressionOutputSizeMismatchIsRejected() throws {
        let (fileData, _, _) = makeLZ4CompressedFile(inflateVertexUncompressedSize: true)
        let reader = UntoldReader()
        let decoded = try reader.readAsset(from: fileData)

        XCTAssertThrowsError(
            try reader.readChunkData(.vertexData, from: fileData, entries: decoded.chunks)
        ) { error in
            guard case let UntoldValidationError.compressionOutputSizeMismatch(expected, actual) = error else {
                return XCTFail("Expected compressionOutputSizeMismatch, got \(error)")
            }
            XCTAssertGreaterThan(expected, actual)
        }
    }

    func testZstdCompressionIsRejected() throws {
        let base = makeTinyFixture()
        guard let idx = base.chunkEntries.firstIndex(where: { $0.chunkType == .vertexData }) else {
            XCTFail("No vertex chunk in fixture"); return
        }
        // Swap compressionType to .zstd on the vertex chunk entry without touching file bytes.
        var mutatedEntries = base.chunkEntries
        let orig = mutatedEntries[idx]
        mutatedEntries[idx] = UntoldChunkEntryV1(
            chunkType: orig.chunkType,
            compressionType: .zstd,
            fileOffset: orig.fileOffset,
            compressedSize: orig.compressedSize,
            uncompressedSize: orig.uncompressedSize,
            elementCount: orig.elementCount
        )

        let reader = UntoldReader()
        XCTAssertThrowsError(
            try reader.readChunkData(.vertexData, from: base.fileData, entries: mutatedEntries)
        ) { error in
            XCTAssertEqual(
                error as? UntoldValidationError,
                .unsupportedCompression(UntoldCompressionType.zstd.rawValue)
            )
        }
    }

    private struct AnimationOnlyFixture {
        let url: URL
        let fileData: Data
        let clip: UntoldAnimationClipRecordV1
        let channel: UntoldAnimationChannelRecordV1
        let translationKeyframes: [UntoldTranslationKeyframeRecordV1]
        let rotationKeyframes: [UntoldRotationKeyframeRecordV1]
    }

    private func makeAnimationOnlyFixture() throws -> AnimationOnlyFixture {
        let stringTable = makeStringTable(["running", "/Hips"])

        let clip = UntoldAnimationClipRecordV1(
            nameOffset: stringTable.offsets["running"] ?? UntoldFormat.invalidIndex,
            duration: 1.0,
            firstChannelRecordIndex: 0,
            channelRecordCount: 1
        )

        let channel = UntoldAnimationChannelRecordV1(
            jointPathOffset: stringTable.offsets["/Hips"] ?? UntoldFormat.invalidIndex,
            firstTranslationKeyframeIndex: 0,
            translationKeyframeCount: 2,
            firstRotationKeyframeIndex: 0,
            rotationKeyframeCount: 2
        )

        let translationKeyframes = [
            UntoldTranslationKeyframeRecordV1(time: 0.0, value: SIMD3<Float>(0, 0, 0)),
            UntoldTranslationKeyframeRecordV1(time: 1.0, value: SIMD3<Float>(0, 1, 0)),
        ]

        let rotationKeyframes = [
            UntoldRotationKeyframeRecordV1(time: 0.0, value: SIMD4<Float>(0, 0, 0, 1)),
            UntoldRotationKeyframeRecordV1(time: 1.0, value: SIMD4<Float>(0, 0.70710677, 0, 0.70710677)),
        ]

        let chunkPayloads: [(type: UntoldChunkType, data: Data, elementCount: UInt32)] = [
            (.stringTable, stringTable.data, 0),
            (.animationClipTable, encodeChunk([clip]), 1),
            (.animationChannelTable, encodeChunk([channel]), 1),
            (.translationKeyframeTable, encodeChunk(translationKeyframes), UInt32(translationKeyframes.count)),
            (.rotationKeyframeTable, encodeChunk(rotationKeyframes), UInt32(rotationKeyframes.count)),
        ]

        let bounds = UntoldAABB(min: SIMD3<Float>(0, 0, 0), max: SIMD3<Float>(0, 0, 0))
        let header = UntoldFileHeaderV1(
            fileType: .animation,
            chunkCount: UInt32(chunkPayloads.count),
            meshCount: 0,
            materialCount: 0,
            textureRefCount: 0,
            entityCount: 0,
            vertexLayout: .pbrStaticV1,
            worldBounds: bounds
        )

        let (fileData, _) = buildFileData(header: header, chunkPayloads: chunkPayloads, computeHash: true)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("untold")
        try fileData.write(to: url)

        return AnimationOnlyFixture(
            url: url,
            fileData: fileData,
            clip: clip,
            channel: channel,
            translationKeyframes: translationKeyframes,
            rotationKeyframes: rotationKeyframes
        )
    }

    private func writeFixtureToTemporaryFile(_ fileData: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("untold")
        try fileData.write(to: url)
        return url
    }
}

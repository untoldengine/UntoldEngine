//
//  UntoldBinaryCodable.swift
//  UntoldEngine
//
//  Explicit field-by-field binary encoding helpers for the cooked `.untold`
//  runtime asset container.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

public protocol UntoldBinaryEncodable {
    func encode(to writer: UntoldBinaryWriter)
}

public protocol UntoldBinaryDecodable {
    static func decode(from reader: UntoldBinaryReader) throws -> Self
}

extension UntoldAABB: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeFloat32LE(min.x)
        writer.writeFloat32LE(min.y)
        writer.writeFloat32LE(min.z)
        writer.writeFloat32LE(max.x)
        writer.writeFloat32LE(max.y)
        writer.writeFloat32LE(max.z)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldAABB {
        let min = SIMD3<Float>(
            try reader.readFloat32LE(),
            try reader.readFloat32LE(),
            try reader.readFloat32LE()
        )
        let max = SIMD3<Float>(
            try reader.readFloat32LE(),
            try reader.readFloat32LE(),
            try reader.readFloat32LE()
        )
        return UntoldAABB(min: min, max: max)
    }
}

extension UntoldChunkEntryV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeUInt32LE(chunkType.rawValue)
        writer.writeUInt32LE(compressionType.rawValue)
        writer.writeUInt64LE(fileOffset)
        writer.writeUInt64LE(compressedSize)
        writer.writeUInt64LE(uncompressedSize)
        writer.writeUInt32LE(elementCount)
        writer.writeUInt32LE(reserved0)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldChunkEntryV1 {
        let chunkTypeRaw = try reader.readUInt32LE()
        let compressionRaw = try reader.readUInt32LE()
        guard let chunkType = UntoldChunkType(rawValue: chunkTypeRaw),
              let compressionType = UntoldCompressionType(rawValue: compressionRaw)
        else {
            throw UntoldValidationError.unsupportedEnumValue
        }

        var entry = UntoldChunkEntryV1(
            chunkType: chunkType,
            compressionType: compressionType,
            fileOffset: try reader.readUInt64LE(),
            compressedSize: try reader.readUInt64LE(),
            uncompressedSize: try reader.readUInt64LE(),
            elementCount: try reader.readUInt32LE()
        )
        entry.reserved0 = try reader.readUInt32LE()
        return entry
    }
}

extension UntoldFileHeaderV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeBytes(magic)
        writer.writeUInt32LE(formatVersion)
        writer.writeUInt32LE(fileType.rawValue)
        writer.writeUInt32LE(flags)
        writer.writeUInt32LE(headerSize)
        writer.writeUInt32LE(chunkCount)
        writer.writeUInt32LE(meshCount)
        writer.writeUInt32LE(materialCount)
        writer.writeUInt32LE(textureRefCount)
        writer.writeUInt32LE(entityCount)
        writer.writeUInt32LE(vertexLayout.rawValue)
        writer.writeUInt32LE(reserved0)
        worldBounds.encode(to: writer)
        writer.writeMatrix4x4LE(rootTransform)
        writer.writeBytes(contentHash)
        writer.writeBytes(reserved1)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldFileHeaderV1 {
        let magic = Array(try reader.readBytes(count: 8))
        let version = try reader.readUInt32LE()
        let fileTypeRaw = try reader.readUInt32LE()
        let flags = try reader.readUInt32LE()
        let headerSize = try reader.readUInt32LE()
        let chunkCount = try reader.readUInt32LE()
        let meshCount = try reader.readUInt32LE()
        let materialCount = try reader.readUInt32LE()
        let textureRefCount = try reader.readUInt32LE()
        let entityCount = try reader.readUInt32LE()
        let vertexLayoutRaw = try reader.readUInt32LE()
        let reserved0 = try reader.readUInt32LE()
        let worldBounds = try UntoldAABB.decode(from: reader)
        let rootTransform = try reader.readMatrix4x4LE()
        let contentHash = Array(try reader.readBytes(count: UntoldFormat.hashByteCount))
        let reserved1 = Array(try reader.readBytes(count: UntoldFormat.hashByteCount))

        guard let fileType = UntoldFileType(rawValue: fileTypeRaw),
              let vertexLayout = UntoldVertexLayout(rawValue: vertexLayoutRaw)
        else {
            throw UntoldValidationError.unsupportedEnumValue
        }

        var header = UntoldFileHeaderV1(
            fileType: fileType,
            chunkCount: chunkCount,
            meshCount: meshCount,
            materialCount: materialCount,
            textureRefCount: textureRefCount,
            entityCount: entityCount,
            vertexLayout: vertexLayout,
            worldBounds: worldBounds,
            rootTransform: rootTransform
        )
        header.magic = magic
        header.formatVersion = version
        header.flags = flags
        header.headerSize = headerSize
        header.reserved0 = reserved0
        header.contentHash = contentHash
        header.reserved1 = reserved1
        return header
    }
}

extension UntoldEntityRecordV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeUInt32LE(entityId)
        writer.writeUInt32LE(parentEntityId)
        writer.writeUInt32LE(nameOffset)
        writer.writeUInt32LE(firstMeshRecordIndex)
        writer.writeUInt32LE(meshRecordCount)
        writer.writeUInt32LE(flags)
        localBounds.encode(to: writer)
        worldBounds.encode(to: writer)
        writer.writeMatrix4x4LE(localTransform)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldEntityRecordV1 {
        UntoldEntityRecordV1(
            entityId: try reader.readUInt32LE(),
            parentEntityId: try reader.readUInt32LE(),
            nameOffset: try reader.readUInt32LE(),
            firstMeshRecordIndex: try reader.readUInt32LE(),
            meshRecordCount: try reader.readUInt32LE(),
            flags: try reader.readUInt32LE(),
            localBounds: try UntoldAABB.decode(from: reader),
            worldBounds: try UntoldAABB.decode(from: reader),
            localTransform: try reader.readMatrix4x4LE()
        )
    }
}

extension UntoldMeshRecordV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeUInt32LE(entityId)
        writer.writeUInt32LE(meshNameOffset)
        writer.writeUInt32LE(materialIndex)
        writer.writeUInt32LE(indexType.rawValue)
        writer.writeUInt32LE(vertexCount)
        writer.writeUInt32LE(indexCount)
        writer.writeUInt32LE(vertexStrideBytes)
        writer.writeUInt32LE(flags)
        writer.writeUInt64LE(vertexDataOffset)
        writer.writeUInt64LE(indexDataOffset)
        writer.writeUInt64LE(vertexDataSizeBytes)
        writer.writeUInt64LE(indexDataSizeBytes)
        writer.writeUInt64LE(estimatedGPUBytes)
        writer.writeUInt64LE(reserved0)
        localBounds.encode(to: writer)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldMeshRecordV1 {
        let entityId = try reader.readUInt32LE()
        let meshNameOffset = try reader.readUInt32LE()
        let materialIndex = try reader.readUInt32LE()
        let indexTypeRaw = try reader.readUInt32LE()
        guard let indexType = UntoldIndexType(rawValue: indexTypeRaw) else {
            throw UntoldValidationError.unsupportedEnumValue
        }

        let vertexCount = try reader.readUInt32LE()
        let indexCount = try reader.readUInt32LE()
        let vertexStrideBytes = try reader.readUInt32LE()
        let flags = try reader.readUInt32LE()
        let vertexDataOffset = try reader.readUInt64LE()
        let indexDataOffset = try reader.readUInt64LE()
        let vertexDataSizeBytes = try reader.readUInt64LE()
        let indexDataSizeBytes = try reader.readUInt64LE()
        let estimatedGPUBytes = try reader.readUInt64LE()
        let reserved0 = try reader.readUInt64LE()
        let localBounds = try UntoldAABB.decode(from: reader)

        var record = UntoldMeshRecordV1(
            entityId: entityId,
            meshNameOffset: meshNameOffset,
            materialIndex: materialIndex,
            indexType: indexType,
            vertexCount: vertexCount,
            indexCount: indexCount,
            vertexStrideBytes: vertexStrideBytes,
            flags: flags,
            vertexDataOffset: vertexDataOffset,
            indexDataOffset: indexDataOffset,
            vertexDataSizeBytes: vertexDataSizeBytes,
            indexDataSizeBytes: indexDataSizeBytes,
            estimatedGPUBytes: estimatedGPUBytes,
            localBounds: localBounds
        )
        record.reserved0 = reserved0
        return record
    }
}

extension UntoldMaterialRecordV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeUInt32LE(nameOffset)
        writer.writeUInt32LE(flags)
        writer.writeFloat32LE(baseColorFactor.x)
        writer.writeFloat32LE(baseColorFactor.y)
        writer.writeFloat32LE(baseColorFactor.z)
        writer.writeFloat32LE(baseColorFactor.w)
        writer.writeFloat32LE(emissiveFactor.x)
        writer.writeFloat32LE(emissiveFactor.y)
        writer.writeFloat32LE(emissiveFactor.z)
        writer.writeFloat32LE(normalScale)
        writer.writeFloat32LE(metallicFactor)
        writer.writeFloat32LE(roughnessFactor)
        writer.writeFloat32LE(occlusionStrength)
        writer.writeFloat32LE(alphaCutoff)
        writer.writeUInt32LE(baseColorTextureIndex)
        writer.writeUInt32LE(normalTextureIndex)
        writer.writeUInt32LE(metallicTextureIndex)
        writer.writeUInt32LE(roughnessTextureIndex)
        writer.writeUInt32LE(emissiveTextureIndex)
        writer.writeUInt32LE(occlusionTextureIndex)
        writer.writeUInt32LE(reserved0[safe: 0] ?? 0)
        writer.writeUInt32LE(reserved0[safe: 1] ?? 0)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldMaterialRecordV1 {
        var record = UntoldMaterialRecordV1(
            nameOffset: try reader.readUInt32LE(),
            flags: try reader.readUInt32LE(),
            baseColorFactor: SIMD4<Float>(
                try reader.readFloat32LE(),
                try reader.readFloat32LE(),
                try reader.readFloat32LE(),
                try reader.readFloat32LE()
            ),
            emissiveFactor: SIMD3<Float>(
                try reader.readFloat32LE(),
                try reader.readFloat32LE(),
                try reader.readFloat32LE()
            ),
            normalScale: try reader.readFloat32LE(),
            metallicFactor: try reader.readFloat32LE(),
            roughnessFactor: try reader.readFloat32LE(),
            occlusionStrength: try reader.readFloat32LE(),
            alphaCutoff: try reader.readFloat32LE(),
            baseColorTextureIndex: try reader.readUInt32LE(),
            normalTextureIndex: try reader.readUInt32LE(),
            metallicTextureIndex: try reader.readUInt32LE(),
            roughnessTextureIndex: try reader.readUInt32LE(),
            emissiveTextureIndex: try reader.readUInt32LE(),
            occlusionTextureIndex: try reader.readUInt32LE()
        )
        record.reserved0 = [
            try reader.readUInt32LE(),
            try reader.readUInt32LE(),
        ]
        return record
    }
}

extension UntoldTextureRefRecordV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeUInt32LE(nameOffset)
        writer.writeUInt32LE(uriOffset)
        writer.writeUInt32LE(textureFormat.rawValue)
        writer.writeUInt32LE(flags)
        writer.writeUInt32LE(width)
        writer.writeUInt32LE(height)
        writer.writeUInt32LE(mipCount)
        writer.writeUInt32LE(reserved0)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldTextureRefRecordV1 {
        let nameOffset = try reader.readUInt32LE()
        let uriOffset = try reader.readUInt32LE()
        let textureFormatRaw = try reader.readUInt32LE()
        guard let textureFormat = UntoldTextureFormat(rawValue: textureFormatRaw) else {
            throw UntoldValidationError.unsupportedEnumValue
        }

        var record = UntoldTextureRefRecordV1(
            nameOffset: nameOffset,
            uriOffset: uriOffset,
            textureFormat: textureFormat,
            flags: try reader.readUInt32LE(),
            width: try reader.readUInt32LE(),
            height: try reader.readUInt32LE(),
            mipCount: try reader.readUInt32LE()
        )
        record.reserved0 = try reader.readUInt32LE()
        return record
    }
}

extension UntoldPBRStaticVertexV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeFloat32LE(position.x)
        writer.writeFloat32LE(position.y)
        writer.writeFloat32LE(position.z)
        writer.writeUInt32LE(normalPacked)
        writer.writeUInt32LE(tangentPacked)
        writer.writeUInt16LE(uv0.x)
        writer.writeUInt16LE(uv0.y)
        writer.writeUInt16LE(uv1.x)
        writer.writeUInt16LE(uv1.y)
        writer.writeUInt8(color0.x)
        writer.writeUInt8(color0.y)
        writer.writeUInt8(color0.z)
        writer.writeUInt8(color0.w)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldPBRStaticVertexV1 {
        UntoldPBRStaticVertexV1(
            position: SIMD3<Float>(
                try reader.readFloat32LE(),
                try reader.readFloat32LE(),
                try reader.readFloat32LE()
            ),
            normalPacked: try reader.readUInt32LE(),
            tangentPacked: try reader.readUInt32LE(),
            uv0: SIMD2<UInt16>(
                try reader.readUInt16LE(),
                try reader.readUInt16LE()
            ),
            uv1: SIMD2<UInt16>(
                try reader.readUInt16LE(),
                try reader.readUInt16LE()
            ),
            color0: SIMD4<UInt8>(
                try reader.readUInt8(),
                try reader.readUInt8(),
                try reader.readUInt8(),
                try reader.readUInt8()
            )
        )
    }
}

public extension UntoldBinaryWriter {
    func writeMatrix4x4LE(_ matrix: simd_float4x4) {
        for column in 0 ..< 4 {
            for row in 0 ..< 4 {
                writeFloat32LE(matrix[column][row])
            }
        }
    }
}

public extension UntoldBinaryReader {
    func readMatrix4x4LE() throws -> simd_float4x4 {
        let c0 = SIMD4<Float>(
            try readFloat32LE(),
            try readFloat32LE(),
            try readFloat32LE(),
            try readFloat32LE()
        )
        let c1 = SIMD4<Float>(
            try readFloat32LE(),
            try readFloat32LE(),
            try readFloat32LE(),
            try readFloat32LE()
        )
        let c2 = SIMD4<Float>(
            try readFloat32LE(),
            try readFloat32LE(),
            try readFloat32LE(),
            try readFloat32LE()
        )
        let c3 = SIMD4<Float>(
            try readFloat32LE(),
            try readFloat32LE(),
            try readFloat32LE(),
            try readFloat32LE()
        )
        return simd_float4x4(columns: (c0, c1, c2, c3))
    }
}

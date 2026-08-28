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
        let min = try SIMD3<Float>(
            reader.readFloat32LE(),
            reader.readFloat32LE(),
            reader.readFloat32LE()
        )
        let max = try SIMD3<Float>(
            reader.readFloat32LE(),
            reader.readFloat32LE(),
            reader.readFloat32LE()
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
        guard let compressionType = UntoldCompressionType(rawValue: compressionRaw) else {
            throw UntoldValidationError.unsupportedEnumValue
        }

        var entry = try UntoldChunkEntryV1(
            chunkType: UntoldChunkType(rawValue: chunkTypeRaw),
            compressionType: compressionType,
            fileOffset: reader.readUInt64LE(),
            compressedSize: reader.readUInt64LE(),
            uncompressedSize: reader.readUInt64LE(),
            elementCount: reader.readUInt32LE()
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
        let magic = try Array(reader.readBytes(count: 8))
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
        let contentHash = try Array(reader.readBytes(count: UntoldFormat.hashByteCount))
        let reserved1 = try Array(reader.readBytes(count: UntoldFormat.hashByteCount))

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
        try UntoldEntityRecordV1(
            entityId: reader.readUInt32LE(),
            parentEntityId: reader.readUInt32LE(),
            nameOffset: reader.readUInt32LE(),
            firstMeshRecordIndex: reader.readUInt32LE(),
            meshRecordCount: reader.readUInt32LE(),
            flags: reader.readUInt32LE(),
            localBounds: UntoldAABB.decode(from: reader),
            worldBounds: UntoldAABB.decode(from: reader),
            localTransform: reader.readMatrix4x4LE()
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
        writer.writeUInt32LE(heightTextureIndex)
        writer.writeFloat32LE(heightScale)
        writer.writeFloat32LE(heightMidlevel)
        writer.writeFloat32LE(heightRemapMin)
        writer.writeFloat32LE(heightRemapMax)
        writer.writeUInt32LE(reserved0[safe: 0] ?? 0)
        writer.writeUInt32LE(reserved0[safe: 1] ?? 0)
    }

    /// Decodes the current (>= `UntoldFormat.minHeightRemapVersion`) on-disk layout, which
    /// includes both the height-map and height-remap fields. Do not call this against files
    /// written by an older exporter — use `decodeLegacyWithHeightNoRemap(from:)` or
    /// `decodeLegacyWithoutHeight(from:)` instead, gated on the file header's `formatVersion`,
    /// or every record after the first will be misaligned.
    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldMaterialRecordV1 {
        var record = try UntoldMaterialRecordV1(
            nameOffset: reader.readUInt32LE(),
            flags: reader.readUInt32LE(),
            baseColorFactor: SIMD4<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            ),
            emissiveFactor: SIMD3<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            ),
            normalScale: reader.readFloat32LE(),
            metallicFactor: reader.readFloat32LE(),
            roughnessFactor: reader.readFloat32LE(),
            occlusionStrength: reader.readFloat32LE(),
            alphaCutoff: reader.readFloat32LE(),
            baseColorTextureIndex: reader.readUInt32LE(),
            normalTextureIndex: reader.readUInt32LE(),
            metallicTextureIndex: reader.readUInt32LE(),
            roughnessTextureIndex: reader.readUInt32LE(),
            emissiveTextureIndex: reader.readUInt32LE(),
            occlusionTextureIndex: reader.readUInt32LE(),
            heightTextureIndex: reader.readUInt32LE(),
            heightScale: reader.readFloat32LE(),
            heightMidlevel: reader.readFloat32LE(),
            heightRemapMin: reader.readFloat32LE(),
            heightRemapMax: reader.readFloat32LE()
        )
        record.reserved0 = try [
            reader.readUInt32LE(),
            reader.readUInt32LE(),
        ]
        return record
    }

    /// Decodes the on-disk layout for `minHeightMapVersion <= formatVersion < minHeightRemapVersion`:
    /// height-map fields present, height-remap fields not yet on disk (defaulted to identity).
    public static func decodeLegacyWithHeightNoRemap(from reader: UntoldBinaryReader) throws -> UntoldMaterialRecordV1 {
        var record = try UntoldMaterialRecordV1(
            nameOffset: reader.readUInt32LE(),
            flags: reader.readUInt32LE(),
            baseColorFactor: SIMD4<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            ),
            emissiveFactor: SIMD3<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            ),
            normalScale: reader.readFloat32LE(),
            metallicFactor: reader.readFloat32LE(),
            roughnessFactor: reader.readFloat32LE(),
            occlusionStrength: reader.readFloat32LE(),
            alphaCutoff: reader.readFloat32LE(),
            baseColorTextureIndex: reader.readUInt32LE(),
            normalTextureIndex: reader.readUInt32LE(),
            metallicTextureIndex: reader.readUInt32LE(),
            roughnessTextureIndex: reader.readUInt32LE(),
            emissiveTextureIndex: reader.readUInt32LE(),
            occlusionTextureIndex: reader.readUInt32LE(),
            heightTextureIndex: reader.readUInt32LE(),
            heightScale: reader.readFloat32LE(),
            heightMidlevel: reader.readFloat32LE()
        )
        record.reserved0 = try [
            reader.readUInt32LE(),
            reader.readUInt32LE(),
        ]
        return record
    }

    /// Decodes the pre-height-map on-disk layout (`formatVersion < UntoldFormat.minHeightMapVersion`).
    /// Height fields are not present on disk for these files and are defaulted; `hasHeightMap`
    /// on the resulting runtime material will correctly report `false` since `heightTextureIndex`
    /// defaults to `UntoldFormat.invalidIndex`.
    public static func decodeLegacyWithoutHeight(from reader: UntoldBinaryReader) throws -> UntoldMaterialRecordV1 {
        var record = try UntoldMaterialRecordV1(
            nameOffset: reader.readUInt32LE(),
            flags: reader.readUInt32LE(),
            baseColorFactor: SIMD4<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            ),
            emissiveFactor: SIMD3<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            ),
            normalScale: reader.readFloat32LE(),
            metallicFactor: reader.readFloat32LE(),
            roughnessFactor: reader.readFloat32LE(),
            occlusionStrength: reader.readFloat32LE(),
            alphaCutoff: reader.readFloat32LE(),
            baseColorTextureIndex: reader.readUInt32LE(),
            normalTextureIndex: reader.readUInt32LE(),
            metallicTextureIndex: reader.readUInt32LE(),
            roughnessTextureIndex: reader.readUInt32LE(),
            emissiveTextureIndex: reader.readUInt32LE(),
            occlusionTextureIndex: reader.readUInt32LE()
        )
        record.reserved0 = try [
            reader.readUInt32LE(),
            reader.readUInt32LE(),
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

        var record = try UntoldTextureRefRecordV1(
            nameOffset: nameOffset,
            uriOffset: uriOffset,
            textureFormat: textureFormat,
            flags: reader.readUInt32LE(),
            width: reader.readUInt32LE(),
            height: reader.readUInt32LE(),
            mipCount: reader.readUInt32LE()
        )
        record.reserved0 = try reader.readUInt32LE()
        return record
    }
}

extension UntoldLightRecordV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeUInt32LE(entityId)
        writer.writeUInt32LE(nameOffset)
        writer.writeUInt32LE(lightType.rawValue)
        writer.writeUInt32LE(flags)
        writer.writeFloat32LE(color.x)
        writer.writeFloat32LE(color.y)
        writer.writeFloat32LE(color.z)
        writer.writeFloat32LE(intensity)
        writer.writeFloat32LE(position.x)
        writer.writeFloat32LE(position.y)
        writer.writeFloat32LE(position.z)
        writer.writeFloat32LE(radius)
        writer.writeFloat32LE(direction.x)
        writer.writeFloat32LE(direction.y)
        writer.writeFloat32LE(direction.z)
        writer.writeFloat32LE(falloff)
        writer.writeFloat32LE(right.x)
        writer.writeFloat32LE(right.y)
        writer.writeFloat32LE(right.z)
        writer.writeFloat32LE(innerCone)
        writer.writeFloat32LE(up.x)
        writer.writeFloat32LE(up.y)
        writer.writeFloat32LE(up.z)
        writer.writeFloat32LE(outerCone)
        writer.writeFloat32LE(areaSize.x)
        writer.writeFloat32LE(areaSize.y)
        writer.writeFloat32LE(sourcePower)
        writer.writeFloat32LE(sourceExposure)
        writer.writeMatrix4x4LE(localTransform)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldLightRecordV1 {
        let entityId = try reader.readUInt32LE()
        let nameOffset = try reader.readUInt32LE()
        let lightTypeRaw = try reader.readUInt32LE()
        guard let lightType = UntoldLightType(rawValue: lightTypeRaw) else {
            throw UntoldValidationError.unsupportedEnumValue
        }

        return try UntoldLightRecordV1(
            entityId: entityId,
            nameOffset: nameOffset,
            lightType: lightType,
            flags: reader.readUInt32LE(),
            color: SIMD3<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            ),
            intensity: reader.readFloat32LE(),
            position: SIMD3<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            ),
            radius: reader.readFloat32LE(),
            direction: SIMD3<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            ),
            falloff: reader.readFloat32LE(),
            right: SIMD3<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            ),
            innerCone: reader.readFloat32LE(),
            up: SIMD3<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            ),
            outerCone: reader.readFloat32LE(),
            areaSize: SIMD2<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE()
            ),
            sourcePower: reader.readFloat32LE(),
            sourceExposure: reader.readFloat32LE(),
            localTransform: reader.readMatrix4x4LE()
        )
    }
}

extension UntoldCameraRecordV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeUInt32LE(entityId)
        writer.writeUInt32LE(nameOffset)
        writer.writeUInt32LE(flags)
        writer.writeUInt32LE(reserved0)
        writer.writeFloat32LE(position.x)
        writer.writeFloat32LE(position.y)
        writer.writeFloat32LE(position.z)
        writer.writeFloat32LE(fovYDegrees)
        writer.writeFloat32LE(forward.x)
        writer.writeFloat32LE(forward.y)
        writer.writeFloat32LE(forward.z)
        writer.writeFloat32LE(nearClip)
        writer.writeFloat32LE(up.x)
        writer.writeFloat32LE(up.y)
        writer.writeFloat32LE(up.z)
        writer.writeFloat32LE(farClip)
        writer.writeFloat32LE(right.x)
        writer.writeFloat32LE(right.y)
        writer.writeFloat32LE(right.z)
        writer.writeFloat32LE(aspectRatio)
        writer.writeMatrix4x4LE(localTransform)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldCameraRecordV1 {
        let entityId = try reader.readUInt32LE()
        let nameOffset = try reader.readUInt32LE()
        let flags = try reader.readUInt32LE()
        let reserved0 = try reader.readUInt32LE()
        var record = try UntoldCameraRecordV1(
            entityId: entityId,
            nameOffset: nameOffset,
            flags: flags,
            position: SIMD3<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            ),
            fovYDegrees: reader.readFloat32LE(),
            forward: SIMD3<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            ),
            nearClip: reader.readFloat32LE(),
            up: SIMD3<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            ),
            farClip: reader.readFloat32LE(),
            right: SIMD3<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            ),
            aspectRatio: reader.readFloat32LE(),
            localTransform: reader.readMatrix4x4LE()
        )
        record.reserved0 = reserved0
        return record
    }
}

extension UntoldColorManagementRecordV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeUInt32LE(lutTextureIndex)
        writer.writeUInt32LE(viewTransformNameOffset)
        writer.writeUInt32LE(lookNameOffset)
        writer.writeFloat32LE(exposure)
        writer.writeFloat32LE(gamma)
        writer.writeFloat32LE(shaperMinStops)
        writer.writeFloat32LE(shaperMaxStops)
        writer.writeUInt32LE(lutSize)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldColorManagementRecordV1 {
        try UntoldColorManagementRecordV1(
            lutTextureIndex: reader.readUInt32LE(),
            viewTransformNameOffset: reader.readUInt32LE(),
            lookNameOffset: reader.readUInt32LE(),
            exposure: reader.readFloat32LE(),
            gamma: reader.readFloat32LE(),
            shaperMinStops: reader.readFloat32LE(),
            shaperMaxStops: reader.readFloat32LE(),
            lutSize: reader.readUInt32LE()
        )
    }
}

extension UntoldSkeletonRecordV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeUInt32LE(entityId)
        writer.writeUInt32LE(nameOffset)
        writer.writeUInt32LE(firstJointRecordIndex)
        writer.writeUInt32LE(jointRecordCount)
        writer.writeUInt32LE(reserved0[safe: 0] ?? 0)
        writer.writeUInt32LE(reserved0[safe: 1] ?? 0)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldSkeletonRecordV1 {
        var record = try UntoldSkeletonRecordV1(
            entityId: reader.readUInt32LE(),
            nameOffset: reader.readUInt32LE(),
            firstJointRecordIndex: reader.readUInt32LE(),
            jointRecordCount: reader.readUInt32LE()
        )
        record.reserved0 = try [
            reader.readUInt32LE(),
            reader.readUInt32LE(),
        ]
        return record
    }
}

extension UntoldSkeletonJointRecordV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeUInt32LE(parentJointIndex)
        writer.writeUInt32LE(jointPathOffset)
        writer.writeUInt32LE(flags)
        writer.writeUInt32LE(reserved0)
        writer.writeMatrix4x4LE(bindTransform)
        writer.writeMatrix4x4LE(restTransform)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldSkeletonJointRecordV1 {
        let parentJointIndex = try reader.readUInt32LE()
        let jointPathOffset = try reader.readUInt32LE()
        let flags = try reader.readUInt32LE()
        let reserved0 = try reader.readUInt32LE()
        var record = try UntoldSkeletonJointRecordV1(
            parentJointIndex: parentJointIndex,
            jointPathOffset: jointPathOffset,
            flags: flags,
            bindTransform: reader.readMatrix4x4LE(),
            restTransform: reader.readMatrix4x4LE()
        )
        record.reserved0 = reserved0
        return record
    }
}

extension UntoldSkinRecordV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeUInt32LE(entityId)
        writer.writeUInt32LE(meshRecordIndex)
        writer.writeUInt32LE(skeletonEntityId)
        writer.writeUInt32LE(jointCount)
        writer.writeUInt32LE(firstJointMappingIndex)
        writer.writeUInt32LE(vertexCount)
        writer.writeUInt64LE(jointIndexDataOffset)
        writer.writeUInt64LE(jointWeightDataOffset)
        writer.writeUInt32LE(reserved0)
        writer.writeUInt32LE(0)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldSkinRecordV1 {
        var record = try UntoldSkinRecordV1(
            entityId: reader.readUInt32LE(),
            meshRecordIndex: reader.readUInt32LE(),
            skeletonEntityId: reader.readUInt32LE(),
            jointCount: reader.readUInt32LE(),
            firstJointMappingIndex: reader.readUInt32LE(),
            jointIndexDataOffset: 0,
            jointWeightDataOffset: 0,
            vertexCount: reader.readUInt32LE()
        )
        record.jointIndexDataOffset = try reader.readUInt64LE()
        record.jointWeightDataOffset = try reader.readUInt64LE()
        record.reserved0 = try reader.readUInt32LE()
        _ = try reader.readUInt32LE()
        return record
    }
}

extension UntoldSkinJointMappingRecordV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeUInt32LE(skeletonJointIndex)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldSkinJointMappingRecordV1 {
        try UntoldSkinJointMappingRecordV1(skeletonJointIndex: reader.readUInt32LE())
    }
}

extension UntoldAnimationClipRecordV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeUInt32LE(nameOffset)
        writer.writeFloat32LE(duration)
        writer.writeUInt32LE(firstChannelRecordIndex)
        writer.writeUInt32LE(channelRecordCount)
        writer.writeUInt32LE(flags)
        writer.writeUInt32LE(reserved0[safe: 0] ?? 0)
        writer.writeUInt32LE(reserved0[safe: 1] ?? 0)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldAnimationClipRecordV1 {
        var record = try UntoldAnimationClipRecordV1(
            nameOffset: reader.readUInt32LE(),
            duration: reader.readFloat32LE(),
            firstChannelRecordIndex: reader.readUInt32LE(),
            channelRecordCount: reader.readUInt32LE(),
            flags: reader.readUInt32LE()
        )
        record.reserved0 = try [
            reader.readUInt32LE(),
            reader.readUInt32LE(),
        ]
        return record
    }
}

extension UntoldAnimationChannelRecordV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeUInt32LE(jointPathOffset)
        writer.writeUInt32LE(firstTranslationKeyframeIndex)
        writer.writeUInt32LE(translationKeyframeCount)
        writer.writeUInt32LE(firstRotationKeyframeIndex)
        writer.writeUInt32LE(rotationKeyframeCount)
        writer.writeUInt32LE(flags)
        writer.writeUInt32LE(reserved0)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldAnimationChannelRecordV1 {
        var record = try UntoldAnimationChannelRecordV1(
            jointPathOffset: reader.readUInt32LE(),
            firstTranslationKeyframeIndex: reader.readUInt32LE(),
            translationKeyframeCount: reader.readUInt32LE(),
            firstRotationKeyframeIndex: reader.readUInt32LE(),
            rotationKeyframeCount: reader.readUInt32LE(),
            flags: reader.readUInt32LE()
        )
        record.reserved0 = try reader.readUInt32LE()
        return record
    }
}

extension UntoldTranslationKeyframeRecordV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeFloat32LE(time)
        writer.writeFloat32LE(value.x)
        writer.writeFloat32LE(value.y)
        writer.writeFloat32LE(value.z)
        writer.writeUInt32LE(reserved0)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldTranslationKeyframeRecordV1 {
        var record = try UntoldTranslationKeyframeRecordV1(
            time: reader.readFloat32LE(),
            value: SIMD3<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            )
        )
        record.reserved0 = try reader.readUInt32LE()
        return record
    }
}

extension UntoldRotationKeyframeRecordV1: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeFloat32LE(time)
        writer.writeFloat32LE(value.x)
        writer.writeFloat32LE(value.y)
        writer.writeFloat32LE(value.z)
        writer.writeFloat32LE(value.w)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldRotationKeyframeRecordV1 {
        try UntoldRotationKeyframeRecordV1(
            time: reader.readFloat32LE(),
            value: SIMD4<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            )
        )
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
        try UntoldPBRStaticVertexV1(
            position: SIMD3<Float>(
                reader.readFloat32LE(),
                reader.readFloat32LE(),
                reader.readFloat32LE()
            ),
            normalPacked: reader.readUInt32LE(),
            tangentPacked: reader.readUInt32LE(),
            uv0: SIMD2<UInt16>(
                reader.readUInt16LE(),
                reader.readUInt16LE()
            ),
            uv1: SIMD2<UInt16>(
                reader.readUInt16LE(),
                reader.readUInt16LE()
            ),
            color0: SIMD4<UInt8>(
                reader.readUInt8(),
                reader.readUInt8(),
                reader.readUInt8(),
                reader.readUInt8()
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
        let c0 = try SIMD4<Float>(
            readFloat32LE(),
            readFloat32LE(),
            readFloat32LE(),
            readFloat32LE()
        )
        let c1 = try SIMD4<Float>(
            readFloat32LE(),
            readFloat32LE(),
            readFloat32LE(),
            readFloat32LE()
        )
        let c2 = try SIMD4<Float>(
            readFloat32LE(),
            readFloat32LE(),
            readFloat32LE(),
            readFloat32LE()
        )
        let c3 = try SIMD4<Float>(
            readFloat32LE(),
            readFloat32LE(),
            readFloat32LE(),
            readFloat32LE()
        )
        return simd_float4x4(columns: (c0, c1, c2, c3))
    }
}

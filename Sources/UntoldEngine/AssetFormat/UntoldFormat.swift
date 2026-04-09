//
//  UntoldFormat.swift
//  UntoldEngine
//
//  Core binary format types for the cooked `.untold` runtime asset container.
//  Defines the V1 file header, chunk table, entity/mesh/material/texture records,
//  and shared enums/constants used by the reader and validation layers.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

public enum UntoldFormat {
    public static let magic = "UNTOLD\0"
    public static let version: UInt32 = 1
    public static let fileAlignment: UInt64 = 16
    public static let invalidIndex: UInt32 = .max
    public static let hashByteCount = 32
}

public enum UntoldFileType: UInt32, Sendable {
    case tile = 1
    case lod = 2
    case hlod = 3
    case shared = 4
}

public enum UntoldChunkType: UInt32, Sendable {
    case stringTable = 1
    case entityTable = 2
    case meshTable = 3
    case materialTable = 4
    case textureTable = 5
    case vertexData = 6
    case indexData = 7
}

public enum UntoldCompressionType: UInt32, Sendable {
    case none = 0
    case lz4 = 1
    case zstd = 2
}

public enum UntoldVertexLayout: UInt32, Sendable {
    case pbrStaticV1 = 1
}

public enum UntoldIndexType: UInt32, Sendable {
    case uint16 = 1
    case uint32 = 2
}

public enum UntoldTextureFormat: UInt32, Sendable {
    case unknown = 0
    case rgba8 = 1
    case bc7 = 2
    case bc5 = 3
    case astc4x4 = 4
    case astc5x5 = 5
    case astc6x6 = 6
    case astc8x8 = 7

    /// True for formats stored in the engine-native .utex container and uploaded
    /// directly to Metal without passing through MTKTextureLoader or CGImage.
    public var isASTCNative: Bool {
        switch self {
        case .astc4x4, .astc5x5, .astc6x6, .astc8x8: true
        default: false
        }
    }
}

public struct UntoldAABB: Sendable, Equatable {
    public var min: SIMD3<Float>
    public var max: SIMD3<Float>

    public init(min: SIMD3<Float>, max: SIMD3<Float>) {
        self.min = min
        self.max = max
    }
}

public struct UntoldFileHeaderV1: Sendable, Equatable {
    /// Fixed-length 8-byte magic. Expected value: "UNTOLD\0\0".
    public var magic: [UInt8]
    public var formatVersion: UInt32
    public var fileType: UntoldFileType
    public var flags: UInt32
    public var headerSize: UInt32
    public var chunkCount: UInt32
    public var meshCount: UInt32
    public var materialCount: UInt32
    public var textureRefCount: UInt32
    public var entityCount: UInt32
    public var vertexLayout: UntoldVertexLayout
    public var reserved0: UInt32
    public var worldBounds: UntoldAABB
    public var rootTransform: simd_float4x4
    /// Fixed-length 32-byte SHA-256 digest.
    public var contentHash: [UInt8]
    /// Reserved fixed-length 32-byte field for forward compatibility.
    public var reserved1: [UInt8]

    public init(
        fileType: UntoldFileType,
        chunkCount: UInt32,
        meshCount: UInt32,
        materialCount: UInt32,
        textureRefCount: UInt32,
        entityCount: UInt32,
        vertexLayout: UntoldVertexLayout,
        worldBounds: UntoldAABB,
        rootTransform: simd_float4x4 = matrix_identity_float4x4
    ) {
        magic = [85, 78, 84, 79, 76, 68, 0, 0]
        formatVersion = UntoldFormat.version
        self.fileType = fileType
        flags = 0
        headerSize = UInt32(MemoryLayout<UntoldFileHeaderV1>.size)
        self.chunkCount = chunkCount
        self.meshCount = meshCount
        self.materialCount = materialCount
        self.textureRefCount = textureRefCount
        self.entityCount = entityCount
        self.vertexLayout = vertexLayout
        reserved0 = 0
        self.worldBounds = worldBounds
        self.rootTransform = rootTransform
        contentHash = Array(repeating: 0, count: UntoldFormat.hashByteCount)
        reserved1 = Array(repeating: 0, count: UntoldFormat.hashByteCount)
    }
}

public struct UntoldChunkEntryV1: Sendable, Equatable {
    public var chunkType: UntoldChunkType
    public var compressionType: UntoldCompressionType
    public var fileOffset: UInt64
    public var compressedSize: UInt64
    public var uncompressedSize: UInt64
    public var elementCount: UInt32
    public var reserved0: UInt32

    public init(
        chunkType: UntoldChunkType,
        compressionType: UntoldCompressionType = .none,
        fileOffset: UInt64,
        compressedSize: UInt64,
        uncompressedSize: UInt64,
        elementCount: UInt32 = 0
    ) {
        self.chunkType = chunkType
        self.compressionType = compressionType
        self.fileOffset = fileOffset
        self.compressedSize = compressedSize
        self.uncompressedSize = uncompressedSize
        self.elementCount = elementCount
        reserved0 = 0
    }
}

public struct UntoldEntityRecordV1: Sendable, Equatable {
    public var entityId: UInt32
    public var parentEntityId: UInt32
    public var nameOffset: UInt32
    public var firstMeshRecordIndex: UInt32
    public var meshRecordCount: UInt32
    public var flags: UInt32
    public var localBounds: UntoldAABB
    public var worldBounds: UntoldAABB
    public var localTransform: simd_float4x4

    public init(
        entityId: UInt32,
        parentEntityId: UInt32 = UntoldFormat.invalidIndex,
        nameOffset: UInt32 = UntoldFormat.invalidIndex,
        firstMeshRecordIndex: UInt32 = 0,
        meshRecordCount: UInt32 = 0,
        flags: UInt32 = 0,
        localBounds: UntoldAABB,
        worldBounds: UntoldAABB,
        localTransform: simd_float4x4 = matrix_identity_float4x4
    ) {
        self.entityId = entityId
        self.parentEntityId = parentEntityId
        self.nameOffset = nameOffset
        self.firstMeshRecordIndex = firstMeshRecordIndex
        self.meshRecordCount = meshRecordCount
        self.flags = flags
        self.localBounds = localBounds
        self.worldBounds = worldBounds
        self.localTransform = localTransform
    }
}

public struct UntoldMeshRecordV1: Sendable, Equatable {
    public var entityId: UInt32
    public var meshNameOffset: UInt32
    public var materialIndex: UInt32
    public var indexType: UntoldIndexType
    public var vertexCount: UInt32
    public var indexCount: UInt32
    public var vertexStrideBytes: UInt32
    public var flags: UInt32
    public var vertexDataOffset: UInt64
    public var indexDataOffset: UInt64
    public var vertexDataSizeBytes: UInt64
    public var indexDataSizeBytes: UInt64
    public var estimatedGPUBytes: UInt64
    public var reserved0: UInt64
    public var localBounds: UntoldAABB

    public init(
        entityId: UInt32,
        meshNameOffset: UInt32 = UntoldFormat.invalidIndex,
        materialIndex: UInt32 = UntoldFormat.invalidIndex,
        indexType: UntoldIndexType,
        vertexCount: UInt32,
        indexCount: UInt32,
        vertexStrideBytes: UInt32,
        flags: UInt32 = 0,
        vertexDataOffset: UInt64,
        indexDataOffset: UInt64,
        vertexDataSizeBytes: UInt64,
        indexDataSizeBytes: UInt64,
        estimatedGPUBytes: UInt64,
        localBounds: UntoldAABB
    ) {
        self.entityId = entityId
        self.meshNameOffset = meshNameOffset
        self.materialIndex = materialIndex
        self.indexType = indexType
        self.vertexCount = vertexCount
        self.indexCount = indexCount
        self.vertexStrideBytes = vertexStrideBytes
        self.flags = flags
        self.vertexDataOffset = vertexDataOffset
        self.indexDataOffset = indexDataOffset
        self.vertexDataSizeBytes = vertexDataSizeBytes
        self.indexDataSizeBytes = indexDataSizeBytes
        self.estimatedGPUBytes = estimatedGPUBytes
        reserved0 = 0
        self.localBounds = localBounds
    }
}

public struct UntoldMaterialRecordV1: Sendable, Equatable {
    public var nameOffset: UInt32
    public var flags: UInt32
    public var baseColorFactor: SIMD4<Float>
    public var emissiveFactor: SIMD3<Float>
    public var normalScale: Float
    public var metallicFactor: Float
    public var roughnessFactor: Float
    public var occlusionStrength: Float
    public var alphaCutoff: Float
    public var baseColorTextureIndex: UInt32
    public var normalTextureIndex: UInt32
    public var metallicTextureIndex: UInt32
    public var roughnessTextureIndex: UInt32
    public var emissiveTextureIndex: UInt32
    public var occlusionTextureIndex: UInt32
    /// Reserved fixed-length 2-word field for forward compatibility.
    public var reserved0: [UInt32]

    public init(
        nameOffset: UInt32 = UntoldFormat.invalidIndex,
        flags: UInt32 = 0,
        baseColorFactor: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1),
        emissiveFactor: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
        normalScale: Float = 1.0,
        metallicFactor: Float = 1.0,
        roughnessFactor: Float = 1.0,
        occlusionStrength: Float = 1.0,
        alphaCutoff: Float = 0.5,
        baseColorTextureIndex: UInt32 = UntoldFormat.invalidIndex,
        normalTextureIndex: UInt32 = UntoldFormat.invalidIndex,
        metallicTextureIndex: UInt32 = UntoldFormat.invalidIndex,
        roughnessTextureIndex: UInt32 = UntoldFormat.invalidIndex,
        emissiveTextureIndex: UInt32 = UntoldFormat.invalidIndex,
        occlusionTextureIndex: UInt32 = UntoldFormat.invalidIndex
    ) {
        self.nameOffset = nameOffset
        self.flags = flags
        self.baseColorFactor = baseColorFactor
        self.emissiveFactor = emissiveFactor
        self.normalScale = normalScale
        self.metallicFactor = metallicFactor
        self.roughnessFactor = roughnessFactor
        self.occlusionStrength = occlusionStrength
        self.alphaCutoff = alphaCutoff
        self.baseColorTextureIndex = baseColorTextureIndex
        self.normalTextureIndex = normalTextureIndex
        self.metallicTextureIndex = metallicTextureIndex
        self.roughnessTextureIndex = roughnessTextureIndex
        self.emissiveTextureIndex = emissiveTextureIndex
        self.occlusionTextureIndex = occlusionTextureIndex
        reserved0 = [0, 0]
    }
}

public struct UntoldTextureRefRecordV1: Sendable, Equatable {
    public var nameOffset: UInt32
    public var uriOffset: UInt32
    public var textureFormat: UntoldTextureFormat
    public var flags: UInt32
    public var width: UInt32
    public var height: UInt32
    public var mipCount: UInt32
    public var reserved0: UInt32

    public init(
        nameOffset: UInt32 = UntoldFormat.invalidIndex,
        uriOffset: UInt32 = UntoldFormat.invalidIndex,
        textureFormat: UntoldTextureFormat = .unknown,
        flags: UInt32 = 0,
        width: UInt32 = 0,
        height: UInt32 = 0,
        mipCount: UInt32 = 0
    ) {
        self.nameOffset = nameOffset
        self.uriOffset = uriOffset
        self.textureFormat = textureFormat
        self.flags = flags
        self.width = width
        self.height = height
        self.mipCount = mipCount
        reserved0 = 0
    }
}

/// Packed 32-byte vertex used by the V1 static PBR layout.
public struct UntoldPBRStaticVertexV1: Sendable, Equatable {
    public var position: SIMD3<Float>
    public var normalPacked: UInt32
    public var tangentPacked: UInt32
    public var uv0: SIMD2<UInt16>
    public var uv1: SIMD2<UInt16>
    public var color0: SIMD4<UInt8>

    public init(
        position: SIMD3<Float>,
        normalPacked: UInt32,
        tangentPacked: UInt32,
        uv0: SIMD2<UInt16> = SIMD2<UInt16>(0, 0),
        uv1: SIMD2<UInt16> = SIMD2<UInt16>(0, 0),
        color0: SIMD4<UInt8> = SIMD4<UInt8>(255, 255, 255, 255)
    ) {
        self.position = position
        self.normalPacked = normalPacked
        self.tangentPacked = tangentPacked
        self.uv0 = uv0
        self.uv1 = uv1
        self.color0 = color0
    }
}

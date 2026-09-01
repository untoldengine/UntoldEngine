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
    /// Current format version written by the exporter. Bumped to 2 when the
    /// Blender exporter started multiplying emissive_factor by Emission
    /// Strength — files below `minTrustedEmissiveVersion` were written before
    /// that fix and can carry a bogus (1,1,1) emissiveFactor left over from
    /// Blender's default Emission Color, so readers must not trust it.
    /// Bumped to 3 when the material record grew height-map fields
    /// (`heightTextureIndex`, `heightScale`, `heightMidlevel`) — see
    /// `minHeightMapVersion`. Files below that version don't have these bytes
    /// on disk at all, so the reader must not attempt to decode them.
    /// Bumped to 4 when the material record grew height-remap fields
    /// (`heightRemapMin`, `heightRemapMax`) — see `minHeightRemapVersion`.
    public static let version: UInt32 = 4
    /// Oldest format version this reader will still load.
    public static let minSupportedVersion: UInt32 = 1
    /// First format version whose emissiveFactor is safe to use as authored.
    public static let minTrustedEmissiveVersion: UInt32 = 2
    /// First format version whose material record includes height-map fields.
    /// Files older than this must be decoded with the legacy (pre-height) material
    /// record layout, or the reader will misalign every subsequent record in the
    /// MATERIAL_TABLE chunk.
    public static let minHeightMapVersion: UInt32 = 3
    /// First format version whose material record includes height-remap fields
    /// (heightRemapMin/heightRemapMax). Files between minHeightMapVersion and this
    /// version have height fields but not remap fields on disk.
    public static let minHeightRemapVersion: UInt32 = 4
    public static let fileAlignment: UInt64 = 16
    public static let invalidIndex: UInt32 = .max
    public static let hashByteCount = 32
}

public enum UntoldFileType: UInt32, Sendable {
    case tile = 1
    case lod = 2
    case hlod = 3
    case shared = 4
    case animation = 5
}

public struct UntoldChunkType: RawRepresentable, Hashable, Sendable, Equatable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let stringTable = UntoldChunkType(rawValue: 1)
    public static let entityTable = UntoldChunkType(rawValue: 2)
    public static let meshTable = UntoldChunkType(rawValue: 3)
    public static let materialTable = UntoldChunkType(rawValue: 4)
    public static let textureTable = UntoldChunkType(rawValue: 5)
    public static let vertexData = UntoldChunkType(rawValue: 6)
    public static let indexData = UntoldChunkType(rawValue: 7)
    public static let skeletonTable = UntoldChunkType(rawValue: 8)
    public static let skeletonJointTable = UntoldChunkType(rawValue: 9)
    public static let skinTable = UntoldChunkType(rawValue: 10)
    public static let skinJointMappingTable = UntoldChunkType(rawValue: 11)
    public static let animationClipTable = UntoldChunkType(rawValue: 12)
    public static let animationChannelTable = UntoldChunkType(rawValue: 13)
    public static let translationKeyframeTable = UntoldChunkType(rawValue: 14)
    public static let rotationKeyframeTable = UntoldChunkType(rawValue: 15)
    public static let jointIndexData = UntoldChunkType(rawValue: 16)
    public static let jointWeightData = UntoldChunkType(rawValue: 17)
    public static let edgeIndexData = UntoldChunkType(rawValue: 18)
    public static let lightTable = UntoldChunkType(rawValue: 19)
    public static let cameraTable = UntoldChunkType(rawValue: 20)
    public static let colorManagementTable = UntoldChunkType(rawValue: 21)
    public static let colorGradeLUTTable = UntoldChunkType(rawValue: 22)

    public static let firstPluginChunkRawValue: UInt32 = 0x8000

    public var isPluginExtensionChunk: Bool {
        rawValue >= Self.firstPluginChunkRawValue
    }
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
    case rgba16Float = 8
    /// Single-channel, 16-bit, linear, uncompressed — height/displacement map data.
    /// Bypasses ASTC deliberately; see NativeTexFormat.r16UnormPixelFormat.
    case r16Unorm = 9

    /// True for formats stored in the engine-native .utex container and uploaded
    /// directly to Metal without passing through MTKTextureLoader or CGImage.
    public var isASTCNative: Bool {
        switch self {
        case .astc4x4, .astc5x5, .astc6x6, .astc8x8: true
        default: false
        }
    }

    /// True when the referenced file is an engine-native `.utex` container.
    public var isNativeContainer: Bool {
        isASTCNative || self == .rgba16Float || self == .r16Unorm
    }
}

/// Bits of `UntoldTextureRefRecordV1.flags` set by the exporter (see
/// TEXTURE_FLAG_* in scripts/untoldexplorer.py). Most are informational only
/// today; `lut` is the one the runtime currently acts on, to identify the
/// color-grading LUT texture regardless of filename.
public enum UntoldTextureFlags {
    public static let srgb: UInt32 = 1 << 0
    public static let normalMap: UInt32 = 1 << 1
    public static let lut: UInt32 = 1 << 2
    public static let emissive: UInt32 = 1 << 6
    public static let occlusion: UInt32 = 1 << 7
}

public enum UntoldTextureChannel: UInt32, Sendable, Equatable {
    case r = 0
    case g = 1
    case b = 2
    case a = 3

    public static func decoded(from rawValue: UInt32) -> UntoldTextureChannel {
        UntoldTextureChannel(rawValue: rawValue & 0b11) ?? .r
    }
}

public enum UntoldLightType: UInt32, Sendable {
    case directional = 1
    case point = 2
    case spot = 3
    case area = 4
}

/// Bits stored in `UntoldLightRecordV1.flags`.
///
/// `radiometric` also gives the legacy `falloff` float a new, compatible
/// meaning: it stores an optional influence range in scene units (zero means
/// automatic/unbounded). Records without this bit retain the old artistic
/// attenuation behavior.
public enum UntoldLightFlags {
    public static let castsShadow: UInt32 = 1 << 0
    public static let radiometric: UInt32 = 1 << 1
    public static let customDistance: UInt32 = 1 << 2
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

    public var edgeIndexDataOffset: UInt32 {
        UInt32(reserved0 & 0xFFFF_FFFF)
    }

    public var edgeIndexCount: UInt32 {
        UInt32((reserved0 >> 32) & 0xFFFF_FFFF)
    }

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
    private static let roughnessChannelShift: UInt32 = 0
    private static let metallicChannelShift: UInt32 = 2
    private static let textureChannelMask: UInt32 = 0b11
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
    /// Total Parallax Occlusion Mapping ray-march depth, in UV-normalized units.
    public var heightScale: Float
    /// Height-sample offset, matching Blender's Displacement node "Midlevel" input.
    public var heightMidlevel: Float
    public var heightTextureIndex: UInt32
    /// Contrast-stretch bounds applied to the raw height sample before heightMidlevel.
    /// Identity is (0.0, 1.0).
    public var heightRemapMin: Float
    public var heightRemapMax: Float
    /// Reserved fixed-length 2-word field for forward compatibility.
    public var reserved0: [UInt32]
    public var roughnessTextureChannel: UntoldTextureChannel {
        let word = reserved0.first ?? 0
        return UntoldTextureChannel.decoded(from: word >> Self.roughnessChannelShift)
    }

    public var metallicTextureChannel: UntoldTextureChannel {
        let word = reserved0.first ?? 0
        return UntoldTextureChannel.decoded(from: word >> Self.metallicChannelShift)
    }

    public static func packTextureChannels(
        roughness: UntoldTextureChannel = .r,
        metallic: UntoldTextureChannel = .r
    ) -> UInt32 {
        ((roughness.rawValue & textureChannelMask) << roughnessChannelShift)
            | ((metallic.rawValue & textureChannelMask) << metallicChannelShift)
    }

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
        occlusionTextureIndex: UInt32 = UntoldFormat.invalidIndex,
        heightTextureIndex: UInt32 = UntoldFormat.invalidIndex,
        heightScale: Float = 0.05,
        heightMidlevel: Float = 0.5,
        heightRemapMin: Float = 0.0,
        heightRemapMax: Float = 1.0,
        roughnessTextureChannel: UntoldTextureChannel = .r,
        metallicTextureChannel: UntoldTextureChannel = .r
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
        self.heightTextureIndex = heightTextureIndex
        self.heightScale = heightScale
        self.heightMidlevel = heightMidlevel
        self.heightRemapMin = heightRemapMin
        self.heightRemapMax = heightRemapMax
        reserved0 = [
            Self.packTextureChannels(
                roughness: roughnessTextureChannel,
                metallic: metallicTextureChannel
            ),
            0,
        ]
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

public struct UntoldLightRecordV1: Sendable, Equatable {
    public var entityId: UInt32
    public var nameOffset: UInt32
    public var lightType: UntoldLightType
    public var flags: UInt32
    public var color: SIMD3<Float>
    public var intensity: Float
    public var position: SIMD3<Float>
    public var radius: Float
    public var direction: SIMD3<Float>
    /// Legacy artistic falloff, or influence range when
    /// `UntoldLightFlags.radiometric` is set.
    public var falloff: Float
    public var right: SIMD3<Float>
    public var innerCone: Float
    public var up: SIMD3<Float>
    public var outerCone: Float
    public var areaSize: SIMD2<Float>
    public var sourcePower: Float
    public var sourceExposure: Float
    public var localTransform: simd_float4x4

    public init(
        entityId: UInt32,
        nameOffset: UInt32 = UntoldFormat.invalidIndex,
        lightType: UntoldLightType,
        flags: UInt32 = 0,
        color: SIMD3<Float> = SIMD3<Float>(1, 1, 1),
        intensity: Float = 1.0,
        position: SIMD3<Float> = .zero,
        radius: Float = 1.0,
        direction: SIMD3<Float> = SIMD3<Float>(0, -1, 0),
        falloff: Float = 0.5,
        right: SIMD3<Float> = SIMD3<Float>(1, 0, 0),
        innerCone: Float = 5.0,
        up: SIMD3<Float> = SIMD3<Float>(0, 1, 0),
        outerCone: Float = 10.0,
        areaSize: SIMD2<Float> = SIMD2<Float>(1, 1),
        sourcePower: Float = 1.0,
        sourceExposure: Float = 0.0,
        localTransform: simd_float4x4 = matrix_identity_float4x4
    ) {
        self.entityId = entityId
        self.nameOffset = nameOffset
        self.lightType = lightType
        self.flags = flags
        self.color = color
        self.intensity = intensity
        self.position = position
        self.radius = radius
        self.direction = direction
        self.falloff = falloff
        self.right = right
        self.innerCone = innerCone
        self.up = up
        self.outerCone = outerCone
        self.areaSize = areaSize
        self.sourcePower = sourcePower
        self.sourceExposure = sourceExposure
        self.localTransform = localTransform
    }
}

public struct UntoldCameraRecordV1: Sendable, Equatable {
    public var entityId: UInt32
    public var nameOffset: UInt32
    public var flags: UInt32
    public var reserved0: UInt32
    public var position: SIMD3<Float>
    public var fovYDegrees: Float
    public var forward: SIMD3<Float>
    public var nearClip: Float
    public var up: SIMD3<Float>
    public var farClip: Float
    public var right: SIMD3<Float>
    public var aspectRatio: Float
    public var localTransform: simd_float4x4

    public init(
        entityId: UInt32,
        nameOffset: UInt32 = UntoldFormat.invalidIndex,
        flags: UInt32 = 0,
        position: SIMD3<Float> = .zero,
        fovYDegrees: Float = 50.0,
        forward: SIMD3<Float> = SIMD3<Float>(0, 0, 1),
        nearClip: Float = 0.1,
        up: SIMD3<Float> = SIMD3<Float>(0, 1, 0),
        farClip: Float = 1000.0,
        right: SIMD3<Float> = SIMD3<Float>(1, 0, 0),
        aspectRatio: Float = 1.5,
        localTransform: simd_float4x4 = matrix_identity_float4x4
    ) {
        self.entityId = entityId
        self.nameOffset = nameOffset
        self.flags = flags
        reserved0 = 0
        self.position = position
        self.fovYDegrees = fovYDegrees
        self.forward = forward
        self.nearClip = nearClip
        self.up = up
        self.farClip = farClip
        self.right = right
        self.aspectRatio = aspectRatio
        self.localTransform = localTransform
    }
}

/// Scene-wide color-management bake (see ColorManagementRecord in
/// scripts/untoldexplorer.py). At most one per file — the LUT reproduces
/// the source scene's View Transform/Look/Exposure/Gamma for a canonical sRGB
/// display target, captured through Blender rather than reimplemented.
public struct UntoldColorManagementRecordV1: Sendable, Equatable {
    public var lutTextureIndex: UInt32
    public var viewTransformNameOffset: UInt32
    public var lookNameOffset: UInt32
    public var exposure: Float
    public var gamma: Float
    public var shaperMinStops: Float
    public var shaperMaxStops: Float
    public var lutSize: UInt32

    public init(
        lutTextureIndex: UInt32 = UntoldFormat.invalidIndex,
        viewTransformNameOffset: UInt32 = UntoldFormat.invalidIndex,
        lookNameOffset: UInt32 = UntoldFormat.invalidIndex,
        exposure: Float = 0.0,
        gamma: Float = 1.0,
        shaperMinStops: Float = -10.0,
        shaperMaxStops: Float = 6.0,
        lutSize: UInt32 = 0
    ) {
        self.lutTextureIndex = lutTextureIndex
        self.viewTransformNameOffset = viewTransformNameOffset
        self.lookNameOffset = lookNameOffset
        self.exposure = exposure
        self.gamma = gamma
        self.shaperMinStops = shaperMinStops
        self.shaperMaxStops = shaperMaxStops
        self.lutSize = lutSize
    }
}

/// An externally-authored standard .cube 3D LUT staged alongside the export
/// (see ColorGradeLUTRecord in scripts/untoldexplorer.py), applied as a
/// post-tonemap creative grade. At most one per file. Unlike
/// UntoldColorManagementRecordV1 above, this references a plain staged file
/// via a string-table URI, not a native texture-table entry -- the engine
/// parses/uploads the .cube directly (see CubeLUTLoader) rather than going
/// through the native texture pipeline.
public struct UntoldColorGradeLUTRecordV1: Sendable, Equatable {
    public var lutUriOffset: UInt32
    public var lutSize: UInt32
    public var domainMin: SIMD3<Float>
    public var domainMax: SIMD3<Float>

    public init(
        lutUriOffset: UInt32 = UntoldFormat.invalidIndex,
        lutSize: UInt32 = 0,
        domainMin: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
        domainMax: SIMD3<Float> = SIMD3<Float>(1, 1, 1)
    ) {
        self.lutUriOffset = lutUriOffset
        self.lutSize = lutSize
        self.domainMin = domainMin
        self.domainMax = domainMax
    }
}

public struct UntoldSkeletonRecordV1: Sendable, Equatable {
    public var entityId: UInt32
    public var nameOffset: UInt32
    public var firstJointRecordIndex: UInt32
    public var jointRecordCount: UInt32
    public var reserved0: [UInt32]

    public init(
        entityId: UInt32,
        nameOffset: UInt32 = UntoldFormat.invalidIndex,
        firstJointRecordIndex: UInt32 = 0,
        jointRecordCount: UInt32 = 0
    ) {
        self.entityId = entityId
        self.nameOffset = nameOffset
        self.firstJointRecordIndex = firstJointRecordIndex
        self.jointRecordCount = jointRecordCount
        reserved0 = [0, 0]
    }
}

public struct UntoldSkeletonJointRecordV1: Sendable, Equatable {
    public var parentJointIndex: UInt32
    public var jointPathOffset: UInt32
    public var flags: UInt32
    public var reserved0: UInt32
    public var bindTransform: simd_float4x4
    public var restTransform: simd_float4x4

    public init(
        parentJointIndex: UInt32 = UntoldFormat.invalidIndex,
        jointPathOffset: UInt32,
        flags: UInt32 = 0,
        bindTransform: simd_float4x4,
        restTransform: simd_float4x4
    ) {
        self.parentJointIndex = parentJointIndex
        self.jointPathOffset = jointPathOffset
        self.flags = flags
        reserved0 = 0
        self.bindTransform = bindTransform
        self.restTransform = restTransform
    }
}

public struct UntoldSkinRecordV1: Sendable, Equatable {
    public var entityId: UInt32
    public var meshRecordIndex: UInt32
    public var skeletonEntityId: UInt32
    public var jointCount: UInt32
    public var firstJointMappingIndex: UInt32
    public var jointIndexDataOffset: UInt64
    public var jointWeightDataOffset: UInt64
    public var vertexCount: UInt32
    public var reserved0: UInt32

    public init(
        entityId: UInt32,
        meshRecordIndex: UInt32,
        skeletonEntityId: UInt32,
        jointCount: UInt32,
        firstJointMappingIndex: UInt32,
        jointIndexDataOffset: UInt64,
        jointWeightDataOffset: UInt64,
        vertexCount: UInt32
    ) {
        self.entityId = entityId
        self.meshRecordIndex = meshRecordIndex
        self.skeletonEntityId = skeletonEntityId
        self.jointCount = jointCount
        self.firstJointMappingIndex = firstJointMappingIndex
        self.jointIndexDataOffset = jointIndexDataOffset
        self.jointWeightDataOffset = jointWeightDataOffset
        self.vertexCount = vertexCount
        reserved0 = 0
    }
}

public struct UntoldSkinJointMappingRecordV1: Sendable, Equatable {
    public var skeletonJointIndex: UInt32

    public init(skeletonJointIndex: UInt32) {
        self.skeletonJointIndex = skeletonJointIndex
    }
}

public struct UntoldAnimationClipRecordV1: Sendable, Equatable {
    public var nameOffset: UInt32
    public var duration: Float
    public var firstChannelRecordIndex: UInt32
    public var channelRecordCount: UInt32
    public var flags: UInt32
    public var reserved0: [UInt32]

    public init(
        nameOffset: UInt32,
        duration: Float,
        firstChannelRecordIndex: UInt32,
        channelRecordCount: UInt32,
        flags: UInt32 = 0
    ) {
        self.nameOffset = nameOffset
        self.duration = duration
        self.firstChannelRecordIndex = firstChannelRecordIndex
        self.channelRecordCount = channelRecordCount
        self.flags = flags
        reserved0 = [0, 0]
    }
}

public struct UntoldAnimationChannelRecordV1: Sendable, Equatable {
    public var jointPathOffset: UInt32
    public var firstTranslationKeyframeIndex: UInt32
    public var translationKeyframeCount: UInt32
    public var firstRotationKeyframeIndex: UInt32
    public var rotationKeyframeCount: UInt32
    public var flags: UInt32
    public var reserved0: UInt32

    public init(
        jointPathOffset: UInt32,
        firstTranslationKeyframeIndex: UInt32,
        translationKeyframeCount: UInt32,
        firstRotationKeyframeIndex: UInt32,
        rotationKeyframeCount: UInt32,
        flags: UInt32 = 0
    ) {
        self.jointPathOffset = jointPathOffset
        self.firstTranslationKeyframeIndex = firstTranslationKeyframeIndex
        self.translationKeyframeCount = translationKeyframeCount
        self.firstRotationKeyframeIndex = firstRotationKeyframeIndex
        self.rotationKeyframeCount = rotationKeyframeCount
        self.flags = flags
        reserved0 = 0
    }
}

public struct UntoldTranslationKeyframeRecordV1: Sendable, Equatable {
    public var time: Float
    public var value: SIMD3<Float>
    public var reserved0: UInt32

    public init(time: Float, value: SIMD3<Float>) {
        self.time = time
        self.value = value
        reserved0 = 0
    }
}

public struct UntoldRotationKeyframeRecordV1: Sendable, Equatable {
    public var time: Float
    public var value: SIMD4<Float>

    public init(time: Float, value: SIMD4<Float>) {
        self.time = time
        self.value = value
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

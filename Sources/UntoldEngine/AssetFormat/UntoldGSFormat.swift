//
//  UntoldGSFormat.swift
//  UntoldEngine
//
//  Engine-native `.untoldgs` Gaussian splat container, version 3.
//
//  `.untoldgs` is a regeneratable cache of a source capture (`.ply`); a version bump
//  means "re-bake". Versions 1 and 2 stored one flat array of GPU-encoded splats and
//  were read whole. Version 3 stores quantised splats in page-aligned chunks so any
//  chunk can be read by byte range, memory-mapped, or loaded with Metal fast resource
//  loading straight into a GPU page:
//
//    [0]                  UntoldGSHeaderV3       256 bytes, padded to 16 KB
//    [chunkIndexOffset]   UntoldGSChunkEntry[]   64 bytes each, padded
//    [nodeTreeOffset]     UntoldGSTreeNode[]     48 bytes each, padded
//    [paletteOffset]      reserved (0 when absent)
//    [payloadOffset]      chunk payloads, each padded to a 16 KB multiple:
//                           core block  16 bytes × splatCount
//                           SH block    higher-order SH bytes × splatCount (optional)
//    [coarseIndexOffset]  UntoldGSChunkEntry[]   optional (`hasCoarseLevels`): one entry per
//                                                coarse level per chunk, level-major, padded
//    [coarsePayloadOffset] coarse records, coarsest level first, 16 bytes × splatCount per
//                                                entry, 16-byte aligned; padded to 16 KB
//
//  The coarse section holds one or two importance-sorted merged levels of every chunk
//  (`UntoldGSCoarsener`), lies after the last fine payload and is advertised by a flag
//  bit and header words carved from the reserved tail, so a reader that predates it
//  parses the file unchanged and draws the fine records only.
//
//  Integrity is per chunk (`UntoldGSChunkEntry.crc32`): a streamed payload is never
//  fully resident, so there is no whole-file hash. Scene-side facts (mesh twin,
//  budgets, portal bakes) live in the `.untold` asset that references this file.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import simd

// MARK: - Errors

public enum UntoldGSError: Error, CustomStringConvertible, Equatable {
    case badMagic
    case unsupportedVersion(UInt32)
    case truncated
    /// A header-declared size, count or offset disagrees with the file.
    case sizeMismatch(String)
    /// The bytes are the right size but their content is inconsistent (CRC, tree, counts).
    case corrupt(String)
    /// A feature flag or field value this reader does not implement.
    case unsupported(String)
    /// The writer was given splats it cannot encode.
    case invalidInput(String)

    public var description: String {
        switch self {
        case .badMagic: "Not an Untold Gaussian splat file"
        case let .unsupportedVersion(version): "Unsupported Untold Gaussian splat version \(version)"
        case .truncated: "Untold Gaussian splat file is truncated"
        case let .sizeMismatch(reason): "Untold Gaussian splat size mismatch: \(reason)"
        case let .corrupt(reason): "Untold Gaussian splat file is corrupt: \(reason)"
        case let .unsupported(reason): "Untold Gaussian splat feature is not supported: \(reason)"
        case let .invalidInput(reason): "Untold Gaussian splat input is invalid: \(reason)"
        }
    }
}

// MARK: - Decoded asset (what the runtime consumes)

public struct UntoldGSAsset {
    public let encodedSplats: [EncodedGaussianSplat]
    public let shCoefficients: [UInt8]
    public let shMetadata: GaussianSHMetadata?
    /// Mean of this tier's splats' squared major-axis extent, baked in by
    /// `bakeGaussianSplatProgressiveTiers` — see `estimatedGaussianOverdraw`. 0 for files
    /// baked without the statistic (indistinguishable from a real 0, but a real 0 can only
    /// happen for a tier with no splats, which never gets written).
    public let meanSquaredSplatExtent: Float
    /// Asset-level local-space bounding box (shared by every tier of the same bake, not
    /// per-tier — see `bakeGaussianSplatProgressiveTiers`). Lets any registration path —
    /// including streaming, which needs a real box before it can decide whether to load
    /// anything — read a real box via `UntoldGSFormat.readHeader` without a caller-supplied value.
    public let boundingBoxMin: simd_float3
    public let boundingBoxMax: simd_float3

    public init(
        encodedSplats: [EncodedGaussianSplat],
        shCoefficients: [UInt8],
        shMetadata: GaussianSHMetadata?,
        meanSquaredSplatExtent: Float,
        boundingBoxMin: simd_float3,
        boundingBoxMax: simd_float3
    ) {
        self.encodedSplats = encodedSplats
        self.shCoefficients = shCoefficients
        self.shMetadata = shMetadata
        self.meanSquaredSplatExtent = meanSquaredSplatExtent
        self.boundingBoxMin = boundingBoxMin
        self.boundingBoxMax = boundingBoxMax
    }

    public var splatCount: Int {
        encodedSplats.count
    }
}

// MARK: - Constants

public enum UntoldGSFormat {
    /// "UTGS" as a little-endian UInt32; unchanged since version 1 so older files are
    /// recognised and rejected with `.unsupportedVersion` rather than `.badMagic`.
    public static let magic: UInt32 = 0x5347_5455
    public static let magicBytes: [UInt8] = [0x55, 0x54, 0x47, 0x53]
    public static let version: UInt32 = 3

    /// Section and chunk payload alignment. Matches the VM page size on current Apple
    /// devices, which `MTLDevice.makeBuffer(bytesNoCopy:)` requires and Metal fast resource
    /// loading works best with.
    public static let pageAlignment: Int = 16384

    public static let headerSize: Int = 256
    public static let chunkEntrySize: Int = 64
    public static let treeNodeSize: Int = 48
    /// Bytes per splat in the core block: packed position, rotation, scale, RGBA.
    public static let coreRecordSize: Int = 16

    public static let defaultLog2ChunkSplats: UInt8 = 10 // 1024 splats, 16 KB core
    public static let maxLog2ChunkSplats: UInt8 = 14 // 16384 splats
    public static let maxSHDegree: UInt8 = 3
    public static let invalidNode: UInt32 = 0xFFFF_FFFF

    /// Coarse levels a file may carry per chunk (`UntoldGSHeaderV3.coarseLevelCount`).
    public static let maxCoarseLevels: Int = 2
    /// A coarse index entry is a `UntoldGSChunkEntry`.
    public static let coarseIndexEntrySize: Int = chunkEntrySize
    /// `UntoldGSWriteOptions.coarseLevelsAutomatic` bakes levels for a tier of at least this
    /// many chunks; smaller assets (every chunk in view is cheap to draw whole) bake as before.
    public static let coarseLevelsAutomaticMinimumChunks: Int = 64

    /// Higher-order SH bytes stored per splat for a degree (DC excluded, three channels):
    /// 0, 9, 24, 45. Same contract as `GaussianSHMetadata.higherOrderCoefficientsPerSplat`.
    public static func shCoefficientCount(degree: UInt8) -> Int {
        let perChannel = Int(degree + 1) * Int(degree + 1) - 1
        return perChannel * 3
    }

    public static func alignedToPage(_ value: Int) -> Int {
        let remainder = value % pageAlignment
        return remainder == 0 ? value : value + (pageAlignment - remainder)
    }
}

public enum UntoldGSFlags {
    /// A spherical-harmonics block follows each chunk's core block.
    public static let hasSphericalHarmonics: UInt32 = 1 << 0
    /// SH block stores 16-bit palette indices instead of direct coefficients. Reserved.
    public static let sphericalHarmonicsPalette: UInt32 = 1 << 1
    /// Splats were cooked with the anti-aliasing (3D smoothing) convention.
    public static let antialiased: UInt32 = 1 << 2
    /// Payload was produced for an environment (large chunks, LOD tree, visibility table).
    public static let environment: UInt32 = 1 << 3
    /// The file carries the optional per-chunk coarse-level section (header bytes 204–227).
    /// A reader that predates the section ignores the bit and draws the fine records only.
    public static let hasCoarseLevels: UInt32 = 1 << 4
}

/// Coordinate-system convention of the stored positions and rotations.
public enum UntoldGSCoordinateSystem: UInt8, Sendable {
    /// Right-handed, +X right, +Y up, −Z forward. Matches the engine.
    case rightUpBack = 0
    /// Right-handed, +X right, −Y up, +Z forward. The 3DGS training convention.
    case rightDownFront = 1
}

/// How the stored colour values are meant to be interpreted.
public enum UntoldGSColorSpace: UInt8, Sendable {
    /// sRGB-encoded, display-referred values. Decoded to linear by the shader.
    case sRGBDisplayReferred = 0
    /// Linear, scene-referred values.
    case linearSceneReferred = 1
}

// MARK: - Header

/// 256-byte version-3 file header.
public struct UntoldGSHeaderV3: Sendable, Equatable {
    public var magic: [UInt8]
    public var version: UInt32
    /// See `UntoldGSFlags`.
    public var flags: UInt32
    /// Spherical-harmonics degree stored in the SH block, 0...3.
    public var shDegree: UInt8
    public var coordinateSystem: UInt8
    public var colorSpace: UInt8
    /// log2 of the maximum splat count per chunk.
    public var log2ChunkSplats: UInt8
    /// Total splat count across all LOD levels.
    public var splatCount: UInt32
    public var chunkCount: UInt32
    public var nodeCount: UInt32
    public var lodLevels: UInt8
    /// 3-byte pad. Write as zero.
    public var reserved0: [UInt8]
    /// Bounds of the stored splat centres.
    public var boundsMin: SIMD3<Float>
    public var boundsMax: SIMD3<Float>
    /// Asset-level local-space bounding box, expanded by splat extent and shared by every tier
    /// of a bake. What `UntoldGSFormat.readHeader` returns.
    public var boundingBoxMin: SIMD3<Float>
    public var boundingBoxMax: SIMD3<Float>
    /// Mean squared major-axis extent of this tier's splats — see `estimatedGaussianOverdraw`.
    public var meanSquaredSplatExtent: Float
    /// Exposure the colours were captured at, in EV. Zero when unknown.
    public var captureExposureEV: Float
    /// Per-channel tint that neutralises the capture white balance. Ones when unknown.
    public var captureWhiteBalance: SIMD3<Float>
    /// Registers splat space onto the mesh twin. Identity for worlds.
    public var splatToMesh: simd_float4x4
    public var chunkIndexOffset: UInt64
    public var nodeTreeOffset: UInt64
    /// Zero when the file carries no palette.
    public var paletteOffset: UInt64
    public var payloadOffset: UInt64
    /// Byte size of the whole file, so a reader can bounds-check ranges before opening the payload.
    public var fileSize: UInt64
    /// Absolute offset of the coarse index (`UntoldGSChunkEntry[coarseLevelCount × chunkCount]`,
    /// level-major), a page multiple at or after the last fine payload. 0 when absent.
    public var coarseIndexOffset: UInt64
    /// Absolute offset of the coarse records, a page multiple after the coarse index; the region
    /// runs to `fileSize`. 0 when absent.
    public var coarsePayloadOffset: UInt64
    /// Records over every coarse entry (the fine `splatCount` is unchanged by the section).
    public var coarseRecordCount: UInt32
    /// Coarse levels per chunk, 0…`UntoldGSFormat.maxCoarseLevels`.
    public var coarseLevelCount: UInt8
    /// Level L holds `max(1, n >> coarseRatioLog2[L − 1])` records of a chunk of `n` fine splats;
    /// strictly increasing over the level count, unused slots zero. Two bytes.
    public var coarseRatioLog2: [UInt8]
    /// Zero. Bit 0 is reserved for coarse records that carry a spherical-harmonics block.
    public var coarseFlags: UInt8
    /// Reserved tail bringing the header to 256 bytes. Write as zero.
    public var reserved1: [UInt8]

    public static let reserved1Size = 256 - 228
    public static let coarseRatioLog2Size = 2

    public init(
        flags: UInt32 = 0,
        shDegree: UInt8 = 0,
        coordinateSystem: UntoldGSCoordinateSystem = .rightUpBack,
        colorSpace: UntoldGSColorSpace = .sRGBDisplayReferred,
        log2ChunkSplats: UInt8 = UntoldGSFormat.defaultLog2ChunkSplats,
        splatCount: UInt32,
        chunkCount: UInt32,
        nodeCount: UInt32,
        lodLevels: UInt8 = 1,
        boundsMin: SIMD3<Float>,
        boundsMax: SIMD3<Float>,
        boundingBoxMin: SIMD3<Float>,
        boundingBoxMax: SIMD3<Float>,
        meanSquaredSplatExtent: Float = 0,
        captureExposureEV: Float = 0,
        captureWhiteBalance: SIMD3<Float> = SIMD3<Float>(repeating: 1),
        splatToMesh: simd_float4x4 = matrix_identity_float4x4,
        chunkIndexOffset: UInt64,
        nodeTreeOffset: UInt64,
        paletteOffset: UInt64 = 0,
        payloadOffset: UInt64,
        fileSize: UInt64,
        coarseIndexOffset: UInt64 = 0,
        coarsePayloadOffset: UInt64 = 0,
        coarseRecordCount: UInt32 = 0,
        coarseLevelCount: UInt8 = 0,
        coarseRatioLog2: [UInt8] = [0, 0],
        coarseFlags: UInt8 = 0
    ) {
        magic = UntoldGSFormat.magicBytes
        version = UntoldGSFormat.version
        self.flags = flags
        self.shDegree = shDegree
        self.coordinateSystem = coordinateSystem.rawValue
        self.colorSpace = colorSpace.rawValue
        self.log2ChunkSplats = log2ChunkSplats
        self.splatCount = splatCount
        self.chunkCount = chunkCount
        self.nodeCount = nodeCount
        self.lodLevels = lodLevels
        reserved0 = [0, 0, 0]
        self.boundsMin = boundsMin
        self.boundsMax = boundsMax
        self.boundingBoxMin = boundingBoxMin
        self.boundingBoxMax = boundingBoxMax
        self.meanSquaredSplatExtent = meanSquaredSplatExtent
        self.captureExposureEV = captureExposureEV
        self.captureWhiteBalance = captureWhiteBalance
        self.splatToMesh = splatToMesh
        self.chunkIndexOffset = chunkIndexOffset
        self.nodeTreeOffset = nodeTreeOffset
        self.paletteOffset = paletteOffset
        self.payloadOffset = payloadOffset
        self.fileSize = fileSize
        self.coarseIndexOffset = coarseIndexOffset
        self.coarsePayloadOffset = coarsePayloadOffset
        self.coarseRecordCount = coarseRecordCount
        self.coarseLevelCount = coarseLevelCount
        var ratios = Array(coarseRatioLog2.prefix(UntoldGSHeaderV3.coarseRatioLog2Size))
        while ratios.count < UntoldGSHeaderV3.coarseRatioLog2Size {
            ratios.append(0)
        }
        self.coarseRatioLog2 = ratios
        self.coarseFlags = coarseFlags
        reserved1 = Array(repeating: 0, count: UntoldGSHeaderV3.reserved1Size)
    }

    public var splatsPerChunk: Int {
        1 << Int(log2ChunkSplats)
    }

    public var hasSphericalHarmonics: Bool {
        flags & UntoldGSFlags.hasSphericalHarmonics != 0
    }

    /// The file carries the per-chunk coarse-level section.
    public var hasCoarseLevels: Bool {
        flags & UntoldGSFlags.hasCoarseLevels != 0
    }

    /// Higher-order SH bytes stored per splat; zero without an SH block.
    public var shBytesPerSplat: Int {
        hasSphericalHarmonics ? UntoldGSFormat.shCoefficientCount(degree: shDegree) : 0
    }

    /// The GPU SH contract for this file, or nil without an SH block.
    public var shMetadata: GaussianSHMetadata? {
        guard hasSphericalHarmonics, shDegree > 0 else { return nil }
        let perChannel = UInt32(shDegree + 1) * UInt32(shDegree + 1)
        return GaussianSHMetadata(
            degree: UInt32(shDegree),
            coefficientsPerChannel: perChannel,
            higherOrderCoefficientsPerSplat: UInt32(shBytesPerSplat),
            _pad0: 0
        )
    }
}

// MARK: - Chunk index entry

/// 64-byte entry: everything needed to serve and decode one chunk by byte range. The coarse
/// index reuses it for a merged level of a chunk: `lodLevel` is the level (1 or 2), `reserved0`
/// the fine chunk index, `payloadOffset` 16-byte aligned inside the coarse payload region,
/// `payloadBytes == coreBytes` (no padding, no SH), and `splatCount == 0` means the chunk has
/// no such level; the ranges and CRC are the level's own.
public struct UntoldGSChunkEntry: Sendable, Equatable {
    /// Absolute file offset of the chunk payload. Multiple of `pageAlignment` for a fine chunk,
    /// of `coreRecordSize` for a coarse level.
    public var payloadOffset: UInt64
    /// Padded payload size (core + SH, rounded up to the page); unpadded for a coarse level.
    public var payloadBytes: UInt32
    /// Unpadded core block size: `coreRecordSize × splatCount`.
    public var coreBytes: UInt32
    public var splatCount: UInt32
    /// 0 for a fine chunk; the coarse level (1 or 2) for a coarse index entry.
    public var lodLevel: UInt16
    /// Owning tree node.
    public var nodeId: UInt16
    /// Decode constants for the 11/10/11 packed positions.
    public var aabbMin: SIMD3<Float>
    public var aabbMax: SIMD3<Float>
    /// Decode constants for the 11/10/11 packed log-scales.
    public var logScaleMin: Float
    public var logScaleMax: Float
    /// Zero for a fine chunk; the fine chunk index for a coarse index entry.
    public var reserved0: UInt32
    /// CRC-32 (IEEE) over the unpadded payload: core block followed by SH block.
    public var crc32: UInt32

    public init(
        payloadOffset: UInt64,
        payloadBytes: UInt32,
        coreBytes: UInt32,
        splatCount: UInt32,
        lodLevel: UInt16 = 0,
        nodeId: UInt16 = 0,
        aabbMin: SIMD3<Float>,
        aabbMax: SIMD3<Float>,
        logScaleMin: Float,
        logScaleMax: Float,
        reserved0: UInt32 = 0,
        crc32: UInt32
    ) {
        self.payloadOffset = payloadOffset
        self.payloadBytes = payloadBytes
        self.coreBytes = coreBytes
        self.splatCount = splatCount
        self.lodLevel = lodLevel
        self.nodeId = nodeId
        self.aabbMin = aabbMin
        self.aabbMax = aabbMax
        self.logScaleMin = logScaleMin
        self.logScaleMax = logScaleMax
        self.reserved0 = reserved0
        self.crc32 = crc32
    }
}

// MARK: - Tree node

/// 48-byte node of the binary tree over the Morton-ordered chunk array.
/// Chunks under a node are contiguous in the index, so a node maps to one byte range per LOD.
public struct UntoldGSTreeNode: Sendable, Equatable {
    public var aabbMin: SIMD3<Float>
    public var aabbMax: SIMD3<Float>
    /// Child node indices; `UntoldGSFormat.invalidNode` on leaves.
    public var child0: UInt32
    public var child1: UInt32
    public var firstChunk: UInt32
    public var chunkCount: UInt32
    /// World-space error of this node's coarsest representation. Zero for single-level files.
    public var geometricError: Float
    /// Environments only: offset into the visibility table. Zero when absent.
    public var visibilityMaskOffset: UInt32

    public init(
        aabbMin: SIMD3<Float>,
        aabbMax: SIMD3<Float>,
        child0: UInt32 = UntoldGSFormat.invalidNode,
        child1: UInt32 = UntoldGSFormat.invalidNode,
        firstChunk: UInt32,
        chunkCount: UInt32,
        geometricError: Float = 0,
        visibilityMaskOffset: UInt32 = 0
    ) {
        self.aabbMin = aabbMin
        self.aabbMax = aabbMax
        self.child0 = child0
        self.child1 = child1
        self.firstChunk = firstChunk
        self.chunkCount = chunkCount
        self.geometricError = geometricError
        self.visibilityMaskOffset = visibilityMaskOffset
    }

    public var isLeaf: Bool {
        child0 == UntoldGSFormat.invalidNode && child1 == UntoldGSFormat.invalidNode
    }
}

// MARK: - Binary encode / decode

extension UntoldGSHeaderV3: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeBytes(magic) // 0 – 3
        writer.writeUInt32LE(version) // 4 – 7
        writer.writeUInt32LE(flags) // 8 – 11
        writer.writeUInt8(shDegree) // 12
        writer.writeUInt8(coordinateSystem) // 13
        writer.writeUInt8(colorSpace) // 14
        writer.writeUInt8(log2ChunkSplats) // 15
        writer.writeUInt32LE(splatCount) // 16 – 19
        writer.writeUInt32LE(chunkCount) // 20 – 23
        writer.writeUInt32LE(nodeCount) // 24 – 27
        writer.writeUInt8(lodLevels) // 28
        writer.writeBytes(reserved0) // 29 – 31
        writer.writeFloat3LE(boundsMin) // 32 – 43
        writer.writeFloat3LE(boundsMax) // 44 – 55
        writer.writeFloat3LE(boundingBoxMin) // 56 – 67
        writer.writeFloat3LE(boundingBoxMax) // 68 – 79
        writer.writeFloat32LE(meanSquaredSplatExtent) // 80 – 83
        writer.writeFloat32LE(captureExposureEV) // 84 – 87
        writer.writeFloat3LE(captureWhiteBalance) // 88 – 99
        writer.writeMatrix4x4LE(splatToMesh) // 100 – 163
        writer.writeUInt64LE(chunkIndexOffset) // 164 – 171
        writer.writeUInt64LE(nodeTreeOffset) // 172 – 179
        writer.writeUInt64LE(paletteOffset) // 180 – 187
        writer.writeUInt64LE(payloadOffset) // 188 – 195
        writer.writeUInt64LE(fileSize) // 196 – 203
        writer.writeUInt64LE(coarseIndexOffset) // 204 – 211
        writer.writeUInt64LE(coarsePayloadOffset) // 212 – 219
        writer.writeUInt32LE(coarseRecordCount) // 220 – 223
        writer.writeUInt8(coarseLevelCount) // 224
        writer.writeBytes(coarseRatioLog2.prefix(UntoldGSHeaderV3.coarseRatioLog2Size)) // 225 – 226
        writer.writeUInt8(coarseFlags) // 227
        writer.writeBytes(reserved1) // 228 – 255
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldGSHeaderV3 {
        let magic = try Array(reader.readBytes(count: 4))
        let version = try reader.readUInt32LE()
        let flags = try reader.readUInt32LE()
        let shDegree = try reader.readUInt8()
        let coordinateSystem = try reader.readUInt8()
        let colorSpace = try reader.readUInt8()
        let log2ChunkSplats = try reader.readUInt8()
        let splatCount = try reader.readUInt32LE()
        let chunkCount = try reader.readUInt32LE()
        let nodeCount = try reader.readUInt32LE()
        let lodLevels = try reader.readUInt8()
        let reserved0 = try Array(reader.readBytes(count: 3))
        let boundsMin = try reader.readFloat3LE()
        let boundsMax = try reader.readFloat3LE()
        let boundingBoxMin = try reader.readFloat3LE()
        let boundingBoxMax = try reader.readFloat3LE()
        let meanSquaredSplatExtent = try reader.readFloat32LE()
        let captureExposureEV = try reader.readFloat32LE()
        let captureWhiteBalance = try reader.readFloat3LE()
        let splatToMesh = try reader.readMatrix4x4LE()
        let chunkIndexOffset = try reader.readUInt64LE()
        let nodeTreeOffset = try reader.readUInt64LE()
        let paletteOffset = try reader.readUInt64LE()
        let payloadOffset = try reader.readUInt64LE()
        let fileSize = try reader.readUInt64LE()
        let coarseIndexOffset = try reader.readUInt64LE()
        let coarsePayloadOffset = try reader.readUInt64LE()
        let coarseRecordCount = try reader.readUInt32LE()
        let coarseLevelCount = try reader.readUInt8()
        let coarseRatioLog2 = try Array(reader.readBytes(count: UntoldGSHeaderV3.coarseRatioLog2Size))
        let coarseFlags = try reader.readUInt8()
        let reserved1 = try Array(reader.readBytes(count: UntoldGSHeaderV3.reserved1Size))

        var header = UntoldGSHeaderV3(
            flags: flags,
            shDegree: shDegree,
            log2ChunkSplats: log2ChunkSplats,
            splatCount: splatCount,
            chunkCount: chunkCount,
            nodeCount: nodeCount,
            lodLevels: lodLevels,
            boundsMin: boundsMin,
            boundsMax: boundsMax,
            boundingBoxMin: boundingBoxMin,
            boundingBoxMax: boundingBoxMax,
            meanSquaredSplatExtent: meanSquaredSplatExtent,
            captureExposureEV: captureExposureEV,
            captureWhiteBalance: captureWhiteBalance,
            splatToMesh: splatToMesh,
            chunkIndexOffset: chunkIndexOffset,
            nodeTreeOffset: nodeTreeOffset,
            paletteOffset: paletteOffset,
            payloadOffset: payloadOffset,
            fileSize: fileSize,
            coarseIndexOffset: coarseIndexOffset,
            coarsePayloadOffset: coarsePayloadOffset,
            coarseRecordCount: coarseRecordCount,
            coarseLevelCount: coarseLevelCount,
            coarseRatioLog2: coarseRatioLog2,
            coarseFlags: coarseFlags
        )
        header.magic = magic
        header.version = version
        header.coordinateSystem = coordinateSystem
        header.colorSpace = colorSpace
        header.reserved0 = reserved0
        header.reserved1 = reserved1
        return header
    }
}

extension UntoldGSChunkEntry: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeUInt64LE(payloadOffset) // 0 – 7
        writer.writeUInt32LE(payloadBytes) // 8 – 11
        writer.writeUInt32LE(coreBytes) // 12 – 15
        writer.writeUInt32LE(splatCount) // 16 – 19
        writer.writeUInt16LE(lodLevel) // 20 – 21
        writer.writeUInt16LE(nodeId) // 22 – 23
        writer.writeFloat3LE(aabbMin) // 24 – 35
        writer.writeFloat3LE(aabbMax) // 36 – 47
        writer.writeFloat32LE(logScaleMin) // 48 – 51
        writer.writeFloat32LE(logScaleMax) // 52 – 55
        writer.writeUInt32LE(reserved0) // 56 – 59
        writer.writeUInt32LE(crc32) // 60 – 63
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldGSChunkEntry {
        try UntoldGSChunkEntry(
            payloadOffset: reader.readUInt64LE(),
            payloadBytes: reader.readUInt32LE(),
            coreBytes: reader.readUInt32LE(),
            splatCount: reader.readUInt32LE(),
            lodLevel: reader.readUInt16LE(),
            nodeId: reader.readUInt16LE(),
            aabbMin: reader.readFloat3LE(),
            aabbMax: reader.readFloat3LE(),
            logScaleMin: reader.readFloat32LE(),
            logScaleMax: reader.readFloat32LE(),
            reserved0: reader.readUInt32LE(),
            crc32: reader.readUInt32LE()
        )
    }
}

extension UntoldGSTreeNode: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeFloat3LE(aabbMin) // 0 – 11
        writer.writeFloat3LE(aabbMax) // 12 – 23
        writer.writeUInt32LE(child0) // 24 – 27
        writer.writeUInt32LE(child1) // 28 – 31
        writer.writeUInt32LE(firstChunk) // 32 – 35
        writer.writeUInt32LE(chunkCount) // 36 – 39
        writer.writeFloat32LE(geometricError) // 40 – 43
        writer.writeUInt32LE(visibilityMaskOffset) // 44 – 47
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> UntoldGSTreeNode {
        try UntoldGSTreeNode(
            aabbMin: reader.readFloat3LE(),
            aabbMax: reader.readFloat3LE(),
            child0: reader.readUInt32LE(),
            child1: reader.readUInt32LE(),
            firstChunk: reader.readUInt32LE(),
            chunkCount: reader.readUInt32LE(),
            geometricError: reader.readFloat32LE(),
            visibilityMaskOffset: reader.readUInt32LE()
        )
    }
}

extension UntoldBinaryWriter {
    func writeFloat3LE(_ value: SIMD3<Float>) {
        writeFloat32LE(value.x)
        writeFloat32LE(value.y)
        writeFloat32LE(value.z)
    }
}

extension UntoldBinaryReader {
    func readFloat3LE() throws -> SIMD3<Float> {
        try SIMD3<Float>(readFloat32LE(), readFloat32LE(), readFloat32LE())
    }
}

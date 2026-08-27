//
//  UntoldReader.swift
//  UntoldEngine
//
//  Reader entry points for the cooked `.untold` runtime asset container.
//  Parsing and binary decoding logic will live here as the format loader is built.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Compression
import CryptoKit
import Foundation

public final class UntoldReader: @unchecked Sendable {
    public init() {}

    public func readAsset(from data: Data) throws -> UntoldDecodedAsset {
        let reader = UntoldBinaryReader(data: data)
        let header = try UntoldFileHeaderV1.decode(from: reader)
        try validateHeader(header)

        var chunks: [UntoldChunkEntryV1] = []
        chunks.reserveCapacity(Int(header.chunkCount))
        for _ in 0 ..< header.chunkCount {
            try chunks.append(UntoldChunkEntryV1.decode(from: reader))
        }
        try validateChunkTable(chunks)
        try validateRequiredChunks(in: chunks, fileType: header.fileType)
        try validateContentHash(header, chunks: chunks, fileData: data)

        let stringData = try loadRequiredChunk(.stringTable, from: data, entries: chunks)
        let entities = try decodeTableIfPresent(
            UntoldEntityRecordV1.self,
            chunkType: .entityTable,
            from: data,
            entries: chunks
        )
        let meshes = try decodeTableIfPresent(
            UntoldMeshRecordV1.self,
            chunkType: .meshTable,
            from: data,
            entries: chunks
        )
        let materials = try decodeMaterialTable(
            from: data,
            entries: chunks,
            formatVersion: header.formatVersion
        )
        let textures = try decodeTableIfPresent(
            UntoldTextureRefRecordV1.self,
            chunkType: .textureTable,
            from: data,
            entries: chunks
        )
        let lights = try decodeTableIfPresent(
            UntoldLightRecordV1.self,
            chunkType: .lightTable,
            from: data,
            entries: chunks
        )
        let cameras = try decodeTableIfPresent(
            UntoldCameraRecordV1.self,
            chunkType: .cameraTable,
            from: data,
            entries: chunks
        )
        let colorManagement = try decodeSingleIfPresent(
            UntoldColorManagementRecordV1.self,
            chunkType: .colorManagementTable,
            from: data,
            entries: chunks
        )
        let skeletons = try decodeTableIfPresent(
            UntoldSkeletonRecordV1.self,
            chunkType: .skeletonTable,
            from: data,
            entries: chunks
        )
        let skeletonJoints = try decodeTableIfPresent(
            UntoldSkeletonJointRecordV1.self,
            chunkType: .skeletonJointTable,
            from: data,
            entries: chunks
        )
        let skins = try decodeTableIfPresent(
            UntoldSkinRecordV1.self,
            chunkType: .skinTable,
            from: data,
            entries: chunks
        )
        let skinJointMappings = try decodeTableIfPresent(
            UntoldSkinJointMappingRecordV1.self,
            chunkType: .skinJointMappingTable,
            from: data,
            entries: chunks
        )
        let animationClips = try decodeTableIfPresent(
            UntoldAnimationClipRecordV1.self,
            chunkType: .animationClipTable,
            from: data,
            entries: chunks
        )
        let animationChannels = try decodeTableIfPresent(
            UntoldAnimationChannelRecordV1.self,
            chunkType: .animationChannelTable,
            from: data,
            entries: chunks
        )
        let translationKeyframes = try decodeTableIfPresent(
            UntoldTranslationKeyframeRecordV1.self,
            chunkType: .translationKeyframeTable,
            from: data,
            entries: chunks
        )
        let rotationKeyframes = try decodeTableIfPresent(
            UntoldRotationKeyframeRecordV1.self,
            chunkType: .rotationKeyframeTable,
            from: data,
            entries: chunks
        )
        let pluginChunks = try decodePluginChunks(from: data, entries: chunks)

        let decoded = UntoldDecodedAsset(
            header: header,
            chunks: chunks,
            stringTableData: stringData,
            entities: entities,
            meshes: meshes,
            materials: materials,
            textures: textures,
            lights: lights,
            cameras: cameras,
            colorManagement: colorManagement,
            skeletons: skeletons,
            skeletonJoints: skeletonJoints,
            skins: skins,
            skinJointMappings: skinJointMappings,
            animationClips: animationClips,
            animationChannels: animationChannels,
            translationKeyframes: translationKeyframes,
            rotationKeyframes: rotationKeyframes,
            pluginChunks: pluginChunks
        )
        try validateDecodedAsset(decoded)
        return decoded
    }

    private func validateHeader(_ header: UntoldFileHeaderV1) throws {
        let expectedMagic = Array(UntoldFormat.magic.utf8) + [0]
        guard header.magic == expectedMagic else {
            throw UntoldValidationError.invalidMagic
        }
        guard header.formatVersion >= UntoldFormat.minSupportedVersion,
              header.formatVersion <= UntoldFormat.version
        else {
            throw UntoldValidationError.unsupportedVersion(header.formatVersion)
        }
    }

    private func validateChunkTable(_ chunks: [UntoldChunkEntryV1]) throws {
        for chunk in chunks {
            guard chunk.fileOffset % UntoldFormat.fileAlignment == 0 else {
                throw UntoldValidationError.misalignedChunkOffset(chunk.fileOffset)
            }
        }
    }

    private func validateRequiredChunks(in chunks: [UntoldChunkEntryV1], fileType: UntoldFileType) throws {
        let required: [UntoldChunkType] = switch fileType {
        case .animation:
            [
                .stringTable,
                .animationClipTable,
                .animationChannelTable,
                .translationKeyframeTable,
                .rotationKeyframeTable,
            ]
        case .tile, .lod, .hlod, .shared:
            [
                .stringTable,
                .entityTable,
                .meshTable,
                .materialTable,
                .textureTable,
                .vertexData,
                .indexData,
            ]
        }
        let available = Set(chunks.map(\.chunkType))
        for chunkType in required where !available.contains(chunkType) {
            throw UntoldValidationError.missingRequiredChunk(chunkType)
        }
    }

    private func validateContentHash(
        _ header: UntoldFileHeaderV1,
        chunks: [UntoldChunkEntryV1],
        fileData: Data
    ) throws {
        // A zero hash means the file was produced without hash computation (e.g. test
        // fixtures built in Swift). Skip validation so those files continue to load.
        guard header.contentHash.contains(where: { $0 != 0 }) else { return }

        // The exporter hashes raw chunk payloads concatenated in ascending chunk-type
        // order. Alignment padding between payloads in the file is NOT included.
        var hashInput = Data()
        for chunk in chunks.sorted(by: { $0.chunkType.rawValue < $1.chunkType.rawValue }) {
            let start = Int(chunk.fileOffset)
            let end = start + Int(chunk.compressedSize)
            guard start >= 0, end <= fileData.count else {
                throw UntoldBinaryDecodingError.outOfBounds(
                    offset: start,
                    requested: Int(chunk.compressedSize),
                    available: fileData.count
                )
            }
            hashInput.append(fileData.subdata(in: start ..< end))
        }

        let computed = Array(SHA256.hash(data: hashInput))
        guard computed == header.contentHash else {
            throw UntoldValidationError.contentHashMismatch
        }
    }

    private func validateDecodedAsset(_ asset: UntoldDecodedAsset) throws {
        if asset.header.fileType == .animation {
            return
        }

        guard let vertexChunk = asset.chunks.first(where: { $0.chunkType == .vertexData }),
              let indexChunk = asset.chunks.first(where: { $0.chunkType == .indexData })
        else { return }

        let jointIndexChunk = asset.chunks.first(where: { $0.chunkType == .jointIndexData })
        let jointWeightChunk = asset.chunks.first(where: { $0.chunkType == .jointWeightData })
        let edgeIndexChunk = asset.chunks.first(where: { $0.chunkType == .edgeIndexData })

        let expectedVertexStride: UInt32 = switch asset.header.vertexLayout {
        case .pbrStaticV1: 32
        }

        for mesh in asset.meshes {
            if mesh.materialIndex != UntoldFormat.invalidIndex,
               mesh.materialIndex >= UInt32(asset.materials.count)
            {
                throw UntoldValidationError.invalidMaterialIndex(mesh.materialIndex)
            }

            guard mesh.vertexStrideBytes == expectedVertexStride else {
                throw UntoldValidationError.invalidVertexStride(mesh.vertexStrideBytes)
            }

            let expectedIndexDataSize = UInt64(mesh.indexCount) * indexElementSize(for: mesh.indexType)
            guard mesh.indexDataSizeBytes == expectedIndexDataSize else {
                throw UntoldValidationError.invalidIndexDataSize(
                    expected: expectedIndexDataSize,
                    actual: mesh.indexDataSizeBytes
                )
            }

            let vertexEnd = mesh.vertexDataOffset + mesh.vertexDataSizeBytes
            guard vertexEnd <= vertexChunk.uncompressedSize else {
                throw UntoldValidationError.invalidVertexDataRange(
                    offset: mesh.vertexDataOffset,
                    size: mesh.vertexDataSizeBytes,
                    chunkSize: vertexChunk.uncompressedSize
                )
            }

            let indexEnd = mesh.indexDataOffset + mesh.indexDataSizeBytes
            guard indexEnd <= indexChunk.uncompressedSize else {
                throw UntoldValidationError.invalidIndexDataRange(
                    offset: mesh.indexDataOffset,
                    size: mesh.indexDataSizeBytes,
                    chunkSize: indexChunk.uncompressedSize
                )
            }

            if mesh.edgeIndexCount > 0 {
                guard let edgeIndexChunk else {
                    throw UntoldValidationError.missingRequiredChunk(.edgeIndexData)
                }
                let edgeIndexDataSize = UInt64(mesh.edgeIndexCount) * indexElementSize(for: mesh.indexType)
                let edgeIndexEnd = UInt64(mesh.edgeIndexDataOffset) + edgeIndexDataSize
                guard edgeIndexEnd <= edgeIndexChunk.uncompressedSize else {
                    throw UntoldValidationError.invalidIndexDataRange(
                        offset: UInt64(mesh.edgeIndexDataOffset),
                        size: edgeIndexDataSize,
                        chunkSize: edgeIndexChunk.uncompressedSize
                    )
                }
            }
        }

        for skeleton in asset.skeletons {
            let start = Int(skeleton.firstJointRecordIndex)
            let end = start + Int(skeleton.jointRecordCount)
            guard start >= 0, end <= asset.skeletonJoints.count else {
                throw UntoldValidationError.invalidSkeletonJointRange(
                    skeletonEntityId: skeleton.entityId,
                    jointStart: start,
                    jointEnd: end,
                    totalJoints: asset.skeletonJoints.count
                )
            }
        }

        for skin in asset.skins {
            let mappingStart = Int(skin.firstJointMappingIndex)
            let mappingEnd = mappingStart + Int(skin.jointCount)
            guard mappingStart >= 0, mappingEnd <= asset.skinJointMappings.count else {
                throw UntoldValidationError.invalidSkinJointMappingRange(
                    skinEntityId: skin.entityId,
                    mappingStart: mappingStart,
                    mappingEnd: mappingEnd,
                    totalMappings: asset.skinJointMappings.count
                )
            }
            guard let jointIndexChunk, let jointWeightChunk else {
                throw UntoldValidationError.missingRequiredChunk(.jointIndexData)
            }
            let jointIndexEnd = skin.jointIndexDataOffset + UInt64(skin.vertexCount) * 8
            let jointWeightEnd = skin.jointWeightDataOffset + UInt64(skin.vertexCount) * 16
            guard jointIndexEnd <= jointIndexChunk.uncompressedSize else {
                throw UntoldValidationError.invalidVertexDataRange(offset: skin.jointIndexDataOffset, size: UInt64(skin.vertexCount) * 8, chunkSize: jointIndexChunk.uncompressedSize)
            }
            guard jointWeightEnd <= jointWeightChunk.uncompressedSize else {
                throw UntoldValidationError.invalidVertexDataRange(offset: skin.jointWeightDataOffset, size: UInt64(skin.vertexCount) * 16, chunkSize: jointWeightChunk.uncompressedSize)
            }
        }
    }

    private func indexElementSize(for indexType: UntoldIndexType) -> UInt64 {
        switch indexType {
        case .uint16: 2
        case .uint32: 4
        }
    }

    public func readAsset(from url: URL) throws -> UntoldDecodedAsset {
        try readAsset(from: Data(contentsOf: url))
    }

    private func decodeTable<T: UntoldBinaryDecodable>(
        _: T.Type,
        chunkType: UntoldChunkType,
        from fileData: Data,
        entries: [UntoldChunkEntryV1]
    ) throws -> [T] {
        let chunkData = try loadRequiredChunk(chunkType, from: fileData, entries: entries)
        let chunkReader = UntoldBinaryReader(data: chunkData)
        guard let entry = entries.first(where: { $0.chunkType == chunkType }) else {
            throw UntoldValidationError.missingRequiredChunk(chunkType)
        }

        var records: [T] = []
        records.reserveCapacity(Int(entry.elementCount))
        for _ in 0 ..< entry.elementCount {
            try records.append(T.decode(from: chunkReader))
        }
        return records
    }

    /// The material record's on-disk layout grew height-map fields at
    /// `UntoldFormat.minHeightMapVersion`. Files written before that version don't have
    /// those bytes at all — reading them unconditionally via the generic decode path would
    /// misalign every record after the first in the MATERIAL_TABLE chunk. This dedicated
    /// path picks the correct decoder for the whole chunk based on the file's header version
    /// (all records in one file share one exporter run, hence one layout).
    private func decodeMaterialTable(
        from fileData: Data,
        entries: [UntoldChunkEntryV1],
        formatVersion: UInt32
    ) throws -> [UntoldMaterialRecordV1] {
        guard entries.contains(where: { $0.chunkType == .materialTable }) else {
            return []
        }
        let chunkData = try loadRequiredChunk(.materialTable, from: fileData, entries: entries)
        let chunkReader = UntoldBinaryReader(data: chunkData)
        guard let entry = entries.first(where: { $0.chunkType == .materialTable }) else {
            throw UntoldValidationError.missingRequiredChunk(.materialTable)
        }

        var records: [UntoldMaterialRecordV1] = []
        records.reserveCapacity(Int(entry.elementCount))
        let decodeRecord: (UntoldBinaryReader) throws -> UntoldMaterialRecordV1
        if formatVersion >= UntoldFormat.minHeightRemapVersion {
            decodeRecord = UntoldMaterialRecordV1.decode
        } else if formatVersion >= UntoldFormat.minHeightMapVersion {
            decodeRecord = UntoldMaterialRecordV1.decodeLegacyWithHeightNoRemap
        } else {
            decodeRecord = UntoldMaterialRecordV1.decodeLegacyWithoutHeight
        }
        for _ in 0 ..< entry.elementCount {
            try records.append(decodeRecord(chunkReader))
        }
        return records
    }

    private func decodeTableIfPresent<T: UntoldBinaryDecodable>(
        _: T.Type,
        chunkType: UntoldChunkType,
        from fileData: Data,
        entries: [UntoldChunkEntryV1]
    ) throws -> [T] {
        guard entries.contains(where: { $0.chunkType == chunkType }) else {
            return []
        }
        return try decodeTable(T.self, chunkType: chunkType, from: fileData, entries: entries)
    }

    /// Like `decodeTableIfPresent`, but for chunk types that hold at most one
    /// scene-wide record (e.g. color management) rather than a per-entity table.
    private func decodeSingleIfPresent<T: UntoldBinaryDecodable>(
        _: T.Type,
        chunkType: UntoldChunkType,
        from fileData: Data,
        entries: [UntoldChunkEntryV1]
    ) throws -> T? {
        guard let entry = entries.first(where: { $0.chunkType == chunkType }) else {
            return nil
        }
        guard entry.elementCount <= 1 else {
            throw UntoldValidationError.invalidSingletonRecordCount(
                chunkType: chunkType,
                count: entry.elementCount
            )
        }
        return try decodeTableIfPresent(T.self, chunkType: chunkType, from: fileData, entries: entries).first
    }

    private func decodePluginChunks(
        from fileData: Data,
        entries: [UntoldChunkEntryV1]
    ) throws -> [UntoldPluginChunk] {
        try entries
            .filter(\.chunkType.isPluginExtensionChunk)
            .map { entry in
                let data = try decompressChunk(entry, fileData: fileData)
                return try UntoldPluginChunkEnvelope.decode(chunkType: entry.chunkType, data: data)
            }
    }

    /// Returns decompressed chunk payload for the given chunk type.
    /// Call this from external loaders (e.g. NativeFormatLoader) to retrieve
    /// vertex or index data with transparent decompression.
    public func readChunkData(
        _ chunkType: UntoldChunkType,
        from fileData: Data,
        entries: [UntoldChunkEntryV1]
    ) throws -> Data {
        guard let entry = entries.first(where: { $0.chunkType == chunkType }) else {
            throw UntoldValidationError.missingRequiredChunk(chunkType)
        }
        return try decompressChunk(entry, fileData: fileData)
    }

    private func loadRequiredChunk(
        _ chunkType: UntoldChunkType,
        from fileData: Data,
        entries: [UntoldChunkEntryV1]
    ) throws -> Data {
        guard let entry = entries.first(where: { $0.chunkType == chunkType }) else {
            throw UntoldValidationError.missingRequiredChunk(chunkType)
        }
        return try decompressChunk(entry, fileData: fileData)
    }

    private func decompressChunk(_ entry: UntoldChunkEntryV1, fileData: Data) throws -> Data {
        let fileOffset = Int(entry.fileOffset)
        let compressedSize = Int(entry.compressedSize)
        let uncompressedSize = Int(entry.uncompressedSize)

        guard fileOffset >= 0,
              compressedSize >= 0,
              fileOffset <= fileData.count,
              fileOffset + compressedSize <= fileData.count
        else {
            throw UntoldBinaryDecodingError.outOfBounds(
                offset: fileOffset,
                requested: compressedSize,
                available: fileData.count
            )
        }

        switch entry.compressionType {
        case .none:
            return fileData.subdata(in: fileOffset ..< fileOffset + compressedSize)

        case .lz4:
            var output = Data(count: uncompressedSize)
            let written: Int = output.withUnsafeMutableBytes { outBuf in
                fileData.withUnsafeBytes { inBuf in
                    compression_decode_buffer(
                        outBuf.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        uncompressedSize,
                        inBuf.baseAddress!.advanced(by: fileOffset).assumingMemoryBound(to: UInt8.self),
                        compressedSize,
                        nil,
                        COMPRESSION_LZ4_RAW
                    )
                }
            }
            guard written == uncompressedSize else {
                throw UntoldValidationError.compressionOutputSizeMismatch(
                    expected: UInt64(uncompressedSize),
                    actual: UInt64(written)
                )
            }
            return output

        case .zstd:
            throw UntoldValidationError.unsupportedCompression(entry.compressionType.rawValue)
        }
    }
}

public struct UntoldDecodedAsset: Sendable {
    public let header: UntoldFileHeaderV1
    public let chunks: [UntoldChunkEntryV1]
    public let stringTableData: Data
    public let entities: [UntoldEntityRecordV1]
    public let meshes: [UntoldMeshRecordV1]
    public let materials: [UntoldMaterialRecordV1]
    public let textures: [UntoldTextureRefRecordV1]
    public let lights: [UntoldLightRecordV1]
    public let cameras: [UntoldCameraRecordV1]
    public let colorManagement: UntoldColorManagementRecordV1?
    public let skeletons: [UntoldSkeletonRecordV1]
    public let skeletonJoints: [UntoldSkeletonJointRecordV1]
    public let skins: [UntoldSkinRecordV1]
    public let skinJointMappings: [UntoldSkinJointMappingRecordV1]
    public let animationClips: [UntoldAnimationClipRecordV1]
    public let animationChannels: [UntoldAnimationChannelRecordV1]
    public let translationKeyframes: [UntoldTranslationKeyframeRecordV1]
    public let rotationKeyframes: [UntoldRotationKeyframeRecordV1]
    public let pluginChunks: [UntoldPluginChunk]

    public init(
        header: UntoldFileHeaderV1,
        chunks: [UntoldChunkEntryV1],
        stringTableData: Data,
        entities: [UntoldEntityRecordV1],
        meshes: [UntoldMeshRecordV1],
        materials: [UntoldMaterialRecordV1],
        textures: [UntoldTextureRefRecordV1],
        lights: [UntoldLightRecordV1] = [],
        cameras: [UntoldCameraRecordV1] = [],
        colorManagement: UntoldColorManagementRecordV1? = nil,
        skeletons: [UntoldSkeletonRecordV1],
        skeletonJoints: [UntoldSkeletonJointRecordV1],
        skins: [UntoldSkinRecordV1],
        skinJointMappings: [UntoldSkinJointMappingRecordV1],
        animationClips: [UntoldAnimationClipRecordV1],
        animationChannels: [UntoldAnimationChannelRecordV1],
        translationKeyframes: [UntoldTranslationKeyframeRecordV1],
        rotationKeyframes: [UntoldRotationKeyframeRecordV1],
        pluginChunks: [UntoldPluginChunk] = []
    ) {
        self.header = header
        self.chunks = chunks
        self.stringTableData = stringTableData
        self.entities = entities
        self.meshes = meshes
        self.materials = materials
        self.textures = textures
        self.lights = lights
        self.cameras = cameras
        self.colorManagement = colorManagement
        self.skeletons = skeletons
        self.skeletonJoints = skeletonJoints
        self.skins = skins
        self.skinJointMappings = skinJointMappings
        self.animationClips = animationClips
        self.animationChannels = animationChannels
        self.translationKeyframes = translationKeyframes
        self.rotationKeyframes = rotationKeyframes
        self.pluginChunks = pluginChunks
    }

    public func string(at offset: UInt32) throws -> String? {
        guard offset != UntoldFormat.invalidIndex else { return nil }
        return try UntoldBinaryReader(data: stringTableData).readNullTerminatedUTF8String(at: Int(offset))
    }
}

public enum UntoldBinaryDecodingError: Error, Sendable, Equatable {
    case outOfBounds(offset: Int, requested: Int, available: Int)
    case invalidUTF8String(offset: Int)
    case unterminatedString(offset: Int)
}

public final class UntoldBinaryReader: @unchecked Sendable {
    public private(set) var data: Data
    public private(set) var offset: Int = 0

    public init(data: Data) {
        self.data = data
    }

    public var remainingBytes: Int {
        data.count - offset
    }

    public func seek(to newOffset: Int) throws {
        guard newOffset >= 0, newOffset <= data.count else {
            throw UntoldBinaryDecodingError.outOfBounds(offset: newOffset, requested: 0, available: data.count)
        }
        offset = newOffset
    }

    public func skip(_ byteCount: Int) throws {
        try seek(to: offset + byteCount)
    }

    public func readUInt8() throws -> UInt8 {
        try require(1)
        let value = data[offset]
        offset += 1
        return value
    }

    public func readUInt16LE() throws -> UInt16 {
        try readFixedWidthInteger(of: UInt16.self)
    }

    public func readUInt32LE() throws -> UInt32 {
        try readFixedWidthInteger(of: UInt32.self)
    }

    public func readUInt64LE() throws -> UInt64 {
        try readFixedWidthInteger(of: UInt64.self)
    }

    public func readFloat32LE() throws -> Float {
        let bits = try readUInt32LE()
        return Float(bitPattern: bits)
    }

    public func readBytes(count: Int) throws -> Data {
        try require(count)
        let slice = data.subdata(in: offset ..< offset + count)
        offset += count
        return slice
    }

    public func readNullTerminatedUTF8String(at absoluteOffset: Int) throws -> String {
        guard absoluteOffset >= 0, absoluteOffset < data.count else {
            throw UntoldBinaryDecodingError.outOfBounds(offset: absoluteOffset, requested: 1, available: data.count)
        }

        guard let terminatorIndex = data[absoluteOffset...].firstIndex(of: 0) else {
            throw UntoldBinaryDecodingError.unterminatedString(offset: absoluteOffset)
        }

        let bytes = data.subdata(in: absoluteOffset ..< terminatorIndex)
        guard let string = String(data: bytes, encoding: .utf8) else {
            throw UntoldBinaryDecodingError.invalidUTF8String(offset: absoluteOffset)
        }
        return string
    }

    private func require(_ byteCount: Int) throws {
        let end = offset + byteCount
        guard offset >= 0, end <= data.count else {
            throw UntoldBinaryDecodingError.outOfBounds(offset: offset, requested: byteCount, available: data.count)
        }
    }

    private func readFixedWidthInteger<T: FixedWidthInteger>(of _: T.Type) throws -> T {
        let byteCount = MemoryLayout<T>.size
        try require(byteCount)
        let value: T = data.withUnsafeBytes { rawBuffer in
            let base = rawBuffer.baseAddress!.advanced(by: offset)
            return base.loadUnaligned(as: T.self)
        }
        offset += byteCount
        return T(littleEndian: value)
    }
}

public final class UntoldBinaryWriter: @unchecked Sendable {
    public private(set) var data = Data()

    public init() {}

    public var count: Int {
        data.count
    }

    public func align(to alignment: Int) {
        guard alignment > 0 else { return }
        let remainder = data.count % alignment
        guard remainder != 0 else { return }
        data.append(contentsOf: repeatElement(0, count: alignment - remainder))
    }

    public func writeUInt8(_ value: UInt8) {
        data.append(value)
    }

    public func writeUInt16LE(_ value: UInt16) {
        writeFixedWidthInteger(value.littleEndian)
    }

    public func writeUInt32LE(_ value: UInt32) {
        writeFixedWidthInteger(value.littleEndian)
    }

    public func writeUInt64LE(_ value: UInt64) {
        writeFixedWidthInteger(value.littleEndian)
    }

    public func writeFloat32LE(_ value: Float) {
        writeUInt32LE(value.bitPattern)
    }

    public func writeBytes(_ bytes: some Sequence<UInt8>) {
        data.append(contentsOf: bytes)
    }

    public func writeData(_ other: Data) {
        data.append(other)
    }

    public func writeNullTerminatedUTF8(_ string: String) {
        data.append(contentsOf: string.utf8)
        data.append(0)
    }

    private func writeFixedWidthInteger(_ value: some FixedWidthInteger) {
        var mutableValue = value
        withUnsafeBytes(of: &mutableValue) { rawBuffer in
            data.append(contentsOf: rawBuffer)
        }
    }
}

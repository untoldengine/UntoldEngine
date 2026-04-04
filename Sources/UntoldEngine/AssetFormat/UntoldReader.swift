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
            chunks.append(try UntoldChunkEntryV1.decode(from: reader))
        }
        try validateChunkTable(chunks)
        try validateRequiredChunks(in: chunks)
        try validateContentHash(header, chunks: chunks, fileData: data)

        let stringData = try loadRequiredChunk(.stringTable, from: data, entries: chunks)
        let entities = try decodeTable(
            UntoldEntityRecordV1.self,
            chunkType: .entityTable,
            from: data,
            entries: chunks
        )
        let meshes = try decodeTable(
            UntoldMeshRecordV1.self,
            chunkType: .meshTable,
            from: data,
            entries: chunks
        )
        let materials = try decodeTable(
            UntoldMaterialRecordV1.self,
            chunkType: .materialTable,
            from: data,
            entries: chunks
        )
        let textures = try decodeTable(
            UntoldTextureRefRecordV1.self,
            chunkType: .textureTable,
            from: data,
            entries: chunks
        )

        let decoded = UntoldDecodedAsset(
            header: header,
            chunks: chunks,
            stringTableData: stringData,
            entities: entities,
            meshes: meshes,
            materials: materials,
            textures: textures
        )
        try validateDecodedAsset(decoded)
        return decoded
    }

    private func validateHeader(_ header: UntoldFileHeaderV1) throws {
        let expectedMagic = Array(UntoldFormat.magic.utf8) + [0]
        guard header.magic == expectedMagic else {
            throw UntoldValidationError.invalidMagic
        }
        guard header.formatVersion == UntoldFormat.version else {
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

    private func validateRequiredChunks(in chunks: [UntoldChunkEntryV1]) throws {
        let required: [UntoldChunkType] = [
            .stringTable,
            .entityTable,
            .meshTable,
            .materialTable,
            .textureTable,
            .vertexData,
            .indexData,
        ]
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
        guard let vertexChunk = asset.chunks.first(where: { $0.chunkType == .vertexData }),
              let indexChunk = asset.chunks.first(where: { $0.chunkType == .indexData })
        else {
            return
        }

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
        _ type: T.Type,
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
            records.append(try T.decode(from: chunkReader))
        }
        return records
    }

    private func loadRequiredChunk(
        _ chunkType: UntoldChunkType,
        from fileData: Data,
        entries: [UntoldChunkEntryV1]
    ) throws -> Data {
        guard let entry = entries.first(where: { $0.chunkType == chunkType }) else {
            throw UntoldValidationError.missingRequiredChunk(chunkType)
        }

        guard entry.compressionType == .none else {
            throw UntoldValidationError.unsupportedCompression(entry.compressionType.rawValue)
        }

        let fileOffset = Int(entry.fileOffset)
        let byteCount = Int(entry.compressedSize)
        guard fileOffset >= 0,
              byteCount >= 0,
              fileOffset <= fileData.count,
              fileOffset + byteCount <= fileData.count
        else {
            throw UntoldBinaryDecodingError.outOfBounds(
                offset: fileOffset,
                requested: byteCount,
                available: fileData.count
            )
        }

        return fileData.subdata(in: fileOffset ..< fileOffset + byteCount)
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

    public init(
        header: UntoldFileHeaderV1,
        chunks: [UntoldChunkEntryV1],
        stringTableData: Data,
        entities: [UntoldEntityRecordV1],
        meshes: [UntoldMeshRecordV1],
        materials: [UntoldMaterialRecordV1],
        textures: [UntoldTextureRefRecordV1]
    ) {
        self.header = header
        self.chunks = chunks
        self.stringTableData = stringTableData
        self.entities = entities
        self.meshes = meshes
        self.materials = materials
        self.textures = textures
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

    private func readFixedWidthInteger<T: FixedWidthInteger>(of type: T.Type) throws -> T {
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

    private func writeFixedWidthInteger<T: FixedWidthInteger>(_ value: T) {
        var mutableValue = value
        withUnsafeBytes(of: &mutableValue) { rawBuffer in
            data.append(contentsOf: rawBuffer)
        }
    }
}

//
//  UntoldMeshLODWriter.swift
//  UntoldEngineMeshCook
//
//  Writes one level of a model's LOD chain as a `.untold` file of its own.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Compression
import Foundation
import UntoldEngine

/// A level file is the source model with its geometry replaced: the same entities, mesh
/// records, materials and texture references, in the same order, so a loader can pair
/// the meshes of a level with those of the model by entity and position. The string,
/// entity, material and texture tables are copied byte for byte; feature edges, lights,
/// cameras and colour management stay with the model.
enum UntoldMeshLODWriter {
    private struct ChunkPayload {
        var entry: UntoldChunkEntryV1
        var storedBytes: Data
    }

    /// The file for `levels`, one per mesh record of `source`, in the records' order.
    static func levelFile(source: UntoldDecodedAsset, sourceData: Data, levels: [UntoldLODMeshLevel]) throws -> Data {
        precondition(levels.count == source.meshes.count, "one level per mesh record")

        var vertexChunk = Data()
        var indexChunk = Data()
        let meshTable = UntoldBinaryWriter()
        for (record, level) in zip(source.meshes, levels) {
            let usesShortIndices = level.vertexCount <= Int(UInt16.max) + 1
            let vertexOffset = vertexChunk.count
            let indexOffset = indexChunk.count
            vertexChunk.append(level.vertexData)
            if usesShortIndices {
                level.indices.withUnsafeBufferPointer { indices in
                    var short = [UInt16](repeating: 0, count: indices.count)
                    for position in 0 ..< indices.count {
                        short[position] = UInt16(truncatingIfNeeded: indices[position]).littleEndian
                    }
                    short.withUnsafeBufferPointer { indexChunk.append($0) }
                }
            } else {
                level.indices.withUnsafeBufferPointer { indices in
                    if UInt32(1).littleEndian == 1 {
                        indexChunk.append(indices)
                    } else {
                        indices.map(\.littleEndian).withUnsafeBufferPointer { indexChunk.append($0) }
                    }
                }
            }

            var updated = record
            updated.indexType = usesShortIndices ? .uint16 : .uint32
            updated.vertexCount = UInt32(level.vertexCount)
            updated.indexCount = UInt32(level.indices.count)
            updated.vertexDataOffset = UInt64(vertexOffset)
            updated.indexDataOffset = UInt64(indexOffset)
            updated.vertexDataSizeBytes = UInt64(level.vertexData.count)
            updated.indexDataSizeBytes = UInt64(indexChunk.count - indexOffset)
            updated.estimatedGPUBytes = updated.vertexDataSizeBytes + updated.indexDataSizeBytes
            // No feature edges: they outline the full model in the editor's wireframe.
            updated.reserved0 = 0
            updated.localBounds = UntoldAABB(min: level.boundsMin, max: level.boundsMax)
            updated.encode(to: meshTable)
        }

        // The geometry chunks follow the model's choice of compression.
        let compressGeometry = source.chunks.first(where: { $0.chunkType == .vertexData })?.compressionType == .lz4
        var payloads: [ChunkPayload] = []
        for chunkType in [UntoldChunkType.stringTable, .entityTable] {
            try payloads.append(copiedPayload(chunkType, source: source, sourceData: sourceData))
        }
        payloads.append(ChunkPayload(
            entry: UntoldChunkEntryV1(
                chunkType: .meshTable,
                fileOffset: 0,
                compressedSize: UInt64(meshTable.count),
                uncompressedSize: UInt64(meshTable.count),
                elementCount: UInt32(source.meshes.count)
            ),
            storedBytes: meshTable.data
        ))
        for chunkType in [UntoldChunkType.materialTable, .textureTable] {
            try payloads.append(copiedPayload(chunkType, source: source, sourceData: sourceData))
        }
        payloads.append(geometryPayload(.vertexData, bytes: vertexChunk, compress: compressGeometry))
        payloads.append(geometryPayload(.indexData, bytes: indexChunk, compress: compressGeometry))

        var header = source.header
        header.fileType = .lod
        header.flags |= UntoldFileFlags.generatedLODLevel
        header.chunkCount = UInt32(payloads.count)
        let headerSize = encodedSize(of: header)
        let entrySize = encodedSize(of: UntoldChunkEntryV1(chunkType: .stringTable, fileOffset: 0, compressedSize: 0, uncompressedSize: 0))
        let alignment = Int(UntoldFormat.fileAlignment)

        var offset = headerSize + entrySize * payloads.count
        for index in payloads.indices {
            offset = aligned(offset, to: alignment)
            payloads[index].entry.fileOffset = UInt64(offset)
            payloads[index].entry.compressedSize = UInt64(payloads[index].storedBytes.count)
            offset += payloads[index].storedBytes.count
        }

        let file = UntoldBinaryWriter()
        header.encode(to: file)
        for payload in payloads {
            payload.entry.encode(to: file)
        }
        for payload in payloads {
            file.align(to: alignment)
            file.writeData(payload.storedBytes)
        }

        // The hash covers the payloads alone, so the header is filled in once they are laid out.
        var data = file.data
        header.contentHash = try Array(UntoldFormat.contentHash(of: payloads.map(\.entry), in: data))
        let headerWriter = UntoldBinaryWriter()
        header.encode(to: headerWriter)
        data.replaceSubrange(0 ..< headerSize, with: headerWriter.data)
        return data
    }

    /// A chunk of the model as it is stored, compression included.
    private static func copiedPayload(_ chunkType: UntoldChunkType, source: UntoldDecodedAsset, sourceData: Data) throws -> ChunkPayload {
        guard let entry = source.chunks.first(where: { $0.chunkType == chunkType }) else {
            throw UntoldValidationError.missingRequiredChunk(chunkType)
        }
        guard entry.fileOffset <= UInt64(sourceData.count),
              entry.compressedSize <= UInt64(sourceData.count) - entry.fileOffset
        else {
            throw UntoldBinaryDecodingError.outOfBounds(
                offset: Int(clamping: entry.fileOffset),
                requested: Int(clamping: entry.compressedSize),
                available: sourceData.count
            )
        }
        let start = sourceData.startIndex + Int(entry.fileOffset)
        return ChunkPayload(entry: entry, storedBytes: sourceData.subdata(in: start ..< start + Int(entry.compressedSize)))
    }

    private static func geometryPayload(_ chunkType: UntoldChunkType, bytes: Data, compress: Bool) -> ChunkPayload {
        var entry = UntoldChunkEntryV1(
            chunkType: chunkType,
            fileOffset: 0,
            compressedSize: UInt64(bytes.count),
            uncompressedSize: UInt64(bytes.count)
        )
        if compress, let compressed = lz4Compressed(bytes), compressed.count < bytes.count {
            entry.compressionType = .lz4
            entry.compressedSize = UInt64(compressed.count)
            return ChunkPayload(entry: entry, storedBytes: compressed)
        }
        return ChunkPayload(entry: entry, storedBytes: bytes)
    }

    /// `bytes` as a raw LZ4 block, the form the exporter writes and `UntoldReader` decodes.
    private static func lz4Compressed(_ bytes: Data) -> Data? {
        guard !bytes.isEmpty else { return nil }
        // Incompressible input grows slightly; a result that does not fit is not wanted anyway.
        var output = Data(count: bytes.count)
        let written = output.withUnsafeMutableBytes { destination in
            bytes.withUnsafeBytes { source in
                compression_encode_buffer(
                    destination.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    destination.count,
                    source.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    source.count,
                    nil,
                    COMPRESSION_LZ4_RAW
                )
            }
        }
        guard written > 0 else { return nil }
        output.removeSubrange(written ..< output.count)
        return output
    }

    private static func encodedSize(of value: some UntoldBinaryEncodable) -> Int {
        let writer = UntoldBinaryWriter()
        value.encode(to: writer)
        return writer.count
    }

    private static func aligned(_ value: Int, to alignment: Int) -> Int {
        let remainder = value % alignment
        return remainder == 0 ? value : value + (alignment - remainder)
    }
}

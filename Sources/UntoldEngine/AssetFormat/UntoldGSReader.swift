//
//  UntoldGSReader.swift
//  UntoldEngine
//
//  Parses and validates the version-3 `.untoldgs` header, chunk index and tree,
//  serves chunk payloads by byte range, decodes chunks on the CPU, and exposes
//  the whole-asset `read`/`readHeader` entry points the runtime already uses.
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

/// Header, chunk index and tree of a `.untoldgs` file. Everything except the payloads.
public struct UntoldGSIndex: Sendable, Equatable {
    public var header: UntoldGSHeaderV3
    public var chunks: [UntoldGSChunkEntry]
    public var nodes: [UntoldGSTreeNode]

    public init(header: UntoldGSHeaderV3, chunks: [UntoldGSChunkEntry], nodes: [UntoldGSTreeNode]) {
        self.header = header
        self.chunks = chunks
        self.nodes = nodes
    }

    /// Byte range that must be read to parse the index: header through the end of the tree.
    public static func prefixSize(header: UntoldGSHeaderV3) -> Int {
        Int(header.nodeTreeOffset) + Int(header.nodeCount) * UntoldGSFormat.treeNodeSize
    }
}

public extension UntoldGSFormat {
    // MARK: - Runtime entry points

    /// Reads only the asset-level bounding box from the fixed-size header via a bounded
    /// `FileHandle` read — not `Data(contentsOf:)`, which would pull the whole payload into
    /// memory to look at a few header bytes. Lets registration paths (including streaming,
    /// which needs a real box before it can decide whether to load anything) get one
    /// synchronously without a caller-supplied value.
    static func readHeader(from url: URL) throws -> (boundingBoxMin: simd_float3, boundingBoxMax: simd_float3) {
        let header = try readHeaderV3(from: url)
        return (header.boundingBoxMin, header.boundingBoxMax)
    }

    /// Reads and validates the full header through a bounded `FileHandle` read.
    static func readHeaderV3(from url: URL) throws -> UntoldGSHeaderV3 {
        guard let fileHandle = FileHandle(forReadingAtPath: url.path) else {
            throw UntoldGSError.truncated
        }
        defer { try? fileHandle.close() }
        let data = try fileHandle.read(upToCount: headerSize) ?? Data()
        return try readHeaderV3(from: data)
    }

    /// Reads the whole asset into the layout the renderer consumes. Every chunk is read,
    /// CRC-verified and decoded on the CPU; the streaming loader reads chunks by range instead.
    static func read(from url: URL) throws -> UntoldGSAsset {
        let file = try UntoldGSFile(url: url)
        let header = file.header
        let shBytes = header.shBytesPerSplat

        var encodedSplats: [EncodedGaussianSplat] = []
        encodedSplats.reserveCapacity(Int(header.splatCount))
        var shCoefficients: [UInt8] = []
        shCoefficients.reserveCapacity(Int(header.splatCount) * shBytes)

        for chunkIndex in file.index.chunks.indices {
            let chunk = file.index.chunks[chunkIndex]
            let payload = try file.chunkPayload(at: chunkIndex)
            let decoded = try UntoldGSDecoder.decodeCore(chunk: chunk, payload: payload)
            for splat in decoded {
                encodedSplats.append(splat.encodedForTBDR())
            }
            if shBytes > 0 {
                let start = Int(chunk.coreBytes)
                let end = start + Int(chunk.splatCount) * shBytes
                shCoefficients.append(contentsOf: payload[payload.startIndex + start ..< payload.startIndex + end])
            }
        }

        return UntoldGSAsset(
            encodedSplats: encodedSplats,
            shCoefficients: shCoefficients,
            shMetadata: header.shMetadata,
            meanSquaredSplatExtent: header.meanSquaredSplatExtent,
            boundingBoxMin: header.boundingBoxMin,
            boundingBoxMax: header.boundingBoxMax
        )
    }

    // MARK: - Index parsing

    /// Parses the header alone from at least `headerSize` bytes. Older versions report
    /// `.unsupportedVersion` (the file must be re-baked), not `.truncated`.
    static func readHeaderV3(from data: Data) throws -> UntoldGSHeaderV3 {
        guard data.count >= 8 else { throw UntoldGSError.truncated }
        let prefix = UntoldBinaryReader(data: data)
        let magicValue = try prefix.readUInt32LE()
        guard magicValue == magic else { throw UntoldGSError.badMagic }
        let versionValue = try prefix.readUInt32LE()
        guard versionValue == version else { throw UntoldGSError.unsupportedVersion(versionValue) }
        guard data.count >= headerSize else { throw UntoldGSError.truncated }

        let header = try UntoldGSHeaderV3.decode(from: UntoldBinaryReader(data: data))
        try validate(header: header)
        return header
    }

    /// Parses header, chunk index and tree. `data` may be the whole file or any prefix
    /// covering the tree section; payload ranges are validated against `header.fileSize`.
    static func readIndex(from data: Data) throws -> UntoldGSIndex {
        let header = try readHeaderV3(from: data)
        let required = UntoldGSIndex.prefixSize(header: header)
        guard data.count >= required else { throw UntoldGSError.truncated }

        let reader = UntoldBinaryReader(data: data)
        try reader.seek(to: Int(header.chunkIndexOffset))
        var chunks: [UntoldGSChunkEntry] = []
        chunks.reserveCapacity(Int(header.chunkCount))
        for _ in 0 ..< header.chunkCount {
            try chunks.append(UntoldGSChunkEntry.decode(from: reader))
        }

        try reader.seek(to: Int(header.nodeTreeOffset))
        var nodes: [UntoldGSTreeNode] = []
        nodes.reserveCapacity(Int(header.nodeCount))
        for _ in 0 ..< header.nodeCount {
            try nodes.append(UntoldGSTreeNode.decode(from: reader))
        }

        let index = UntoldGSIndex(header: header, chunks: chunks, nodes: nodes)
        try validate(index: index)
        return index
    }

    // MARK: - Validation

    internal static func validate(header: UntoldGSHeaderV3) throws {
        guard header.shDegree <= maxSHDegree else {
            throw UntoldGSError.unsupported("spherical-harmonics degree \(header.shDegree)")
        }
        guard header.log2ChunkSplats >= 1, header.log2ChunkSplats <= maxLog2ChunkSplats else {
            throw UntoldGSError.unsupported("log2ChunkSplats \(header.log2ChunkSplats)")
        }
        guard header.flags & UntoldGSFlags.sphericalHarmonicsPalette == 0 else {
            throw UntoldGSError.unsupported("sphericalHarmonicsPalette")
        }
        guard header.splatCount > 0, header.chunkCount > 0, header.nodeCount > 0 else {
            throw UntoldGSError.sizeMismatch("empty asset")
        }
        for offset in [header.chunkIndexOffset, header.nodeTreeOffset, header.payloadOffset] {
            guard offset % UInt64(pageAlignment) == 0 else {
                throw UntoldGSError.sizeMismatch("section offset \(offset) is not page aligned")
            }
        }
        // Overflow-checked: a corrupt header can declare counts whose byte sizes overflow.
        let (indexSize, indexOverflow) = UInt64(header.chunkCount).multipliedReportingOverflow(by: UInt64(chunkEntrySize))
        let (treeSize, treeOverflow) = UInt64(header.nodeCount).multipliedReportingOverflow(by: UInt64(treeNodeSize))
        guard !indexOverflow, !treeOverflow else {
            throw UntoldGSError.sizeMismatch("header-declared counts overflow")
        }
        try requireInFile(offset: header.chunkIndexOffset, size: indexSize, fileSize: header.fileSize, what: "chunk index")
        try requireInFile(offset: header.nodeTreeOffset, size: treeSize, fileSize: header.fileSize, what: "node tree")
        guard header.payloadOffset <= header.fileSize else {
            throw UntoldGSError.sizeMismatch("payload offset \(header.payloadOffset) beyond file size \(header.fileSize)")
        }
        // The three sections must not share bytes: a corrupt header could otherwise have the
        // chunk index and the tree parsed from the same range and pass every per-section check.
        let sections: [(name: String, start: UInt64, end: UInt64)] = [
            ("header", 0, UInt64(headerSize)),
            ("chunk index", header.chunkIndexOffset, header.chunkIndexOffset + indexSize),
            ("node tree", header.nodeTreeOffset, header.nodeTreeOffset + treeSize),
            ("payload", header.payloadOffset, header.fileSize),
        ]
        for first in sections.indices {
            for second in sections.indices where second > first {
                let a = sections[first]
                let b = sections[second]
                let overlap = a.start < b.end && b.start < a.end
                guard !overlap else {
                    throw UntoldGSError.sizeMismatch("\(a.name) and \(b.name) sections overlap")
                }
            }
        }
    }

    internal static func validate(index: UntoldGSIndex) throws {
        let header = index.header
        guard index.chunks.count == Int(header.chunkCount) else {
            throw UntoldGSError.sizeMismatch("chunk count \(index.chunks.count), expected \(header.chunkCount)")
        }
        let maxSplats = UInt32(header.splatsPerChunk)
        let shBytes = header.shBytesPerSplat
        var totalSplats: UInt64 = 0

        for (chunkIndex, chunk) in index.chunks.enumerated() {
            guard chunk.splatCount > 0, chunk.splatCount <= maxSplats else {
                throw UntoldGSError.sizeMismatch("chunk \(chunkIndex) splat count \(chunk.splatCount) out of range")
            }
            let expectedCore = chunk.splatCount * UInt32(coreRecordSize)
            guard chunk.coreBytes == expectedCore else {
                throw UntoldGSError.sizeMismatch("chunk \(chunkIndex) core bytes \(chunk.coreBytes), expected \(expectedCore)")
            }
            let unpadded = Int(chunk.coreBytes) + Int(chunk.splatCount) * shBytes
            guard Int(chunk.payloadBytes) >= unpadded, chunk.payloadBytes % UInt32(pageAlignment) == 0 else {
                throw UntoldGSError.sizeMismatch("chunk \(chunkIndex) payload bytes \(chunk.payloadBytes) cannot hold \(unpadded)")
            }
            guard chunk.payloadOffset % UInt64(pageAlignment) == 0 else {
                throw UntoldGSError.sizeMismatch("chunk \(chunkIndex) offset \(chunk.payloadOffset) is not page aligned")
            }
            try requireInFile(offset: chunk.payloadOffset, size: UInt64(chunk.payloadBytes), fileSize: header.fileSize, what: "chunk \(chunkIndex)")
            guard Int(chunk.nodeId) < index.nodes.count else {
                throw UntoldGSError.corrupt("chunk \(chunkIndex) references node \(chunk.nodeId) of \(index.nodes.count)")
            }
            totalSplats += UInt64(chunk.splatCount)
        }
        guard totalSplats == UInt64(header.splatCount) else {
            throw UntoldGSError.sizeMismatch("chunks hold \(totalSplats) splats, header declares \(header.splatCount)")
        }

        for (nodeIndex, node) in index.nodes.enumerated() {
            let end = UInt64(node.firstChunk) + UInt64(node.chunkCount)
            guard node.chunkCount > 0, end <= UInt64(index.chunks.count) else {
                throw UntoldGSError.corrupt("node \(nodeIndex) spans chunks \(node.firstChunk)..<\(end) of \(index.chunks.count)")
            }
            for child in [node.child0, node.child1] where child != invalidNode {
                guard Int(child) < index.nodes.count, Int(child) > nodeIndex else {
                    throw UntoldGSError.corrupt("node \(nodeIndex) has invalid child \(child)")
                }
            }
        }
        guard index.nodes[0].firstChunk == 0, index.nodes[0].chunkCount == UInt32(index.chunks.count) else {
            throw UntoldGSError.corrupt("root does not cover every chunk")
        }
    }

    private static func requireInFile(offset: UInt64, size: UInt64, fileSize: UInt64, what: String) throws {
        let (end, overflow) = offset.addingReportingOverflow(size)
        guard !overflow, end <= fileSize else {
            throw UntoldGSError.sizeMismatch("\(what) at \(offset)+\(size) exceeds file size \(fileSize)")
        }
    }
}

// MARK: - Chunk decoding

public enum UntoldGSDecoder {
    /// Verifies the chunk CRC over the unpadded payload.
    public static func verify(chunk: UntoldGSChunkEntry, chunkIndex: Int, header: UntoldGSHeaderV3, payload: Data) throws {
        let unpadded = Int(chunk.coreBytes) + Int(chunk.splatCount) * header.shBytesPerSplat
        guard payload.count >= unpadded else {
            throw UntoldGSError.truncated
        }
        let actual = UntoldGSCRC32.checksum(payload.prefix(unpadded))
        guard actual == chunk.crc32 else {
            throw UntoldGSError.corrupt("chunk \(chunkIndex) CRC \(String(actual, radix: 16)) does not match \(String(chunk.crc32, radix: 16))")
        }
    }

    /// Decodes the core block of a chunk payload (positions, scales, rotations, colour, opacity).
    public static func decodeCore(chunk: UntoldGSChunkEntry, payload: Data) throws -> [UntoldGSSplat] {
        let count = Int(chunk.splatCount)
        guard payload.count >= Int(chunk.coreBytes) else {
            throw UntoldGSError.truncated
        }
        let ranges = UntoldGSPacking.ChunkRanges(entry: chunk)
        let reader = UntoldBinaryReader(data: payload)
        var splats: [UntoldGSSplat] = []
        splats.reserveCapacity(count)
        for _ in 0 ..< count {
            let record = try UntoldGSCoreRecord(
                position: reader.readUInt32LE(),
                rotation: reader.readUInt32LE(),
                scale: reader.readUInt32LE(),
                rgba: reader.readUInt32LE()
            )
            splats.append(UntoldGSPacking.decode(record, ranges: ranges))
        }
        return splats
    }

    /// Decodes a chunk payload including its SH block, dequantised to floats.
    public static func decode(chunk: UntoldGSChunkEntry, header: UntoldGSHeaderV3, payload: Data) throws -> [UntoldGSSplat] {
        var splats = try decodeCore(chunk: chunk, payload: payload)
        let shBytes = header.shBytesPerSplat
        guard shBytes > 0 else { return splats }
        let count = Int(chunk.splatCount)
        guard payload.count >= Int(chunk.coreBytes) + count * shBytes else {
            throw UntoldGSError.truncated
        }
        let reader = UntoldBinaryReader(data: payload)
        try reader.seek(to: Int(chunk.coreBytes))
        for index in 0 ..< count {
            var coefficients: [Float] = []
            coefficients.reserveCapacity(shBytes)
            for _ in 0 ..< shBytes {
                try coefficients.append(UntoldGSPacking.unpackSHCoefficient(reader.readUInt8()))
            }
            splats[index].sphericalHarmonics = coefficients
        }
        return splats
    }
}

// MARK: - Range-based file access

/// Opens a `.untoldgs` on disk, parses only the index, and serves chunk payloads by
/// byte range. The payload is never read whole.
public final class UntoldGSFile: @unchecked Sendable {
    public let url: URL
    public let index: UntoldGSIndex
    private let handle: FileHandle
    private let lock = NSLock()

    public init(url: URL) throws {
        self.url = url
        guard let handle = FileHandle(forReadingAtPath: url.path) else {
            throw UntoldGSError.truncated
        }
        self.handle = handle

        try handle.seek(toOffset: 0)
        let headerData = try handle.read(upToCount: UntoldGSFormat.headerSize) ?? Data()
        let header = try UntoldGSFormat.readHeaderV3(from: headerData)

        let actualSize = try handle.seekToEnd()
        guard actualSize == header.fileSize else {
            throw UntoldGSError.sizeMismatch("file has \(actualSize) bytes, header declares \(header.fileSize)")
        }

        let prefixSize = UntoldGSIndex.prefixSize(header: header)
        try handle.seek(toOffset: 0)
        guard let prefix = try handle.read(upToCount: prefixSize), prefix.count == prefixSize else {
            throw UntoldGSError.truncated
        }
        index = try UntoldGSFormat.readIndex(from: prefix)
    }

    deinit {
        try? handle.close()
    }

    public var header: UntoldGSHeaderV3 {
        index.header
    }

    /// Reads one chunk's padded payload. Verifies the CRC when `verify` is set.
    public func chunkPayload(at chunkIndex: Int, verify: Bool = true) throws -> Data {
        guard chunkIndex >= 0, chunkIndex < index.chunks.count else {
            throw UntoldGSError.sizeMismatch("chunk \(chunkIndex) of \(index.chunks.count)")
        }
        let chunk = index.chunks[chunkIndex]
        let payload: Data = try lock.withLock {
            try handle.seek(toOffset: chunk.payloadOffset)
            guard let data = try handle.read(upToCount: Int(chunk.payloadBytes)), data.count == Int(chunk.payloadBytes) else {
                throw UntoldGSError.truncated
            }
            return data
        }
        if verify {
            try UntoldGSDecoder.verify(chunk: chunk, chunkIndex: chunkIndex, header: index.header, payload: payload)
        }
        return payload
    }

    /// Reads and decodes one chunk on the CPU, SH included.
    public func decodeChunk(at chunkIndex: Int, verify: Bool = true) throws -> [UntoldGSSplat] {
        let payload = try chunkPayload(at: chunkIndex, verify: verify)
        return try UntoldGSDecoder.decode(chunk: index.chunks[chunkIndex], header: index.header, payload: payload)
    }

    /// Reads and decodes every chunk in index order. Intended for tests and tooling.
    public func decodeAll(verify: Bool = true) throws -> [UntoldGSSplat] {
        var splats: [UntoldGSSplat] = []
        splats.reserveCapacity(Int(index.header.splatCount))
        for chunkIndex in index.chunks.indices {
            try splats.append(contentsOf: decodeChunk(at: chunkIndex, verify: verify))
        }
        return splats
    }
}

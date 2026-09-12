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

/// Header, chunk index, tree and (when the file carries one) coarse index of a `.untoldgs`
/// file. Everything except the payloads.
public struct UntoldGSIndex: Sendable, Equatable {
    public var header: UntoldGSHeaderV3
    public var chunks: [UntoldGSChunkEntry]
    public var nodes: [UntoldGSTreeNode]
    /// The coarse index, level-major: entry `(L − 1) × chunkCount + c` is level `L` of chunk `c`.
    /// Empty without the section.
    public var coarse: [UntoldGSChunkEntry]

    public init(header: UntoldGSHeaderV3, chunks: [UntoldGSChunkEntry], nodes: [UntoldGSTreeNode], coarse: [UntoldGSChunkEntry] = []) {
        self.header = header
        self.chunks = chunks
        self.nodes = nodes
        self.coarse = coarse
    }

    /// Byte range that must be read to parse the index: header through the end of the tree.
    /// The coarse index, when flagged, is a second bounded read at `coarseIndexRange(header:)`.
    public static func prefixSize(header: UntoldGSHeaderV3) -> Int {
        Int(header.nodeTreeOffset) + Int(header.nodeCount) * UntoldGSFormat.treeNodeSize
    }

    /// Bytes of the coarse index: `coarseLevelCount × chunkCount` entries at `coarseIndexOffset`.
    /// Zero without the section.
    public static func coarseIndexSize(header: UntoldGSHeaderV3) -> Int {
        guard header.hasCoarseLevels else { return 0 }
        return Int(header.coarseLevelCount) * Int(header.chunkCount) * UntoldGSFormat.coarseIndexEntrySize
    }

    /// The file range of the coarse index, or nil without the section.
    public static func coarseIndexRange(header: UntoldGSHeaderV3) -> Range<UInt64>? {
        guard header.hasCoarseLevels else { return nil }
        return header.coarseIndexOffset ..< header.coarseIndexOffset + UInt64(coarseIndexSize(header: header))
    }

    /// Coarse levels per chunk: 0 without the section.
    public var coarseLevelCount: Int {
        Int(header.coarseLevelCount)
    }

    /// `coarseRatioLog2[L − 1]` for the levels present.
    public var coarseRatioLog2: [UInt8] {
        Array(header.coarseRatioLog2.prefix(coarseLevelCount))
    }

    /// The coarse entry of level `level` (1-based) of chunk `chunk`, or nil when the file has no
    /// such level or the chunk has no records at it.
    public func coarseEntry(level: Int, chunk: Int) -> UntoldGSChunkEntry? {
        guard level >= 1, level <= coarseLevelCount, chunk >= 0, chunk < chunks.count else { return nil }
        let entry = coarse[(level - 1) * chunks.count + chunk]
        return entry.splatCount > 0 ? entry : nil
    }

    /// The contiguous file range holding every chunk's records of level `level`, or nil when the
    /// level is absent or holds no records. Levels are laid out coarsest first, each in chunk order.
    public func coarseLevelRange(level: Int) -> Range<UInt64>? {
        guard level >= 1, level <= coarseLevelCount else { return nil }
        var start = UInt64.max
        var end: UInt64 = 0
        for chunk in chunks.indices {
            guard let entry = coarseEntry(level: level, chunk: chunk) else { continue }
            start = min(start, entry.payloadOffset)
            end = max(end, entry.payloadOffset + UInt64(entry.payloadBytes))
        }
        return start < end ? start ..< end : nil
    }

    /// Index of the first record of level `level` of chunk `chunk` inside the coarse payload
    /// region, in records: `(payloadOffset − coarsePayloadOffset) / 16`. 0 for an absent level.
    public func coarseRecordIndex(level: Int, chunk: Int) -> Int {
        guard let entry = coarseEntry(level: level, chunk: chunk) else { return 0 }
        return Int((entry.payloadOffset - header.coarsePayloadOffset) / UInt64(UntoldGSFormat.coreRecordSize))
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

    /// Parses header, chunk index, tree and — when the file carries coarse levels — the coarse
    /// index. `data` may be the whole file or any prefix covering the tree section and, when
    /// flagged, the coarse index (which lies after the fine payloads, so a prefix reader passes
    /// the whole file or uses `readIndex(from url:)`); payload ranges are validated against
    /// `header.fileSize`.
    static func readIndex(from data: Data) throws -> UntoldGSIndex {
        let header = try readHeaderV3(from: data)
        let required = UntoldGSIndex.prefixSize(header: header)
        guard data.count >= required else { throw UntoldGSError.truncated }
        var coarseIndex = Data()
        if let range = UntoldGSIndex.coarseIndexRange(header: header) {
            guard UInt64(data.count) >= range.upperBound else { throw UntoldGSError.truncated }
            coarseIndex = data.subdata(in: data.startIndex + Int(range.lowerBound) ..< data.startIndex + Int(range.upperBound))
        }
        return try readIndex(header: header, prefix: data, coarseIndex: coarseIndex)
    }

    /// Reads the index of the file at `url` with bounded reads: the prefix through the tree and,
    /// when flagged, the coarse index. The payloads are never read.
    static func readIndex(from url: URL) throws -> UntoldGSIndex {
        guard let fileHandle = FileHandle(forReadingAtPath: url.path) else {
            throw UntoldGSError.truncated
        }
        defer { try? fileHandle.close() }
        let header = try readHeaderV3(from: fileHandle.read(upToCount: headerSize) ?? Data())
        return try readIndex(header: header) { offset, count in
            try fileHandle.seek(toOffset: offset)
            guard let data = try fileHandle.read(upToCount: count), data.count == count else {
                throw UntoldGSError.truncated
            }
            return data
        }
    }

    /// Reads the index through `read(offset, count)` — the prefix, then the coarse index when
    /// flagged — for callers that own the descriptor (`UntoldGSFile`, the page source).
    static func readIndex(header: UntoldGSHeaderV3, read: (UInt64, Int) throws -> Data) throws -> UntoldGSIndex {
        let prefix = try read(0, UntoldGSIndex.prefixSize(header: header))
        var coarseIndex = Data()
        if let range = UntoldGSIndex.coarseIndexRange(header: header) {
            coarseIndex = try read(range.lowerBound, Int(range.upperBound - range.lowerBound))
        }
        return try readIndex(header: header, prefix: prefix, coarseIndex: coarseIndex)
    }

    /// Parses the sections out of their bytes: `prefix` covers header through tree, `coarseIndex`
    /// is exactly the coarse index (empty without the section).
    private static func readIndex(header: UntoldGSHeaderV3, prefix: Data, coarseIndex: Data) throws -> UntoldGSIndex {
        guard prefix.count >= UntoldGSIndex.prefixSize(header: header) else { throw UntoldGSError.truncated }
        let reader = UntoldBinaryReader(data: prefix)
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

        var coarse: [UntoldGSChunkEntry] = []
        let coarseSize = UntoldGSIndex.coarseIndexSize(header: header)
        if coarseSize > 0 {
            guard coarseIndex.count >= coarseSize else { throw UntoldGSError.truncated }
            let coarseReader = UntoldBinaryReader(data: coarseIndex)
            let count = coarseSize / coarseIndexEntrySize
            coarse.reserveCapacity(count)
            for _ in 0 ..< count {
                try coarse.append(UntoldGSChunkEntry.decode(from: coarseReader))
            }
        }

        let index = UntoldGSIndex(header: header, chunks: chunks, nodes: nodes, coarse: coarse)
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
        // The sections must not share bytes: a corrupt header could otherwise have the chunk
        // index and the tree parsed from the same range and pass every per-section check.
        var sections: [(name: String, start: UInt64, end: UInt64)] = [
            ("header", 0, UInt64(headerSize)),
            ("chunk index", header.chunkIndexOffset, header.chunkIndexOffset + indexSize),
            ("node tree", header.nodeTreeOffset, header.nodeTreeOffset + treeSize),
        ]
        if header.hasCoarseLevels {
            try validateCoarse(header: header)
            let coarseIndexSize = UInt64(UntoldGSIndex.coarseIndexSize(header: header))
            try requireInFile(offset: header.coarseIndexOffset, size: coarseIndexSize, fileSize: header.fileSize, what: "coarse index")
            guard header.coarsePayloadOffset <= header.fileSize else {
                throw UntoldGSError.sizeMismatch("coarse payload offset \(header.coarsePayloadOffset) beyond file size \(header.fileSize)")
            }
            sections.append(("payload", header.payloadOffset, header.coarseIndexOffset))
            sections.append(("coarse index", header.coarseIndexOffset, header.coarseIndexOffset + coarseIndexSize))
            sections.append(("coarse payload", header.coarsePayloadOffset, header.fileSize))
        } else {
            guard header.coarseIndexOffset == 0, header.coarsePayloadOffset == 0, header.coarseRecordCount == 0,
                  header.coarseLevelCount == 0, header.coarseRatioLog2.allSatisfy({ $0 == 0 }), header.coarseFlags == 0
            else {
                throw UntoldGSError.corrupt("coarse fields without the flag")
            }
            sections.append(("payload", header.payloadOffset, header.fileSize))
        }
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

    /// The coarse header words with the flag set: level count, ratios, flags, alignment and the
    /// index at or after the fine payloads. Ranges against the file follow in `validate(header:)`.
    private static func validateCoarse(header: UntoldGSHeaderV3) throws {
        let levels = Int(header.coarseLevelCount)
        guard levels >= 1, levels <= maxCoarseLevels else {
            throw UntoldGSError.corrupt("coarse level count \(levels)")
        }
        guard header.coarseRatioLog2.count == UntoldGSHeaderV3.coarseRatioLog2Size else {
            throw UntoldGSError.corrupt("coarse ratio slots \(header.coarseRatioLog2.count)")
        }
        var previous: UInt8 = 0
        for level in 0 ..< UntoldGSHeaderV3.coarseRatioLog2Size {
            let ratio = header.coarseRatioLog2[level]
            if level < levels {
                guard ratio > previous, ratio <= header.log2ChunkSplats else {
                    throw UntoldGSError.corrupt("coarse ratio log2 \(header.coarseRatioLog2) for level \(level + 1)")
                }
                previous = ratio
            } else {
                guard ratio == 0 else {
                    throw UntoldGSError.corrupt("coarse ratio slot \(level) of an absent level is \(ratio)")
                }
            }
        }
        guard header.coarseFlags == 0 else {
            throw UntoldGSError.unsupported("coarse flags \(header.coarseFlags)")
        }
        for offset in [header.coarseIndexOffset, header.coarsePayloadOffset] {
            guard offset % UInt64(pageAlignment) == 0 else {
                throw UntoldGSError.sizeMismatch("coarse section offset \(offset) is not page aligned")
            }
        }
        guard header.coarseIndexOffset >= header.payloadOffset else {
            throw UntoldGSError.sizeMismatch("coarse index at \(header.coarseIndexOffset) precedes the payload at \(header.payloadOffset)")
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
            if header.hasCoarseLevels {
                guard chunk.payloadOffset + UInt64(chunk.payloadBytes) <= header.coarseIndexOffset else {
                    throw UntoldGSError.sizeMismatch("chunk \(chunkIndex) at \(chunk.payloadOffset)+\(chunk.payloadBytes) runs into the coarse index at \(header.coarseIndexOffset)")
                }
            }
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

        try validateCoarse(index: index)
    }

    /// The coarse index against the header and the fine index: one entry per level per chunk
    /// naming its level and chunk, record counts within the level's ratio, unpadded core-only
    /// payloads 16-byte aligned inside the coarse payload region and laid out coarsest level
    /// first in chunk order without overlap, a finer level wherever a coarser one exists, and the
    /// header's record total. Nothing here falls back to fine-only: a malformed section is corrupt.
    private static func validateCoarse(index: UntoldGSIndex) throws {
        let header = index.header
        let levels = index.coarseLevelCount
        let expectedCount = levels * index.chunks.count
        guard index.coarse.count == expectedCount else {
            throw UntoldGSError.sizeMismatch("coarse index holds \(index.coarse.count) entries, expected \(expectedCount)")
        }
        guard levels > 0 else { return }

        var totalRecords: UInt64 = 0
        var cursor = header.coarsePayloadOffset
        for level in stride(from: levels, through: 1, by: -1) {
            let maxRecords = UInt32(max(1, header.splatsPerChunk >> Int(header.coarseRatioLog2[level - 1])))
            for chunkIndex in index.chunks.indices {
                let entry = index.coarse[(level - 1) * index.chunks.count + chunkIndex]
                let what = "coarse level \(level) of chunk \(chunkIndex)"
                guard Int(entry.lodLevel) == level else {
                    throw UntoldGSError.corrupt("\(what) is labelled level \(entry.lodLevel)")
                }
                guard Int(entry.reserved0) == chunkIndex else {
                    throw UntoldGSError.corrupt("\(what) names chunk \(entry.reserved0)")
                }
                guard entry.nodeId == index.chunks[chunkIndex].nodeId else {
                    throw UntoldGSError.corrupt("\(what) references node \(entry.nodeId), the chunk's is \(index.chunks[chunkIndex].nodeId)")
                }
                guard entry.splatCount <= maxRecords else {
                    throw UntoldGSError.sizeMismatch("\(what) holds \(entry.splatCount) records, at most \(maxRecords)")
                }
                let finite = entry.aabbMin.x.isFinite && entry.aabbMin.y.isFinite && entry.aabbMin.z.isFinite
                    && entry.aabbMax.x.isFinite && entry.aabbMax.y.isFinite && entry.aabbMax.z.isFinite
                    && entry.logScaleMin.isFinite && entry.logScaleMax.isFinite
                guard finite, entry.aabbMin.x <= entry.aabbMax.x, entry.aabbMin.y <= entry.aabbMax.y, entry.aabbMin.z <= entry.aabbMax.z,
                      entry.logScaleMin <= entry.logScaleMax
                else {
                    throw UntoldGSError.corrupt("\(what) has invalid decode ranges")
                }
                if level > 1, entry.splatCount > 0 {
                    guard index.coarse[(level - 2) * index.chunks.count + chunkIndex].splatCount > 0 else {
                        throw UntoldGSError.corrupt("\(what) exists without level \(level - 1)")
                    }
                }
                guard entry.splatCount > 0 else {
                    guard entry.coreBytes == 0, entry.payloadBytes == 0 else {
                        throw UntoldGSError.sizeMismatch("\(what) is empty but declares \(entry.coreBytes) core and \(entry.payloadBytes) payload bytes")
                    }
                    continue
                }
                let expectedCore = entry.splatCount * UInt32(coreRecordSize)
                guard entry.coreBytes == expectedCore, entry.payloadBytes == expectedCore else {
                    throw UntoldGSError.sizeMismatch("\(what) core bytes \(entry.coreBytes), payload bytes \(entry.payloadBytes), expected \(expectedCore)")
                }
                guard entry.payloadOffset % UInt64(coreRecordSize) == 0 else {
                    throw UntoldGSError.sizeMismatch("\(what) offset \(entry.payloadOffset) is not record aligned")
                }
                guard entry.payloadOffset >= cursor else {
                    throw UntoldGSError.sizeMismatch("\(what) at \(entry.payloadOffset) overlaps the previous coarse payload ending at \(cursor)")
                }
                try requireInFile(offset: entry.payloadOffset, size: UInt64(entry.payloadBytes), fileSize: header.fileSize, what: what)
                cursor = entry.payloadOffset + UInt64(entry.payloadBytes)
                totalRecords += UInt64(entry.splatCount)
            }
        }
        guard totalRecords == UInt64(header.coarseRecordCount) else {
            throw UntoldGSError.sizeMismatch("coarse levels hold \(totalRecords) records, header declares \(header.coarseRecordCount)")
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
        try verify(chunk: chunk, chunkIndex: chunkIndex, shBytesPerSplat: header.shBytesPerSplat, payload: payload)
    }

    /// Verifies the CRC of an entry whose SH block holds `shBytesPerSplat` per record — 0 for a
    /// coarse level, whose records carry no harmonics whatever the file's degree.
    public static func verify(chunk: UntoldGSChunkEntry, chunkIndex: Int, shBytesPerSplat: Int, payload: Data) throws {
        let unpadded = Int(chunk.coreBytes) + Int(chunk.splatCount) * shBytesPerSplat
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

        index = try UntoldGSFormat.readIndex(header: header) { offset, count in
            try handle.seek(toOffset: offset)
            guard let data = try handle.read(upToCount: count), data.count == count else {
                throw UntoldGSError.truncated
            }
            return data
        }
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

    /// Reads the records of coarse level `level` (1-based) of chunk `chunk`: `coreBytes` bytes,
    /// unpadded, empty when the chunk has no such level. Verifies the level's CRC when `verify` is set.
    public func coarsePayload(level: Int, chunk: Int, verify: Bool = true) throws -> Data {
        guard level >= 1, level <= index.coarseLevelCount else {
            throw UntoldGSError.sizeMismatch("coarse level \(level) of \(index.coarseLevelCount)")
        }
        guard chunk >= 0, chunk < index.chunks.count else {
            throw UntoldGSError.sizeMismatch("chunk \(chunk) of \(index.chunks.count)")
        }
        guard let entry = index.coarseEntry(level: level, chunk: chunk) else { return Data() }
        let payload: Data = try lock.withLock {
            try handle.seek(toOffset: entry.payloadOffset)
            guard let data = try handle.read(upToCount: Int(entry.payloadBytes)), data.count == Int(entry.payloadBytes) else {
                throw UntoldGSError.truncated
            }
            return data
        }
        if verify {
            try UntoldGSDecoder.verify(chunk: entry, chunkIndex: chunk, shBytesPerSplat: 0, payload: payload)
        }
        return payload
    }

    /// Reads and decodes coarse level `level` of chunk `chunk` on the CPU; empty when absent.
    public func decodeCoarseLevel(level: Int, chunk: Int, verify: Bool = true) throws -> [UntoldGSSplat] {
        guard let entry = index.coarseEntry(level: level, chunk: chunk) else {
            _ = try coarsePayload(level: level, chunk: chunk, verify: false) // range checks
            return []
        }
        let payload = try coarsePayload(level: level, chunk: chunk, verify: verify)
        return try UntoldGSDecoder.decodeCore(chunk: entry, payload: payload)
    }
}

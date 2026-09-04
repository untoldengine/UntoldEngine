//
//  UntoldGSWriter.swift
//  UntoldEngine
//
//  Builds a version-3 `.untoldgs` file from an in-memory splat list: Morton
//  ordering, chunking with per-chunk quantisation ranges, a binary tree over
//  the chunk array, and page-aligned sections.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

public struct UntoldGSWriteOptions: Sendable {
    /// log2 of the maximum splat count per chunk. 10 (1024 splats) for objects, 12 for environments.
    public var log2ChunkSplats: UInt8 = UntoldGSFormat.defaultLog2ChunkSplats
    /// SH degree to store. Every splat must carry the matching coefficient count. 0 stores none.
    public var shDegree: UInt8 = 0
    /// Maximum chunks under a tree leaf.
    public var leafMaxChunks: Int = 8
    /// Within a chunk, order splats by opacity × area so partial reads keep the important ones.
    public var sortByImportanceWithinChunk = true
    public var coordinateSystem: UntoldGSCoordinateSystem = .rightUpBack
    public var colorSpace: UntoldGSColorSpace = .sRGBDisplayReferred
    public var antialiased = false
    public var isEnvironment = false
    /// Asset-level bounding box to bake. Defaults to the splat bounds expanded by each
    /// splat's largest scale, like `computeGaussianSplatBoundingBox`.
    public var boundingBoxMin: SIMD3<Float>?
    public var boundingBoxMax: SIMD3<Float>?
    /// Bake-time overdraw statistic for this tier — see `estimatedGaussianOverdraw`.
    public var meanSquaredSplatExtent: Float = 0
    public var splatToMesh: simd_float4x4 = matrix_identity_float4x4
    public var captureExposureEV: Float = 0
    public var captureWhiteBalance = SIMD3<Float>(repeating: 1)

    public init() {}
}

public extension UntoldGSFormat {
    /// Encodes `splats` into a complete version-3 file image.
    static func write(splats: [UntoldGSSplat], options: UntoldGSWriteOptions = .init()) throws -> Data {
        guard !splats.isEmpty else { throw UntoldGSError.invalidInput("no splats to write") }
        guard options.shDegree <= maxSHDegree else {
            throw UntoldGSError.unsupported("spherical-harmonics degree \(options.shDegree)")
        }
        guard options.log2ChunkSplats >= 1, options.log2ChunkSplats <= maxLog2ChunkSplats else {
            throw UntoldGSError.unsupported("log2ChunkSplats \(options.log2ChunkSplats)")
        }

        let shCount = shCoefficientCount(degree: options.shDegree)
        for (index, splat) in splats.enumerated() where splat.sphericalHarmonics.count != shCount {
            throw UntoldGSError.invalidInput(
                "splat \(index) carries \(splat.sphericalHarmonics.count) SH coefficients, expected \(shCount)"
            )
        }

        let bounds = bounds(of: splats)
        let order = mortonOrder(splats, boundsMin: bounds.min, boundsMax: bounds.max)
        let splatsPerChunk = 1 << Int(options.log2ChunkSplats)
        let chunkRanges = stride(from: 0, to: order.count, by: splatsPerChunk).map { start in
            Array(order[start ..< min(start + splatsPerChunk, order.count)])
        }

        let headerSection = alignedToPage(headerSize)
        let chunkIndexOffset = headerSection
        let chunkIndexSection = alignedToPage(chunkRanges.count * chunkEntrySize)

        var entries: [UntoldGSChunkEntry] = []
        entries.reserveCapacity(chunkRanges.count)
        var payloads: [Data] = []
        payloads.reserveCapacity(chunkRanges.count)

        for indices in chunkRanges {
            var ordered = indices
            if options.sortByImportanceWithinChunk {
                ordered.sort { importance(splats[$0]) > importance(splats[$1]) }
            }
            let encoded = encodeChunk(ordered.map { splats[$0] }, shCount: shCount)
            entries.append(encoded.entry)
            payloads.append(encoded.payload)
        }

        let nodes = try buildTree(entries: &entries, leafMaxChunks: max(1, options.leafMaxChunks))
        let nodeTreeOffset = chunkIndexOffset + chunkIndexSection
        let nodeTreeSection = alignedToPage(nodes.count * treeNodeSize)
        let payloadOffset = nodeTreeOffset + nodeTreeSection

        var cursor = payloadOffset
        for index in entries.indices {
            entries[index].payloadOffset = UInt64(cursor)
            cursor += Int(entries[index].payloadBytes)
        }
        let fileSize = cursor

        var flags: UInt32 = 0
        if options.shDegree > 0 {
            flags |= UntoldGSFlags.hasSphericalHarmonics
        }
        if options.antialiased {
            flags |= UntoldGSFlags.antialiased
        }
        if options.isEnvironment {
            flags |= UntoldGSFlags.environment
        }

        let boundingBox = defaultBoundingBox(of: splats)
        let header = UntoldGSHeaderV3(
            flags: flags,
            shDegree: options.shDegree,
            coordinateSystem: options.coordinateSystem,
            colorSpace: options.colorSpace,
            log2ChunkSplats: options.log2ChunkSplats,
            splatCount: UInt32(splats.count),
            chunkCount: UInt32(entries.count),
            nodeCount: UInt32(nodes.count),
            lodLevels: 1,
            boundsMin: bounds.min,
            boundsMax: bounds.max,
            boundingBoxMin: options.boundingBoxMin ?? boundingBox.min,
            boundingBoxMax: options.boundingBoxMax ?? boundingBox.max,
            meanSquaredSplatExtent: options.meanSquaredSplatExtent,
            captureExposureEV: options.captureExposureEV,
            captureWhiteBalance: options.captureWhiteBalance,
            splatToMesh: options.splatToMesh,
            chunkIndexOffset: UInt64(chunkIndexOffset),
            nodeTreeOffset: UInt64(nodeTreeOffset),
            paletteOffset: 0,
            payloadOffset: UInt64(payloadOffset),
            fileSize: UInt64(fileSize)
        )

        let writer = UntoldBinaryWriter()
        header.encode(to: writer)
        writer.align(to: pageAlignment)
        for entry in entries {
            entry.encode(to: writer)
        }
        writer.align(to: pageAlignment)
        for node in nodes {
            node.encode(to: writer)
        }
        writer.align(to: pageAlignment)
        precondition(writer.count == payloadOffset, "section layout mismatch")
        for payload in payloads {
            writer.writeData(payload)
            writer.align(to: pageAlignment)
        }
        precondition(writer.count == fileSize, "payload layout mismatch")
        return writer.data
    }

    /// Encodes and writes atomically, creating the parent directory when needed.
    static func write(splats: [UntoldGSSplat], options: UntoldGSWriteOptions = .init(), to url: URL) throws {
        let data = try write(splats: splats, options: options)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Ordering

    /// Indices of `splats` sorted by Morton key over `boundsMin...boundsMax`.
    static func mortonOrder(_ splats: [UntoldGSSplat], boundsMin: SIMD3<Float>, boundsMax: SIMD3<Float>) -> [Int] {
        let keys = splats.map { UntoldGSPacking.mortonKey($0.position, boundsMin: boundsMin, boundsMax: boundsMax) }
        return splats.indices.sorted { a, b in
            keys[a] != keys[b] ? keys[a] < keys[b] : a < b
        }
    }

    /// Bounds of the splat centres.
    static func bounds(of splats: [UntoldGSSplat]) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for splat in splats {
            minimum = simd_min(minimum, splat.position)
            maximum = simd_max(maximum, splat.position)
        }
        return (minimum, maximum)
    }

    /// Centre bounds expanded by each splat's largest scale, matching `computeGaussianSplatBoundingBox`.
    static func defaultBoundingBox(of splats: [UntoldGSSplat]) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for splat in splats {
            let extent = SIMD3<Float>(repeating: splat.scale.max())
            minimum = simd_min(minimum, splat.position - extent)
            maximum = simd_max(maximum, splat.position + extent)
        }
        return (minimum, maximum)
    }

    /// Opacity × summed pairwise scale products (proportional to surface area).
    internal static func importance(_ splat: UntoldGSSplat) -> Float {
        let s = splat.scale
        return splat.opacity * (s.x * s.y + s.y * s.z + s.z * s.x)
    }

    // MARK: - Chunk encoding

    internal struct EncodedChunk {
        var entry: UntoldGSChunkEntry
        var payload: Data
    }

    internal static func encodeChunk(_ splats: [UntoldGSSplat], shCount: Int) -> EncodedChunk {
        var aabbMin = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var aabbMax = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        var logScaleMin = Float.greatestFiniteMagnitude
        var logScaleMax = -Float.greatestFiniteMagnitude

        for splat in splats {
            aabbMin = simd_min(aabbMin, splat.position)
            aabbMax = simd_max(aabbMax, splat.position)
            for axis in 0 ..< 3 {
                let logScale = log(max(splat.scale[axis], Float.leastNormalMagnitude))
                logScaleMin = min(logScaleMin, logScale)
                logScaleMax = max(logScaleMax, logScale)
            }
        }

        let ranges = UntoldGSPacking.ChunkRanges(
            aabbMin: aabbMin, aabbMax: aabbMax, logScaleMin: logScaleMin, logScaleMax: logScaleMax
        )

        let coreWriter = UntoldBinaryWriter()
        for splat in splats {
            let record = UntoldGSPacking.encode(splat, ranges: ranges)
            coreWriter.writeUInt32LE(record.position)
            coreWriter.writeUInt32LE(record.rotation)
            coreWriter.writeUInt32LE(record.scale)
            coreWriter.writeUInt32LE(record.rgba)
        }
        if shCount > 0 {
            for splat in splats {
                for coefficient in splat.sphericalHarmonics {
                    coreWriter.writeUInt8(UntoldGSPacking.packSHCoefficient(coefficient))
                }
            }
        }

        let payload = coreWriter.data
        let entry = UntoldGSChunkEntry(
            payloadOffset: 0,
            payloadBytes: UInt32(alignedToPage(payload.count)),
            coreBytes: UInt32(splats.count * coreRecordSize),
            splatCount: UInt32(splats.count),
            lodLevel: 0,
            nodeId: 0,
            aabbMin: aabbMin,
            aabbMax: aabbMax,
            logScaleMin: logScaleMin,
            logScaleMax: logScaleMax,
            crc32: UntoldGSCRC32.checksum(payload)
        )
        return EncodedChunk(entry: entry, payload: payload)
    }

    // MARK: - Tree

    /// Binary tree over the chunk array by range halving, so every node's chunks are
    /// contiguous. Nodes are stored in preorder; leaves stamp `nodeId` on their chunks.
    internal static func buildTree(entries: inout [UntoldGSChunkEntry], leafMaxChunks: Int) throws -> [UntoldGSTreeNode] {
        var nodes: [UntoldGSTreeNode] = []

        func build(first: Int, count: Int) -> UInt32 {
            let nodeIndex = UInt32(nodes.count)
            var aabbMin = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
            var aabbMax = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
            for index in first ..< first + count {
                aabbMin = simd_min(aabbMin, entries[index].aabbMin)
                aabbMax = simd_max(aabbMax, entries[index].aabbMax)
            }
            nodes.append(UntoldGSTreeNode(aabbMin: aabbMin, aabbMax: aabbMax, firstChunk: UInt32(first), chunkCount: UInt32(count)))

            if count <= leafMaxChunks {
                for index in first ..< first + count {
                    entries[index].nodeId = UInt16(truncatingIfNeeded: nodeIndex)
                }
                return nodeIndex
            }
            let half = count / 2
            let child0 = build(first: first, count: half)
            let child1 = build(first: first + half, count: count - half)
            nodes[Int(nodeIndex)].child0 = child0
            nodes[Int(nodeIndex)].child1 = child1
            return nodeIndex
        }

        _ = build(first: 0, count: entries.count)
        guard nodes.count <= Int(UInt16.max) else {
            throw UntoldGSError.unsupported("tree with \(nodes.count) nodes exceeds \(UInt16.max)")
        }
        return nodes
    }
}

// MARK: - Importer conversion

/// Converts importer splats (plus their channel-major SH including the DC term) into
/// writer splats carrying only the higher-order SH coefficients. `keeping` selects and
/// orders the splats, as the progressive bake does.
func makeUntoldGSSplats(asset: GaussianSplatAsset, keeping indices: [Int]) -> [UntoldGSSplat] {
    let perChannel = asset.sphericalHarmonics?.coefficientsPerChannel ?? 1
    let perSplat = perChannel * 3
    let higherOrder = perChannel - 1
    var splats: [UntoldGSSplat] = []
    splats.reserveCapacity(indices.count)
    for index in indices {
        var coefficients: [Float] = []
        if let harmonics = asset.sphericalHarmonics, higherOrder > 0 {
            coefficients.reserveCapacity(higherOrder * 3)
            let base = index * perSplat
            for channel in 0 ..< 3 {
                let start = base + channel * perChannel + 1
                coefficients.append(contentsOf: harmonics.coefficients[start ..< start + higherOrder])
            }
        }
        splats.append(UntoldGSSplat(asset.splats[index], sphericalHarmonics: coefficients))
    }
    return splats
}

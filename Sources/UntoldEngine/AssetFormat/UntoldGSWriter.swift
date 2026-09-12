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
    /// Per-chunk coarse levels to bake into the optional section (`UntoldGSCoarsener`). With
    /// `coarseLevelsAutomatic` off, `nil` writes no section and a value always writes one.
    public var coarseLevels: UntoldGSCoarseLevelOptions?
    /// Bake `coarseLevels ?? .default` only when the tier has at least
    /// `UntoldGSFormat.coarseLevelsAutomaticMinimumChunks` chunks and its chunks are large enough
    /// for a level at all (`minimumChunkSplats`), with the ratios clamped to the chunk size, and
    /// write no section otherwise — so small assets bake exactly as they did before the section
    /// existed. Off, `coarseLevels` decides on its own.
    public var coarseLevelsAutomatic = true

    public init() {}
}

/// What `UntoldGSFormat.writeReporting` baked beyond the fine chunks.
public struct UntoldGSWriteReport: Sendable, Equatable {
    public var chunkCount: Int
    /// The coarse section, or nil when none was written.
    public var coarse: UntoldGSCoarseLevelReport?

    public init(chunkCount: Int, coarse: UntoldGSCoarseLevelReport? = nil) {
        self.chunkCount = chunkCount
        self.coarse = coarse
    }
}

public extension UntoldGSFormat {
    /// Encodes `splats` into a complete version-3 file image.
    static func write(splats: [UntoldGSSplat], options: UntoldGSWriteOptions = .init()) throws -> Data {
        try writeReporting(splats: splats, options: options).data
    }

    /// Encodes `splats` into a complete version-3 file image and reports what was baked.
    static func writeReporting(splats: [UntoldGSSplat], options: UntoldGSWriteOptions = .init()) throws -> (data: Data, report: UntoldGSWriteReport) {
        try writeReporting(splats: splats, options: options, serialCoarsening: false)
    }

    /// `writeReporting` with the chunk loop (encode and coarsening) optionally forced onto one
    /// thread (tests pin that the scheduling never changes a byte).
    internal static func writeReporting(splats: [UntoldGSSplat], options: UntoldGSWriteOptions, serialCoarsening: Bool) throws -> (data: Data, report: UntoldGSWriteReport) {
        let store = try makeStore(splats, options: options)
        let sink = UntoldGSMemorySink()
        let report = try writeStore(UntoldGSStoreView(store: store), options: options, sink: sink, serialChunks: serialCoarsening, progress: nil)
        return (sink.data, report)
    }

    /// Encodes and writes atomically, creating the parent directory when needed.
    static func write(splats: [UntoldGSSplat], options: UntoldGSWriteOptions = .init(), to url: URL) throws {
        _ = try writeReporting(splats: splats, options: options, to: url)
    }

    /// `write(splats:options:to:)` returning what was baked.
    static func writeReporting(splats: [UntoldGSSplat], options: UntoldGSWriteOptions = .init(), to url: URL) throws -> UntoldGSWriteReport {
        let store = try makeStore(splats, options: options)
        return try writeStore(UntoldGSStoreView(store: store), options: options, to: url, serialChunks: false, progress: nil)
    }

    // MARK: - Array input

    /// The store of an in-memory splat list, validated as the writer always validated its input:
    /// the SH count per splat, then every value finite (and the scale positive), in index order.
    internal static func makeStore(_ splats: [UntoldGSSplat], options: UntoldGSWriteOptions) throws -> UntoldGSSplatStore {
        guard !splats.isEmpty else { throw UntoldGSError.invalidInput("no splats to write") }
        guard options.shDegree <= maxSHDegree else {
            throw UntoldGSError.unsupported("spherical-harmonics degree \(options.shDegree)")
        }
        let shCount = shCoefficientCount(degree: options.shDegree)
        for (index, splat) in splats.enumerated() {
            guard splat.sphericalHarmonics.count == shCount else {
                throw UntoldGSError.invalidInput(
                    "splat \(index) carries \(splat.sphericalHarmonics.count) SH coefficients, expected \(shCount)"
                )
            }
            // One degenerate splat (a scale that overflowed through exp() on import, a NaN
            // colour) must fail the bake, not trap inside an integer conversion.
            guard splat.isFinite else {
                throw UntoldGSError.invalidInput("splat \(index) has non-finite data or a non-positive scale")
            }
        }
        var store = UntoldGSSplatStore(shDegree: options.shDegree)
        store.reserveCapacity(splats.count)
        var shBytes = [UInt8](repeating: 0, count: shCount)
        for splat in splats {
            for (slot, coefficient) in splat.sphericalHarmonics.enumerated() {
                shBytes[slot] = UntoldGSPacking.packSHCoefficient(coefficient)
            }
            store.append(splat, shBytes: shBytes)
        }
        return store
    }

    // MARK: - Store writer

    /// Writes a tier of a store to `url` through a temporary file in the same directory that is
    /// renamed over the destination when complete, so a failed or cancelled bake leaves nothing
    /// behind. Creates the parent directory when needed.
    internal static func writeStore(
        _ view: UntoldGSStoreView,
        options: UntoldGSWriteOptions,
        to url: URL,
        serialChunks: Bool = false,
        progress: UntoldGSCookProgressSink?
    ) throws -> UntoldGSWriteReport {
        let staged = try stageStore(view, options: options, to: url, serialChunks: serialChunks, progress: progress)
        do {
            try staged.publish()
        } catch {
            staged.discard()
            throw error
        }
        return staged.report
    }

    /// Writes a tier of a store, complete and closed, to a temporary file beside `url` without
    /// touching `url` itself: what a multi-tier bake does with each tier so it can rename the
    /// whole set into place only when the last one is written, and a failed or cancelled bake
    /// leaves the previous bake's tiers exactly as they were. Creates the parent directory when
    /// needed.
    internal static func stageStore(
        _ view: UntoldGSStoreView,
        options: UntoldGSWriteOptions,
        to url: URL,
        serialChunks: Bool = false,
        progress: UntoldGSCookProgressSink?
    ) throws -> UntoldGSStagedTier {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
        let sink = try UntoldGSFileSink(path: temporary.path)
        do {
            let report = try writeStore(view, options: options, sink: sink, serialChunks: serialChunks, progress: progress)
            try sink.close()
            return UntoldGSStagedTier(temporaryURL: temporary, url: url, report: report)
        } catch {
            sink.discard()
            throw error
        }
    }

    /// The writer: Morton order over the tier, chunks encoded and coarsened in parallel and
    /// written at their precomputed offsets, then the coarse section, the header, the chunk
    /// index and the tree. Every byte of the output is a function of the tier's splats and the
    /// options alone — the batch size, the thread count and the sink never change one.
    internal static func writeStore(
        _ view: UntoldGSStoreView,
        options: UntoldGSWriteOptions,
        sink: UntoldGSWriteSink,
        serialChunks: Bool,
        progress: UntoldGSCookProgressSink?
    ) throws -> UntoldGSWriteReport {
        let splatCount = view.count
        guard splatCount > 0 else { throw UntoldGSError.invalidInput("no splats to write") }
        guard options.shDegree <= maxSHDegree else {
            throw UntoldGSError.unsupported("spherical-harmonics degree \(options.shDegree)")
        }
        guard options.log2ChunkSplats >= 1, options.log2ChunkSplats <= maxLog2ChunkSplats else {
            throw UntoldGSError.unsupported("log2ChunkSplats \(options.log2ChunkSplats)")
        }
        let shCount = shCoefficientCount(degree: options.shDegree)
        guard view.store.shBytesPerSplat == shCount else {
            throw UntoldGSError.invalidInput(
                "splat 0 carries \(view.store.shBytesPerSplat) SH coefficients, expected \(shCount)"
            )
        }

        let splatsPerChunk = 1 << Int(options.log2ChunkSplats)
        let chunkCount = (splatCount + splatsPerChunk - 1) / splatsPerChunk

        // The coarse levels: automatic above the chunk-count threshold (the template's ratios
        // clamped to the chunk size), or exactly what was asked for.
        let coarseOptions: UntoldGSCoarseLevelOptions? = try {
            if options.coarseLevelsAutomatic {
                let template = options.coarseLevels ?? .default
                try template.validate(log2ChunkSplats: maxLog2ChunkSplats)
                // Below the chunk-count threshold, or with chunks too small for any chunk to
                // have a level, no section at all.
                guard chunkCount >= coarseLevelsAutomaticMinimumChunks, splatsPerChunk >= template.minimumChunkSplats else { return nil }
                let clamped = template.clamped(toLog2ChunkSplats: options.log2ChunkSplats)
                return clamped.levelCount > 0 ? clamped : nil
            }
            guard let requested = options.coarseLevels else { return nil }
            try requested.validate(log2ChunkSplats: options.log2ChunkSplats)
            return requested
        }()

        // Progress: with coarse levels the `chunk` phase is the ordering and the layout and the
        // chunk loop reports as `coarsen`; without them the loop is the rest of `chunk`, so the
        // ordering takes the first tenth and the fraction never runs backwards.
        let orderingShare = coarseOptions == nil ? 0.1 : 1.0
        progress?.setTierHasCoarseLevels(coarseOptions != nil)
        try progress?.report(.chunk, fraction: 0)
        let bounds = bounds(of: view)
        let order = mortonOrder(view, boundsMin: bounds.min, boundsMax: bounds.max)
        try progress?.report(.chunk, fraction: 0.5 * orderingShare)

        // The layout is fixed before a chunk is encoded: the tree's node count depends on the
        // chunk count alone, a chunk's padded payload on its splat count alone.
        let leafMaxChunks = max(1, options.leafMaxChunks)
        let headerSection = alignedToPage(headerSize)
        let chunkIndexOffset = headerSection
        let chunkIndexSection = alignedToPage(chunkCount * chunkEntrySize)
        let nodeTreeOffset = chunkIndexOffset + chunkIndexSection
        let nodeCount = treeNodeCount(chunkCount: chunkCount, leafMaxChunks: leafMaxChunks)
        let nodeTreeSection = alignedToPage(nodeCount * treeNodeSize)
        let payloadOffset = nodeTreeOffset + nodeTreeSection
        var cursor = payloadOffset
        let payloadOffsets: [Int] = (0 ..< chunkCount).map { chunk in
            let offset = cursor
            let count = min(splatsPerChunk, splatCount - chunk * splatsPerChunk)
            cursor += alignedToPage(count * (coreRecordSize + shCount))
            return offset
        }
        var fileSize = cursor

        // The writer's importance per splat, so the in-chunk sort compares the same values it
        // always compared without recomputing them per comparison.
        let importance = options.sortByImportanceWithinChunk ? importances(of: view) : []
        try progress?.report(.chunk, fraction: orderingShare)

        // The chunks: each work item sorts its chunk by importance, encodes the records and the
        // SH bytes into its own buffer, checksums them, writes them at the chunk's offset, and
        // coarsens the chunk in Morton order. Results land by chunk index whatever the
        // scheduling; the chunk's arithmetic is sequential in a fixed order.
        let loopPhase: UntoldGSCookPhase = coarseOptions == nil ? .chunk : .coarsen
        let loopFraction: (Int) -> Double = { done in
            let fraction = Double(done) / Double(chunkCount)
            return loopPhase == .chunk ? orderingShare + (1 - orderingShare) * fraction : fraction
        }
        let results = ChunkResults(count: chunkCount)
        let work: @Sendable (Int) -> Void = { chunk in
            do {
                let start = chunk * splatsPerChunk
                let end = min(start + splatsPerChunk, splatCount)
                let mortonOrdered = order[start ..< end].map { Int($0) }
                var ordered = mortonOrdered
                if options.sortByImportanceWithinChunk {
                    // The same `sort` call on the same sequence with the same comparisons as
                    // ever; the pointer only spares the shared array's reference count.
                    importance.withUnsafeBufferPointer { importance in
                        ordered.sort { importance[$0] > importance[$1] }
                    }
                }
                var encoded = encodeFineChunk(view, ordered: ordered, shCount: shCount)
                encoded.entry.payloadOffset = UInt64(payloadOffsets[chunk])
                try encoded.payload.withUnsafeBytes { bytes in
                    try sink.write(bytes, at: payloadOffsets[chunk])
                }
                var levels = UntoldGSCoarseLevels.none
                if let coarseOptions {
                    // The merge seeds on the Morton order of the chunk, not the importance
                    // order the fine payload took.
                    let gathered = view.withUnsafePointers { pointers in
                        mortonOrdered.map { pointers.splat(pointers.storeIndex($0)) }
                    }
                    levels = try UntoldGSCoarsener.coarsen(gathered, options: coarseOptions)
                }
                results.store(encoded.entry, levels: levels, at: chunk)
            } catch {
                // Kept as thrown — the coarsener's UntoldGSError, or the sink's POSIX error
                // (a full disk) — so the caller sees what happened, not "invalid input".
                results.fail(error, at: chunk)
            }
        }
        if serialChunks {
            for chunk in 0 ..< chunkCount {
                work(chunk)
                if let progress, chunk % 64 == 63 {
                    try progress.report(loopPhase, fraction: loopFraction(chunk + 1))
                }
            }
        } else {
            let batchSize = max(16, ProcessInfo.processInfo.activeProcessorCount * 4)
            var first = 0
            while first < chunkCount {
                let count = min(batchSize, chunkCount - first)
                let base = first
                DispatchQueue.concurrentPerform(iterations: count) { work(base + $0) }
                first += count
                if let failure = results.firstFailure {
                    throw failure
                }
                try progress?.report(loopPhase, fraction: loopFraction(first))
            }
        }
        var (entries, coarseLevels) = try results.take()
        try progress?.report(.write, fraction: 0)

        let nodes = try buildTree(entries: &entries, leafMaxChunks: leafMaxChunks)
        precondition(nodes.count == nodeCount, "tree layout mismatch")

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

        // The coarse section: the level-major index on the page after the last fine payload, the
        // records after it coarsest level first, each level in chunk order, 16-byte aligned.
        var coarseEntries: [UntoldGSChunkEntry] = []
        var coarsePayload = Data()
        var coarseIndexOffset = 0
        var coarsePayloadOffset = 0
        var coarseRecordCount = 0
        var coarseReport: UntoldGSCoarseLevelReport?
        if let coarseOptions {
            let levelCount = coarseOptions.levelCount
            coarseIndexOffset = alignedToPage(cursor)
            coarsePayloadOffset = coarseIndexOffset + alignedToPage(levelCount * entries.count * coarseIndexEntrySize)
            coarseEntries = [UntoldGSChunkEntry](repeating: UntoldGSChunkEntry.emptyCoarse(level: 0, chunk: 0, nodeId: 0), count: levelCount * entries.count)
            var recordsPerLevel = [Int](repeating: 0, count: levelCount)
            var chunksWithoutLevels = 0
            cursor = coarsePayloadOffset
            for level in stride(from: levelCount, through: 1, by: -1) {
                for chunk in entries.indices {
                    let merged = coarseLevels[chunk].level(level)
                    let slot = (level - 1) * entries.count + chunk
                    if level == 1, merged.isEmpty {
                        chunksWithoutLevels += 1
                    }
                    guard !merged.isEmpty else {
                        coarseEntries[slot] = .emptyCoarse(level: UInt16(level), chunk: UInt32(chunk), nodeId: entries[chunk].nodeId)
                        continue
                    }
                    let encoded = encodeChunk(orderedByImportance(merged), shCount: 0, padToPage: false)
                    var entry = encoded.entry
                    entry.payloadOffset = UInt64(cursor)
                    entry.lodLevel = UInt16(level)
                    entry.nodeId = entries[chunk].nodeId
                    entry.reserved0 = UInt32(chunk)
                    coarseEntries[slot] = entry
                    coarsePayload.append(encoded.payload)
                    cursor += encoded.payload.count
                    recordsPerLevel[level - 1] += merged.count
                    coarseRecordCount += merged.count
                }
            }
            coarseLevels = []
            fileSize = alignedToPage(cursor)
            flags |= UntoldGSFlags.hasCoarseLevels
            coarseReport = UntoldGSCoarseLevelReport(
                levelCount: levelCount,
                ratioLog2: Array(coarseOptions.ratioLog2.prefix(levelCount)),
                recordsPerLevel: recordsPerLevel,
                bytes: fileSize - coarseIndexOffset,
                chunksWithoutLevels: chunksWithoutLevels
            )
        }

        // Only scanned when the caller did not supply a box (the bake always does).
        let boundingBox = (options.boundingBoxMin == nil || options.boundingBoxMax == nil)
            ? defaultBoundingBox(of: view)
            : (min: options.boundingBoxMin!, max: options.boundingBoxMax!)
        let header = UntoldGSHeaderV3(
            flags: flags,
            shDegree: options.shDegree,
            coordinateSystem: options.coordinateSystem,
            colorSpace: options.colorSpace,
            log2ChunkSplats: options.log2ChunkSplats,
            splatCount: UInt32(splatCount),
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
            fileSize: UInt64(fileSize),
            coarseIndexOffset: UInt64(coarseIndexOffset),
            coarsePayloadOffset: UInt64(coarsePayloadOffset),
            coarseRecordCount: UInt32(coarseRecordCount),
            coarseLevelCount: UInt8(coarseOptions?.levelCount ?? 0),
            coarseRatioLog2: coarseOptions.map { Array($0.ratioLog2.prefix($0.levelCount)) } ?? [0, 0]
        )

        // The sections around the payloads, each at its offset; the padding between them and
        // after the last is the zero the sink guarantees for bytes never written.
        let headerWriter = UntoldBinaryWriter()
        header.encode(to: headerWriter)
        try sink.write(headerWriter.data, at: 0)
        let indexWriter = UntoldBinaryWriter()
        for entry in entries {
            entry.encode(to: indexWriter)
        }
        try sink.write(indexWriter.data, at: chunkIndexOffset)
        let treeWriter = UntoldBinaryWriter()
        for node in nodes {
            node.encode(to: treeWriter)
        }
        try sink.write(treeWriter.data, at: nodeTreeOffset)
        if coarseOptions != nil {
            let coarseIndexWriter = UntoldBinaryWriter()
            for entry in coarseEntries {
                entry.encode(to: coarseIndexWriter)
            }
            try sink.write(coarseIndexWriter.data, at: coarseIndexOffset)
            try sink.write(coarsePayload, at: coarsePayloadOffset)
            precondition(coarsePayloadOffset + coarsePayload.count <= fileSize, "coarse payload layout mismatch")
        }
        try sink.finish(fileSize: fileSize)
        try progress?.report(.write, fraction: 1)
        return UntoldGSWriteReport(chunkCount: entries.count, coarse: coarseReport)
    }

    /// The per-chunk results of the chunk loop, filled from `concurrentPerform` under one lock
    /// (one store per chunk, so the lock is never contended for long). A chunk's failure is kept
    /// as the error it threw.
    private final class ChunkResults: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [UntoldGSChunkEntry?]
        private var levels: [UntoldGSCoarseLevels]
        private var failures: [(any Error)?]

        init(count: Int) {
            entries = [UntoldGSChunkEntry?](repeating: nil, count: count)
            levels = [UntoldGSCoarseLevels](repeating: .none, count: count)
            failures = [(any Error)?](repeating: nil, count: count)
        }

        func store(_ entry: UntoldGSChunkEntry, levels chunkLevels: UntoldGSCoarseLevels, at chunk: Int) {
            lock.withLock {
                entries[chunk] = entry
                levels[chunk] = chunkLevels
            }
        }

        func fail(_ error: any Error, at chunk: Int) {
            lock.withLock { failures[chunk] = error }
        }

        /// The first chunk's failure, in chunk order.
        var firstFailure: (any Error)? {
            lock.withLock { failures.compactMap { $0 }.first }
        }

        /// The entries and levels by chunk index, or the first chunk's failure.
        func take() throws -> ([UntoldGSChunkEntry], [UntoldGSCoarseLevels]) {
            try lock.withLock {
                if let failure = failures.compactMap({ $0 }).first {
                    throw failure
                }
                let taken = entries.map { $0! }
                let levels = self.levels
                entries = []
                self.levels = []
                return (taken, levels)
            }
        }
    }

    /// Nodes `buildTree` makes over `chunkCount` chunks: the shape depends on the counts alone.
    internal static func treeNodeCount(chunkCount: Int, leafMaxChunks: Int) -> Int {
        func count(_ n: Int) -> Int {
            n <= leafMaxChunks ? 1 : 1 + count(n / 2) + count(n - n / 2)
        }
        return count(chunkCount)
    }

    /// The rank order of a coarse level: importance descending, ties by index.
    internal static func orderedByImportance(_ splats: [UntoldGSSplat]) -> [UntoldGSSplat] {
        UntoldGSCoarsener.orderedByImportance(splats)
    }

    // MARK: - Ordering

    /// Indices of `splats` sorted by Morton key over `boundsMin...boundsMax`.
    static func mortonOrder(_ splats: [UntoldGSSplat], boundsMin: SIMD3<Float>, boundsMax: SIMD3<Float>) -> [Int] {
        let keys = splats.map { UntoldGSPacking.mortonKey($0.position, boundsMin: boundsMin, boundsMax: boundsMax) }
        return splats.indices.sorted { a, b in
            keys[a] != keys[b] ? keys[a] < keys[b] : a < b
        }
    }

    /// Positions of `view` sorted by Morton key over `boundsMin...boundsMax`, ties by position —
    /// the same permutation `mortonOrder(_:boundsMin:boundsMax:)` gives (the order is total), from
    /// keys computed in parallel and a stable radix sort.
    internal static func mortonOrder(_ view: UntoldGSStoreView, boundsMin: SIMD3<Float>, boundsMax: SIMD3<Float>) -> [UInt32] {
        let count = view.count
        let keys = UnsafeSharedBuffer<UInt64>(count: count)
        let slice = 1 << 16
        DispatchQueue.concurrentPerform(iterations: (count + slice - 1) / slice) { part in
            let start = part * slice
            view.withUnsafePointers { pointers in
                for index in start ..< min(start + slice, count) {
                    let position = pointers.position(pointers.storeIndex(index))
                    keys[index] = UntoldGSPacking.mortonKey(position, boundsMin: boundsMin, boundsMax: boundsMax)
                }
            }
        }
        return sortedByKeyThenIndex(keys)
    }

    /// Indices `0 ..< keys.count` ordered by `(key, index)`: a least-significant-digit radix sort
    /// in 16-bit digits, stable, so equal keys keep ascending indices.
    private static func sortedByKeyThenIndex(_ keys: UnsafeSharedBuffer<UInt64>) -> [UInt32] {
        let count = keys.count
        guard count > 1 else { return count == 1 ? [0] : [] }
        var maxKey: UInt64 = 0
        for index in 0 ..< count {
            maxKey = max(maxKey, keys[index])
        }
        var sourceKeys = keys
        var sourceIndices = UnsafeSharedBuffer<UInt32>(count: count)
        for index in 0 ..< count {
            sourceIndices[index] = UInt32(index)
        }
        var targetKeys = UnsafeSharedBuffer<UInt64>(count: count)
        var targetIndices = UnsafeSharedBuffer<UInt32>(count: count)
        var histogram = [Int](repeating: 0, count: 1 << 16)
        var shift = 0
        while shift < 64, maxKey >> UInt64(shift) != 0 {
            for digit in 0 ..< histogram.count {
                histogram[digit] = 0
            }
            for index in 0 ..< count {
                histogram[Int((sourceKeys[index] >> UInt64(shift)) & 0xFFFF)] += 1
            }
            var running = 0
            for digit in 0 ..< histogram.count {
                let n = histogram[digit]
                histogram[digit] = running
                running += n
            }
            for index in 0 ..< count {
                let key = sourceKeys[index]
                let digit = Int((key >> UInt64(shift)) & 0xFFFF)
                let target = histogram[digit]
                histogram[digit] = target + 1
                targetKeys[target] = key
                targetIndices[target] = sourceIndices[index]
            }
            swap(&sourceKeys, &targetKeys)
            swap(&sourceIndices, &targetIndices)
            shift += 16
        }
        return [UInt32](unsafeUninitializedCapacity: count) { buffer, initialized in
            for index in 0 ..< count {
                buffer[index] = sourceIndices[index]
            }
            initialized = count
        }
    }

    /// `importance` of every position of `view`.
    private static func importances(of view: UntoldGSStoreView) -> [Float] {
        let count = view.count
        return view.withUnsafePointers { pointers in
            [Float](unsafeUninitializedCapacity: count) { buffer, initialized in
                for index in 0 ..< count {
                    buffer[index] = pointers.writerImportance(pointers.storeIndex(index))
                }
                initialized = count
            }
        }
    }

    /// Bounds of the tier's centres.
    internal static func bounds(of view: UntoldGSStoreView) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        view.withUnsafePointers { pointers in
            for index in 0 ..< view.count {
                let position = pointers.position(pointers.storeIndex(index))
                minimum = simd_min(minimum, position)
                maximum = simd_max(maximum, position)
            }
        }
        return (minimum, maximum)
    }

    /// `defaultBoundingBox(of:)` over a tier.
    internal static func defaultBoundingBox(of view: UntoldGSStoreView) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        let store = view.store
        return expandedBoundingBox(count: view.count, position: { view.position($0) }, radius: { store.scale(view.storeIndex($0)).max() })
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

    /// Centre bounds expanded by each splat's largest scale (`computeGaussianSplatBoundingBox`
    /// applies the same rule to importer splats through `expandedBoundingBox`).
    static func defaultBoundingBox(of splats: [UntoldGSSplat]) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        expandedBoundingBox(count: splats.count, position: { splats[$0].position }, radius: { splats[$0].scale.max() })
    }

    /// Bounds of `count` centres, each grown by its radius: the box a splat visually extends
    /// to, rather than a centres-only box. Empty input gives the empty (inverted) box.
    static func expandedBoundingBox(
        count: Int,
        position: (Int) -> SIMD3<Float>,
        radius: (Int) -> Float
    ) -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for index in 0 ..< count {
            let extent = SIMD3<Float>(repeating: radius(index))
            let center = position(index)
            minimum = simd_min(minimum, center - extent)
            maximum = simd_max(maximum, center + extent)
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

    /// One fine chunk's entry and unpadded payload — `ordered` the tier positions in the order
    /// the records take — straight from the store: the same ranges, records, SH bytes and CRC
    /// `encodeChunk` produces for the same splats, written into one buffer with no per-word
    /// appends. `payloadBytes` is padded to the page, as for every fine chunk.
    internal static func encodeFineChunk(_ view: UntoldGSStoreView, ordered: [Int], shCount: Int) -> (entry: UntoldGSChunkEntry, payload: [UInt8]) {
        var aabbMin = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var aabbMax = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        var logScaleMin = Float.greatestFiniteMagnitude
        var logScaleMax = -Float.greatestFiniteMagnitude
        let count = ordered.count
        let coreBytes = count * coreRecordSize
        var payload = [UInt8](repeating: 0, count: coreBytes + count * shCount)
        var crc = UntoldGSCRC32.initialValue

        // Counted loops over raw pointers: this runs once per splat on every thread, and a debug
        // build's generic array iteration would cost more than the encoding itself.
        view.withUnsafePointers { pointers in
            ordered.withUnsafeBufferPointer { ordered in
                var slot = 0
                while slot < count {
                    let index = pointers.storeIndex(ordered[slot])
                    aabbMin = simd_min(aabbMin, pointers.position(index))
                    aabbMax = simd_max(aabbMax, pointers.position(index))
                    let scale = pointers.scale(index)
                    var axis = 0
                    while axis < 3 {
                        let logScale = log(max(scale[axis], Float.leastNormalMagnitude))
                        logScaleMin = min(logScaleMin, logScale)
                        logScaleMax = max(logScaleMax, logScale)
                        axis += 1
                    }
                    slot += 1
                }

                let ranges = UntoldGSPacking.ChunkRanges(
                    aabbMin: aabbMin, aabbMax: aabbMax, logScaleMin: logScaleMin, logScaleMax: logScaleMax
                )
                payload.withUnsafeMutableBytes { raw in
                    var offset = 0
                    slot = 0
                    while slot < count {
                        let record = UntoldGSPacking.encode(pointers.splat(pointers.storeIndex(ordered[slot])), ranges: ranges)
                        raw.storeBytes(of: record.position.littleEndian, toByteOffset: offset, as: UInt32.self)
                        raw.storeBytes(of: record.rotation.littleEndian, toByteOffset: offset + 4, as: UInt32.self)
                        raw.storeBytes(of: record.scale.littleEndian, toByteOffset: offset + 8, as: UInt32.self)
                        raw.storeBytes(of: record.rgba.littleEndian, toByteOffset: offset + 12, as: UInt32.self)
                        offset += coreRecordSize
                        slot += 1
                    }
                    if shCount > 0, let sh = pointers.sh.baseAddress {
                        slot = 0
                        while slot < count {
                            let start = pointers.storeIndex(ordered[slot]) * shCount
                            raw.baseAddress!.advanced(by: offset).copyMemory(from: sh.advanced(by: start), byteCount: shCount)
                            offset += shCount
                            slot += 1
                        }
                    }
                    UntoldGSCRC32.update(&crc, UnsafeRawBufferPointer(raw))
                }
            }
        }
        let entry = UntoldGSChunkEntry(
            payloadOffset: 0,
            payloadBytes: UInt32(alignedToPage(payload.count)),
            coreBytes: UInt32(coreBytes),
            splatCount: UInt32(count),
            lodLevel: 0,
            nodeId: 0,
            aabbMin: aabbMin,
            aabbMax: aabbMax,
            logScaleMin: logScaleMin,
            logScaleMax: logScaleMax,
            crc32: UntoldGSCRC32.finalize(crc)
        )
        return (entry, payload)
    }

    /// Encodes one chunk (or one coarse level of a chunk) against its own ranges. A fine chunk's
    /// `payloadBytes` is padded to the page; a coarse level's (`padToPage == false`) is the
    /// unpadded core size, the levels being packed 16-byte aligned inside their own region.
    internal static func encodeChunk(_ splats: [UntoldGSSplat], shCount: Int, padToPage: Bool = true) -> EncodedChunk {
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
            payloadBytes: UInt32(padToPage ? alignedToPage(payload.count) : payload.count),
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

extension UntoldGSChunkEntry {
    /// The coarse index entry of a chunk that has no records at `level`: zero sizes and ranges,
    /// labelled with its level and chunk so the index stays self-describing.
    static func emptyCoarse(level: UInt16, chunk: UInt32, nodeId: UInt16) -> UntoldGSChunkEntry {
        UntoldGSChunkEntry(
            payloadOffset: 0, payloadBytes: 0, coreBytes: 0, splatCount: 0,
            lodLevel: level, nodeId: nodeId,
            aabbMin: .zero, aabbMax: .zero, logScaleMin: 0, logScaleMax: 0,
            reserved0: chunk, crc32: 0
        )
    }
}

// MARK: - Sinks

/// Where the writer puts its bytes: a file or memory. Writes may arrive from several threads at
/// once at disjoint offsets; bytes never written read as zero (the padding between sections).
protocol UntoldGSWriteSink: Sendable {
    func write(_ bytes: UnsafeRawBufferPointer, at offset: Int) throws
    /// Called once at the end with the file's exact size.
    func finish(fileSize: Int) throws
}

extension UntoldGSWriteSink {
    func write(_ data: Data, at offset: Int) throws {
        try data.withUnsafeBytes { try write($0, at: offset) }
    }
}

/// A whole-file image in memory, grown as sections arrive.
final class UntoldGSMemorySink: UntoldGSWriteSink, @unchecked Sendable {
    private let lock = NSLock()
    private var bytes: [UInt8] = []

    init() {}

    func write(_ source: UnsafeRawBufferPointer, at offset: Int) throws {
        guard let base = source.baseAddress, source.count > 0 else { return }
        lock.withLock {
            let end = offset + source.count
            if bytes.count < end {
                bytes.append(contentsOf: repeatElement(0, count: end - bytes.count))
            }
            bytes.withUnsafeMutableBytes { raw in
                raw.baseAddress!.advanced(by: offset).copyMemory(from: base, byteCount: source.count)
            }
        }
    }

    func finish(fileSize: Int) throws {
        lock.withLock {
            if bytes.count < fileSize {
                bytes.append(contentsOf: repeatElement(0, count: fileSize - bytes.count))
            } else if bytes.count > fileSize {
                bytes.removeLast(bytes.count - fileSize)
            }
        }
    }

    var data: Data {
        lock.withLock { Data(bytes) }
    }
}

/// A tier written whole to its temporary file and not yet renamed over its destination.
struct UntoldGSStagedTier {
    let temporaryURL: URL
    /// The destination.
    let url: URL
    let report: UntoldGSWriteReport

    /// Renames the temporary over `url`, replacing whatever was there.
    func publish() throws {
        guard rename(temporaryURL.path, url.path) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: url.path])
        }
    }

    /// Removes the temporary, leaving `url` as it was. Nothing to do once published.
    func discard() {
        unlink(temporaryURL.path)
    }
}

/// A file written with `pwrite` at absolute offsets; holes read as zero, `finish` sets the size.
final class UntoldGSFileSink: UntoldGSWriteSink, @unchecked Sendable {
    let path: String
    private var descriptor: Int32

    /// Creates the file (it must not exist yet).
    init(path: String) throws {
        self.path = path
        descriptor = open(path, O_CREAT | O_EXCL | O_RDWR, 0o644)
        guard descriptor >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: path])
        }
    }

    deinit {
        if descriptor >= 0 {
            Darwin.close(descriptor)
        }
    }

    func write(_ bytes: UnsafeRawBufferPointer, at offset: Int) throws {
        guard let base = bytes.baseAddress, bytes.count > 0 else { return }
        var done = 0
        while done < bytes.count {
            let written = pwrite(descriptor, base.advanced(by: done), bytes.count - done, off_t(offset + done))
            if written < 0 {
                if errno == EINTR { continue }
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: path])
            }
            done += written
        }
    }

    func finish(fileSize: Int) throws {
        guard ftruncate(descriptor, off_t(fileSize)) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: path])
        }
    }

    /// Closes the file, keeping it.
    func close() throws {
        guard descriptor >= 0 else { return }
        let result = Darwin.close(descriptor)
        descriptor = -1
        guard result == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: path])
        }
    }

    /// Closes and deletes the file: what a failed or cancelled bake does with its temporary.
    func discard() {
        if descriptor >= 0 {
            Darwin.close(descriptor)
            descriptor = -1
        }
        unlink(path)
    }
}

/// A fixed-size zeroed buffer several threads fill at disjoint indices, owned for the writer's
/// pass. Mapped straight from the kernel rather than malloc'd: the sort's scratch is a quarter
/// of a gigabyte for a 10 M-splat tier, and malloc would keep that much freed memory cached —
/// dirty, in the footprint — for the rest of the bake, where `munmap` gives it back at once.
final class UnsafeSharedBuffer<Element: FixedWidthInteger>: @unchecked Sendable {
    let count: Int
    private let base: UnsafeMutablePointer<Element>
    private let byteCount: Int

    init(count: Int) {
        self.count = count
        byteCount = max(1, count) * MemoryLayout<Element>.stride
        let mapped = mmap(nil, byteCount, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0)
        precondition(mapped != nil && mapped != MAP_FAILED, "cannot map \(byteCount) bytes for the writer")
        base = mapped!.bindMemory(to: Element.self, capacity: max(1, count))
    }

    deinit {
        munmap(UnsafeMutableRawPointer(base), byteCount)
    }

    @inline(__always)
    subscript(index: Int) -> Element {
        get { base[index] }
        set { base[index] = newValue }
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

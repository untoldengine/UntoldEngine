//
//  GaussianChunkLoader.swift
//  UntoldEngine
//
//  Loads a version-3 `.untoldgs` file for rendering. Below the paging threshold
//  (`GaussianPagingPolicy`) it reads every chunk by byte range (CRC-verified) into
//  the packed buffer that stays resident — the 16-byte core records the fused
//  per-chunk pass (`gaussianChunkDecodePreprocess`) decodes every frame — binds the
//  SH bytes as they are (the file already stores the renderer's byte contract), and
//  keeps the chunk table (`GaussianChunkTable`) so the frame can cull chunk by
//  chunk. Above the threshold the records live in a bounded page pool of 256-rank
//  tiers instead: the packed buffer is the pool, the chunk table carries the
//  per-slot residency, page and demand tables, nothing is read at load, and a
//  `GaussianPageManager` fills the pool from the cull's demand frame by frame. The
//  file is never read whole and no CPU decode runs. `decodeEncodedSplats` expands
//  a whole-resident load's records once into the `EncodedGaussianSplat` layout with
//  the `gaussianDecodeChunks` kernel, for the whole-buffer path (when the per-chunk
//  kernels are unavailable) and for tests.
//
//  A file that carries per-chunk coarse levels (per-chunk-lod-tiers, `UntoldGSIndex.coarse`)
//  gets a `GaussianCoarseTable` on both chunked paths when the levels fit their share of the
//  residency budget (`GaussianPagingPolicy.coarseResidentLevels`: both levels, else the
//  coarsest alone, else none — logged, the entity then draws fine only as before): the
//  levels' own decode constants, a records buffer holding the section's payload region as
//  stored, outside the page pool, and the persistent per-chunk level state. A whole-resident
//  entity reads and CRC-checks the region at load; a paged one hands the pager the region to
//  stream through its read queue, coarsest level first, marking each chunk's levels available
//  as their pieces land and verify.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import Metal
import simd

/// The chunk table of a `.untoldgs` asset as the renderer keeps it after the load: the
/// per-chunk decode constants (`GaussianChunkDecodeConstants`, 48 bytes per chunk — centre
/// AABB, log-scale range, first splat and count) GPU-resident for the chunk-level cull
/// (`gaussianChunkCull`), the file's index on the CPU (the pager's byte ranges and CRCs, the
/// tests), and for a paged entity the per-slot tables the pager writes.
struct GaussianChunkTable {
    /// `GaussianChunkDecodeConstants × chunkCount`, in chunk order; `firstSplat` runs
    /// contiguously so chunk `i` owns splats `firstSplat ..< firstSplat + splatCount` of the
    /// packed buffer (and of the SH buffer) — of a whole-resident entity; a paged entity's
    /// fused pass maps ranks through the page table instead and never reads it.
    let constantsBuffer: MTLBuffer
    let chunkCount: Int
    /// `1 << header.log2ChunkSplats`: the most splats any chunk holds, the threadgroup width
    /// of the per-chunk passes.
    let splatsPerChunk: Int
    let index: UntoldGSIndex
    /// Per in-flight frame slot, written by `gaussianChunkCull` and `gaussianComputeChunkQuotas`
    /// and read by the fused pass the same frame: the visible-chunk list
    /// (`GaussianVisibleChunk × chunkCount`) and its `GaussianVisibleSet`-shaped record.
    /// Allocated by `buildGaussianLoadResult` (`allocateGaussianVisibleChunkBuffers`).
    var visibleChunks: [MTLBuffer] = []
    var visibleChunkSets: [MTLBuffer] = []
    /// A paged entity's per-slot tables (`GaussianPageManager`): the residency
    /// (`GaussianChunkResidency × chunkCount`), the page table (`uint × chunkCount ×
    /// pagesPerChunk`) and the demand words (`uint × chunkCount`); empty for a whole-resident
    /// entity.
    var residencyTables: [MTLBuffer] = []
    var pageTables: [MTLBuffer] = []
    var demandTables: [MTLBuffer] = []
    /// Tiers per chunk and log2 of the ranks per tier of a paged entity (1 and 0 otherwise).
    var pagesPerChunk = 1
    var ranksPerPageLog2 = 0
    /// The entity's per-chunk coarse levels (per-chunk-lod-tiers); nil when the file has none or
    /// they did not fit beside the pool — every kernel then takes the paths without levels.
    var coarse: GaussianCoarseTable?
    /// Frames the driver has encoded for a whole-resident entity with coarse levels: the clock its
    /// level cross-fades count on (`GaussianChunkLevelConstants.frameIndex`; a paged entity's is
    /// its pager's tick). Incremented once per frame by `executeGaussianFrustumCulling` before
    /// the entity's constants are built, so the cull, the quota pass and the fused pass of one
    /// frame read one value.
    var executedFrames: UInt32 = 0

    var hasCoarse: Bool {
        coarse != nil
    }

    var gpuBytes: Int {
        constantsBuffer.length
            + visibleChunks.reduce(0) { $0 + $1.length }
            + visibleChunkSets.reduce(0) { $0 + $1.length }
            + residencyTables.reduce(0) { $0 + $1.length }
            + pageTables.reduce(0) { $0 + $1.length }
            + demandTables.reduce(0) { $0 + $1.length }
            + (coarse?.gpuBytes ?? 0)
    }

    /// The coarse index entry the runtime's level `level` (1-based) of `chunk` draws, or nil when
    /// the level is not resident or the chunk has none at it.
    func coarseEntry(runtimeLevel level: Int, chunk: Int) -> UntoldGSChunkEntry? {
        guard let coarse, level >= 1, level <= coarse.levelCount else { return nil }
        return index.coarseEntry(level: coarse.fileLevels[level - 1], chunk: chunk)
    }
}

/// The per-chunk coarse levels of a `.untoldgs` entity as the renderer keeps them
/// (per-chunk-lod-tiers): the runtime's level 1 is the file's finest *resident* level, so with
/// both levels resident (`levelCount` 2) the runtime's 1 and 2 are the file's 1 and 2, and with
/// the coarsest alone (1, the fit check's fallback) the runtime's level 1 is the file's level 2
/// with that level's ratio for its tier shift.
struct GaussianCoarseTable {
    /// Resident runtime levels, 1 or 2.
    let levelCount: Int
    /// The file level (1 or 2) each runtime level draws, finest first: `[1, 2]`, or `[2]`.
    let fileLevels: [Int]
    /// The file's `coarseRatioLog2` of each runtime level, for the tier shifts.
    let ratioLog2: [UInt8]
    /// `GaussianChunkDecodeConstants × levelCount × chunkCount`, level-major (the runtime's level
    /// 1 rows first): the level's own centre AABB and log-scale range, `firstSplat` the index of
    /// its first record in `recordsBuffer`, `splatCount` its count (0 where the chunk has no
    /// level).
    let constantsBuffer: MTLBuffer
    /// The section's payload region as stored — `uint4` records, the coarsest level first, each
    /// level in chunk order — over the file bytes `recordsRange`; outside the page pool. Zeroed
    /// at load for a paged entity and filled by the pager's pieces.
    let recordsBuffer: MTLBuffer
    /// `GaussianChunkLevelState × chunkCount`, persistent, zero (fine, nothing fading) at load;
    /// written only by `gaussianComputeChunkQuotas`.
    let levelStateBuffer: MTLBuffer
    /// The file range `recordsBuffer` holds: from the coarsest resident level's first record to
    /// the finest resident level's last.
    let recordsRange: Range<UInt64>
    /// The entity's claim on the coarse share of the residency budget
    /// (`GaussianPagePoolRegistry.coarseBytes`), given back when the table is dropped.
    let claim: GaussianCoarseClaim?

    var recordBytes: Int {
        recordsBuffer.length
    }

    /// The coarse records resident: what the levels can add to a frame beside the fine ranks.
    var recordCount: Int {
        recordsBuffer.length / UntoldGSFormat.coreRecordSize
    }

    var gpuBytes: Int {
        constantsBuffer.length + recordsBuffer.length + levelStateBuffer.length
    }

    /// The buffers the three per-chunk kernels bind.
    var levelBuffers: GaussianChunkLevelBuffers {
        GaussianChunkLevelBuffers(coarseTable: constantsBuffer, coarseRecords: recordsBuffer, levelState: levelStateBuffer)
    }

    /// The tier shifts of the runtime's two levels (`GaussianChunkLevelConstants.tierShift1/2`;
    /// equal when one level is resident).
    var tierShifts: (Int, Int) {
        let first = GaussianChunkCullMath.tierShift(ratioLog2: ratioLog2[0])
        let second = GaussianChunkCullMath.tierShift(ratioLog2: ratioLog2[min(1, ratioLog2.count - 1)])
        return (first, second)
    }
}

/// GPU-resident result of loading a `.untoldgs` file.
struct GaussianChunkLoadResult {
    let splatCount: Int
    /// The file's 16-byte core records, contiguous in chunk order (`uint4` per splat) — or,
    /// for a paged load, the core page pool the pager fills.
    let packedSplatBuffer: MTLBuffer
    /// The harmonics as stored — or the harmonics page pool, in the core pool's slot layout.
    let sphericalHarmonicsBuffer: MTLBuffer?
    let sphericalHarmonicsMetadata: GaussianSHMetadata?
    let meanSquaredSplatExtent: Float
    /// Capture exposure (EV) and white balance the cook recorded in the header.
    let captureExposureEV: Float
    let captureWhiteBalance: SIMD3<Float>
    let boundingBox: (min: simd_float3, max: simd_float3)
    /// Chunk index of the file, kept for callers that want to page later.
    let index: UntoldGSIndex
    /// The same index's decode constants, GPU-resident, for the chunk-level cull.
    let chunkTable: GaussianChunkTable
    /// The pager of a paged load; nil when every record is resident.
    var pager: GaussianPageManager?

    /// Whether the records live in a page pool.
    var isPaged: Bool {
        pager != nil
    }
}

enum GaussianChunkLoadError: Error, CustomStringConvertible {
    case decodePipelineUnavailable
    case deviceUnavailable
    case tooManySplats(Int)
    case bufferAllocationFailed(String)
    case gpuDecodeFailed(String)
    /// `decodeEncodedSplats` of a paged load: the pool holds only what the frames asked for.
    case pagedAssetCannotBeExpanded
    /// The coarse section could not be read whole at load (a whole-resident entity).
    case coarseReadFailed(String)

    var description: String {
        switch self {
        case .decodePipelineUnavailable: "the Gaussian decode compute pipeline is not available"
        case .deviceUnavailable: "no Metal device or command queue"
        case let .tooManySplats(count): "too many Gaussian splats: \(count) exceeds maximum \(maxNumOfGaussians)"
        case let .bufferAllocationFailed(what): "failed to allocate \(what)"
        case let .gpuDecodeFailed(reason): "GPU decode failed: \(reason)"
        case .pagedAssetCannotBeExpanded: "a paged Gaussian asset cannot be expanded into the whole-buffer layout"
        case let .coarseReadFailed(reason): "the coarse levels could not be read: \(reason)"
        }
    }
}

enum GaussianChunkLoader {
    /// True when the decode kernel compiled, so `.untoldgs` files can take the GPU path.
    static var isAvailable: Bool {
        gaussianDecodePipeline.success && gaussianDecodePipeline.pipelineState != nil
    }

    /// Reads `url` into GPU buffers. Synchronous: the caller is already off the render thread
    /// on the async and streaming paths, and the synchronous `setEntityGaussian` blocks by
    /// contract. Nothing runs on the GPU here; the records are decoded by the frame. With
    /// `allowPaging` (the caller has the per-chunk kernels) an asset above the paging
    /// threshold gets a page pool and a pager instead of resident records; the whole-resident
    /// load is unchanged below it.
    static func load(url: URL, allowPaging: Bool = false) throws -> GaussianChunkLoadResult {
        guard let device = renderInfo.device else {
            throw GaussianChunkLoadError.deviceUnavailable
        }
        guard isAvailable else {
            throw GaussianChunkLoadError.decodePipelineUnavailable
        }

        let source = try GaussianPageSourceFactory.make(url)
        let index = source.index
        let header = index.header
        let splatCount = Int(header.splatCount)
        guard splatCount <= Int(maxNumOfGaussians) else {
            source.close()
            throw GaussianChunkLoadError.tooManySplats(splatCount)
        }
        let shBytesPerSplat = header.shBytesPerSplat

        let assetBytes = GaussianPagingPolicy.assetBytes(splatCount: splatCount, shBytesPerSplat: shBytesPerSplat)
        let residencyBudget = GaussianPagingPolicy.residencyBudgetBytes()
        let pages = GaussianPagingPolicy.shouldPage(
            assetBytes: assetBytes,
            thresholdBytes: GaussianPagingPolicy.pagingThresholdBytes(residencyBudgetBytes: residencyBudget),
            allowPaging: allowPaging,
            disablePaging: GaussianDebugOptions.shared.disablePaging
        )
        if pages {
            return try loadPaged(source: source, url: url, device: device, residencyBudgetBytes: residencyBudget)
        }
        // Whole resident: the source served the index; the records come through UntoldGSFile.
        source.close()
        let file = try UntoldGSFile(url: url)

        // Packed records for every chunk, contiguous, in chunk order: the resident splat data.
        guard let packedBuffer = device.makeBuffer(length: splatCount * UntoldGSFormat.coreRecordSize, options: .storageModeShared) else {
            throw GaussianChunkLoadError.bufferAllocationFailed("Gaussian packed splat buffer")
        }
        packedBuffer.label = "Gaussian Packed Chunks"

        let sphericalHarmonicsBuffer: MTLBuffer?
        if shBytesPerSplat > 0 {
            guard let buffer = device.makeBuffer(length: splatCount * shBytesPerSplat, options: .storageModeShared) else {
                throw GaussianChunkLoadError.bufferAllocationFailed("Gaussian spherical-harmonics buffer")
            }
            buffer.label = "Gaussian Spherical Harmonics"
            sphericalHarmonicsBuffer = buffer
        } else {
            sphericalHarmonicsBuffer = nil
        }

        var constants: [GaussianChunkDecodeConstants] = []
        constants.reserveCapacity(file.index.chunks.count)
        var firstSplat = 0
        let packedBase = packedBuffer.contents()
        let shBase = sphericalHarmonicsBuffer?.contents()

        for chunkIndex in file.index.chunks.indices {
            let chunk = file.index.chunks[chunkIndex]
            let payload = try file.chunkPayload(at: chunkIndex, verify: true)
            let count = Int(chunk.splatCount)
            let coreBytes = Int(chunk.coreBytes)

            payload.withUnsafeBytes { bytes in
                let source = bytes.baseAddress!
                packedBase.advanced(by: firstSplat * UntoldGSFormat.coreRecordSize)
                    .copyMemory(from: source, byteCount: coreBytes)
                if let shBase, shBytesPerSplat > 0 {
                    shBase.advanced(by: firstSplat * shBytesPerSplat)
                        .copyMemory(from: source.advanced(by: coreBytes), byteCount: count * shBytesPerSplat)
                }
            }

            constants.append(GaussianChunkDecodeConstants(
                aabbMinX: chunk.aabbMin.x, aabbMinY: chunk.aabbMin.y, aabbMinZ: chunk.aabbMin.z,
                logScaleMin: chunk.logScaleMin,
                aabbMaxX: chunk.aabbMax.x, aabbMaxY: chunk.aabbMax.y, aabbMaxZ: chunk.aabbMax.z,
                logScaleMax: chunk.logScaleMax,
                firstSplat: UInt32(firstSplat),
                splatCount: UInt32(count),
                _pad0: 0, _pad1: 0
            ))
            firstSplat += count
        }

        guard let constantsBuffer = device.makeBuffer(
            bytes: constants,
            length: constants.count * MemoryLayout<GaussianChunkDecodeConstants>.stride,
            options: .storageModeShared
        ) else {
            throw GaussianChunkLoadError.bufferAllocationFailed("Gaussian chunk constants buffer")
        }
        constantsBuffer.label = "Gaussian Chunk Table"

        var table = GaussianChunkTable(
            constantsBuffer: constantsBuffer,
            chunkCount: constants.count,
            splatsPerChunk: header.splatsPerChunk,
            index: file.index
        )
        // The coarse levels that fit beside what the whole load holds: the region read once,
        // every level payload CRC-checked like the fine chunks above.
        let fit = coarseResidentFileLevels(index: file.index, residencyBudgetBytes: residencyBudget, label: url.lastPathComponent)
        if let coarse = try makeCoarseTable(device: device, index: file.index, fileLevels: fit.levels, claim: fit.claim) {
            try readCoarseRecords(url: url, index: file.index, into: coarse)
            table.coarse = coarse
        }

        return GaussianChunkLoadResult(
            splatCount: splatCount,
            packedSplatBuffer: packedBuffer,
            sphericalHarmonicsBuffer: sphericalHarmonicsBuffer,
            sphericalHarmonicsMetadata: header.shMetadata,
            meanSquaredSplatExtent: header.meanSquaredSplatExtent,
            captureExposureEV: header.captureExposureEV,
            captureWhiteBalance: header.captureWhiteBalance,
            boundingBox: (header.boundingBoxMin, header.boundingBoxMax),
            index: file.index,
            chunkTable: table
        )
    }

    // MARK: Coarse levels (per-chunk-lod-tiers)

    /// The file levels that stay resident for `index`, finest first — `[1, 2]`, `[2]` (the
    /// coarsest alone, when both do not fit what the other entities leave of the levels' share
    /// of the residency budget) or `[]` (the file has none, none fits, or the chunk count would
    /// carry into the visible-chunk tag bits) — with the claim on the share their bytes take,
    /// made under the registry's lock so concurrent loads fit against each other; the claim is
    /// released with the coarse table that holds it. The fallbacks are logged once per load;
    /// the entity then draws fine only.
    static func coarseResidentFileLevels(index: UntoldGSIndex, residencyBudgetBytes: Int, label: String) -> (levels: [Int], claim: GaussianCoarseClaim?) {
        let levelCount = index.coarseLevelCount
        guard levelCount > 0 else { return ([], nil) }
        guard index.chunks.count <= Int(kGaussianVisibleChunkIndexMask) else {
            Logger.logWarning(
                message: "Gaussian coarse levels of \(label) are off: \(index.chunks.count) chunks exceed the 2^24 the visible-chunk tag bits hold; drawing fine only",
                category: LogCategory.gaussian.rawValue
            )
            return ([], nil)
        }
        let bytes = (1 ... levelCount).map { level in
            index.coarseLevelRange(level: level).map { Int($0.upperBound - $0.lowerBound) } ?? 0
        }
        guard bytes.contains(where: { $0 > 0 }) else { return ([], nil) }
        // Sized and claimed in one step: the bytes the other levelled entities hold come off the
        // share, so the share bounds every entity's coarse records together.
        let registry = GaussianPagePoolRegistry.shared
        var resident = 0
        var held = 0
        var claimed = 0
        let reservation = registry.reserveCoarse { coarseBytes in
            held = coarseBytes
            resident = GaussianPagingPolicy.coarseResidentLevels(coarseBytesPerLevel: bytes, residencyBudgetBytes: residencyBudgetBytes, allocatedBytes: coarseBytes)
            claimed = resident >= levelCount ? bytes.reduce(0, +) : (resident > 0 ? bytes[levelCount - 1] : 0)
            return claimed
        }
        let claim = GaussianCoarseClaim(reservation: reservation, bytes: claimed)
        let percent = Int((GaussianPagingPolicy.coarseBudgetFractionInEffect * 100).rounded())
        let share = "\(percent) % of the residency budget (\(gaussianFormatBytes(residencyBudgetBytes)))" + (held > 0 ? ", \(gaussianFormatBytes(held)) of it held by other entities" : "")
        if resident >= levelCount {
            return (Array(1 ... levelCount), claim)
        }
        if resident == 0 {
            Logger.logWarning(
                message: "Gaussian coarse levels of \(label) (\(gaussianFormatBytes(bytes.reduce(0, +)))) exceed \(share); drawing fine only",
                category: LogCategory.gaussian.rawValue
            )
            return ([], nil)
        }
        Logger.logWarning(
            message: "Gaussian coarse levels of \(label) (\(gaussianFormatBytes(bytes.reduce(0, +)))) exceed \(share); keeping the coarsest level only (\(gaussianFormatBytes(bytes[levelCount - 1])))",
            category: LogCategory.gaussian.rawValue
        )
        return ([levelCount], claim)
    }

    /// The file range the records of `fileLevels` span — the coarsest first in the file, each
    /// level contiguous in chunk order — or nil when they hold no record.
    static func coarseRecordsRange(index: UntoldGSIndex, fileLevels: [Int]) -> Range<UInt64>? {
        var start = UInt64.max
        var end: UInt64 = 0
        for level in fileLevels {
            guard let range = index.coarseLevelRange(level: level) else { continue }
            start = min(start, range.lowerBound)
            end = max(end, range.upperBound)
        }
        return start < end ? start ..< end : nil
    }

    /// The coarse rows of the decode constants for `fileLevels`, level-major (the runtime's level
    /// 1 — the finest resident file level — first): the level's own ranges, `firstSplat` the
    /// record's index into a records buffer holding the file from `recordsBase`, `splatCount` 0
    /// where the chunk has no level.
    static func coarseConstants(index: UntoldGSIndex, fileLevels: [Int], recordsBase: UInt64) -> [GaussianChunkDecodeConstants] {
        var rows: [GaussianChunkDecodeConstants] = []
        rows.reserveCapacity(fileLevels.count * index.chunks.count)
        for level in fileLevels {
            for chunk in index.chunks.indices {
                let entry = index.coarseEntry(level: level, chunk: chunk)
                let firstSplat = entry.map { ($0.payloadOffset - recordsBase) / UInt64(UntoldGSFormat.coreRecordSize) } ?? 0
                rows.append(GaussianChunkDecodeConstants(
                    aabbMinX: entry?.aabbMin.x ?? 0, aabbMinY: entry?.aabbMin.y ?? 0, aabbMinZ: entry?.aabbMin.z ?? 0,
                    logScaleMin: entry?.logScaleMin ?? 0,
                    aabbMaxX: entry?.aabbMax.x ?? 0, aabbMaxY: entry?.aabbMax.y ?? 0, aabbMaxZ: entry?.aabbMax.z ?? 0,
                    logScaleMax: entry?.logScaleMax ?? 0,
                    firstSplat: UInt32(firstSplat),
                    splatCount: entry?.splatCount ?? 0,
                    _pad0: 0, _pad1: 0
                ))
            }
        }
        return rows
    }

    /// The coarse table of `index` for `fileLevels`: the constants, a zeroed records buffer over
    /// the levels' file range and a zeroed level state, holding `claim` on the coarse share. nil
    /// when no level is resident.
    static func makeCoarseTable(device: MTLDevice, index: UntoldGSIndex, fileLevels: [Int], claim: GaussianCoarseClaim? = nil) throws -> GaussianCoarseTable? {
        guard !fileLevels.isEmpty, let range = coarseRecordsRange(index: index, fileLevels: fileLevels) else { return nil }
        let rows = coarseConstants(index: index, fileLevels: fileLevels, recordsBase: range.lowerBound)
        guard let constants = device.makeBuffer(bytes: rows, length: max(1, rows.count) * MemoryLayout<GaussianChunkDecodeConstants>.stride, options: .storageModeShared) else {
            throw GaussianChunkLoadError.bufferAllocationFailed("Gaussian coarse chunk table")
        }
        constants.label = "Gaussian Coarse Chunk Table"
        guard let records = device.makeBuffer(length: Int(range.upperBound - range.lowerBound), options: .storageModeShared) else {
            throw GaussianChunkLoadError.bufferAllocationFailed("Gaussian coarse records")
        }
        records.label = "Gaussian Coarse Records"
        memset(records.contents(), 0, records.length)
        guard let state = device.makeBuffer(length: max(1, index.chunks.count) * MemoryLayout<GaussianChunkLevelState>.stride, options: .storageModeShared) else {
            throw GaussianChunkLoadError.bufferAllocationFailed("Gaussian chunk level state")
        }
        state.label = "Gaussian Chunk Level State"
        memset(state.contents(), 0, state.length)
        return GaussianCoarseTable(
            levelCount: fileLevels.count,
            fileLevels: fileLevels,
            ratioLog2: fileLevels.map { index.header.coarseRatioLog2[$0 - 1] },
            constantsBuffer: constants,
            recordsBuffer: records,
            levelStateBuffer: state,
            recordsRange: range,
            claim: claim
        )
    }

    /// Reads the records of `coarse.recordsRange` from `url` into the records buffer and
    /// CRC-checks every resident level payload against its entry — a whole-resident entity's
    /// load, beside the fine payload copy. A mismatch is the file's fault (`UntoldGSError.corrupt`),
    /// as for a fine chunk.
    static func readCoarseRecords(url: URL, index: UntoldGSIndex, into coarse: GaussianCoarseTable) throws {
        guard let handle = FileHandle(forReadingAtPath: url.path) else {
            throw GaussianChunkLoadError.coarseReadFailed("cannot open \(url.lastPathComponent)")
        }
        defer { try? handle.close() }
        let base = coarse.recordsRange.lowerBound
        let total = coarse.recordsBuffer.length
        let destination = coarse.recordsBuffer.contents()
        var done = 0
        try handle.seek(toOffset: base)
        while done < total {
            guard let data = try handle.read(upToCount: total - done), !data.isEmpty else {
                throw UntoldGSError.truncated
            }
            data.withUnsafeBytes { bytes in
                destination.advanced(by: done).copyMemory(from: bytes.baseAddress!, byteCount: bytes.count)
            }
            done += data.count
        }
        for level in coarse.fileLevels {
            for chunk in index.chunks.indices {
                guard let entry = index.coarseEntry(level: level, chunk: chunk) else { continue }
                let offset = Int(entry.payloadOffset - base)
                let bytes = UnsafeRawBufferPointer(start: destination.advanced(by: offset), count: Int(entry.coreBytes))
                var crc = UntoldGSCRC32.initialValue
                UntoldGSCRC32.update(&crc, bytes)
                let actual = UntoldGSCRC32.finalize(crc)
                guard actual == entry.crc32 else {
                    throw UntoldGSError.corrupt("coarse level \(level) of chunk \(chunk) CRC \(String(actual, radix: 16)) does not match \(String(entry.crc32, radix: 16))")
                }
            }
        }
    }

    /// The paged load: the decode constants from the index without reading a payload
    /// (`firstSplat` still the file-order prefix sum, unused by a paged frame), the two pools
    /// sized by `GaussianPagingPolicy` against what the residency budget leaves, the nine
    /// per-slot tables, and the pager that owns them all.
    private static func loadPaged(source: any GaussianPageSource, url: URL, device: MTLDevice, residencyBudgetBytes: Int) throws -> GaussianChunkLoadResult {
        let index = source.index
        let header = index.header
        let splatCount = Int(header.splatCount)
        let shBytesPerSplat = header.shBytesPerSplat
        let chunkCount = index.chunks.count
        let ranksPerPage = GaussianPagingPolicy.ranksPerPage(splatsPerChunk: header.splatsPerChunk)
        let pagesPerChunk = GaussianPagingPolicy.pagesPerChunk(splatsPerChunk: header.splatsPerChunk)
        let slotBytes = ranksPerPage * (UntoldGSFormat.coreRecordSize + shBytesPerSplat)
        let assetBytes = GaussianPagingPolicy.assetBytes(splatCount: splatCount, shBytesPerSplat: shBytesPerSplat)
        // Sized and claimed in one step under the registry's lock: two loads running at once
        // (tiers of one progressive entity, streamed entities) each see the other's claim, so
        // the pools together stay within the residency budget. The claim becomes the pager's
        // registration once it exists and is given back on every failure before that.
        let registry = GaussianPagePoolRegistry.shared
        var slotCount = 0
        let reservation = registry.reserve { allocatedBytes in
            slotCount = GaussianPagingPolicy.poolSlotCount(
                assetBytes: assetBytes,
                slotBytes: slotBytes,
                residencyBudgetBytes: residencyBudgetBytes,
                allocatedBytes: allocatedBytes
            )
            return slotCount * slotBytes
        }
        var unregistered: GaussianPagePoolReservation? = reservation
        defer {
            if let unregistered { registry.release(unregistered) }
        }

        // The pools: halve the slot count down to the minimum when the device refuses.
        var corePool: MTLBuffer?
        var shPool: MTLBuffer?
        while corePool == nil {
            corePool = device.makeBuffer(length: slotCount * ranksPerPage * UntoldGSFormat.coreRecordSize, options: .storageModeShared)
            if corePool != nil, shBytesPerSplat > 0 {
                shPool = device.makeBuffer(length: slotCount * ranksPerPage * shBytesPerSplat, options: .storageModeShared)
                if shPool == nil { corePool = nil }
            }
            if corePool == nil {
                guard slotCount > GaussianPagingPolicy.minPoolSlots else {
                    source.close()
                    throw GaussianChunkLoadError.bufferAllocationFailed("Gaussian page pool")
                }
                slotCount = max(GaussianPagingPolicy.minPoolSlots, slotCount / 2)
                registry.resize(reservation, bytes: slotCount * slotBytes)
            }
        }
        guard let corePool else {
            source.close()
            throw GaussianChunkLoadError.bufferAllocationFailed("Gaussian page pool")
        }
        corePool.label = "Gaussian Page Pool Core"
        shPool?.label = "Gaussian Page Pool SH"

        // The decode constants, as the whole load builds them, without a payload read.
        var constants: [GaussianChunkDecodeConstants] = []
        constants.reserveCapacity(chunkCount)
        var firstSplat = 0
        for chunk in index.chunks {
            constants.append(GaussianChunkDecodeConstants(
                aabbMinX: chunk.aabbMin.x, aabbMinY: chunk.aabbMin.y, aabbMinZ: chunk.aabbMin.z,
                logScaleMin: chunk.logScaleMin,
                aabbMaxX: chunk.aabbMax.x, aabbMaxY: chunk.aabbMax.y, aabbMaxZ: chunk.aabbMax.z,
                logScaleMax: chunk.logScaleMax,
                firstSplat: UInt32(firstSplat),
                splatCount: chunk.splatCount,
                _pad0: 0, _pad1: 0
            ))
            firstSplat += Int(chunk.splatCount)
        }
        guard let constantsBuffer = device.makeBuffer(
            bytes: constants,
            length: constants.count * MemoryLayout<GaussianChunkDecodeConstants>.stride,
            options: .storageModeShared
        ) else {
            source.close()
            throw GaussianChunkLoadError.bufferAllocationFailed("Gaussian chunk constants buffer")
        }
        constantsBuffer.label = "Gaussian Chunk Table"

        // The nine per-slot tables; the pager initialises them.
        var residencyTables: [MTLBuffer] = []
        var pageTables: [MTLBuffer] = []
        var demandTables: [MTLBuffer] = []
        for slot in 0 ..< maxInFlightCommandBuffers {
            guard let residency = device.makeBuffer(length: max(1, chunkCount) * MemoryLayout<GaussianChunkResidency>.stride, options: .storageModeShared),
                  let pageTable = device.makeBuffer(length: max(1, chunkCount * pagesPerChunk) * MemoryLayout<UInt32>.stride, options: .storageModeShared),
                  let demand = device.makeBuffer(length: max(1, chunkCount) * MemoryLayout<UInt32>.stride, options: .storageModeShared)
            else {
                source.close()
                throw GaussianChunkLoadError.bufferAllocationFailed("Gaussian page tables")
            }
            residency.label = "Gaussian Chunk Residency \(slot)"
            pageTable.label = "Gaussian Page Table \(slot)"
            demand.label = "Gaussian Chunk Demand \(slot)"
            residencyTables.append(residency)
            pageTables.append(pageTable)
            demandTables.append(demand)
        }

        // The coarse levels that fit beside the pool: their buffers here, zeroed; the pager
        // streams the region into them coarsest level first and marks the levels available.
        let fit = coarseResidentFileLevels(index: index, residencyBudgetBytes: residencyBudgetBytes, label: url.lastPathComponent)
        let coarse: GaussianCoarseTable?
        do {
            coarse = try makeCoarseTable(device: device, index: index, fileLevels: fit.levels, claim: fit.claim)
        } catch {
            source.close()
            throw error
        }

        let pager = GaussianPageManager(
            source: source,
            index: index,
            label: url.lastPathComponent,
            corePool: corePool,
            shPool: shPool,
            residencyTables: residencyTables,
            pageTables: pageTables,
            demandTables: demandTables,
            slotCount: slotCount,
            ranksPerPage: ranksPerPage,
            pagesPerChunk: pagesPerChunk,
            reservation: reservation,
            coarse: coarse.map { GaussianPagerCoarseInputs(recordsBuffer: $0.recordsBuffer, recordsRange: $0.recordsRange, fileLevels: $0.fileLevels) }
        )
        unregistered = nil

        var table = GaussianChunkTable(
            constantsBuffer: constantsBuffer,
            chunkCount: chunkCount,
            splatsPerChunk: header.splatsPerChunk,
            index: index
        )
        table.residencyTables = residencyTables
        table.pageTables = pageTables
        table.demandTables = demandTables
        table.pagesPerChunk = pagesPerChunk
        table.ranksPerPageLog2 = pager.ranksPerPageLog2
        table.coarse = coarse

        return GaussianChunkLoadResult(
            splatCount: splatCount,
            packedSplatBuffer: corePool,
            sphericalHarmonicsBuffer: shPool,
            sphericalHarmonicsMetadata: header.shMetadata,
            meanSquaredSplatExtent: header.meanSquaredSplatExtent,
            captureExposureEV: header.captureExposureEV,
            captureWhiteBalance: header.captureWhiteBalance,
            boundingBox: (header.boundingBoxMin, header.boundingBoxMax),
            index: index,
            chunkTable: table,
            pager: pager
        )
    }

    /// Expands `loaded`'s packed records into a new `EncodedGaussianSplat` buffer with the
    /// `gaussianDecodeChunks` kernel, waiting for the GPU: the whole-buffer representation a
    /// `.ply` loads to, for a `.untoldgs` that has to take that path (the per-chunk kernels are
    /// unavailable) and for tests of the decode.
    static func decodeEncodedSplats(_ loaded: GaussianChunkLoadResult) throws -> MTLBuffer {
        guard !loaded.isPaged else {
            throw GaussianChunkLoadError.pagedAssetCannotBeExpanded
        }
        guard let device = renderInfo.device, let commandQueue = renderInfo.commandQueue else {
            throw GaussianChunkLoadError.deviceUnavailable
        }
        guard isAvailable, let pipelineState = gaussianDecodePipeline.pipelineState else {
            throw GaussianChunkLoadError.decodePipelineUnavailable
        }
        guard let encodedSplatBuffer = device.makeBuffer(length: max(1, loaded.splatCount) * MemoryLayout<EncodedGaussianSplat>.stride, options: .storageModeShared) else {
            throw GaussianChunkLoadError.bufferAllocationFailed("Encoded Gaussian splat buffer")
        }
        encodedSplatBuffer.label = "Gaussian Encoded Splats"

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            throw GaussianChunkLoadError.gpuDecodeFailed("could not create a command buffer")
        }
        commandBuffer.label = "Gaussian Chunk Decode"
        encoder.label = "Gaussian Decode Chunks"
        encoder.setComputePipelineState(pipelineState)
        encoder.setBuffer(loaded.packedSplatBuffer, offset: 0, index: Int(gaussianDecodePackedIndex.rawValue))
        encoder.setBuffer(loaded.chunkTable.constantsBuffer, offset: 0, index: Int(gaussianDecodeChunksIndex.rawValue))
        var chunkCount = UInt32(loaded.chunkTable.chunkCount)
        encoder.setBytes(&chunkCount, length: MemoryLayout<UInt32>.stride, index: Int(gaussianDecodeChunkCountIndex.rawValue))
        encoder.setBuffer(encodedSplatBuffer, offset: 0, index: Int(gaussianDecodeOutputIndex.rawValue))

        // One threadgroup per chunk; the kernel strides over the chunk when it holds more
        // splats than a threadgroup has threads.
        let threadsPerGroup = max(1, min(loaded.chunkTable.splatsPerChunk, pipelineState.maxTotalThreadsPerThreadgroup))
        encoder.dispatchThreadgroups(
            MTLSize(width: max(1, loaded.chunkTable.chunkCount), height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: threadsPerGroup, height: 1, depth: 1)
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if let error = commandBuffer.error {
            throw GaussianChunkLoadError.gpuDecodeFailed(error.localizedDescription)
        }
        return encodedSplatBuffer
    }
}

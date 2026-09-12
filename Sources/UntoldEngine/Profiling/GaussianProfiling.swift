//
//  GaussianProfiling.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import QuartzCore

struct GaussianProfileTotals {
    var entityCount: Int = 0
    var splatCount: Int = 0
    var drawCallCount: Int = 0
    var dispatchCount: Int = 0
    var radixPassCount: Int = 0
    var encodedBytes: Int = 0
    /// `.untoldgs` entities' resident 16-byte core records.
    var packedBytes: Int = 0
    var sortedIndexBytes: Int = 0
    var visibleIndexBytes: Int = 0
    var visibleCountBytes: Int = 0
    /// `.untoldgs` chunk tables (GaussianChunkDecodeConstants per chunk) and their visible-chunk lists.
    var chunkTableBytes: Int = 0
    var sphericalHarmonicsBytes: Int = 0
    var uniformBytes: Int = 0
    var scratchBytes: Int = 0
    var maxSphericalHarmonicsDegree: UInt32 = 0
    var higherOrderCoefficientsPerSplat: UInt32 = 0

    /// Sort keys, working-set records, visible sets and entity constants shared by every
    /// entity of a frame (GaussianSharedWorkingSet), counted once per profile line.
    var sharedWorkingSetBytes: Int = 0

    /// Paged `.untoldgs` entities (GaussianPageManager): their pools (already in `packedBytes`
    /// and `sphericalHarmonicsBytes`, the pool being the packed buffer), their per-slot tables
    /// (already in `chunkTableBytes`), and what the pagers hold and do.
    var pagedEntityCount: Int = 0
    var pagePoolBytes: Int = 0
    var pageTableBytes: Int = 0
    var residentPages: Int = 0
    var poolPages: Int = 0
    var pendingPageReads: Int = 0
    var pageBytesInFlight: Int = 0
    var issuedPageReads: Int = 0
    var committedPages: Int = 0
    var evictedPages: Int = 0
    var saturatedCandidates: Int = 0
    var faultedChunks: Int = 0

    /// Entities with per-chunk coarse levels (per-chunk-lod-tiers): their coarse buffers (already
    /// in `chunkTableBytes` through `GaussianChunkTable.gpuBytes`: the coarse rows, the records
    /// outside the pool, the level state), the coarse bytes and chunk-levels a pager has landed,
    /// the pieces it issued, and the entities whose levels faulted.
    var coarseEntityCount: Int = 0
    var coarseBytes: Int = 0
    var coarseBytesLanded: Int = 0
    var coarseChunkLevelsAvailable: Int = 0
    var coarseReadsIssued: Int = 0
    var coarseFaultedEntities: Int = 0

    var totalResidentBytes: Int {
        encodedBytes + packedBytes + sortedIndexBytes + visibleIndexBytes + visibleCountBytes + chunkTableBytes + sphericalHarmonicsBytes + uniformBytes + scratchBytes + sharedWorkingSetBytes
    }

    /// The paging fields of a profile line's `extra`, empty when no entity pages.
    var pagingSummary: String {
        guard pagedEntityCount > 0 else { return "" }
        return " paged=\(pagedEntityCount) pool=\(gaussianFormatBytes(pagePoolBytes)) pages=\(residentPages)/\(poolPages) pending=\(pendingPageReads) inFlight=\(gaussianFormatBytes(pageBytesInFlight)) issued=\(issuedPageReads) committed=\(committedPages) evicted=\(evictedPages) saturated=\(saturatedCandidates) faults=\(faultedChunks)"
    }

    /// The coarse-level fields of a profile line's `extra`, empty when no entity has levels.
    var coarseSummary: String {
        guard coarseEntityCount > 0 else { return "" }
        return " coarseEntities=\(coarseEntityCount) coarseBytes=\(gaussianFormatBytes(coarseBytes)) coarseLanded=\(gaussianFormatBytes(coarseBytesLanded)) coarseLevelsAvailable=\(coarseChunkLevelsAvailable) coarseReads=\(coarseReadsIssued) coarseFaulted=\(coarseFaultedEntities)"
    }

    mutating func include(component: GaussianComponent) {
        entityCount += 1
        splatCount += Int(component.splatCount)
        encodedBytes += component.encodedSplatData?.length ?? 0
        packedBytes += component.packedSplatData?.length ?? 0
        visibleIndexBytes += component.gaussianVisibleIndices.reduce(0) { $0 + ($1?.length ?? 0) }
        visibleCountBytes += component.gaussianVisibleCount.reduce(0) { $0 + ($1?.length ?? 0) }
        chunkTableBytes += component.chunkTable?.gpuBytes ?? 0
        if let pager = component.pager {
            let stats = pager.stats
            pagedEntityCount += 1
            pagePoolBytes += stats.poolBytes
            if let table = component.chunkTable {
                pageTableBytes += table.residencyTables.reduce(0) { $0 + $1.length }
                    + table.pageTables.reduce(0) { $0 + $1.length }
                    + table.demandTables.reduce(0) { $0 + $1.length }
            }
            residentPages += stats.residentSlots
            poolPages += stats.slotCount
            pendingPageReads += stats.pendingReads
            pageBytesInFlight += stats.bytesInFlight
            issuedPageReads += stats.issuedThisTick
            committedPages += stats.committedThisTick
            evictedPages += stats.evictedThisTick
            saturatedCandidates += stats.saturatedCandidates
            faultedChunks += stats.faultedChunks
            coarseBytesLanded += stats.coarseBytesLanded
            coarseChunkLevelsAvailable += stats.coarseChunkLevelsAvailable
            coarseReadsIssued += stats.coarseReadsIssued
            if stats.coarseFaulted { coarseFaultedEntities += 1 }
        }
        if let coarse = component.chunkTable?.coarse {
            coarseEntityCount += 1
            coarseBytes += coarse.gpuBytes
            if component.pager == nil {
                // A whole-resident entity holds every level from the load.
                coarseBytesLanded += coarse.recordBytes
            }
        }
        if let shBuffer = component.sphericalHarmonicsData {
            sphericalHarmonicsBytes += shBuffer.length
        }
        if let metadata = component.sphericalHarmonicsMetadata {
            maxSphericalHarmonicsDegree = max(maxSphericalHarmonicsDegree, metadata.degree)
            higherOrderCoefficientsPerSplat = max(
                higherOrderCoefficientsPerSplat,
                metadata.higherOrderCoefficientsPerSplat
            )
        }
    }
}

@inline(__always)
func gaussianProfilingStartTime() -> CFTimeInterval? {
    guard Logger.isEnabled(category: .gaussian) else { return nil }
    return CACurrentMediaTime()
}

func logGaussianProfile(
    stage: String,
    startTime: CFTimeInterval?,
    totals: GaussianProfileTotals,
    extra: String = ""
) {
    guard let startTime else { return }

    let elapsedMs = (CACurrentMediaTime() - startTime) * 1000.0
    let bytesPerSplat = totals.splatCount > 0
        ? Double(totals.totalResidentBytes) / Double(totals.splatCount)
        : 0.0
    let suffix = extra.isEmpty ? "" : " \(extra)"

    Logger.log(
        message: String(
            format: "[Gaussian][%@] cpuEncodeMs=%.3f entities=%d splats=%d draws=%d dispatches=%d radixPasses=%d shDegree=%u shRestCoeffsPerSplat=%u memory=%@ bytesPerSplat=%.1f encoded=%@ packed=%@ sorted=%@ visible=%@ chunks=%@ sh=%@ uniforms=%@ scratch=%@ sharedSet=%@%@",
            stage,
            elapsedMs,
            totals.entityCount,
            totals.splatCount,
            totals.drawCallCount,
            totals.dispatchCount,
            totals.radixPassCount,
            totals.maxSphericalHarmonicsDegree,
            totals.higherOrderCoefficientsPerSplat,
            gaussianFormatBytes(totals.totalResidentBytes),
            bytesPerSplat,
            gaussianFormatBytes(totals.encodedBytes),
            gaussianFormatBytes(totals.packedBytes),
            gaussianFormatBytes(totals.sortedIndexBytes),
            gaussianFormatBytes(totals.visibleIndexBytes + totals.visibleCountBytes),
            gaussianFormatBytes(totals.chunkTableBytes),
            gaussianFormatBytes(totals.sphericalHarmonicsBytes),
            gaussianFormatBytes(totals.uniformBytes),
            gaussianFormatBytes(totals.scratchBytes),
            gaussianFormatBytes(totals.sharedWorkingSetBytes),
            suffix
        ),
        category: LogCategory.gaussian.rawValue
    )
}

func gaussianFormatBytes(_ bytes: Int) -> String {
    let value = Double(bytes)
    if bytes >= 1024 * 1024 {
        return String(format: "%.2fMiB", value / 1_048_576.0)
    }
    if bytes >= 1024 {
        return String(format: "%.2fKiB", value / 1024.0)
    }
    return "\(bytes)B"
}

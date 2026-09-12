//
//  GaussianPagingPolicy.swift
//  UntoldEngine
//
//  The rules of the chunk pager (`GaussianPageManager`) as pure functions over plain values,
//  and its knobs: when an asset pages and how big its pool is, how many ranks of a chunk the
//  frame wants (the quota rule with headroom, or a fill density when the frame fits), the load
//  priority, the eviction classes and their hysteresis, the retire ring that keeps a freed pool
//  slot out of use while a frame may still read it, the coalescing of a chunk's tiers into one
//  read, the per-tick I/O caps, and the per-chunk coarse levels' share of it (per-chunk-lod-tiers):
//  which levels of a file's coarse section fit beside the pool, how the section is cut into the
//  pieces the pager streams, and how the level rule zeroes the fine wants of a chunk drawn
//  coarse. Everything here is CPU-testable without Metal (GaussianPagingPolicyTests).
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation

/// The pager's constants and knobs. The mutable ones are lock-guarded statics like
/// `GaussianRuntimeLimits.workingSetSplatsOverride`; tests save and restore them.
public enum GaussianPagingPolicy {
    // MARK: Sizing

    /// The share of `MemoryBudgetManager.geometryBudget` every paged entity's pool is carved
    /// from (beside the working set's own quarter).
    public static let residencyBudgetFraction = 0.25
    /// Below this many bytes of unpadded records (16 + SH per splat) an asset loads whole.
    public static let pagingThresholdBytesMobile = 64 << 20
    public static let pagingThresholdBytesMac = 512 << 20
    /// The most one pool may hold.
    public static let pagePoolMaxBytesMobile = 256 << 20
    public static let pagePoolMaxBytesMac = 1 << 30
    /// A page (tier) holds at most this many ranks of one chunk: 4 KiB of core records.
    public static let maxRanksPerPage = 256

    /// The wanted ranks are the quota rule's with this headroom, so the density solve has a
    /// fixed point once residency feeds the histogram.
    public static let wantedHeadroom: Float = 1.25
    /// A candidate displaces a demanded chunk's tail tier only when its priority is at least
    /// this multiple of the tier's keep score.
    public static let swapMargin: Float = 1.5
    /// Ticks a failed chunk waits before its first, second and third retry; then it is faulted.
    public static let retryTicks: [UInt32] = [8, 32, 128]
    /// A slot's demand words older than this many frames (the loading gate skipped frames, the
    /// entity was hidden) are replaced by the CPU seed.
    public static let seedGapFrames: UInt64 = 8
    /// More than this fraction of an asset's chunks faulted — and at least `faultedChunkMinimum`
    /// of them — means the disk, not the chunks: the asset faults.
    public static let faultedChunkFraction = 0.01
    public static let faultedChunkMinimum = 4
    /// Soft pool targets under memory pressure: warning and critical.
    public static let pressureFractionWarning: Float = 0.5
    public static let pressureFractionCritical: Float = 0.25
    /// The share of the residency budget an entity's per-chunk coarse levels may take beside its
    /// pool (per-chunk-lod-tiers): both levels when they fit it, else the coarsest alone, else
    /// none. The coarse records live outside the pool, in their own buffer charged to the ledger.
    public static let coarseBudgetFraction = 0.2

    /// Replaces `coarseBudgetFraction` (tests, the editor); nil restores it.
    public static var coarseBudgetFractionOverride: Double? {
        get { storage.coarseBudgetFractionOverride }
        set { storage.coarseBudgetFractionOverride = newValue }
    }

    /// The fraction in effect.
    public static var coarseBudgetFractionInEffect: Double {
        coarseBudgetFractionOverride ?? coarseBudgetFraction
    }

    /// Replaces the residency budget (25 % of the geometry budget) with an exact figure.
    public static var residencyBudgetBytesOverride: Int? {
        get { storage.residencyBudgetBytesOverride }
        set { storage.residencyBudgetBytesOverride = newValue }
    }

    /// Replaces the paging threshold; 0 pages every chunked asset (tests, the editor).
    public static var pagingThresholdBytesOverride: Int? {
        get { storage.pagingThresholdBytesOverride }
        set { storage.pagingThresholdBytesOverride = newValue }
    }

    /// The fewest slots a pool is given, whatever the budget leaves.
    public static var minPoolSlots: Int {
        get { storage.minPoolSlots }
        set { storage.minPoolSlots = max(1, newValue) }
    }

    /// Ticks a resident chunk survives after it was last seen before it is stale.
    public static var holdOffTicks: UInt32 {
        get { storage.holdOffTicks }
        set { storage.holdOffTicks = newValue }
    }

    /// Ticks a demanded chunk's tier above its wanted tiers survives before it is surplus.
    public static var surplusTicks: UInt32 {
        get { storage.surplusTicks }
        set { storage.surplusTicks = newValue }
    }

    /// Ticks a freshly mapped tier is pinned against displacement.
    public static var minResidencyTicks: UInt32 {
        get { storage.minResidencyTicks }
        set { storage.minResidencyTicks = newValue }
    }

    /// Ticks an evicted tier waits before it may be requested again.
    public static var reloadCooldownTicks: UInt32 {
        get { storage.reloadCooldownTicks }
        set { storage.reloadCooldownTicks = newValue }
    }

    /// The most tiers evicted per tick.
    public static var maxEvictionsPerTick: Int {
        get { storage.maxEvictionsPerTick }
        set { storage.maxEvictionsPerTick = max(1, newValue) }
    }

    /// The most read requests issued per tick.
    public static var maxPageReadsPerTick: Int {
        get { storage.maxPageReadsPerTick }
        set { storage.maxPageReadsPerTick = max(1, newValue) }
    }

    /// The most bytes in flight to the pool at once.
    public static var maxPageBytesInFlight: Int {
        get { storage.maxPageBytesInFlight }
        set { storage.maxPageBytesInFlight = max(1, newValue) }
    }

    /// Reads of one pager running on the paging queue at once; the rest wait in the pager's own
    /// list, occupying no thread (tests raise it so held reads never block the rest).
    public static var maxConcurrentReads: Int {
        get { storage.maxConcurrentReads }
        set { storage.maxConcurrentReads = max(1, newValue) }
    }

    /// The most tiers mapped per tick (the rest of the completed reads wait in the inbox), the
    /// ceiling of the commit budget below.
    public static var maxCommitsPerTick: Int {
        get { storage.maxCommitsPerTick }
        set { storage.maxCommitsPerTick = max(1, newValue) }
    }

    /// The time a tick spends mapping landed tiers before the rest wait for the next tick, in
    /// seconds, past the first completion; the frame's cost of a fill is bounded by this while
    /// the pool has room and the reads keep up, up to `maxCommitsPerTick` tiers. The clock
    /// makes the tiers a tick maps a function of the machine's speed, not only of the arrivals:
    /// `.infinity` turns it off, so the count cap alone bounds a tick and the fill's schedule is
    /// reproducible run to run (the test fixtures and the benchmarks pin it so). 0 maps the
    /// first completion and one clock stride (16 tiers) per tick.
    public static var commitBudget: Double {
        get { storage.commitBudget }
        set { storage.commitBudget = max(0, newValue) }
    }

    /// Executed frames an arriving tier fades in over; 0 shows it at once.
    public static var fadeFrames: UInt32 {
        get { storage.fadeFrames }
        set { storage.fadeFrames = newValue }
    }

    /// Verify a chunk's CRC once it becomes fully resident.
    public static var verifyPagedChunkCRC: Bool {
        get { storage.verifyPagedChunkCRC }
        set { storage.verifyPagedChunkCRC = newValue }
    }

    /// Ticks between reopen attempts of a faulted source.
    public static var faultReopenTicks: UInt32 {
        get { storage.faultReopenTicks }
        set { storage.faultReopenTicks = max(1, newValue) }
    }

    /// A warming tier is warm when this fraction of its demanded wanted ranks is resident.
    public static var warmFraction: Float {
        get { storage.warmFraction }
        set { storage.warmFraction = newValue }
    }

    /// Ticks after which a warming tier counts as warm whatever is resident.
    public static var warmTimeoutTicks: UInt32 {
        get { storage.warmTimeoutTicks }
        set { storage.warmTimeoutTicks = newValue }
    }

    /// Ticks a memory-pressure soft target stays in force.
    public static var pressureTicks: UInt32 {
        get { storage.pressureTicks }
        set { storage.pressureTicks = newValue }
    }

    /// The platform's paging threshold, pool cap and in-flight cap.
    public static var pagingThresholdBytesDefault: Int {
        #if os(macOS)
            pagingThresholdBytesMac
        #else
            pagingThresholdBytesMobile
        #endif
    }

    public static var pagePoolMaxBytes: Int {
        #if os(macOS)
            pagePoolMaxBytesMac
        #else
            pagePoolMaxBytesMobile
        #endif
    }

    static var maxPageBytesInFlightDefault: Int {
        #if os(macOS)
            16 << 20
        #else
            4 << 20
        #endif
    }

    /// Restores every knob to its default (tests).
    public static func resetKnobs() {
        storage.reset()
    }

    // MARK: Sizing rules

    /// The unpadded record bytes of an asset: 16 plus the harmonics per splat.
    public static func assetBytes(splatCount: Int, shBytesPerSplat: Int) -> Int {
        splatCount * (UntoldGSFormat.coreRecordSize + shBytesPerSplat)
    }

    /// Ranks per page: 256, or the whole chunk when it is smaller.
    public static func ranksPerPage(splatsPerChunk: Int) -> Int {
        max(1, min(maxRanksPerPage, splatsPerChunk))
    }

    /// Tiers per chunk: splatsPerChunk / ranksPerPage (both powers of two).
    public static func pagesPerChunk(splatsPerChunk: Int) -> Int {
        max(1, splatsPerChunk / ranksPerPage(splatsPerChunk: splatsPerChunk))
    }

    /// The residency budget: the override, else a quarter of the geometry budget.
    public static func residencyBudgetBytes(geometryBudget: Int = MemoryBudgetManager.shared.geometryBudget) -> Int {
        if let override = residencyBudgetBytesOverride { return max(0, override) }
        return Int(Double(max(0, geometryBudget)) * residencyBudgetFraction)
    }

    /// The paging threshold: the override, else the platform figure, never above the budget.
    public static func pagingThresholdBytes(residencyBudgetBytes: Int) -> Int {
        if let override = pagingThresholdBytesOverride { return max(0, override) }
        return min(pagingThresholdBytesDefault, residencyBudgetBytes)
    }

    /// Whether an asset of `assetBytes` pages: above the threshold, when the caller has the
    /// chunk kernels (`allowPaging`) and the debug switch leaves paging on.
    public static func shouldPage(assetBytes: Int, thresholdBytes: Int, allowPaging: Bool, disablePaging: Bool) -> Bool {
        allowPaging && !disablePaging && assetBytes > thresholdBytes
    }

    /// The pool's slot count: what the residency budget leaves after the pools already
    /// allocated, clamped between the minimum and the smaller of the asset and the platform cap.
    public static func poolSlotCount(assetBytes: Int, slotBytes: Int, residencyBudgetBytes: Int, allocatedBytes: Int, poolMaxBytes: Int = pagePoolMaxBytes, minPoolSlots: Int = minPoolSlots) -> Int {
        guard slotBytes > 0 else { return minPoolSlots }
        // The asset in whole slots: its last tier is short but takes a slot.
        let assetSlots = (assetBytes + slotBytes - 1) / slotBytes
        let poolCap = min(assetSlots * slotBytes, poolMaxBytes)
        let remaining = residencyBudgetBytes - allocatedBytes
        let poolBytes = min(max(remaining, minPoolSlots * slotBytes), max(poolCap, minPoolSlots * slotBytes))
        return max(minPoolSlots, poolBytes / slotBytes)
    }

    /// The bytes a streaming pre-check should expect a splat entity to hold: the whole asset
    /// below the threshold, else the pool it would get.
    public static func residentEstimateBytes(assetBytes: Int, residencyBudgetBytes: Int? = nil, poolMaxBytes: Int = pagePoolMaxBytes) -> Int {
        let budget = residencyBudgetBytes ?? GaussianPagingPolicy.residencyBudgetBytes()
        let threshold = pagingThresholdBytes(residencyBudgetBytes: budget)
        guard assetBytes > threshold else { return assetBytes }
        return min(assetBytes, poolMaxBytes, budget)
    }

    // MARK: Coarse levels (per-chunk-lod-tiers)

    /// How many of a file's coarse levels stay resident beside the pool: `coarseBytesPerLevel`
    /// holds the record bytes of each level, finest first (the file's level 1, then level 2).
    /// Every level when their sum fits `fraction × residencyBudgetBytes − allocatedBytes` (the
    /// coarse bytes other entities already hold), else the coarsest level alone when it fits,
    /// else none — the runtime then draws the fine records only, as before the levels existed.
    public static func coarseResidentLevels(coarseBytesPerLevel: [Int], residencyBudgetBytes: Int, allocatedBytes: Int = 0, fraction: Double = coarseBudgetFractionInEffect) -> Int {
        guard !coarseBytesPerLevel.isEmpty else { return 0 }
        let bound = Double(max(0, residencyBudgetBytes)) * max(0, fraction) - Double(max(0, allocatedBytes))
        let total = coarseBytesPerLevel.reduce(0, +)
        if Double(total) <= bound { return coarseBytesPerLevel.count }
        if coarseBytesPerLevel.count > 1, let coarsest = coarseBytesPerLevel.last, Double(coarsest) <= bound { return 1 }
        return 0
    }

    /// The most bytes one piece of the coarse section carries through the read queue: half the
    /// in-flight cap, so a piece never starves the tier reads of the same tick, at least a page.
    public static func coarsePieceBytes(maxPageBytesInFlight: Int = maxPageBytesInFlight) -> Int {
        max(UntoldGSFormat.pageAlignment, maxPageBytesInFlight / 2)
    }

    /// The pieces the pager reads the coarse region `[rangeStart, rangeEnd)` in: sequential from
    /// the start (the coarsest level lies first in the file), each at most `pieceBytes`, landing
    /// in the records buffer at `fileOffset − rangeStart`. Deterministic, so an entry's pieces
    /// are known before any read.
    public static func coarsePieces(rangeStart: UInt64, rangeEnd: UInt64, pieceBytes: Int) -> [GaussianCoarsePiece] {
        guard rangeEnd > rangeStart, pieceBytes > 0 else { return [] }
        var pieces: [GaussianCoarsePiece] = []
        var cursor = rangeStart
        while cursor < rangeEnd {
            let count = Int(min(UInt64(pieceBytes), rangeEnd - cursor))
            pieces.append(GaussianCoarsePiece(fileOffset: cursor, byteCount: count, bufferOffset: Int(cursor - rangeStart)))
            cursor += UInt64(count)
        }
        return pieces
    }

    /// The residency struct `GaussianPageManager.map` writes when ranks `[firstRank, firstRank +
    /// rankCount)` of a chunk land at tick `now`: the new resident prefix, the fade from the
    /// first arrived rank, the arrival frame — and the coarse availability bits `previous`
    /// carried, which ride in the same struct and must survive every rewrite.
    public static func mappedResidency(previous: GaussianChunkResidency, firstRank: Int, rankCount: Int, now: UInt32) -> GaussianChunkResidency {
        GaussianChunkResidency(
            residentRanks: UInt32(firstRank + rankCount),
            fadeFromRank: UInt32(firstRank),
            arrivalFrame: now,
            coarseAvailable: previous.coarseAvailable
        )
    }

    // MARK: Wanted ranks

    /// The density at which the demanded chunks together would consume the whole room the
    /// headroom leaves, if none were capped by its count: the prefetch target when the frame
    /// fits (the read-back cap is +inf). +inf when nothing is demanded.
    public static func fillDensity(budget: Int, reservedSplats: Int, demandedArea: Float) -> Float {
        guard demandedArea > 0 else { return .infinity }
        let room = max(0, gaussianBudgetHeadroom * Float(budget) - Float(reservedSplats))
        return room / demandedArea
    }

    /// The room the fill aims at: the headroom's share of the budget after the whole-buffer
    /// entities' reservation.
    public static func fillRoom(budget: Int, reservedSplats: Int) -> Float {
        max(0, gaussianBudgetHeadroom * Float(budget) - Float(reservedSplats))
    }

    /// The largest room `fillDensityCap` takes as a whole number of splats: the largest `Float`
    /// below 2^32 (4,294,967,040; `Float(UInt32.max)` itself rounds up to 2^32).
    static let fillRoomMax = Float(UInt32.max).nextDown

    /// Adds (or, with `sign` −1, removes) a demanded chunk's term to the fill histogram: the
    /// chunk as the cull would list it resident whole with every level its file holds landed —
    /// binned by its full density, its splats, its scaled area, and with levels
    /// (`coarseCounts`, the runtime level 1 and 2 counts; 0 without) the counts the level rule
    /// draws in each coarse regime and the levelled shares — `GaussianChunkCullMath.densityHistogram`
    /// term by term, so the sum over the demanded set is that histogram of a whole-resident
    /// entity. The tier sums wrap, so a removal undoes an addition exactly.
    public static func addFillTerm(to histogram: inout GaussianBudgetDensityHistogram, splatCount: UInt32, area: Float, coarseCounts: (UInt32, UInt32), sign: Int32 = 1) {
        withUnsafeMutableBytes(of: &histogram.tiers) { bytes in
            addFillTerm(to: bytes.bindMemory(to: GaussianBudgetDensityTier.self).baseAddress!, splatCount: splatCount, area: area, coarseCounts: coarseCounts, sign: sign)
        }
    }

    /// `addFillTerm` over the histogram's tiers as a buffer of `gaussianDensityTierCount`
    /// entries (the pager keeps them so).
    static func addFillTerm(to tiers: UnsafeMutablePointer<GaussianBudgetDensityTier>, splatCount: UInt32, area: Float, coarseCounts: (UInt32, UInt32), sign: Int32) {
        guard area > 0, splatCount > 0 else { return }
        let hasLevel = coarseCounts.0 > 0 || coarseCounts.1 > 0
        let finest = coarseCounts.0 > 0 ? coarseCounts.0 : coarseCounts.1
        let listed = max(splatCount, finest)
        let tier = tiers + GaussianChunkCullMath.densityTier(density: Float(splatCount) / area)
        let scaledArea = UInt32(ceil(area * GaussianChunkCullMath.densityTierFloor(tier - tiers)))
        if sign >= 0 {
            tier.pointee.splats &+= listed
            tier.pointee.scaledArea &+= scaledArea
            if hasLevel {
                tier.pointee.coarse1 &+= finest
                tier.pointee.coarse2 &+= coarseCounts.1 > 0 ? coarseCounts.1 : coarseCounts.0
                tier.pointee.levelledSplats &+= listed
                tier.pointee.levelledScaledArea &+= scaledArea
            }
        } else {
            tier.pointee.splats &-= listed
            tier.pointee.scaledArea &-= scaledArea
            if hasLevel {
                tier.pointee.coarse1 &-= finest
                tier.pointee.coarse2 &-= coarseCounts.1 > 0 ? coarseCounts.1 : coarseCounts.0
                tier.pointee.levelledSplats &-= listed
                tier.pointee.levelledScaledArea &-= scaledArea
            }
        }
    }

    /// The fill density: the cap the budget solve would settle at with every demanded chunk
    /// resident whole (and, with `levels`, its levels landed and the level rule in force) — the
    /// largest density whose bounded request over the fill histogram stays within `room`
    /// (`GaussianChunkCullMath.boundedRequest` / `boundedGrant`, the same bisection on log2 as
    /// `densityCap`), +inf when everything fits whole or nothing is demanded, 0 when nothing
    /// fits. `fillDensity`, the room over the demanded area, is the density at which no chunk
    /// would be capped by its count; this one accounts for the chunks that are, so the wants of
    /// a fresh view converge to the state a whole-resident entity settles at rather than short
    /// of it.
    public static func fillDensityCap(histogram: GaussianBudgetDensityHistogram, room: Float, levels: (densityFloor: Float, tierShifts: (Int, Int))?) -> Float {
        var histogram = histogram
        return withUnsafeMutableBytes(of: &histogram.tiers) { bytes -> Float in
            let tiers = bytes.bindMemory(to: GaussianBudgetDensityTier.self)
            var requested: UInt32 = 0
            var highest = -1
            for tier in 0 ..< tiers.count where tiers[tier].splats > 0 {
                requested &+= tiers[tier].splats
                highest = tier
            }
            if requested == 0 { return .infinity }
            // The grant is a whole number of splats, as the kernel takes it. `Float(UInt32.max)`
            // rounds up to 2^32, which `UInt32(_:)` rejects: the clamp is the float just below.
            let room = Float(UInt32(max(0, min(room, fillRoomMax))))
            if room <= 0 { return 0 }
            let full = GaussianChunkCullMath.densityTierFloor(highest + 1)
            func request(_ density: Float) -> Float {
                let k = levels.map { GaussianChunkCullMath.densityTier(density: min(density, $0.densityFloor)) } ?? 0
                var total: Float = 0
                for tier in 0 ... highest where tiers[tier].splats > 0 {
                    let entry = tiers[tier]
                    let splats = Float(entry.splats)
                    let area = Float(entry.scaledArea) / GaussianChunkCullMath.densityTierFloor(tier)
                    let levelled = levels == nil ? 0 : min(entry.levelledSplats, entry.splats)
                    if levelled == 0 {
                        total += min(splats, density * area)
                        continue
                    }
                    let levelledSplats = Float(levelled)
                    let levelledArea = Float(min(entry.levelledScaledArea, entry.scaledArea)) / GaussianChunkCullMath.densityTierFloor(tier)
                    let fineOnly = splats - levelledSplats
                    if fineOnly > 0 {
                        total += min(fineOnly, density * (area - levelledArea))
                    }
                    let delta = k - tier
                    if let shifts = levels?.tierShifts, delta < -shifts.0 - 1 {
                        total += delta >= -shifts.1 - 1 ? Float(entry.coarse1) : Float(entry.coarse2)
                    } else {
                        total += max(min(levelledSplats, density * levelledArea), Float(entry.coarse1))
                    }
                }
                return total
            }
            if request(full) <= room { return .infinity }
            var lo = gaussianBudgetDensityBisectionLog2Floor
            var hi = log2(full)
            if request(exp2(lo)) > room { return 0 }
            for _ in 0 ..< gaussianBudgetDensityBisectionSteps {
                let mid = (lo + hi) * 0.5
                if request(exp2(mid)) <= room {
                    lo = mid
                } else {
                    hi = mid
                }
            }
            return exp2(lo)
        }
    }

    /// The uniform rule's counterpart of `fillDensity`: the scale at which the demanded chunks
    /// together would consume the room, `min(1, room / Σ n)`; 1 when nothing is demanded.
    public static func fillScale(budget: Int, reservedSplats: Int, demandedSplats: Int) -> Float {
        guard demandedSplats > 0 else { return 1 }
        let room = max(0, gaussianBudgetHeadroom * Float(budget) - Float(reservedSplats))
        return min(1, room / Float(demandedSplats))
    }

    /// The ranks the frame would draw of a chunk of `splatCount` splats seen with `area`:
    /// everything with the budget off, the uniform rule's `floor(scale × n)` at the fill scale
    /// under `uniformQuotas`, else the quota rule at the read-back cap, or at the fill density
    /// when the cap is +inf.
    ///
    /// The uniform branch ignores the read-back cap on purpose: under `uniformQuotas` the
    /// kernel publishes the scale it applied to the *listed* counts, which for a paged chunk are
    /// its resident ranks, so applying that cap to the full count has no fixed point (the wants
    /// would grow to the whole chunk once the pool held the headroom, then shrink again). The
    /// fill scale over the full demanded counts does: resident 1.25 × s × n, cap 0.8, quota s × n.
    ///
    /// A chunk of an entity with coarse levels (`coarse`, per-chunk-lod-tiers) wants **0** fine
    /// ranks when the level rule (`GaussianChunkCullMath.level`) picks a coarse level for it at
    /// the same cap (or fill density) and the frame's density floor — evaluated as if the chunk
    /// drew fine last frame, the finer assumption inside the hysteresis band, so a chunk near a
    /// boundary keeps its fine tiers while the GPU still draws it coarse — and the fine ranks
    /// above otherwise. Fine counts as available whatever is resident: the want is what decides
    /// whether to fetch it. Off under `uniformQuotas` (the levels are off there too) and under
    /// `disableWorkingSetBudget` (every rank is wanted; the frame fits, so only the density
    /// floor can still draw a chunk coarse).
    public static func wantedRanks(
        splatCount: UInt32,
        area: Float,
        densityCap: Float,
        fillDensity: Float,
        fillScale: Float = 1,
        uniformQuotas: Bool,
        disableWorkingSetBudget: Bool,
        coarse: GaussianCoarseWantInputs? = nil
    ) -> UInt32 {
        if disableWorkingSetBudget { return splatCount }
        if uniformQuotas {
            return GaussianChunkCullMath.quota(scale: fillScale, splatCount: splatCount)
        }
        let cap = densityCap.isFinite ? densityCap : fillDensity
        let level = coarse.map { coarseLevel($0, splatCount: splatCount, area: area, cap: cap, previous: 0) } ?? 0
        return fineWant(level: level, cap: cap, splatCount: splatCount, area: area)
    }

    /// The fine ranks a chunk of `splatCount` seen with `area` wants at `cap` when the level
    /// rule picks `level` for it: none drawn coarse, the quota otherwise. The one rule
    /// `wantedRanks` and the pager's pass run.
    @inline(__always)
    static func fineWant(level: Int, cap: Float, splatCount: UInt32, area: Float) -> UInt32 {
        level != 0 ? 0 : GaussianChunkCullMath.quota(densityCap: cap, splatCount: splatCount, screenArea: area)
    }

    /// The level the rule picks for a chunk of `splatCount` seen with `area` at `cap` (finite: the
    /// read-back cap or the fill density) given the coarse inputs and the level drawn last tick
    /// (`previous`; 0 for the finer assumption of the wants): the CPU's mirror of the GPU's choice.
    /// `fineAvailable` false (nothing resident) drops fine from the mask, as the GPU's rule does.
    public static func coarseLevel(_ coarse: GaussianCoarseWantInputs, splatCount: UInt32, area: Float, cap: Float, previous: Int, fineAvailable: Bool = true) -> Int {
        guard area > 0 else { return 0 }
        return GaussianChunkCullMath.level(
            densityCap: cap,
            densityFloor: coarse.densityFloor,
            splatCount: splatCount,
            screenArea: area,
            previous: previous,
            available: fineAvailable ? coarse.availabilityMask : coarse.availabilityMask & ~1,
            tierShifts: coarse.tierShifts,
            levelMode: coarse.levelMode
        )
    }

    /// The ranks to keep resident for a chunk that wants `want`: the want with the headroom,
    /// never above the count; 0 when nothing is wanted.
    public static func neededRanks(want: UInt32, splatCount: UInt32, headroom: Float = wantedHeadroom) -> UInt32 {
        guard want > 0 else { return 0 }
        let padded = ceil(headroom * Float(want))
        guard padded < Float(splatCount) else { return splatCount }
        return max(want, UInt32(padded))
    }

    /// Tiers that hold `needed` ranks.
    public static func tiersNeeded(needed: UInt32, ranksPerPage: Int) -> Int {
        (Int(needed) + ranksPerPage - 1) / ranksPerPage
    }

    /// The resident rank count of a prefix of `tiers` tiers of a chunk of `splatCount`.
    public static func residentRanks(tiers: Int, ranksPerPage: Int, splatCount: UInt32) -> UInt32 {
        min(splatCount, UInt32(tiers * ranksPerPage))
    }

    // MARK: Priority and keep score

    /// The load priority of a chunk seen with `area` holding `residentRanks` of the `neededRanks`
    /// it wants: near and large first, empty chunks before top-ups, the chunk the camera stands
    /// in (the guard area) first of all. 0 when nothing is missing.
    @inline(__always)
    public static func loadPriority(area: Float, residentRanks: UInt32, neededRanks: UInt32, ranksPerPage: Int) -> Float {
        guard neededRanks > residentRanks else { return 0 }
        let firstMissingTier = Int(residentRanks) / ranksPerPage
        let deficit = Float(neededRanks - residentRanks) / Float(neededRanks)
        return area * deficit / Float(firstMissingTier + 1)
    }

    /// The score a resident tier would have as a request: what a candidate must beat by the
    /// swap margin to displace it.
    public static func keepScore(area: Float, tier: Int) -> Float {
        area / Float(tier + 1)
    }

    /// Whether `state` may be requested at `tick`: something missing, not loading, not
    /// faulted, past its cooldown or backoff, not fading in.
    @inline(__always)
    public static func isLoadCandidate(_ state: GaussianChunkPageState, tick: UInt32) -> Bool {
        state.neededRanks > state.residentRanks
            && !state.flags.contains(.loading)
            && !state.flags.contains(.faulted)
            && state.retryAfterTick <= tick
            && !state.flags.contains(.fadeActive)
    }

    // MARK: Eviction

    /// The tiers to free for `count` slots, in eviction order, over the resident chunks: stale
    /// chunks whole (oldest first), then surplus tiers of demanded chunks (smallest area first),
    /// then the tail tiers of the resident demanded chunks with the smallest keep scores, each
    /// only when the priority of the candidate its slot serves (`inputs.slotPriorities[i]` for
    /// the i-th victim, else `inputs.candidatePriority`) beats it by the swap margin and the tier
    /// is not pinned. Under pressure the third class ignores margin and pin. A loading chunk is
    /// never a victim (its read must land on a prefix); a chunk flagged `.demanded` is never
    /// stale, whatever its stamp. Fewer than `count` victims means the pool is saturated. Ties
    /// are broken on the chunk index, so the choice does not depend on the order of `resident`.
    public static func selectVictims(
        states: [GaussianChunkPageState],
        resident: [Int],
        count: Int,
        inputs: GaussianEvictionInputs
    ) -> [GaussianEvictionVictim] {
        let residentChunks = resident.map { Int32($0) }
        return states.withUnsafeBufferPointer { states in
            residentChunks.withUnsafeBufferPointer { resident in
                selectVictims(states: states, resident: resident, count: count, inputs: inputs)
            }
        }
    }

    /// `selectVictims` over the pager's own tables (the states as a buffer, the resident
    /// chunks as a dense list of indices).
    static func selectVictims(
        states: UnsafeBufferPointer<GaussianChunkPageState>,
        resident: UnsafeBufferPointer<Int32>,
        count: Int,
        inputs: GaussianEvictionInputs
    ) -> [GaussianEvictionVictim] {
        guard count > 0 else { return [] }
        var victims: [GaussianEvictionVictim] = []
        victims.reserveCapacity(count)
        let ranksPerPage = inputs.ranksPerPage
        // Tiers of a chunk already claimed by an earlier class of this call.
        var taken: [Int: Int] = [:]

        func tiers(_ ranks: UInt16) -> Int {
            (Int(ranks) + ranksPerPage - 1) / ranksPerPage
        }

        func take(_ chunk: Int, tier: Int, kind: GaussianEvictionClass) {
            victims.append(GaussianEvictionVictim(chunk: chunk, tier: tier, kind: kind))
            taken[chunk, default: 0] += 1
        }

        // 1. Stale chunks, oldest demand first, every tier from the top down. A chunk whose level
        // is cross-fading (`.levelFade`) is no victim in any class, pressure included: its
        // outgoing fine window is still drawn.
        var stale: [(chunk: Int, lastDemand: UInt32)] = []
        var demandedResident: [Int] = []
        for residentChunk in resident {
            let chunk = Int(residentChunk)
            let state = states[chunk]
            guard state.residentRanks > 0, !state.flags.contains(.loading), !state.flags.contains(.levelFade) else { continue }
            if !state.flags.contains(.demanded), inputs.tick &- state.lastDemandTick > inputs.holdOffTicks {
                stale.append((chunk, state.lastDemandTick))
            } else {
                demandedResident.append(chunk)
            }
        }
        stale.sort { $0.lastDemand < $1.lastDemand || ($0.lastDemand == $1.lastDemand && $0.chunk < $1.chunk) }
        for entry in stale where victims.count < count {
            let top = tiers(states[entry.chunk].residentRanks)
            for tier in stride(from: top - 1, through: 0, by: -1) where victims.count < count {
                take(entry.chunk, tier: tier, kind: .stale)
            }
        }
        if victims.count >= count { return victims }

        // 2. Surplus tiers: above the wanted tiers for long enough, smallest area first.
        var surplus: [(chunk: Int, area: Float)] = []
        for chunk in demandedResident {
            let state = states[chunk]
            let wanted = tiers(state.neededRanks)
            guard tiers(state.residentRanks) > wanted,
                  state.surplusSinceTick != 0,
                  inputs.tick &- state.surplusSinceTick >= inputs.surplusTicks
            else { continue }
            surplus.append((chunk, state.lastArea))
        }
        surplus.sort { $0.area < $1.area || ($0.area == $1.area && $0.chunk < $1.chunk) }
        for entry in surplus where victims.count < count {
            let state = states[entry.chunk]
            let wanted = tiers(state.neededRanks)
            for tier in stride(from: tiers(state.residentRanks) - 1, through: wanted, by: -1) where victims.count < count {
                take(entry.chunk, tier: tier, kind: .surplus)
            }
        }
        if victims.count >= count { return victims }

        // 3. Displacement of the tail tiers with the smallest keep scores.
        guard inputs.pressure || inputs.candidatePriority != nil || inputs.slotPriorities != nil else { return victims }
        // The tail tier each demanded chunk still holds after the classes above, cheapest first;
        // one tier per chunk per call, so a heavy request spreads over the pool.
        var tails: [(chunk: Int, tier: Int, score: Float)] = []
        for chunk in demandedResident {
            let state = states[chunk]
            let top = tiers(state.residentRanks) - 1 - (taken[chunk] ?? 0)
            guard top >= 0 else { continue }
            if !inputs.pressure, inputs.tick &- state.mappedAtTick < inputs.minResidencyTicks { continue }
            tails.append((chunk, top, keepScore(area: state.lastArea, tier: top)))
        }
        tails.sort { $0.score < $1.score || ($0.score == $1.score && $0.chunk < $1.chunk) }
        for tail in tails where victims.count < count {
            // The i-th victim frees the i-th missing slot: the candidate that slot serves must
            // beat the tail by the margin. The slot priorities fall with the candidate order, so
            // the first tail that holds ends the class.
            if !inputs.pressure, let priority = inputs.priority(forVictim: victims.count), priority < inputs.swapMargin * tail.score {
                break
            }
            take(tail.chunk, tier: tail.tier, kind: .displacement)
        }
        return victims
    }

    // MARK: Coalescing

    /// The file ranges of a request for ranks `[firstRank, firstRank + rankCount)` of `chunk`
    /// landing in `slots` (one per tier): the core bytes and the harmonics bytes, each merged
    /// across tiers whose slots are adjacent in the pool (the file range of one chunk is always
    /// contiguous), split at every other slot boundary.
    public static func coalesceRequest(
        chunk: UntoldGSChunkEntry,
        firstRank: Int,
        rankCount: Int,
        slots: [UInt32],
        ranksPerPage: Int,
        shBytesPerSplat: Int
    ) -> (core: [GaussianPageReadRange], sh: [GaussianPageReadRange]) {
        var core: [GaussianPageReadRange] = []
        var sh: [GaussianPageReadRange] = []
        let recordSize = UntoldGSFormat.coreRecordSize
        let end = firstRank + rankCount
        for (index, slot) in slots.enumerated() {
            let rank = firstRank + index * ranksPerPage
            guard rank < end else { break }
            let ranks = min(ranksPerPage, end - rank)
            let adjacent = index > 0 && slots[index - 1] &+ 1 == slot
            let coreRange = GaussianPageReadRange(
                fileOffset: chunk.payloadOffset + UInt64(rank * recordSize),
                byteCount: ranks * recordSize,
                poolOffset: Int(slot) * ranksPerPage * recordSize
            )
            if adjacent, let last = core.last {
                core[core.count - 1] = GaussianPageReadRange(fileOffset: last.fileOffset, byteCount: last.byteCount + coreRange.byteCount, poolOffset: last.poolOffset)
            } else {
                core.append(coreRange)
            }
            guard shBytesPerSplat > 0 else { continue }
            let shRange = GaussianPageReadRange(
                fileOffset: chunk.payloadOffset + UInt64(Int(chunk.coreBytes) + rank * shBytesPerSplat),
                byteCount: ranks * shBytesPerSplat,
                poolOffset: Int(slot) * ranksPerPage * shBytesPerSplat
            )
            if adjacent, let last = sh.last {
                sh[sh.count - 1] = GaussianPageReadRange(fileOffset: last.fileOffset, byteCount: last.byteCount + shRange.byteCount, poolOffset: last.poolOffset)
            } else {
                sh.append(shRange)
            }
        }
        return (core, sh)
    }

    // MARK: Storage

    private final class Storage: @unchecked Sendable {
        private let lock = NSLock()
        private var _residencyBudgetBytesOverride: Int?
        private var _pagingThresholdBytesOverride: Int?
        private var _minPoolSlots = 64
        private var _holdOffTicks: UInt32 = 30
        private var _surplusTicks: UInt32 = 45
        private var _minResidencyTicks: UInt32 = 30
        private var _reloadCooldownTicks: UInt32 = 15
        private var _maxEvictionsPerTick = 512
        private var _maxPageReadsPerTick = 256
        private var _maxPageBytesInFlight = GaussianPagingPolicy.maxPageBytesInFlightDefault
        private var _maxConcurrentReads = 8
        private var _maxCommitsPerTick = 4096
        private var _commitBudget = 0.0005
        private var _fadeFrames: UInt32 = 16
        private var _verifyPagedChunkCRC = true
        private var _faultReopenTicks: UInt32 = 300
        private var _warmFraction: Float = 0.8
        private var _warmTimeoutTicks: UInt32 = 90
        private var _pressureTicks: UInt32 = 600
        private var _coarseBudgetFractionOverride: Double?

        func reset() {
            lock.lock()
            defer { lock.unlock() }
            _residencyBudgetBytesOverride = nil
            _pagingThresholdBytesOverride = nil
            _minPoolSlots = 64
            _holdOffTicks = 30
            _surplusTicks = 45
            _minResidencyTicks = 30
            _reloadCooldownTicks = 15
            _maxEvictionsPerTick = 512
            _maxPageReadsPerTick = 256
            _maxPageBytesInFlight = GaussianPagingPolicy.maxPageBytesInFlightDefault
            _maxConcurrentReads = 8
            _maxCommitsPerTick = 4096
            _commitBudget = 0.0005
            _fadeFrames = 16
            _verifyPagedChunkCRC = true
            _faultReopenTicks = 300
            _warmFraction = 0.8
            _warmTimeoutTicks = 90
            _pressureTicks = 600
            _coarseBudgetFractionOverride = nil
        }

        var coarseBudgetFractionOverride: Double? {
            get { lock.lock(); defer { lock.unlock() }; return _coarseBudgetFractionOverride }
            set { lock.lock(); _coarseBudgetFractionOverride = newValue; lock.unlock() }
        }

        var residencyBudgetBytesOverride: Int? {
            get { lock.lock(); defer { lock.unlock() }; return _residencyBudgetBytesOverride }
            set { lock.lock(); _residencyBudgetBytesOverride = newValue; lock.unlock() }
        }

        var pagingThresholdBytesOverride: Int? {
            get { lock.lock(); defer { lock.unlock() }; return _pagingThresholdBytesOverride }
            set { lock.lock(); _pagingThresholdBytesOverride = newValue; lock.unlock() }
        }

        var minPoolSlots: Int {
            get { lock.lock(); defer { lock.unlock() }; return _minPoolSlots }
            set { lock.lock(); _minPoolSlots = newValue; lock.unlock() }
        }

        var holdOffTicks: UInt32 {
            get { lock.lock(); defer { lock.unlock() }; return _holdOffTicks }
            set { lock.lock(); _holdOffTicks = newValue; lock.unlock() }
        }

        var surplusTicks: UInt32 {
            get { lock.lock(); defer { lock.unlock() }; return _surplusTicks }
            set { lock.lock(); _surplusTicks = newValue; lock.unlock() }
        }

        var minResidencyTicks: UInt32 {
            get { lock.lock(); defer { lock.unlock() }; return _minResidencyTicks }
            set { lock.lock(); _minResidencyTicks = newValue; lock.unlock() }
        }

        var reloadCooldownTicks: UInt32 {
            get { lock.lock(); defer { lock.unlock() }; return _reloadCooldownTicks }
            set { lock.lock(); _reloadCooldownTicks = newValue; lock.unlock() }
        }

        var maxEvictionsPerTick: Int {
            get { lock.lock(); defer { lock.unlock() }; return _maxEvictionsPerTick }
            set { lock.lock(); _maxEvictionsPerTick = newValue; lock.unlock() }
        }

        var maxPageReadsPerTick: Int {
            get { lock.lock(); defer { lock.unlock() }; return _maxPageReadsPerTick }
            set { lock.lock(); _maxPageReadsPerTick = newValue; lock.unlock() }
        }

        var maxPageBytesInFlight: Int {
            get { lock.lock(); defer { lock.unlock() }; return _maxPageBytesInFlight }
            set { lock.lock(); _maxPageBytesInFlight = newValue; lock.unlock() }
        }

        var maxConcurrentReads: Int {
            get { lock.lock(); defer { lock.unlock() }; return _maxConcurrentReads }
            set { lock.lock(); _maxConcurrentReads = newValue; lock.unlock() }
        }

        var maxCommitsPerTick: Int {
            get { lock.lock(); defer { lock.unlock() }; return _maxCommitsPerTick }
            set { lock.lock(); _maxCommitsPerTick = newValue; lock.unlock() }
        }

        var commitBudget: Double {
            get { lock.lock(); defer { lock.unlock() }; return _commitBudget }
            set { lock.lock(); _commitBudget = newValue; lock.unlock() }
        }

        var fadeFrames: UInt32 {
            get { lock.lock(); defer { lock.unlock() }; return _fadeFrames }
            set { lock.lock(); _fadeFrames = newValue; lock.unlock() }
        }

        var verifyPagedChunkCRC: Bool {
            get { lock.lock(); defer { lock.unlock() }; return _verifyPagedChunkCRC }
            set { lock.lock(); _verifyPagedChunkCRC = newValue; lock.unlock() }
        }

        var faultReopenTicks: UInt32 {
            get { lock.lock(); defer { lock.unlock() }; return _faultReopenTicks }
            set { lock.lock(); _faultReopenTicks = newValue; lock.unlock() }
        }

        var warmFraction: Float {
            get { lock.lock(); defer { lock.unlock() }; return _warmFraction }
            set { lock.lock(); _warmFraction = newValue; lock.unlock() }
        }

        var warmTimeoutTicks: UInt32 {
            get { lock.lock(); defer { lock.unlock() }; return _warmTimeoutTicks }
            set { lock.lock(); _warmTimeoutTicks = newValue; lock.unlock() }
        }

        var pressureTicks: UInt32 {
            get { lock.lock(); defer { lock.unlock() }; return _pressureTicks }
            set { lock.lock(); _pressureTicks = newValue; lock.unlock() }
        }
    }

    private static let storage = Storage()
}

/// The pager's per-chunk CPU state.
public struct GaussianChunkPageState: Equatable, Sendable {
    public struct Flags: OptionSet, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        /// A read of this chunk's missing tiers is in flight.
        public static let loading = Flags(rawValue: 1 << 0)
        /// Never requested again: three failed reads, or a CRC mismatch.
        public static let faulted = Flags(rawValue: 1 << 1)
        /// The last arrival is still fading in; not topped up until it is done.
        public static let fadeActive = Flags(rawValue: 1 << 2)
        /// The chunk's level changed within the last `fadeFrames` ticks (per-chunk-lod-tiers):
        /// its fine tiers may be the outgoing window of the cross-fade and are no victim.
        public static let levelFade = Flags(rawValue: 1 << 3)
        /// Seen by the last ingest (its demand word non-zero): its demand stamp is the ingest's
        /// tick, and it is never stale.
        public static let demanded = Flags(rawValue: 1 << 4)
    }

    /// 0, R, 2R, …, n: the resident prefix.
    public var residentRanks: UInt16 = 0
    /// The ranks to keep resident this tick (§ wanted ranks with headroom).
    public var neededRanks: UInt16 = 0
    /// The tick the chunk was last seen (its demand word non-zero); while `.demanded` is set
    /// the pager's last ingest tick stands for it (`GaussianPageManager.chunkState` fills it in).
    public var lastDemandTick: UInt32 = 0
    /// Its last seen screen area.
    public var lastArea: Float = 0
    /// The first tick the resident tiers exceeded the wanted tiers; 0 = none.
    public var surplusSinceTick: UInt32 = 0
    /// The tick of the last mapping change (the minimum-residency pin).
    public var mappedAtTick: UInt32 = 0
    /// Reload cooldown and failure backoff: not requested before this tick.
    public var retryAfterTick: UInt32 = 0
    public var failures: UInt8 = 0
    public var flags: Flags = []
    /// Ranks from here up arrived at `arrivalTick` (mirrored into the residency table).
    public var fadeFromRank: UInt16 = 0
    public var arrivalTick: UInt32 = 0
    /// The CPU's mirror of the level the chunk draws (0 fine, 1, 2), from the same rule the quota
    /// pass runs, updated each tick the chunk is demanded; never read back from the GPU.
    public var drawnLevel: UInt8 = 0
    /// The tick `drawnLevel` last changed (the `.levelFade` clock).
    public var levelSwitchTick: UInt32 = 0

    public init() {}
}

/// The inputs of the level rule the pager evaluates for a chunk of an entity with coarse levels
/// (per-chunk-lod-tiers): the entity's tier shifts, the chunk's runtime level 1 and 2 counts,
/// which levels have landed for it (`GaussianChunkResidency.coarseAvailable`: bit 0 level 1,
/// bit 1 level 2), the frame's density floor and level mode.
public struct GaussianCoarseWantInputs: Equatable, Sendable {
    public var tierShifts: (Int, Int)
    public var counts: (UInt32, UInt32)
    public var available: UInt32
    public var densityFloor: Float
    public var levelMode: GaussianLevelMode

    public init(tierShifts: (Int, Int), counts: (UInt32, UInt32), available: UInt32, densityFloor: Float = .infinity, levelMode: GaussianLevelMode = .auto) {
        self.tierShifts = tierShifts
        self.counts = counts
        self.available = available
        self.densityFloor = densityFloor
        self.levelMode = levelMode
    }

    /// The rule's availability mask with fine available (bit 0) and each landed level with a
    /// non-zero count (bits 1, 2).
    public var availabilityMask: UInt32 {
        1
            | ((available & 1) != 0 && counts.0 > 0 ? 2 : 0)
            | ((available & 2) != 0 && counts.1 > 0 ? 4 : 0)
    }

    public static func == (lhs: GaussianCoarseWantInputs, rhs: GaussianCoarseWantInputs) -> Bool {
        lhs.tierShifts == rhs.tierShifts && lhs.counts == rhs.counts && lhs.available == rhs.available
            && lhs.densityFloor == rhs.densityFloor && lhs.levelMode == rhs.levelMode
    }
}

/// One piece of a coarse section read through the pager's queue: `byteCount` bytes at
/// `fileOffset`, landing in the entity's coarse records buffer at `bufferOffset`.
public struct GaussianCoarsePiece: Equatable, Sendable {
    public let fileOffset: UInt64
    public let byteCount: Int
    public let bufferOffset: Int

    public init(fileOffset: UInt64, byteCount: Int, bufferOffset: Int) {
        self.fileOffset = fileOffset
        self.byteCount = byteCount
        self.bufferOffset = bufferOffset
    }

    public var end: UInt64 {
        fileOffset + UInt64(byteCount)
    }
}

/// The eviction classes, in the order they are tried.
public enum GaussianEvictionClass: Equatable, Sendable {
    case stale
    case surplus
    case displacement
}

/// One tier chosen for eviction.
public struct GaussianEvictionVictim: Equatable, Sendable {
    public let chunk: Int
    public let tier: Int
    public let kind: GaussianEvictionClass

    public init(chunk: Int, tier: Int, kind: GaussianEvictionClass) {
        self.chunk = chunk
        self.tier = tier
        self.kind = kind
    }
}

/// The tick's inputs to `GaussianPagingPolicy.selectVictims`.
public struct GaussianEvictionInputs: Sendable {
    public var tick: UInt32
    public var ranksPerPage: Int
    public var holdOffTicks: UInt32 = GaussianPagingPolicy.holdOffTicks
    public var surplusTicks: UInt32 = GaussianPagingPolicy.surplusTicks
    public var minResidencyTicks: UInt32 = GaussianPagingPolicy.minResidencyTicks
    public var swapMargin: Float = GaussianPagingPolicy.swapMargin
    /// The load priority every freed slot serves when `slotPriorities` is nil (one candidate);
    /// nil when no candidate needs a slot (no displacement).
    public var candidatePriority: Float?
    /// The load priority of the candidate the i-th freed slot serves, non-increasing (the
    /// candidates in priority order, one entry per missing tier); past its end the last entry
    /// holds. The displacement margin is tested per slot against these.
    public var slotPriorities: [Float]?
    /// Evicting down to a memory-pressure target: margin and pin are ignored.
    public var pressure = false

    public init(tick: UInt32, ranksPerPage: Int, candidatePriority: Float? = nil, slotPriorities: [Float]? = nil, pressure: Bool = false) {
        self.tick = tick
        self.ranksPerPage = ranksPerPage
        self.candidatePriority = candidatePriority
        self.slotPriorities = slotPriorities
        self.pressure = pressure
    }

    /// The priority the `index`-th victim of a call must beat by the margin.
    public func priority(forVictim index: Int) -> Float? {
        if let slotPriorities, let last = slotPriorities.last {
            return index < slotPriorities.count ? slotPriorities[index] : last
        }
        return candidatePriority
    }
}

/// One byte range of a page read: `byteCount` bytes at `fileOffset` into the pool at `poolOffset`.
public struct GaussianPageReadRange: Equatable, Sendable {
    public let fileOffset: UInt64
    public let byteCount: Int
    public let poolOffset: Int

    public init(fileOffset: UInt64, byteCount: Int, poolOffset: Int) {
        self.fileOffset = fileOffset
        self.byteCount = byteCount
        self.poolOffset = poolOffset
    }
}

/// The retire ring: a pool slot unmapped at tick T may be reused at tick T + 3, when every
/// frame that could have read it (the last is the frame before T, three command buffers back)
/// is complete under `commandBufferSemaphore`. `recycle(atTick:)` runs at the start of a tick,
/// before that tick's `retire` calls, so a bucket holds exactly the slots retired three ticks ago.
public struct GaussianPageRetireRing: Sendable {
    public static let depth = maxInFlightCommandBuffers

    private var buckets: [[UInt32]] = Array(repeating: [], count: GaussianPageRetireRing.depth)
    public private(set) var total = 0

    public init() {}

    public mutating func retire(_ slot: UInt32, atTick tick: UInt32) {
        buckets[Int(tick % UInt32(GaussianPageRetireRing.depth))].append(slot)
        total += 1
    }

    /// The slots retired `depth` ticks before `tick`, removed from the ring.
    public mutating func recycle(atTick tick: UInt32) -> [UInt32] {
        let index = Int(tick % UInt32(GaussianPageRetireRing.depth))
        let slots = buckets[index]
        buckets[index] = []
        total -= slots.count
        return slots
    }

    /// Every slot in the ring, removed (the GPU is idle: tests only).
    public mutating func drainAll() -> [UInt32] {
        let slots = buckets.flatMap { $0 }
        buckets = Array(repeating: [], count: GaussianPageRetireRing.depth)
        total = 0
        return slots
    }
}

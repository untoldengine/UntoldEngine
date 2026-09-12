//
//  GaussianPageManager.swift
//  UntoldEngine
//
//  The pager of a `.untoldgs` entity loaded above the paging threshold: its records live in a
//  bounded page pool of 256-rank tiers (`GaussianComponent.packedSplatData` is the pool) and
//  every frame the pager decides, from the demand the chunk cull wrote three frames earlier,
//  which tiers to read from disk into free pool slots and which to give up. Per in-flight slot
//  it keeps a residency table (the resident rank prefix and fade of every chunk), a page table
//  (the pool slot of every tier) and a demand table (the seen screen area of every chunk); the
//  cull skips chunks with nothing resident and lists the others with their resident ranks, so
//  the working-set budget only ever sees drawable ranks. Reads run on a background queue
//  straight into retired pool slots — a slot unmapped at tick T is reused at T + 3, when every
//  frame that could read it is complete — and completions are mapped on the render thread at
//  the next tick. One lock guards what the I/O threads touch (the inbox, the generation, the
//  state); everything else is render-thread-only.
//
//  A file with per-chunk coarse levels (per-chunk-lod-tiers) hands the pager the levels that
//  fit beside the pool (`GaussianPagerCoarseInputs`): their records buffer, outside the pool,
//  and the file range it holds. The pager streams that range through the same read queue in
//  pieces of half the in-flight cap, sequential from the coarsest level (first in the file),
//  every piece before the tier requests of its tick while the coarsest level is still landing
//  and at most one piece per tick after that, so the heads are not starved; the worker checks
//  the CRC of every level payload lying wholly inside its piece, the tick the ones straddling
//  two pieces once both have landed, and marks each verified chunk-level available in the
//  residency table (`GaussianChunkResidency.coarseAvailable`, journaled like the ranks) — the
//  cull then lists a non-resident chunk for its finest landed level. A mismatch faults the
//  entity's coarse levels (`coarseFaulted`): the driver binds `hasCoarse = 0` from then on and
//  the entity draws fine only, as before the levels existed. The wants of a chunk the level
//  rule draws coarse are zero, so its fine tiers leave as surplus, and a chunk whose level
//  changed within the fade window is no eviction victim (`.levelFade`).
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

/// The pager's state: reading, holding after the file changed (resident pages keep drawing,
/// a reopen is tried periodically), or shut down with the entity.
public enum GaussianPagerState: Equatable, Sendable {
    case active
    case faulted
    case closed
}

/// What the pager did and holds, for the profile line and the editor's inspector.
public struct GaussianPagingStats: Equatable, Sendable {
    public var poolBytes = 0
    public var slotCount = 0
    /// Pool slots mapped or being read into.
    public var residentSlots = 0
    /// Chunks with at least their head resident, and chunks resident whole.
    public var residentChunks = 0
    public var wholeChunks = 0
    public var pendingReads = 0
    public var bytesInFlight = 0
    public var issuedThisTick = 0
    public var committedThisTick = 0
    public var evictedThisTick = 0
    /// Landed tiers the tick left unmapped for the next one (its commit cap or budget reached);
    /// they count in `residentSlots` and no longer in `pendingReads`.
    public var deferredTiers = 0
    /// Requests that found no slot and nothing worth displacing, over the pager's life.
    public var saturatedCandidates = 0
    public var faultedChunks = 0
    public var corruptChunks = 0
    public var tick: UInt32 = 0
    public var state: GaussianPagerState = .active
    /// The per-chunk coarse levels (per-chunk-lod-tiers): resident runtime levels (0 none), the
    /// records buffer's bytes, the bytes of its pieces landed and verified, the chunk-levels
    /// marked available, the pieces issued over the pager's life, and whether a CRC mismatch
    /// faulted the levels (the entity then draws fine only).
    public var coarseLevels = 0
    public var coarseBytes = 0
    public var coarseBytesLanded = 0
    public var coarseChunkLevelsAvailable = 0
    public var coarseReadsIssued = 0
    public var coarseFaulted = false

    public init() {}
}

/// The frame's inputs to one tick of the pager.
struct GaussianPagerFrameInputs {
    /// The entity's cull constants this frame (the seed's views; `uniformQuotas` is ignored).
    var cullConstants: GaussianChunkCullConstants
    /// The last read-back budget state (`GaussianSharedWorkingSet.lastBudgetState`).
    var budgetState: GaussianBudgetState
    /// The frame's working-set budget in splats (`gaussianWorkingSetBudget(residentSplats:)`):
    /// what the frame could ever draw, the bound of the fill density when the frame fits.
    var budget: Int
    var uniformQuotas: Bool
    var disableWorkingSetBudget: Bool
    /// `GaussianDebugOptions.freezePaging`: no reads, no evictions.
    var freeze = false
    /// `renderInfo.frameIndex`: tells a slot's demand words from before a gap of frames.
    var frameIndex: UInt64 = 0
    /// Frames an arriving tier fades in over (`GaussianPagingPolicy.fadeFrames`, 0 with
    /// `GaussianDebugOptions.disablePageFade`).
    var fadeFrames: UInt32 = GaussianPagingPolicy.fadeFrames
    /// `GaussianChunkPagingConstants.debugMode`.
    var debugMode: UInt32 = 0
    /// The level rule's inputs for the wants of an entity with coarse levels (per-chunk-lod-tiers):
    /// the frame's density floor (`GaussianChunkLevelConstants.densityFloor`), level mode, and
    /// the frames a level switch cross-fades over (0 with `disableLevelCrossFade`: no `.levelFade`).
    var densityFloor: Float = .infinity
    var levelMode: GaussianLevelMode = .auto
    var levelFadeFrames: UInt32 = GaussianPagingPolicy.fadeFrames
}

/// The coarse section a paged entity streams (per-chunk-lod-tiers): the records buffer the
/// pieces land in (`GaussianCoarseTable.recordsBuffer`), the file range it holds and the file
/// levels resident, finest first (`GaussianCoarseTable.fileLevels`).
struct GaussianPagerCoarseInputs {
    let recordsBuffer: MTLBuffer
    let recordsRange: Range<UInt64>
    let fileLevels: [Int]
}

/// The buffers and constants the frame binds for one slot of a paged entity.
struct GaussianPagerBindings {
    let residency: MTLBuffer
    let pageTable: MTLBuffer
    let demand: MTLBuffer
    let constants: GaussianChunkPagingConstants
}

/// One event of the pager's life, recorded when `eventLogEnabled` (tests).
public struct GaussianPagingEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case issued
        case committed
        case evicted
        case recycled
        case dropped
        case failed
        case corrupt
        case faulted
        /// A piece of the coarse section issued / landed and verified (`tier` = the piece index,
        /// `chunk` −1), and a coarse payload that failed its CRC (`chunk` = its chunk).
        case coarseIssued
        case coarseCommitted
        case coarseCorrupt
    }

    public let tick: UInt32
    public let kind: Kind
    public let chunk: Int
    public let tier: Int
    public let slot: UInt32
    public let generation: UInt32
    /// The request's load priority (issued events); 0 otherwise.
    public let priority: Float
}

/// A tier read: ranks `[firstRank, firstRank + rankCount)` of one chunk into `slots` (one per
/// tier), the core bytes into the core pool and the harmonics into the SH pool. Retains the
/// manager, hence the pools, until it completes; a completion whose generation is stale (the
/// entity was removed) is dropped.
struct GaussianPageReadRequest: @unchecked Sendable {
    let manager: GaussianPageManager
    let generation: UInt32
    let chunkIndex: Int
    let firstRank: Int
    let rankCount: Int
    let slots: [UInt32]
    let slotGenerations: [UInt32]
    /// The slots of the tiers already resident below `firstRank`, for the CRC at full residency.
    let residentSlots: [UInt32]
    let core: [GaussianPageReadRange]
    let sh: [GaussianPageReadRange]
    /// Verify the chunk's CRC once this request lands (it makes the chunk fully resident).
    let verify: Bool
    let byteCount: Int
    let priority: Float
}

/// A finished read, appended to the manager's inbox by the worker.
struct GaussianPageCompletion {
    let request: GaussianPageReadRequest
    let result: Result<Void, GaussianPagingError>
}

/// One piece of the coarse section (per-chunk-lod-tiers): read into the entity's coarse records
/// buffer at the piece's offset, then the CRC of every level payload lying wholly inside it
/// (`entries`, indices into the manager's sorted coarse entries). No pool slot, no page table.
struct GaussianCoarseReadRequest: @unchecked Sendable {
    let manager: GaussianPageManager
    let generation: UInt32
    let pieceIndex: Int
    let piece: GaussianCoarsePiece
    let entries: Range<Int>

    var byteCount: Int {
        piece.byteCount
    }
}

struct GaussianCoarseCompletion {
    let request: GaussianCoarseReadRequest
    let result: Result<Void, GaussianPagingError>
}

/// An item of the pager's read queue: a tier read into the pool, or a coarse piece.
enum GaussianPagerRead: @unchecked Sendable {
    case tier(GaussianPageReadRequest)
    case coarse(GaussianCoarseReadRequest)

    var byteCount: Int {
        switch self {
        case let .tier(request): request.byteCount
        case let .coarse(request): request.byteCount
        }
    }
}

/// One level payload of the coarse section as the pager tracks it: the runtime level it is
/// (1-based; the runtime's level 1 is the file's finest resident level), its chunk, its entry,
/// and the first and last piece its bytes fall in.
struct GaussianPagerCoarseEntry {
    let level: Int
    let chunk: Int
    let entry: UntoldGSChunkEntry
    let firstPiece: Int
    let lastPiece: Int
}

/// Memory-pressure levels the pools react to (`GaussianPagePoolRegistry.noteMemoryPressure`).
public enum GaussianPagePressureLevel: Sendable {
    case warning
    case critical
}

/// Pool bytes a load has claimed from the residency budget before its pager exists, so two
/// loads running at once each see the other's claim. Converted into the pager's registration
/// by `GaussianPageManager.init`, or released when the load fails.
public struct GaussianPagePoolReservation: Equatable, Sendable {
    fileprivate let id: UInt64
}

/// A claim on the coarse levels' share of the residency budget (per-chunk-lod-tiers), held for
/// as long as the entity keeps its coarse records.
public struct GaussianCoarseReservation: Equatable, Sendable {
    fileprivate let id: UInt64
}

/// A levelled entity's claim on the coarse share, released when its last reference goes — the
/// entity's `GaussianCoarseTable`, dropped with the chunk table at removal — so the next fit
/// check sees the bytes this entity no longer holds.
final class GaussianCoarseClaim: @unchecked Sendable {
    let reservation: GaussianCoarseReservation
    /// The record bytes claimed.
    let bytes: Int

    init(reservation: GaussianCoarseReservation, bytes: Int) {
        self.reservation = reservation
        self.bytes = bytes
    }

    deinit {
        GaussianPagePoolRegistry.shared.releaseCoarse(reservation)
    }
}

/// Every live pool and every reservation in progress: their total bytes, so a second paged
/// entity gets what the residency budget leaves, and the fan-out of a memory-pressure event.
public final class GaussianPagePoolRegistry: @unchecked Sendable {
    public static let shared = GaussianPagePoolRegistry()

    private final class Entry {
        weak var manager: GaussianPageManager?
        let bytes: Int
        init(manager: GaussianPageManager, bytes: Int) {
            self.manager = manager
            self.bytes = bytes
        }
    }

    private let lock = NSLock()
    private var entries: [ObjectIdentifier: Entry] = [:]
    private var reservations: [UInt64: Int] = [:]
    private var nextReservation: UInt64 = 1
    private var _allocatedBytes = 0
    private var coarseClaims: [UInt64: Int] = [:]
    private var _coarseBytes = 0

    private init() {}

    /// Bytes of every registered pool and every reservation in progress.
    public var allocatedBytes: Int {
        lock.lock()
        defer { lock.unlock() }
        return _allocatedBytes
    }

    /// The coarse record bytes every levelled entity holds beside the pools
    /// (per-chunk-lod-tiers): what the next entity's fit check sizes its levels against, so the
    /// coarse share of the residency budget is shared by the entities rather than taken by each.
    public var coarseBytes: Int {
        lock.lock()
        defer { lock.unlock() }
        return _coarseBytes
    }

    /// Claims coarse bytes in one step: `bytes` is given the coarse bytes held so far and returns
    /// the size to claim, under the lock, so concurrent loads fit their levels against each
    /// other. Held until `releaseCoarse` (a `GaussianCoarseClaim` does so when it is dropped).
    public func reserveCoarse(bytes: (_ coarseBytes: Int) -> Int) -> GaussianCoarseReservation {
        lock.lock()
        defer { lock.unlock() }
        let claimed = max(0, bytes(_coarseBytes))
        let id = nextReservation
        nextReservation &+= 1
        coarseClaims[id] = claimed
        _coarseBytes += claimed
        return GaussianCoarseReservation(id: id)
    }

    /// Gives a coarse claim back (the entity's levels are gone, or the load failed).
    public func releaseCoarse(_ reservation: GaussianCoarseReservation) {
        lock.lock()
        defer { lock.unlock() }
        guard let bytes = coarseClaims.removeValue(forKey: reservation.id) else { return }
        _coarseBytes -= bytes
    }

    /// Claims pool bytes in one step: `bytes` is given the bytes allocated so far and returns
    /// the size to claim, under the lock, so concurrent loads size their pools against each
    /// other. The claim counts in `allocatedBytes` until it is registered or released.
    public func reserve(bytes: (_ allocatedBytes: Int) -> Int) -> GaussianPagePoolReservation {
        lock.lock()
        defer { lock.unlock() }
        let claimed = max(0, bytes(_allocatedBytes))
        let id = nextReservation
        nextReservation &+= 1
        reservations[id] = claimed
        _allocatedBytes += claimed
        return GaussianPagePoolReservation(id: id)
    }

    /// Changes a reservation's size (the pool shrank when the device refused a buffer).
    public func resize(_ reservation: GaussianPagePoolReservation, bytes: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard let previous = reservations[reservation.id] else { return }
        let claimed = max(0, bytes)
        reservations[reservation.id] = claimed
        _allocatedBytes += claimed - previous
    }

    /// Gives a reservation back (the load failed).
    public func release(_ reservation: GaussianPagePoolReservation) {
        lock.lock()
        defer { lock.unlock() }
        guard let bytes = reservations.removeValue(forKey: reservation.id) else { return }
        _allocatedBytes -= bytes
    }

    /// The bytes a reservation holds; nil once registered or released (tests).
    public func reservedBytes(_ reservation: GaussianPagePoolReservation) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        return reservations[reservation.id]
    }

    /// Registers a pager's pool bytes, converting its reservation when it has one (the bytes
    /// were counted since the claim; the difference, if any, is settled here).
    func register(_ manager: GaussianPageManager, bytes: Int, reservation: GaussianPagePoolReservation?) {
        lock.lock()
        defer { lock.unlock() }
        let key = ObjectIdentifier(manager)
        var reserved = 0
        if let reservation, let claimed = reservations.removeValue(forKey: reservation.id) {
            reserved = claimed
        }
        guard entries[key] == nil else {
            _allocatedBytes -= reserved
            return
        }
        entries[key] = Entry(manager: manager, bytes: bytes)
        _allocatedBytes += bytes - reserved
    }

    func unregister(_ key: ObjectIdentifier) {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries.removeValue(forKey: key) else { return }
        _allocatedBytes -= entry.bytes
    }

    /// Sets every live pool's soft target: half the slots on a warning, a quarter on critical,
    /// for `GaussianPagingPolicy.pressureTicks`. The pools evict down to it and issue nothing
    /// above it; the allocation itself is fixed (whole-entity eviction remains the relief).
    public func noteMemoryPressure(_ level: GaussianPagePressureLevel) {
        let fraction = level == .critical ? GaussianPagingPolicy.pressureFractionCritical : GaussianPagingPolicy.pressureFractionWarning
        lock.lock()
        let managers = entries.values.compactMap(\.manager)
        lock.unlock()
        for manager in managers {
            manager.notePressure(fraction: fraction)
        }
    }
}

/// See the file comment.
public final class GaussianPageManager: @unchecked Sendable {
    let source: any GaussianPageSource
    let index: UntoldGSIndex
    /// The file's name, for error reports.
    let label: String
    let corePool: MTLBuffer
    let shPool: MTLBuffer?
    let residencyTables: [MTLBuffer]
    let pageTables: [MTLBuffer]
    let demandTables: [MTLBuffer]
    public let chunkCount: Int
    public let ranksPerPage: Int
    public let ranksPerPageLog2: Int
    public let pagesPerChunk: Int
    public let slotCount: Int
    let shBytesPerSplat: Int
    /// Bytes of one slot across both pools.
    let slotBytes: Int

    public var poolBytes: Int {
        corePool.length + (shPool?.length ?? 0)
    }

    // MARK: Lock-guarded (the I/O threads, the LOD system, the registry)

    private let lock = NSLock()
    private var inbox: [GaussianPageCompletion] = []
    /// The landed reads a tick left unmapped (its commit cap or budget reached), in priority
    /// order; lock-guarded so a shutdown from any thread drops them with the inbox.
    private var _deferred: [GaussianPageCompletion] = []
    /// Tiers in `_deferred` after the last tick (`GaussianPagingStats.deferredTiers`).
    private var deferredTiers = 0
    private var coarseInbox: [GaussianCoarseCompletion] = []
    /// The tick's own arrays, swapped with the lock-guarded ones so no tick copies an inbox:
    /// the arrivals taken, the deferred list taken, and the merge of the two.
    private var arrivals: [GaussianPageCompletion] = []
    private var deferredTaken: [GaussianPageCompletion] = []
    private var merged: [GaussianPageCompletion] = []
    private var coarseArrivals: [GaussianCoarseCompletion] = []
    private var _generation: UInt32 = 0
    private var _state: GaussianPagerState = .active
    private var _pendingReads = 0
    private var _bytesInFlight = 0
    private var _stats = GaussianPagingStats()
    private var _warming = false
    private var _warmth: Float = 0
    private var _warmingSinceTick: UInt32?
    private var _tickForWarmth: UInt32 = 0
    private var _pressureRequest: Float?
    private var registryKey: ObjectIdentifier?

    // MARK: Render-thread state

    private(set) var tick: UInt32 = 0
    /// The per-chunk tables the tick walks, as plain columns (`chunkCount` entries each, owned
    /// by the pager): the CPU state, the constants of the chunk (its splat count, the counts of
    /// its runtime levels 1 and 2, per-chunk-lod-tiers), the level rule's availability mask
    /// (bit 0 fine, bits 1 and 2 the landed levels that have records), the positions in the
    /// dense sets below and the marks of the dirty list and the journals.
    private let states: UnsafeMutablePointer<GaussianChunkPageState>
    private let splatCounts: UnsafeMutablePointer<UInt32>
    private let coarseCounts1: UnsafeMutablePointer<UInt32>
    private let coarseCounts2: UnsafeMutablePointer<UInt32>
    private let availabilityMasks: UnsafeMutablePointer<UInt8>
    private var masterResidency: [GaussianChunkResidency]
    private var masterPageTable: [UInt32]
    private var slotChunk: [Int32]
    private var slotTier: [UInt8]
    private var slotGeneration: [UInt32]
    /// Sorted descending: `popLast` hands out the lowest free slot, so a fresh pool fills in
    /// ascending runs and a chunk's tiers coalesce into one read.
    private var freeSlots: [UInt32]
    private var retiring = GaussianPageRetireRing()
    private var journals: [[Int]]
    /// Per slot, per chunk: whether the chunk is in the slot's journal (`slot * chunkCount + chunk`).
    private let journalMarks: UnsafeMutablePointer<UInt8>
    private var journalFull: [Bool]
    private var demandStampTick: [UInt32?]
    private var demandStampFrame: [UInt64]
    /// The demand as the last ingest left it: per chunk the bits of its seen area, 0 when no
    /// view kept it. The next ingest diffs the slot's words (or the seed) against it, so only
    /// the chunks whose word changed are touched — none at a still camera.
    private let demandWords: UnsafeMutablePointer<UInt32>
    /// The tick of the last ingest: the demand stamp of every chunk seen by it (`.demanded`),
    /// and what a chunk that drops out keeps as its `lastDemandTick`.
    private var lastIngestTick: UInt32 = 0
    /// The chunks seen by the last ingest, dense, in no particular order; `demandedPosition`
    /// is each chunk's index in it (−1 when not demanded).
    private var demandedChunks: [Int32] = []
    private let demandedPosition: UnsafeMutablePointer<Int32>
    /// Σ splatCount over the demanded chunks (the fill scale's input), recomputed only when an
    /// ingest changed a word.
    private var demandedSplats = 0
    /// The fill histogram over the demanded chunks (`GaussianPagingPolicy.addFillTerm`), kept
    /// as terms come and go while the fill density is in use (the read-back cap +inf) — built
    /// from the demanded set when it comes into use, dropped while a finite cap decides the
    /// wants — and the fill density cap solved over it, cached with the room and the level
    /// rule's inputs it was solved for.
    private let fillTiers: UnsafeMutablePointer<GaussianBudgetDensityTier>
    private var fillHistogramValid = false
    private var fillHistogramVersion: UInt64 = 0
    private var fillCapVersion: UInt64 = .max
    private var fillCapRoom: Float = .nan
    private var fillCapLevelled = false
    private var fillCapFloor: Float = .nan
    private var fillCap: Float = .infinity
    /// The chunks whose own want inputs changed since their last evaluation (dense, with a
    /// mark), the spare list they are swapped into while evaluated, the frame-wide inputs the
    /// last pass ran with, and the warmth sums over the demanded chunks, maintained as their
    /// needed and resident ranks change.
    private var wantsDirty: [Int32] = []
    private var wantsDirtySpare: [Int32] = []
    private let wantsDirtyMark: UnsafeMutablePointer<UInt8>
    private var wantsInputs = WantInputs()
    private var wantsSumNeeded = 0
    private var wantsSumResidentOfNeeded = 0
    /// The chunks with their head resident, dense, in no particular order (`residentPosition`
    /// is each chunk's index in it, −1 when nothing is resident), and how many of them are
    /// resident whole — counters kept as tiers map and leave instead of a scan per tick.
    private var residentList: [Int32] = []
    private let residentPosition: UnsafeMutablePointer<Int32>
    private var wholeChunkCount = 0
    /// The chunks a tick may request, dense (`candidatePosition` as above): every chunk that
    /// wants more than it holds, is not loading, faulted or fading in, and is past its
    /// cooldown, kept up to date at every change of a chunk's state rather than found by a
    /// scan of the demanded set. A chunk that only waits for its cooldown sits in
    /// `cooldownHeap` (keyed by the tick it ends) until the tick that reaches it re-examines it.
    private var candidateChunks: [Int32] = []
    private let candidatePosition: UnsafeMutablePointer<Int32>
    private var cooldownHeap = GaussianTickHeap()
    private let cooldownQueued: UnsafeMutablePointer<UInt8>
    /// The fade-ins running, in arrival order (each entry with its arrival tick, so a chunk
    /// mapped again while an older entry is still queued is expired on its own clock), and the
    /// level cross-fades likewise, keyed by the switch tick (per-chunk-lod-tiers). Both expire
    /// from the head.
    private var fading = GaussianTickQueue()
    private var levelFading = GaussianTickQueue()
    private var lastReopenTick: UInt32 = 0

    // MARK: Coarse levels (per-chunk-lod-tiers; render-thread state)

    let coarse: GaussianPagerCoarseInputs?
    /// The pieces the section is read in, sequential from the coarsest level.
    let coarsePieces: [GaussianCoarsePiece]
    /// Every level payload in file order, with the pieces it spans.
    private let coarseEntries: [GaussianPagerCoarseEntry]
    /// Per piece, the entries lying wholly inside it (verified by its worker).
    private let coarsePieceEntries: [Range<Int>]
    /// The entries that straddle two pieces (verified by the tick once both landed), and which are done.
    private let coarseStraddlers: [Int]
    private var coarseStraddlerDone: [Bool]
    /// The end of the coarsest level's range: pieces below it precede the tick's tier requests
    /// without limit; past it one piece per tick.
    private let coarseFirstLevelEnd: UInt64
    private let coarseTierShifts: (Int, Int)
    private var coarseNextPiece = 0
    /// The pieces awaiting a retry, in failure order; each is due at `coarseRetryAfterTick`.
    private var coarseRetry: [Int] = []
    private var coarseRetryAfterTick: [UInt32]
    private var coarseLanded: [Bool]
    /// Per piece, the I/O failures since its last success: the retry schedule of the tier
    /// reads (`GaussianPagingPolicy.retryTicks`), and the levels fault when one piece exhausts it.
    private var coarseFailures: [UInt8]
    private var coarseBytesLanded = 0
    private var coarseAvailableCount = 0
    private var coarseReadsIssued = 0
    private var reportedCoarseFault = false
    /// A coarse payload failed its CRC (or its pieces kept failing): the levels are off for this
    /// entity for good; the driver binds `hasCoarse = 0` and the wants ignore the levels.
    public private(set) var coarseFaulted = false
    /// The budget state's frame count at the first tick: a readback that has not moved past it
    /// predates this entity's frames (another scene's cap) and is not applied.
    private var baselineFrameCount: UInt32?
    private var faultedChunkCount = 0
    private var corruptChunkCount = 0
    private var saturatedCandidates = 0
    private var reportedAssetFault = false
    private var reportedChunkFault = false
    private var reportedCorruption = false
    private var lastConstants: [GaussianChunkPagingConstants]
    private var pressureFraction: Float?
    private var pressureUntilTick: UInt32 = 0
    /// `handleError` calls the pager made, for tests.
    public private(set) var errorReports = 0
    /// Record every issue, commit, eviction, recycle and drop (tests; lock-guarded, a worker
    /// records the drops after a shutdown).
    public var eventLogEnabled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _eventLogEnabled }
        set { lock.lock(); _eventLogEnabled = newValue; lock.unlock() }
    }

    public var eventLog: [GaussianPagingEvent] {
        lock.lock()
        defer { lock.unlock() }
        return _eventLog
    }

    private var _eventLogEnabled = false
    private var _eventLog: [GaussianPagingEvent] = []

    private static let queue = DispatchQueue(label: "com.untold.gaussian.paging", qos: .userInitiated, attributes: .concurrent)
    /// This pager's reads running on the queue at once: `GaussianPagingPolicy.maxConcurrentReads`
    /// at its creation. The rest wait in `_pendingRequests` (lock-guarded, in issue order) and
    /// occupy no thread: a worker that finishes starts the next one.
    private let maxRunningReads: Int
    private var _runningReads = 0
    private var _pendingRequests: [GaussianPagerRead] = []
    private var _pendingHead = 0

    /// Takes the pools and the nine per-slot tables the loader allocated, initialises the tables
    /// (nothing resident, every tier absent, no demand) and registers the pool bytes, converting
    /// the load's reservation when it made one.
    init(
        source: any GaussianPageSource,
        index: UntoldGSIndex,
        label: String,
        corePool: MTLBuffer,
        shPool: MTLBuffer?,
        residencyTables: [MTLBuffer],
        pageTables: [MTLBuffer],
        demandTables: [MTLBuffer],
        slotCount: Int,
        ranksPerPage: Int,
        pagesPerChunk: Int,
        reservation: GaussianPagePoolReservation? = nil,
        coarse: GaussianPagerCoarseInputs? = nil
    ) {
        self.source = source
        self.index = index
        self.label = label
        self.coarse = coarse
        // The coarse section's plan: the pieces of its range, every level payload in file order
        // with the pieces it spans, and per piece the payloads its worker verifies.
        if let coarse {
            let pieceBytes = GaussianPagingPolicy.coarsePieceBytes()
            let base = coarse.recordsRange.lowerBound
            coarsePieces = GaussianPagingPolicy.coarsePieces(rangeStart: base, rangeEnd: coarse.recordsRange.upperBound, pieceBytes: pieceBytes)
            var entries: [GaussianPagerCoarseEntry] = []
            for (runtimeLevel, fileLevel) in coarse.fileLevels.enumerated() {
                for chunk in index.chunks.indices {
                    guard let entry = index.coarseEntry(level: fileLevel, chunk: chunk) else { continue }
                    let first = Int((entry.payloadOffset - base) / UInt64(pieceBytes))
                    let last = Int((entry.payloadOffset + UInt64(entry.payloadBytes) - 1 - base) / UInt64(pieceBytes))
                    entries.append(GaussianPagerCoarseEntry(level: runtimeLevel + 1, chunk: chunk, entry: entry, firstPiece: first, lastPiece: last))
                }
            }
            entries.sort { $0.entry.payloadOffset < $1.entry.payloadOffset }
            coarseEntries = entries
            var pieceEntries = Array(repeating: 0 ..< 0, count: coarsePieces.count)
            var straddlers: [Int] = []
            var cursor = 0
            for piece in coarsePieces.indices {
                // The payloads are sorted and disjoint, so their first pieces never decrease:
                // past everything that began in an earlier piece (ended there, or a straddler
                // listed with its first piece), the payloads wholly inside this piece follow,
                // and at most one more begins here and ends later — the piece's straddler.
                while cursor < entries.count, entries[cursor].firstPiece < piece {
                    cursor += 1
                }
                let start = cursor
                var end = start
                while end < entries.count, entries[end].firstPiece == piece, entries[end].lastPiece == piece {
                    end += 1
                }
                pieceEntries[piece] = start ..< end
                cursor = end
                if cursor < entries.count, entries[cursor].firstPiece == piece {
                    straddlers.append(cursor)
                    cursor += 1
                }
            }
            coarsePieceEntries = pieceEntries
            coarseStraddlers = straddlers
            coarseStraddlerDone = Array(repeating: false, count: straddlers.count)
            coarseLanded = Array(repeating: false, count: coarsePieces.count)
            coarseRetryAfterTick = Array(repeating: 0, count: coarsePieces.count)
            coarseFailures = Array(repeating: 0, count: coarsePieces.count)
            let coarsestRange = coarse.fileLevels.last.flatMap { index.coarseLevelRange(level: $0) }
            coarseFirstLevelEnd = coarsestRange?.upperBound ?? base
            let ratios = coarse.fileLevels.map { index.header.coarseRatioLog2[$0 - 1] }
            coarseTierShifts = (
                GaussianChunkCullMath.tierShift(ratioLog2: ratios[0]),
                GaussianChunkCullMath.tierShift(ratioLog2: ratios[min(1, ratios.count - 1)])
            )
        } else {
            coarsePieces = []
            coarseEntries = []
            coarsePieceEntries = []
            coarseStraddlers = []
            coarseStraddlerDone = []
            coarseLanded = []
            coarseRetryAfterTick = []
            coarseFailures = []
            coarseFirstLevelEnd = 0
            coarseTierShifts = (0, 0)
        }
        self.corePool = corePool
        self.shPool = shPool
        self.residencyTables = residencyTables
        self.pageTables = pageTables
        self.demandTables = demandTables
        self.slotCount = slotCount
        self.ranksPerPage = ranksPerPage
        ranksPerPageLog2 = max(0, ranksPerPage.trailingZeroBitCount)
        self.pagesPerChunk = pagesPerChunk
        chunkCount = index.chunks.count
        shBytesPerSplat = index.header.shBytesPerSplat
        slotBytes = ranksPerPage * (UntoldGSFormat.coreRecordSize + shBytesPerSplat)
        maxRunningReads = max(1, GaussianPagingPolicy.maxConcurrentReads)

        let columns = max(1, chunkCount)
        states = .allocate(capacity: columns)
        states.initialize(repeating: GaussianChunkPageState(), count: columns)
        splatCounts = .allocate(capacity: columns)
        coarseCounts1 = .allocate(capacity: columns)
        coarseCounts2 = .allocate(capacity: columns)
        availabilityMasks = .allocate(capacity: columns)
        for chunk in 0 ..< columns {
            splatCounts[chunk] = chunk < chunkCount ? index.chunks[chunk].splatCount : 0
            var m1: UInt32 = 0
            var m2: UInt32 = 0
            if let coarse, chunk < chunkCount {
                m1 = index.coarseEntry(level: coarse.fileLevels[0], chunk: chunk)?.splatCount ?? 0
                m2 = coarse.fileLevels.count > 1 ? (index.coarseEntry(level: coarse.fileLevels[1], chunk: chunk)?.splatCount ?? 0) : m1
            }
            coarseCounts1[chunk] = m1
            coarseCounts2[chunk] = m2
            availabilityMasks[chunk] = 1
        }
        demandedPosition = .allocate(capacity: columns)
        demandedPosition.initialize(repeating: -1, count: columns)
        wantsDirtyMark = .allocate(capacity: columns)
        wantsDirtyMark.initialize(repeating: 0, count: columns)
        residentPosition = .allocate(capacity: columns)
        residentPosition.initialize(repeating: -1, count: columns)
        candidatePosition = .allocate(capacity: columns)
        candidatePosition.initialize(repeating: -1, count: columns)
        cooldownQueued = .allocate(capacity: columns)
        cooldownQueued.initialize(repeating: 0, count: columns)
        masterResidency = Array(repeating: GaussianChunkResidency(residentRanks: 0, fadeFromRank: 0, arrivalFrame: 0, coarseAvailable: 0), count: chunkCount)
        masterPageTable = Array(repeating: kGaussianPageSlotInvalid, count: chunkCount * pagesPerChunk)
        slotChunk = Array(repeating: -1, count: slotCount)
        slotTier = Array(repeating: 0, count: slotCount)
        slotGeneration = Array(repeating: 0, count: slotCount)
        freeSlots = (0 ..< slotCount).reversed().map { UInt32($0) }
        let slots = residencyTables.count
        journals = Array(repeating: [], count: slots)
        journalMarks = .allocate(capacity: max(1, slots * chunkCount))
        journalMarks.initialize(repeating: 0, count: max(1, slots * chunkCount))
        journalFull = Array(repeating: false, count: slots)
        demandStampTick = Array(repeating: nil, count: slots)
        demandStampFrame = Array(repeating: 0, count: slots)
        demandWords = UnsafeMutablePointer<UInt32>.allocate(capacity: columns)
        demandWords.initialize(repeating: 0, count: columns)
        fillTiers = .allocate(capacity: gaussianDensityTierCount)
        fillTiers.initialize(repeating: GaussianBudgetDensityTier(), count: gaussianDensityTierCount)
        lastConstants = Array(repeating: GaussianChunkPagingConstants(), count: slots)
        for k in 0 ..< slots {
            copyMasterTables(toSlot: k)
            memset(demandTables[k].contents(), 0, demandTables[k].length)
        }
        let key = ObjectIdentifier(self)
        registryKey = key
        GaussianPagePoolRegistry.shared.register(self, bytes: poolBytes, reservation: reservation)
    }

    deinit {
        shutdown()
        source.close()
        demandWords.deallocate()
        fillTiers.deallocate()
        states.deallocate()
        splatCounts.deallocate()
        coarseCounts1.deallocate()
        coarseCounts2.deallocate()
        availabilityMasks.deallocate()
        demandedPosition.deallocate()
        wantsDirtyMark.deallocate()
        residentPosition.deallocate()
        candidatePosition.deallocate()
        cooldownQueued.deallocate()
        journalMarks.deallocate()
    }

    // MARK: Public state

    public var state: GaussianPagerState {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }

    public var stats: GaussianPagingStats {
        lock.lock()
        defer { lock.unlock() }
        return _stats
    }

    /// The resident ranks of a chunk as the master tables hold them (tests, the inspector).
    public func residentRanks(of chunk: Int) -> UInt32 {
        masterResidency[chunk].residentRanks
    }

    /// The pager's CPU state of a chunk (tests, the inspector). A demanded chunk's
    /// `lastDemandTick` is the tick of the last ingest, which stamps the chunks it sees through
    /// `.demanded` rather than one by one.
    public func chunkState(_ chunk: Int) -> GaussianChunkPageState {
        var state = states[chunk]
        if state.flags.contains(.demanded) { state.lastDemandTick = lastIngestTick }
        return state
    }

    /// The raw bits of `GaussianChunkPageState.Flags`, for the tick's own tests.
    private enum PageFlag {
        static let loading = GaussianChunkPageState.Flags.loading.rawValue
        static let faulted = GaussianChunkPageState.Flags.faulted.rawValue
        static let fadeActive = GaussianChunkPageState.Flags.fadeActive.rawValue
        static let levelFade = GaussianChunkPageState.Flags.levelFade.rawValue
        static let demanded = GaussianChunkPageState.Flags.demanded.rawValue
    }

    /// The pool slot of a tier, or nil (tests).
    public func poolSlot(chunk: Int, tier: Int) -> UInt32? {
        let slot = masterPageTable[chunk * pagesPerChunk + tier]
        return slot == kGaussianPageSlotInvalid ? nil : slot
    }

    /// The coarse levels landed and verified for a chunk, as the master residency holds them
    /// (bit 0 the runtime's level 1, bit 1 its level 2; tests, the inspector).
    public func coarseAvailable(of chunk: Int) -> UInt32 {
        masterResidency[chunk].coarseAvailable
    }

    /// Whether every piece of the coarse section has landed.
    public var coarseSectionLanded: Bool {
        coarse != nil && !coarseLanded.contains(false)
    }

    /// The runtime levels' splat counts of a chunk (the level-2 count is the level-1 count when
    /// one level is resident), 0 without levels.
    func coarseCounts(chunk: Int) -> (UInt32, UInt32) {
        guard coarse != nil else { return (0, 0) }
        return (coarseCounts1[chunk], coarseCounts2[chunk])
    }

    /// Free slots and slots waiting in the retire ring (tests).
    public var freeSlotCount: Int {
        freeSlots.count
    }

    public var retiringSlotCount: Int {
        retiring.total
    }

    /// The LOD system is waiting for this tier to warm before switching to it: its demand is
    /// culled every frame (`encodeGaussianChunkDemand`) and the pager fills it.
    public var warming: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _warming }
        set {
            lock.lock()
            defer { lock.unlock() }
            if newValue, !_warming { _warmingSinceTick = _tickForWarmth }
            if !newValue { _warmingSinceTick = nil }
            _warming = newValue
        }
    }

    /// Whether the demanded chunks hold `GaussianPagingPolicy.warmFraction` of their wanted
    /// ranks, or the warming has gone on for `warmTimeoutTicks`.
    public var isWarm: Bool {
        lock.lock()
        defer { lock.unlock() }
        guard _state != .closed, _tickForWarmth > 0 else { return false }
        if let since = _warmingSinceTick, _tickForWarmth &- since >= GaussianPagingPolicy.warmTimeoutTicks {
            return true
        }
        return _warmth >= GaussianPagingPolicy.warmFraction
    }

    /// The bindings of `slot` as the last tick left them, for the fused pass of the same frame.
    func bindings(slot: Int) -> GaussianPagerBindings {
        GaussianPagerBindings(residency: residencyTables[slot], pageTable: pageTables[slot], demand: demandTables[slot], constants: lastConstants[slot])
    }

    /// Stops the pager: no read is issued after this, the reads waiting to start and the
    /// completions waiting for a tick are dropped here (every one holds the manager, and no
    /// tick will ever drain them), completions of the reads still running are dropped by the
    /// generation check, the pool bytes leave the registry, and the source closes when the last
    /// running read releases it. In-flight frames keep the pools alive through their command
    /// buffers.
    public func shutdown() {
        lock.lock()
        guard _state != .closed else {
            lock.unlock()
            return
        }
        _generation &+= 1
        _state = .closed
        _stats.state = .closed
        var dropped: [GaussianPageReadRequest] = _deferred.map(\.request)
        dropped.append(contentsOf: inbox.map(\.request))
        _deferred.removeAll()
        inbox.removeAll()
        coarseInbox.removeAll()
        let pending = _pendingRequests[_pendingHead...]
        for request in pending {
            _pendingReads -= 1
            _bytesInFlight -= request.byteCount
            if case let .tier(tierRequest) = request {
                dropped.append(tierRequest)
            }
        }
        _pendingRequests.removeAll()
        _pendingHead = 0
        _stats.pendingReads = _pendingReads
        _stats.bytesInFlight = _bytesInFlight
        if _eventLogEnabled {
            for request in dropped {
                for slot in request.slots {
                    _eventLog.append(GaussianPagingEvent(tick: tick, kind: .dropped, chunk: request.chunkIndex, tier: request.firstRank / ranksPerPage, slot: slot, generation: 0, priority: 0))
                }
            }
        }
        let idle = _pendingReads == 0
        let key = registryKey
        registryKey = nil
        lock.unlock()
        if let key { GaussianPagePoolRegistry.shared.unregister(key) }
        if idle { source.close() }
    }

    /// Every slot in the retire ring becomes free at once. Only when no command buffer is in
    /// flight (tests that drive frames by hand and wait for each one): a slot the ring still
    /// holds may be mapped by the page table of a frame the GPU is executing, and the read that
    /// takes it would write over records that frame decodes. Debug builds assert that the last
    /// frame is complete; the method is not engine API.
    func noteGPUIdle() {
        assert(
            (renderInfo.lastCommandBuffer as MTLCommandBuffer?).map { $0.status == .completed || $0.status == .error || $0.status == .notEnqueued } ?? true,
            "GaussianPageManager.noteGPUIdle with a command buffer in flight"
        )
        let slots = retiring.drainAll()
        for slot in slots {
            slotGeneration[Int(slot)] &+= 1
            log(.recycled, chunk: -1, tier: 0, slot: slot)
        }
        addFreeSlots(slots)
    }

    /// Called by the registry on a memory-pressure event, from its thread; the next tick applies it.
    func notePressure(fraction: Float) {
        lock.lock()
        _pressureRequest = fraction
        lock.unlock()
    }

    // MARK: The tick

    /// One tick for the frame that owns `slot`: recycle the slots retired three ticks ago, map
    /// the reads that landed, ingest this slot's demand (or the CPU seed), compute the wanted
    /// ranks, evict, issue reads, bring the slot's tables up to date, and return what to bind.
    /// A warming tier (`warming`, the LOD system's pending switch) takes the same tick: its
    /// demand words come from its demand-only cull and its reads are issued like a live
    /// entity's — the tier has to fill before the switch (`isWarm`) — and of the bindings
    /// returned only the demand table is bound, since no frame draws it yet.
    func tick(slot: Int, frame: GaussianPagerFrameInputs) -> GaussianPagerBindings {
        tick &+= 1
        let now = tick
        var issued = 0
        var committed = 0
        var evicted = 0

        // 1. The slots retired three ticks ago are free again.
        let recycled = retiring.recycle(atTick: now)
        for slot in recycled {
            slotGeneration[Int(slot)] &+= 1
            log(.recycled, chunk: -1, tier: 0, slot: slot)
        }
        addFreeSlots(recycled)

        // 2. Landed reads, and the coarse pieces that landed.
        committed += drainInbox(now: now, fadeFrames: frame.fadeFrames)
        drainCoarseInbox(now: now)

        // 3. Fades that are done.
        expireFades(now: now, fadeFrames: frame.fadeFrames)
        expireLevelFades(now: now, fadeFrames: frame.levelFadeFrames)

        // 4. A faulted source tries to reopen periodically.
        var active = state == .active
        if state == .faulted, now &- lastReopenTick >= GaussianPagingPolicy.faultReopenTicks {
            lastReopenTick = now
            if (try? source.reopen()) != nil {
                setState(.active)
                active = true
            }
        }

        if active {
            let pressure = takePressureRequest(now: now)
            // 5. Demand.
            ingestDemand(slot: slot, frame: frame, now: now)
            // 6. Wanted ranks.
            computeWants(frame: frame, now: now)
            // 7 and 8. Eviction and reads.
            if !frame.freeze {
                let result = issueReads(now: now, pressureTarget: pressure)
                issued = result.issued
                evicted = result.evicted
            }
        }

        // 9. This slot's tables and stamp.
        applyJournal(slot: slot)
        demandStampTick[slot] = now
        demandStampFrame[slot] = frame.frameIndex

        var constants = GaussianChunkPagingConstants()
        constants.pagesPerChunk = UInt32(pagesPerChunk)
        constants.ranksPerPageLog2 = UInt32(ranksPerPageLog2)
        constants.frameIndex = now
        constants.fadeFrames = frame.fadeFrames
        constants.debugMode = frame.debugMode
        lastConstants[slot] = constants

        publishStats(now: now, issued: issued, committed: committed, evicted: evicted)
        return bindings(slot: slot)
    }

    private func setState(_ state: GaussianPagerState) {
        lock.lock()
        if _state != .closed {
            _state = state
            _stats.state = state
        }
        lock.unlock()
    }

    private func takePressureRequest(now: UInt32) -> Int? {
        lock.lock()
        let request = _pressureRequest
        _pressureRequest = nil
        lock.unlock()
        if let request {
            pressureFraction = request
            pressureUntilTick = now &+ GaussianPagingPolicy.pressureTicks
        }
        guard let fraction = pressureFraction else { return nil }
        if now >= pressureUntilTick {
            pressureFraction = nil
            return nil
        }
        return Int(Float(slotCount) * fraction)
    }

    private func publishStats(now: UInt32, issued: Int, committed: Int, evicted: Int) {
        var stats = GaussianPagingStats()
        stats.poolBytes = poolBytes
        stats.slotCount = slotCount
        stats.residentSlots = slotCount - freeSlots.count - retiring.total
        stats.residentChunks = residentList.count
        stats.wholeChunks = wholeChunkCount
        stats.issuedThisTick = issued
        stats.committedThisTick = committed
        stats.evictedThisTick = evicted
        stats.deferredTiers = deferredTiers
        stats.saturatedCandidates = saturatedCandidates
        stats.faultedChunks = faultedChunkCount
        stats.corruptChunks = corruptChunkCount
        stats.tick = now
        if let coarse {
            stats.coarseLevels = coarseFaulted ? 0 : coarse.fileLevels.count
            stats.coarseBytes = coarse.recordsBuffer.length
            stats.coarseBytesLanded = coarseBytesLanded
            stats.coarseChunkLevelsAvailable = coarseAvailableCount
            stats.coarseReadsIssued = coarseReadsIssued
            stats.coarseFaulted = coarseFaulted
        }
        lock.lock()
        stats.pendingReads = _pendingReads
        stats.bytesInFlight = _bytesInFlight
        stats.state = _state
        _stats = stats
        _tickForWarmth = now
        lock.unlock()
    }

    // MARK: Completions

    /// Maps the landed reads in priority order — the arrivals since the last tick sorted and
    /// merged with the ones an earlier tick deferred — until `maxCommitsPerTick` tiers are
    /// mapped or `commitBudget` of the tick's time is spent (past the first completion, so a
    /// slow tick still makes progress; on the monotonic clock, so a step of the wall clock
    /// neither stalls nor unbounds a tick); the rest wait, in order, for the next tick. A
    /// failed read frees its slots at once (never mapped, never referenced by a frame). Ties on
    /// the priority break on the chunk, then the rank.
    private func drainInbox(now: UInt32, fadeFrames: UInt32) -> Int {
        lock.lock()
        swap(&inbox, &arrivals)
        swap(&_deferred, &deferredTaken)
        let generation = _generation
        lock.unlock()
        deferredTiers = 0
        guard !arrivals.isEmpty || !deferredTaken.isEmpty else { return 0 }
        arrivals.sort { GaussianPageManager.before($0, $1) }
        merged.removeAll(keepingCapacity: true)
        merged.reserveCapacity(arrivals.count + deferredTaken.count)
        var a = 0
        var d = 0
        while a < arrivals.count, d < deferredTaken.count {
            if GaussianPageManager.before(deferredTaken[d], arrivals[a]) {
                merged.append(deferredTaken[d])
                d += 1
            } else {
                merged.append(arrivals[a])
                a += 1
            }
        }
        merged.append(contentsOf: arrivals[a...])
        merged.append(contentsOf: deferredTaken[d...])
        arrivals.removeAll(keepingCapacity: true)
        deferredTaken.removeAll(keepingCapacity: true)

        var committed = 0
        let commitCap = GaussianPagingPolicy.maxCommitsPerTick
        // The budget in nanoseconds of the monotonic clock; +inf (no clock) stays +inf.
        let budgetNanoseconds = GaussianPagingPolicy.commitBudget * 1e9
        let start = DispatchTime.now().uptimeNanoseconds
        var overBudget = false
        var sinceClock = 0
        for completion in merged {
            let request = completion.request
            let chunk = request.chunkIndex
            let stale = request.generation != generation
                || zip(request.slots, request.slotGenerations).contains { slotGeneration[Int($0)] != $1 }
            if stale {
                for slot in request.slots {
                    log(.dropped, chunk: chunk, tier: request.firstRank / ranksPerPage, slot: slot)
                }
                continue
            }
            switch completion.result {
            case .success:
                let tiers = request.slots.count
                if committed > 0 {
                    if !overBudget, sinceClock >= 16 {
                        sinceClock = 0
                        overBudget = Double(DispatchTime.now().uptimeNanoseconds &- start) >= budgetNanoseconds
                    }
                    if overBudget || committed + tiers > commitCap {
                        deferredTaken.append(completion)
                        continue
                    }
                }
                map(request, now: now, fadeFrames: fadeFrames)
                committed += tiers
                sinceClock += tiers
            case let .failure(error):
                fail(request, error: error, now: now)
            }
        }
        merged.removeAll(keepingCapacity: true)
        if !deferredTaken.isEmpty {
            // The deferred list was taken whole and nothing else writes it: the ones left are
            // put back, still in order — unless a shutdown ran meanwhile (its generation bump
            // and `.closed` show under the lock), which dropped the list it found empty: they
            // are dropped here as it would have, since no tick drains a closed pager and each
            // completion holds the manager.
            lock.lock()
            if _state != .closed, _generation == generation {
                for completion in deferredTaken {
                    deferredTiers += completion.request.slots.count
                }
                swap(&_deferred, &deferredTaken)
            } else if _eventLogEnabled {
                for completion in deferredTaken {
                    let request = completion.request
                    for slot in request.slots {
                        _eventLog.append(GaussianPagingEvent(tick: tick, kind: .dropped, chunk: request.chunkIndex, tier: request.firstRank / ranksPerPage, slot: slot, generation: 0, priority: 0))
                    }
                }
            }
            lock.unlock()
            deferredTaken.removeAll(keepingCapacity: true)
        }
        return committed
    }

    /// The commit order: priority descending, then the chunk, then the first rank.
    private static func before(_ a: GaussianPageCompletion, _ b: GaussianPageCompletion) -> Bool {
        let x = a.request
        let y = b.request
        if x.priority != y.priority { return x.priority > y.priority }
        if x.chunkIndex != y.chunkIndex { return x.chunkIndex < y.chunkIndex }
        return x.firstRank < y.firstRank
    }

    private func map(_ request: GaussianPageReadRequest, now: UInt32, fadeFrames: UInt32) {
        let chunk = request.chunkIndex
        let firstTier = request.firstRank / ranksPerPage
        let row = chunk * pagesPerChunk
        for (offset, slot) in request.slots.enumerated() {
            masterPageTable[row + firstTier + offset] = slot
            slotChunk[Int(slot)] = Int32(chunk)
            slotTier[Int(slot)] = UInt8(firstTier + offset)
            log(.committed, chunk: chunk, tier: firstTier + offset, slot: slot)
        }
        let resident = UInt32(request.firstRank + request.rankCount)
        // The coarse availability bits (per-chunk-lod-tiers) ride in the same struct and survive the rewrite.
        masterResidency[chunk] = GaussianPagingPolicy.mappedResidency(previous: masterResidency[chunk], firstRank: request.firstRank, rankCount: request.rankCount, now: now)
        var state = states[chunk]
        let before = wantContribution(state)
        let wholeBefore = Int(state.residentRanks) >= Int(splatCounts[chunk])
        state.residentRanks = UInt16(resident)
        state.fadeFromRank = UInt16(request.firstRank)
        state.arrivalTick = now
        state.mappedAtTick = now
        state.flags.remove(.loading)
        if fadeFrames > 0 {
            state.flags.insert(.fadeActive)
            fading.push(chunk: chunk, tick: now)
        }
        states[chunk] = state
        let after = wantContribution(state)
        wantsSumNeeded += after.needed - before.needed
        wantsSumResidentOfNeeded += after.resident - before.resident
        if Int(resident) >= Int(splatCounts[chunk]), !wholeBefore { wholeChunkCount += 1 }
        markWantsDirty(chunk)
        if residentPosition[chunk] < 0 {
            residentPosition[chunk] = Int32(residentList.count)
            residentList.append(Int32(chunk))
        }
        stateChanged(chunk, now: now)
        journal(chunk)
    }

    private func fail(_ request: GaussianPageReadRequest, error: GaussianPagingError, now: UInt32) {
        let chunk = request.chunkIndex
        let tier = request.firstRank / ranksPerPage
        for slot in request.slots {
            slotChunk[Int(slot)] = -1
            log(.failed, chunk: chunk, tier: tier, slot: slot)
        }
        addFreeSlots(request.slots)
        states[chunk].flags.remove(.loading)
        defer { stateChanged(chunk, now: now) }

        switch error {
        case .closed:
            return
        case .fileChanged, .truncated:
            faultAsset(reason: "\(error)", now: now)
        case .corrupt:
            evictChunk(chunk, now: now)
            faultChunk(chunk)
            corruptChunkCount += 1
            if !reportedCorruption {
                reportedCorruption = true
                report("chunk \(chunk) of \(label) failed its CRC once fully resident; the chunk is dropped")
            }
        case .ioFailure:
            states[chunk].failures &+= 1
            let failures = Int(states[chunk].failures)
            if failures >= GaussianPagingPolicy.retryTicks.count + 1 || failures > GaussianPagingPolicy.retryTicks.count {
                faultChunk(chunk)
                if !reportedChunkFault {
                    reportedChunkFault = true
                    report("chunk \(chunk) of \(label) could not be read (\(error)); the chunk is dropped")
                }
            } else {
                states[chunk].retryAfterTick = now &+ GaussianPagingPolicy.retryTicks[failures - 1]
            }
        }
        // A failing disk, not a bad chunk: more than a percent of the chunks (and more than a
        // handful, so one corrupt chunk of a small asset does not fault the whole).
        if faultedChunkCount >= GaussianPagingPolicy.faultedChunkMinimum,
           Double(faultedChunkCount) > GaussianPagingPolicy.faultedChunkFraction * Double(max(1, chunkCount)),
           state == .active
        {
            faultAsset(reason: "\(faultedChunkCount) chunks faulted", now: now)
        }
    }

    private func faultChunk(_ chunk: Int) {
        guard !states[chunk].flags.contains(.faulted) else { return }
        states[chunk].flags.insert(.faulted)
        faultedChunkCount += 1
        stateChanged(chunk, now: tick)
        log(.faulted, chunk: chunk, tier: 0, slot: kGaussianPageSlotInvalid)
    }

    private func faultAsset(reason: String, now: UInt32) {
        guard state == .active else { return }
        setState(.faulted)
        lastReopenTick = now
        if !reportedAssetFault {
            reportedAssetFault = true
            report("\(label) changed under the pager (\(reason)); its resident pages keep drawing until the file is back")
        }
    }

    private func report(_ message: String) {
        errorReports += 1
        handleError(.assetDataMissing, "Gaussian paging: \(message)")
    }

    private func expireFades(now: UInt32, fadeFrames: UInt32) {
        // The fade reaches 1 at arrival + fadeFrames - 1 (the kernel counts the arrival frame).
        // The queue is in arrival order, so the head is the first to be done; an entry older
        // than the chunk's last arrival only leaves the queue.
        while let head = fading.head, fadeFrames == 0 || now &- head.tick &+ 1 >= fadeFrames {
            fading.pop()
            let chunk = Int(head.chunk)
            guard states[chunk].arrivalTick == head.tick else { continue }
            states[chunk].flags.remove(.fadeActive)
            stateChanged(chunk, now: now)
        }
    }

    /// The level cross-fades that are done: `.levelFade` held the chunk's tiers for `fadeFrames`
    /// ticks from its last level change (per-chunk-lod-tiers). The queue is in switch order; an
    /// entry older than the chunk's last switch only leaves the queue.
    private func expireLevelFades(now: UInt32, fadeFrames: UInt32) {
        while let head = levelFading.head, fadeFrames == 0 || now &- head.tick >= fadeFrames {
            levelFading.pop()
            let chunk = Int(head.chunk)
            guard states[chunk].levelSwitchTick == head.tick else { continue }
            states[chunk].flags.remove(.levelFade)
        }
    }

    // MARK: The candidate set

    /// A chunk's state changed: whether it may be requested is re-examined. A chunk that only
    /// waits for its cooldown is queued for the tick the cooldown ends.
    private func stateChanged(_ chunk: Int, now: UInt32) {
        let state = states + chunk
        let flags = state.pointee.flags.rawValue
        let ready = flags & PageFlag.demanded != 0
            && state.pointee.neededRanks > state.pointee.residentRanks
            && flags & (PageFlag.loading | PageFlag.faulted | PageFlag.fadeActive) == 0
        let member = ready && state.pointee.retryAfterTick <= now
        if ready, !member, cooldownQueued[chunk] == 0 {
            cooldownQueued[chunk] = 1
            cooldownHeap.push(chunk: chunk, tick: state.pointee.retryAfterTick)
        }
        let position = Int(candidatePosition[chunk])
        if member, position < 0 {
            candidatePosition[chunk] = Int32(candidateChunks.count)
            candidateChunks.append(Int32(chunk))
        } else if !member, position >= 0 {
            let last = candidateChunks.removeLast()
            if position < candidateChunks.count {
                candidateChunks[position] = last
                candidatePosition[Int(last)] = Int32(position)
            }
            candidatePosition[chunk] = -1
        }
    }

    /// The chunks whose cooldown ended by `now` are re-examined.
    private func expireCooldowns(now: UInt32) {
        while let head = cooldownHeap.head, head.tick <= now {
            cooldownHeap.pop()
            let chunk = Int(head.chunk)
            cooldownQueued[chunk] = 0
            stateChanged(chunk, now: now)
        }
    }

    // MARK: Coarse levels (per-chunk-lod-tiers)

    /// Issues the coarse section's pieces at the head of a tick's reads: the retries that are
    /// due first, then the cursor, sequential from the coarsest level — every piece the in-flight
    /// cap allows while the coarsest level is still landing, one piece per tick after it. Returns
    /// the pieces issued.
    private func issueCoarseReads(now: UInt32) -> Int {
        guard coarse != nil, !coarseFaulted else { return 0 }
        lock.lock()
        var inFlight = _bytesInFlight
        let generation = _generation
        lock.unlock()
        let byteCap = GaussianPagingPolicy.maxPageBytesInFlight
        var issued = 0
        var issuedPastFirstLevel = 0
        while true {
            let pieceIndex: Int
            var retryPosition: Int?
            if let position = coarseRetry.firstIndex(where: { coarseRetryAfterTick[$0] <= now }) {
                pieceIndex = coarseRetry[position]
                retryPosition = position
            } else if coarseNextPiece < coarsePieces.count {
                pieceIndex = coarseNextPiece
            } else {
                break
            }
            let piece = coarsePieces[pieceIndex]
            if piece.fileOffset >= coarseFirstLevelEnd {
                guard issuedPastFirstLevel == 0 else { break }
            }
            guard inFlight == 0 || inFlight + piece.byteCount <= byteCap else { break }
            if let retryPosition {
                coarseRetry.remove(at: retryPosition)
            } else {
                coarseNextPiece += 1
            }
            if piece.fileOffset >= coarseFirstLevelEnd { issuedPastFirstLevel += 1 }
            let request = GaussianCoarseReadRequest(manager: self, generation: generation, pieceIndex: pieceIndex, piece: piece, entries: coarsePieceEntries[pieceIndex])
            log(.coarseIssued, chunk: -1, tier: pieceIndex, slot: kGaussianPageSlotInvalid)
            enqueue(.coarse(request))
            inFlight += piece.byteCount
            issued += 1
            coarseReadsIssued += 1
        }
        return issued
    }

    /// The worker: the piece into the records buffer, then the CRC of every level payload wholly
    /// inside it against its entry.
    private func performCoarse(_ request: GaussianCoarseReadRequest) -> Result<Void, GaussianPagingError> {
        lock.lock()
        let closed = _state == .closed || request.generation != _generation
        lock.unlock()
        if closed { return .failure(.closed) }
        guard let coarse else { return .failure(.closed) }
        let base = coarse.recordsBuffer.contents()
        do {
            try source.read(offset: request.piece.fileOffset, count: request.piece.byteCount, into: base + request.piece.bufferOffset)
        } catch let error as GaussianPagingError {
            return .failure(error)
        } catch {
            return .failure(.ioFailure(errno: EIO))
        }
        for entryIndex in request.entries where !verifyCoarseEntry(coarseEntries[entryIndex]) {
            return .failure(.corrupt(chunk: coarseEntries[entryIndex].chunk))
        }
        return .success(())
    }

    /// The CRC of one level payload in the records buffer against its entry.
    private func verifyCoarseEntry(_ entry: GaussianPagerCoarseEntry) -> Bool {
        guard let coarse else { return false }
        let offset = Int(entry.entry.payloadOffset - coarse.recordsRange.lowerBound)
        let bytes = UnsafeRawBufferPointer(start: UnsafeRawPointer(coarse.recordsBuffer.contents()) + offset, count: Int(entry.entry.coreBytes))
        var crc = UntoldGSCRC32.initialValue
        UntoldGSCRC32.update(&crc, bytes)
        return UntoldGSCRC32.finalize(crc) == entry.entry.crc32
    }

    private func completeCoarse(_ request: GaussianCoarseReadRequest, result: Result<Void, GaussianPagingError>) {
        lock.lock()
        _pendingReads -= 1
        _bytesInFlight -= request.byteCount
        _stats.pendingReads = _pendingReads
        _stats.bytesInFlight = _bytesInFlight
        if _state != .closed, request.generation == _generation {
            coarseInbox.append(GaussianCoarseCompletion(request: request, result: result))
        }
        let closeSource = _state == .closed && _pendingReads == 0
        lock.unlock()
        if closeSource {
            source.close()
        }
    }

    /// The landed pieces: their payloads become available, the straddling payloads whose pieces
    /// have all landed are verified here, a failed piece is retried on the tier reads' schedule
    /// (`retryTicks`: three times with a growing back-off, counted per piece, so a stall across
    /// several pieces costs each one retry; the levels fault when one piece exhausts it), a
    /// corrupt payload faults the levels, a changed file faults the asset as a tier does.
    private func drainCoarseInbox(now: UInt32) {
        lock.lock()
        swap(&coarseInbox, &coarseArrivals)
        let generation = _generation
        lock.unlock()
        guard !coarseArrivals.isEmpty else { return }
        defer { coarseArrivals.removeAll(keepingCapacity: true) }
        for completion in coarseArrivals {
            let request = completion.request
            guard request.generation == generation else { continue }
            switch completion.result {
            case .success:
                guard !coarseFaulted else { continue }
                coarseLanded[request.pieceIndex] = true
                coarseFailures[request.pieceIndex] = 0
                coarseBytesLanded += request.byteCount
                for entryIndex in request.entries {
                    markCoarse(coarseEntries[entryIndex])
                }
                log(.coarseCommitted, chunk: -1, tier: request.pieceIndex, slot: kGaussianPageSlotInvalid)
                verifyStraddlers(touching: request.pieceIndex)
            case let .failure(error):
                switch error {
                case .closed:
                    continue
                case let .corrupt(chunk):
                    faultCoarse(reason: "the coarse level of chunk \(chunk) failed its CRC", chunk: chunk)
                case .fileChanged, .truncated:
                    // Re-issued as soon as the source is reopened.
                    coarseRetryAfterTick[request.pieceIndex] = now
                    coarseRetry.append(request.pieceIndex)
                    faultAsset(reason: "\(error)", now: now)
                case .ioFailure:
                    coarseFailures[request.pieceIndex] &+= 1
                    let failures = Int(coarseFailures[request.pieceIndex])
                    if failures > GaussianPagingPolicy.retryTicks.count {
                        faultCoarse(reason: "piece \(request.pieceIndex) of the coarse section could not be read (\(error))", chunk: -1)
                    } else {
                        coarseRetryAfterTick[request.pieceIndex] = now &+ GaussianPagingPolicy.retryTicks[failures - 1]
                        coarseRetry.append(request.pieceIndex)
                    }
                }
            }
        }
    }

    /// Verifies the payloads straddling `piece` and a neighbour once every piece they span has landed.
    private func verifyStraddlers(touching piece: Int) {
        for (position, entryIndex) in coarseStraddlers.enumerated() where !coarseStraddlerDone[position] {
            let entry = coarseEntries[entryIndex]
            guard entry.firstPiece <= piece, piece <= entry.lastPiece else { continue }
            guard (entry.firstPiece ... entry.lastPiece).allSatisfy({ coarseLanded[$0] }) else { continue }
            coarseStraddlerDone[position] = true
            if verifyCoarseEntry(entry) {
                markCoarse(entry)
            } else {
                faultCoarse(reason: "the coarse level of chunk \(entry.chunk) failed its CRC", chunk: entry.chunk)
                return
            }
        }
    }

    /// One chunk-level landed and verified: its bit in the residency table, journaled to every slot.
    private func markCoarse(_ entry: GaussianPagerCoarseEntry) {
        let bit = UInt32(1) << UInt32(entry.level - 1)
        guard masterResidency[entry.chunk].coarseAvailable & bit == 0 else { return }
        masterResidency[entry.chunk].coarseAvailable |= bit
        coarseAvailableCount += 1
        let available = masterResidency[entry.chunk].coarseAvailable
        availabilityMasks[entry.chunk] = 1
            | ((available & 1) != 0 && coarseCounts1[entry.chunk] > 0 ? 2 : 0)
            | ((available & 2) != 0 && coarseCounts2[entry.chunk] > 0 ? 4 : 0)
        markWantsDirty(entry.chunk)
        journal(entry.chunk)
    }

    /// The coarse levels are off for this entity for good: reported once; the availability bits
    /// stay (the driver binds `hasCoarse = 0`, so no kernel reads them).
    private func faultCoarse(reason: String, chunk: Int) {
        guard !coarseFaulted else { return }
        coarseFaulted = true
        coarseRetry.removeAll()
        log(.coarseCorrupt, chunk: chunk, tier: 0, slot: kGaussianPageSlotInvalid)
        if !reportedCoarseFault {
            reportedCoarseFault = true
            report("\(reason) in \(label); its coarse levels are off, the entity draws its fine records only")
        }
    }

    // MARK: Demand and wants

    /// This slot's demand words when they are this entity's and recent, else the CPU seed
    /// (frustum and area for every chunk, no HZB), diffed against the last ingest: a chunk whose
    /// word changed is (re)stamped, enters or leaves the demanded set; the others are not
    /// touched. The slot's words are compared a block at a time (`memcmp`), so a still camera
    /// costs a scan of the table and nothing per chunk.
    private func ingestDemand(slot: Int, frame: GaussianPagerFrameInputs, now: UInt32) {
        var changed = false
        let fresh = demandStampTick[slot] != nil && frame.frameIndex &- demandStampFrame[slot] <= GaussianPagingPolicy.seedGapFrames
        if fresh {
            let words = demandTables[slot].contents().bindMemory(to: UInt32.self, capacity: chunkCount)
            let block = 256
            var chunk = 0
            while chunk < chunkCount {
                let end = min(chunk + block, chunkCount)
                if memcmp(words + chunk, demandWords + chunk, (end - chunk) * MemoryLayout<UInt32>.size) == 0 {
                    chunk = end
                    continue
                }
                while chunk < end {
                    var bits = words[chunk]
                    if bits != 0 {
                        let area = Float(bitPattern: bits)
                        if !(area > 0 && area.isFinite) { bits = 0 }
                    }
                    if bits != demandWords[chunk] {
                        noteDemand(chunk: chunk, bits: bits)
                        changed = true
                    }
                    chunk += 1
                }
            }
        } else {
            var constants = frame.cullConstants
            constants.uniformQuotas = 0
            for chunk in 0 ..< chunkCount {
                let area = GaussianPageManager.seedArea(entry: index.chunks[chunk], constants: constants)
                let bits = area > 0 ? area.bitPattern : 0
                if bits != demandWords[chunk] {
                    noteDemand(chunk: chunk, bits: bits)
                    changed = true
                }
            }
        }
        if changed {
            var totalSplats = 0
            for chunk in 0 ..< chunkCount where demandWords[chunk] != 0 {
                totalSplats += Int(splatCounts[chunk])
            }
            demandedSplats = totalSplats
        }
        lastIngestTick = now
    }

    /// A chunk's demand word changed: its area, and its membership of the demanded set. A chunk
    /// that drops out keeps the tick of the last ingest that saw it as its `lastDemandTick`.
    private func noteDemand(chunk: Int, bits: UInt32) {
        let previous = demandWords[chunk]
        demandWords[chunk] = bits
        let state = states + chunk
        if fillHistogramValid {
            let counts = (coarseCounts1[chunk], coarseCounts2[chunk])
            if previous != 0 {
                GaussianPagingPolicy.addFillTerm(to: fillTiers, splatCount: splatCounts[chunk], area: Float(bitPattern: previous), coarseCounts: counts, sign: -1)
            }
            if bits != 0 {
                GaussianPagingPolicy.addFillTerm(to: fillTiers, splatCount: splatCounts[chunk], area: Float(bitPattern: bits), coarseCounts: counts, sign: 1)
            }
            fillHistogramVersion &+= 1
        }
        if bits == 0 {
            let needed = Int(state.pointee.neededRanks)
            wantsSumNeeded -= needed
            wantsSumResidentOfNeeded -= min(needed, Int(state.pointee.residentRanks))
            state.pointee.lastDemandTick = lastIngestTick
            state.pointee.flags = GaussianChunkPageState.Flags(rawValue: state.pointee.flags.rawValue & ~PageFlag.demanded)
            let position = Int(demandedPosition[chunk])
            let last = demandedChunks.removeLast()
            if position < demandedChunks.count {
                demandedChunks[position] = last
                demandedPosition[Int(last)] = Int32(position)
            }
            demandedPosition[chunk] = -1
            stateChanged(chunk, now: tick)
            return
        }
        state.pointee.lastArea = Float(bitPattern: bits)
        if previous == 0 {
            state.pointee.flags = GaussianChunkPageState.Flags(rawValue: state.pointee.flags.rawValue | PageFlag.demanded)
            demandedPosition[chunk] = Int32(demandedChunks.count)
            demandedChunks.append(Int32(chunk))
            let needed = Int(state.pointee.neededRanks)
            wantsSumNeeded += needed
            wantsSumResidentOfNeeded += min(needed, Int(state.pointee.residentRanks))
        }
        if wantsDirtyMark[chunk] == 0 {
            wantsDirtyMark[chunk] = 1
            wantsDirty.append(Int32(chunk))
        }
    }

    /// The area the cull would write for a chunk it keeps in some view (frustum only), 0 when
    /// no view keeps it: `GaussianChunkCullMath.chunkScreenArea` without the minimum clamp of a
    /// rejected chunk.
    static func seedArea(entry: UntoldGSChunkEntry, constants: GaussianChunkCullConstants) -> Float {
        let box = GaussianChunkCullMath.paddedBox(aabbMin: entry.aabbMin, aabbMax: entry.aabbMax, logScaleMax: entry.logScaleMax)
        let limit = max(0, 1 + constants.clipGuardBand)
        var kept = false
        var area: Float = 0
        let view0 = GaussianChunkCullMath.screenArea(boxMin: box.min, boxMax: box.max, viewProjection: constants.viewProjection0, clipGuardBand: constants.clipGuardBand)
        if view0.passes {
            kept = true
            area = max(area, view0.area)
        }
        if constants.viewCount > 1 {
            let view1 = GaussianChunkCullMath.screenArea(boxMin: box.min, boxMax: box.max, viewProjection: constants.viewProjection1, clipGuardBand: constants.clipGuardBand)
            if view1.passes {
                kept = true
                area = max(area, view1.area)
            }
        }
        guard kept else { return 0 }
        return min(max(area, gaussianScreenAreaMin), limit * limit)
    }

    private func computeWants(frame: GaussianPagerFrameInputs, now: UInt32) {
        let totalSplats = demandedSplats
        // A readback that predates this entity's frames (the state is zero, or it is another
        // scene's) says nothing about this entity: the frame is taken as fitting until a frame
        // that saw the entity has been read back.
        let state = frame.budgetState
        if let baseline = baselineFrameCount, state.frameCount < baseline {
            baselineFrameCount = state.frameCount
        }
        if baselineFrameCount == nil { baselineFrameCount = state.frameCount }
        let stale = state.frameCount == 0 || state.frameCount <= (baselineFrameCount ?? 0)
        let cap = stale ? Float.infinity : state.densityCap
        let reserved = stale ? 0 : Int(state.reservedSplats)
        // The uniform rule's scale is an input of the wants under `uniformQuotas` only: NaN
        // otherwise, so a change of the demanded set alone (which moves the scale) does not
        // re-evaluate every demanded chunk when only the changed chunk's own inputs did.
        let fillScale: Float = frame.uniformQuotas
            ? GaussianPagingPolicy.fillScale(budget: frame.budget, reservedSplats: reserved, demandedSplats: totalSplats)
            : .nan
        // The level rule's inputs when the entity draws its coarse levels this frame: a chunk the
        // rule draws coarse wants no fine rank (its tiers leave as surplus), and the CPU keeps a
        // mirror of the level drawn to hold the tiers of a chunk mid-fade (`.levelFade`).
        let levelsOn = coarse != nil && !coarseFaulted && !frame.uniformQuotas && !frame.disableWorkingSetBudget && frame.levelMode != .fineOnly
        // The fill density when the frame fits: the cap the solve would settle at with every
        // demanded chunk resident whole, solved over the fill histogram when it, the room or
        // the level rule's inputs changed. A finite cap decides the wants instead, and the
        // histogram is neither kept nor solved while it does.
        var fill: Float = .nan
        if cap.isFinite {
            fillHistogramValid = false
        } else {
            if !fillHistogramValid {
                fillTiers.update(repeating: GaussianBudgetDensityTier(), count: gaussianDensityTierCount)
                demandedChunks.withUnsafeBufferPointer { demanded in
                    for position in 0 ..< demanded.count {
                        let chunk = Int(demanded[position])
                        GaussianPagingPolicy.addFillTerm(to: fillTiers, splatCount: splatCounts[chunk], area: Float(bitPattern: demandWords[chunk]), coarseCounts: (coarseCounts1[chunk], coarseCounts2[chunk]), sign: 1)
                    }
                }
                fillHistogramValid = true
                fillHistogramVersion &+= 1
            }
            let room = GaussianPagingPolicy.fillRoom(budget: frame.budget, reservedSplats: reserved)
            let levelledFill = levelsOn && frame.levelMode == .auto
            if fillCapVersion != fillHistogramVersion || fillCapRoom.bitPattern != room.bitPattern || fillCapLevelled != levelledFill || fillCapFloor.bitPattern != frame.densityFloor.bitPattern {
                fillCapVersion = fillHistogramVersion
                fillCapRoom = room
                fillCapLevelled = levelledFill
                fillCapFloor = frame.densityFloor
                var histogram = GaussianBudgetDensityHistogram()
                withUnsafeMutableBytes(of: &histogram.tiers) { bytes in
                    bytes.bindMemory(to: GaussianBudgetDensityTier.self).baseAddress!.update(from: fillTiers, count: gaussianDensityTierCount)
                }
                fillCap = GaussianPagingPolicy.fillDensityCap(histogram: histogram, room: room, levels: levelledFill ? (frame.densityFloor, coarseTierShifts) : nil)
            }
            fill = fillCap
        }
        let effectiveCap = cap.isFinite ? cap : fill
        let inputs = WantInputs(
            cap: cap,
            fill: fill,
            fillScale: fillScale,
            effectiveCap: effectiveCap,
            densityFloor: frame.densityFloor,
            // The level rule's cap side, once per pass.
            levelCap: GaussianChunkCullMath.levelCap(densityCap: effectiveCap, densityFloor: frame.densityFloor),
            uniformQuotas: frame.uniformQuotas,
            disableWorkingSetBudget: frame.disableWorkingSetBudget,
            levelsOn: levelsOn,
            levelMode: frame.levelMode,
            levelFadeFrames: frame.levelFadeFrames
        )
        // The rule is a function of the frame-wide inputs, the chunk's own (area, residency,
        // landed levels) and the level it drew last: a chunk is re-evaluated when one of its own
        // changed (`wantsDirty`), every demanded chunk when the frame-wide ones did, and one
        // whose drawn level moved is re-evaluated next tick again until it settles — the same
        // sequence of evaluations the per-tick pass made, minus the ones that could not change.
        if inputs != wantsInputs {
            wantsInputs = inputs
            for chunk in wantsDirty {
                wantsDirtyMark[Int(chunk)] = 0
            }
            wantsDirty.removeAll(keepingCapacity: true)
            demandedChunks.withUnsafeBufferPointer { demanded in
                for position in 0 ..< demanded.count {
                    evaluateWant(chunk: Int(demanded[position]), inputs: inputs, now: now)
                }
            }
        } else if !wantsDirty.isEmpty {
            swap(&wantsDirty, &wantsDirtySpare)
            wantsDirtySpare.withUnsafeBufferPointer { dirty in
                for position in 0 ..< dirty.count {
                    let chunk = Int(dirty[position])
                    wantsDirtyMark[chunk] = 0
                    guard states[chunk].flags.rawValue & PageFlag.demanded != 0 else { continue }
                    evaluateWant(chunk: chunk, inputs: inputs, now: now)
                }
            }
            wantsDirtySpare.removeAll(keepingCapacity: true)
        }
        let warmth: Float = wantsSumNeeded == 0 ? 1 : Float(wantsSumResidentOfNeeded) / Float(wantsSumNeeded)
        lock.lock()
        _warmth = warmth
        lock.unlock()
    }

    /// The frame-wide inputs of the wants pass; a change re-evaluates every demanded chunk.
    private struct WantInputs: Equatable {
        var cap: Float = .nan
        var fill: Float = .nan
        var fillScale: Float = .nan
        var effectiveCap: Float = .nan
        var densityFloor: Float = .nan
        var levelCap = GaussianChunkCullMath.LevelCap()
        var uniformQuotas = false
        var disableWorkingSetBudget = false
        var levelsOn = false
        var levelMode: GaussianLevelMode = .auto
        var levelFadeFrames: UInt32 = 0

        static func == (lhs: WantInputs, rhs: WantInputs) -> Bool {
            lhs.cap.bitPattern == rhs.cap.bitPattern && lhs.fill.bitPattern == rhs.fill.bitPattern
                && lhs.fillScale.bitPattern == rhs.fillScale.bitPattern && lhs.effectiveCap.bitPattern == rhs.effectiveCap.bitPattern
                && lhs.densityFloor.bitPattern == rhs.densityFloor.bitPattern && lhs.uniformQuotas == rhs.uniformQuotas
                && lhs.disableWorkingSetBudget == rhs.disableWorkingSetBudget && lhs.levelsOn == rhs.levelsOn
                && lhs.levelMode == rhs.levelMode && lhs.levelFadeFrames == rhs.levelFadeFrames
        }
    }

    /// One chunk through the want rule, the level mirror and the surplus clock:
    /// `GaussianPagingPolicy.wantedRanks`, `coarseLevel` and `neededRanks` over the pager's
    /// columns through the rules they share (`GaussianChunkCullMath.level(mode:deltaTier:…)`,
    /// `GaussianPagingPolicy.fineWant`), the level rule's tier distance computed once for both
    /// the want (as if the chunk drew fine last tick) and the mirror of the level drawn.
    private func evaluateWant(chunk: Int, inputs: WantInputs, now: UInt32) {
        let count = splatCounts[chunk]
        let state = states + chunk
        let area = state.pointee.lastArea
        let residentRanks = state.pointee.residentRanks
        var flags = state.pointee.flags.rawValue
        let neededBefore = Int(state.pointee.neededRanks)
        let residentBefore = min(neededBefore, Int(residentRanks))

        var want: UInt32
        var drawn: UInt8 = 0
        if inputs.disableWorkingSetBudget {
            want = count
        } else if inputs.uniformQuotas {
            want = GaussianChunkCullMath.quota(scale: inputs.fillScale, splatCount: count)
        } else if inputs.levelsOn, area > 0 {
            // The rule with fine assumed drawn and available (the want), and with the level
            // drawn last and fine available only when a rank is resident (the mirror).
            let mask = UInt32(availabilityMasks[chunk])
            let mirrorMask = residentRanks > 0 ? mask : mask & ~1
            let deltaTier = GaussianChunkCullMath.levelDeltaTier(cap: inputs.levelCap, splatCount: count, screenArea: area)
            let wantLevel = GaussianChunkCullMath.level(mode: inputs.levelMode, deltaTier: deltaTier, previous: 0, available: mask, tierShifts: coarseTierShifts)
            let mirrorLevel = GaussianChunkCullMath.level(mode: inputs.levelMode, deltaTier: deltaTier, previous: Int(state.pointee.drawnLevel), available: mirrorMask, tierShifts: coarseTierShifts)
            want = GaussianPagingPolicy.fineWant(level: wantLevel, cap: inputs.effectiveCap, splatCount: count, area: area)
            drawn = UInt8(mirrorLevel)
        } else {
            want = GaussianChunkCullMath.quota(densityCap: inputs.effectiveCap, splatCount: count, screenArea: area)
        }
        if drawn != state.pointee.drawnLevel {
            state.pointee.drawnLevel = drawn
            state.pointee.levelSwitchTick = now
            if inputs.levelFadeFrames > 0 {
                flags |= PageFlag.levelFade
                levelFading.push(chunk: chunk, tick: now)
            }
            // The rule's hysteresis reads the level drawn last: once more next tick.
            markWantsDirty(chunk)
        }
        let needed = GaussianPagingPolicy.neededRanks(want: want, splatCount: count)
        state.pointee.neededRanks = UInt16(needed)
        let residentTiers = (Int(residentRanks) + ranksPerPage - 1) / ranksPerPage
        let wantedTiers = (Int(needed) + ranksPerPage - 1) / ranksPerPage
        if residentTiers > wantedTiers {
            if state.pointee.surplusSinceTick == 0 { state.pointee.surplusSinceTick = now }
        } else {
            state.pointee.surplusSinceTick = 0
        }
        state.pointee.flags = GaussianChunkPageState.Flags(rawValue: flags)
        if flags & PageFlag.demanded != 0 {
            wantsSumNeeded += Int(needed) - neededBefore
            wantsSumResidentOfNeeded += min(Int(needed), Int(residentRanks)) - residentBefore
        }
        stateChanged(chunk, now: now)
    }

    /// A demanded chunk's share of the warmth sums: its needed ranks, and the resident ones
    /// among them. Nothing for a chunk not demanded.
    private func wantContribution(_ state: GaussianChunkPageState) -> (needed: Int, resident: Int) {
        guard state.flags.contains(.demanded) else { return (0, 0) }
        let needed = Int(state.neededRanks)
        return (needed, min(needed, Int(state.residentRanks)))
    }

    /// The chunk's own want inputs changed: its area, its residency or its landed levels.
    private func markWantsDirty(_ chunk: Int) {
        guard wantsDirtyMark[chunk] == 0 else { return }
        wantsDirtyMark[chunk] = 1
        wantsDirty.append(Int32(chunk))
    }

    private func tiers(_ ranks: UInt16) -> Int {
        (Int(ranks) + ranksPerPage - 1) / ranksPerPage
    }

    // MARK: Eviction and reads

    private func issueReads(now: UInt32, pressureTarget: Int?) -> (issued: Int, evicted: Int) {
        var evicted = 0
        // The coarse section's pieces first: outside the pool, counted in the bytes in flight the
        // tier requests below respect.
        let coarseIssued = issueCoarseReads(now: now)
        let residentSlots = slotCount - freeSlots.count - retiring.total

        // Under pressure: down to the soft target, nothing issued above it, and nothing issued
        // that would carry the pool back above it.
        if let target = pressureTarget, residentSlots > target {
            let victims = selectVictims(
                count: min(residentSlots - target, GaussianPagingPolicy.maxEvictionsPerTick),
                inputs: GaussianEvictionInputs(tick: now, ranksPerPage: ranksPerPage, pressure: true)
            )
            for victim in victims {
                evict(chunk: victim.chunk, tier: victim.tier, now: now)
                evicted += 1
            }
            return (coarseIssued, evicted)
        }
        var issuableSlots = pressureTarget.map { max(0, $0 - residentSlots) } ?? Int.max

        // The candidates by priority, ties on the chunk index: the best `maxReads` of the set.
        expireCooldowns(now: now)
        let maxReads = GaussianPagingPolicy.maxPageReadsPerTick
        let candidates = topCandidates(count: maxReads, now: now)
        guard !candidates.isEmpty else { return (coarseIssued, evicted) }

        // Evict ahead: enough for the candidates beyond what is free or retiring. The free and
        // retiring slots serve the candidates in priority order, so the missing slots are the
        // tail of that order: the displacement margin is tested per missing slot against the
        // priority of the candidate it serves, not the best candidate's alone (the stale and
        // surplus classes are free of consequence and need no margin).
        let neededSlots = candidates.reduce(0) { $0 + $1.tiers }
        let available = freeSlots.count + retiring.total
        if neededSlots > available {
            let shortfall = min(neededSlots - available, GaussianPagingPolicy.maxEvictionsPerTick)
            var slotPriorities: [Float] = []
            slotPriorities.reserveCapacity(shortfall)
            var cumulative = 0
            for candidate in candidates where slotPriorities.count < shortfall {
                let end = cumulative + candidate.tiers
                var slot = max(cumulative, available)
                while slot < end, slotPriorities.count < shortfall {
                    slotPriorities.append(candidate.priority)
                    slot += 1
                }
                cumulative = end
            }
            let victims = selectVictims(
                count: shortfall,
                inputs: GaussianEvictionInputs(tick: now, ranksPerPage: ranksPerPage, candidatePriority: candidates.first?.priority, slotPriorities: slotPriorities)
            )
            for victim in victims {
                evict(chunk: victim.chunk, tier: victim.tier, now: now)
                evicted += 1
            }
            // Saturated: the requests whose slots nothing free, retiring or worth displacing
            // covers. A request waiting only for the retire ring is not one of them.
            if victims.count < shortfall {
                let covered = available + victims.count
                cumulative = 0
                for candidate in candidates {
                    cumulative += candidate.tiers
                    if cumulative > covered { saturatedCandidates += 1 }
                }
            }
        }

        // Issue in priority order while the caps allow and free slots suffice.
        var issued = coarseIssued
        var issuedBytes = 0
        lock.lock()
        let inFlight = _bytesInFlight
        let generation = _generation
        lock.unlock()
        let byteCap = GaussianPagingPolicy.maxPageBytesInFlight
        for candidate in candidates {
            guard issued < maxReads else { break }
            let chunk = candidate.chunk
            let state = states[chunk]
            // The evict-ahead may have taken this candidate's own tail for a stronger request:
            // it then waits out the reload cooldown like any evicted chunk instead of fetching
            // the tier back in the same tick.
            guard GaussianPagingPolicy.isLoadCandidate(state, tick: now) else { continue }
            let count = Int(index.chunks[chunk].splatCount)
            let firstTier = tiers(state.residentRanks)
            let lastTier = GaussianPagingPolicy.tiersNeeded(needed: UInt32(state.neededRanks), ranksPerPage: ranksPerPage)
            let tierCount = lastTier - firstTier
            guard tierCount > 0 else { continue }
            let firstRank = Int(state.residentRanks)
            let rankCount = min(count, lastTier * ranksPerPage) - firstRank
            guard rankCount > 0 else { continue }
            let bytes = rankCount * (UntoldGSFormat.coreRecordSize + shBytesPerSplat)
            if inFlight + issuedBytes + bytes > byteCap, inFlight + issuedBytes > 0 {
                break
            }
            guard tierCount <= issuableSlots else { break }
            // Not enough free slots yet: the ones evicted ahead for it are in the retire ring.
            guard freeSlots.count >= tierCount else { continue }
            issuableSlots -= tierCount
            var slots: [UInt32] = []
            slots.reserveCapacity(tierCount)
            for _ in 0 ..< tierCount {
                slots.append(freeSlots.removeLast())
            }
            let ranges = GaussianPagingPolicy.coalesceRequest(
                chunk: index.chunks[chunk],
                firstRank: firstRank,
                rankCount: rankCount,
                slots: slots,
                ranksPerPage: ranksPerPage,
                shBytesPerSplat: shBytesPerSplat
            )
            let row = chunk * pagesPerChunk
            let residentSlots = (0 ..< firstTier).map { masterPageTable[row + $0] }
            let request = GaussianPageReadRequest(
                manager: self,
                generation: generation,
                chunkIndex: chunk,
                firstRank: firstRank,
                rankCount: rankCount,
                slots: slots,
                slotGenerations: slots.map { slotGeneration[Int($0)] },
                residentSlots: residentSlots,
                core: ranges.core,
                sh: ranges.sh,
                verify: GaussianPagingPolicy.verifyPagedChunkCRC && firstRank + rankCount == count,
                byteCount: bytes,
                priority: candidate.priority
            )
            for (offset, slot) in slots.enumerated() {
                slotChunk[Int(slot)] = Int32(chunk)
                slotTier[Int(slot)] = UInt8(firstTier + offset)
                log(.issued, chunk: chunk, tier: firstTier + offset, slot: slot, priority: candidate.priority)
            }
            states[chunk].flags.insert(.loading)
            stateChanged(chunk, now: now)
            enqueue(.tier(request))
            issued += 1
            issuedBytes += bytes
        }
        return (issued, evicted)
    }

    /// Unmaps one tier: the master tables, the journals, the retire ring, the reload cooldown.
    /// Tiers are evicted from the top down, so the prefix invariant holds at every step.
    private func evict(chunk: Int, tier: Int, now: UInt32) {
        let row = chunk * pagesPerChunk
        let slot = masterPageTable[row + tier]
        guard slot != kGaussianPageSlotInvalid else { return }
        masterPageTable[row + tier] = kGaussianPageSlotInvalid
        let resident = UInt32(tier * ranksPerPage)
        masterResidency[chunk].residentRanks = resident
        var state = states[chunk]
        let before = wantContribution(state)
        let wholeBefore = Int(state.residentRanks) >= Int(splatCounts[chunk])
        state.residentRanks = UInt16(resident)
        state.retryAfterTick = max(state.retryAfterTick, now &+ GaussianPagingPolicy.reloadCooldownTicks)
        if tiers(state.residentRanks) <= GaussianPagingPolicy.tiersNeeded(needed: UInt32(state.neededRanks), ranksPerPage: ranksPerPage) {
            state.surplusSinceTick = 0
        }
        if state.fadeFromRank >= UInt16(resident) {
            state.flags.remove(.fadeActive)
        }
        states[chunk] = state
        let after = wantContribution(state)
        wantsSumNeeded += after.needed - before.needed
        wantsSumResidentOfNeeded += after.resident - before.resident
        if wholeBefore { wholeChunkCount -= 1 }
        markWantsDirty(chunk)
        if tier == 0 {
            let position = Int(residentPosition[chunk])
            let last = residentList.removeLast()
            if position < residentList.count {
                residentList[position] = last
                residentPosition[Int(last)] = Int32(position)
            }
            residentPosition[chunk] = -1
        }
        stateChanged(chunk, now: now)
        slotChunk[Int(slot)] = -1
        retiring.retire(slot, atTick: now)
        journal(chunk)
        log(.evicted, chunk: chunk, tier: tier, slot: slot)
    }

    /// `GaussianPagingPolicy.selectVictims` over the pager's own tables.
    private func selectVictims(count: Int, inputs: GaussianEvictionInputs) -> [GaussianEvictionVictim] {
        residentList.withUnsafeBufferPointer { resident in
            GaussianPagingPolicy.selectVictims(states: UnsafeBufferPointer(start: states, count: chunkCount), resident: resident, count: count, inputs: inputs)
        }
    }

    /// The best `count` candidates by priority (ties on the chunk index) with the tiers each
    /// is missing, in that order: a scan of the candidate set, and a bounded heap when the set
    /// is larger than `count`.
    private func topCandidates(count: Int, now: UInt32) -> [(chunk: Int, priority: Float, tiers: Int)] {
        var candidates: [(chunk: Int, priority: Float, tiers: Int)] = []
        candidates.reserveCapacity(min(count, candidateChunks.count))
        var selection = GaussianCandidateSelection(capacity: count)
        let ranksPerPage = ranksPerPage
        candidateChunks.withUnsafeBufferPointer { members in
            for position in 0 ..< members.count {
                let chunk = Int(members[position])
                let state = states[chunk]
                guard GaussianPagingPolicy.isLoadCandidate(state, tick: now) else { continue }
                let needed = Int(state.neededRanks)
                let resident = Int(state.residentRanks)
                let priority = GaussianPagingPolicy.loadPriority(area: state.lastArea, residentRanks: UInt32(resident), neededRanks: UInt32(needed), ranksPerPage: ranksPerPage)
                guard priority > 0 else { continue }
                let missing = (needed + ranksPerPage - 1) / ranksPerPage - (resident + ranksPerPage - 1) / ranksPerPage
                guard missing > 0 else { continue }
                selection.offer(chunk: chunk, priority: priority, tiers: missing)
            }
        }
        selection.drain(into: &candidates)
        return candidates
    }

    private func evictChunk(_ chunk: Int, now: UInt32) {
        let top = tiers(states[chunk].residentRanks)
        for tier in stride(from: top - 1, through: 0, by: -1) {
            evict(chunk: chunk, tier: tier, now: now)
        }
    }

    private func addFreeSlots(_ slots: [UInt32]) {
        guard !slots.isEmpty else { return }
        if freeSlots.isEmpty {
            freeSlots = slots.sorted(by: >)
            return
        }
        // Merge into the descending list.
        let incoming = slots.sorted(by: >)
        var merged: [UInt32] = []
        merged.reserveCapacity(freeSlots.count + incoming.count)
        var a = 0
        var b = 0
        while a < freeSlots.count, b < incoming.count {
            if freeSlots[a] >= incoming[b] {
                merged.append(freeSlots[a])
                a += 1
            } else {
                merged.append(incoming[b])
                b += 1
            }
        }
        merged.append(contentsOf: freeSlots[a...])
        merged.append(contentsOf: incoming[b...])
        freeSlots = merged
    }

    // MARK: Journals

    private func journal(_ chunk: Int) {
        for slot in journals.indices where !journalFull[slot] {
            let mark = journalMarks + (slot * chunkCount + chunk)
            guard mark.pointee == 0 else { continue }
            mark.pointee = 1
            journals[slot].append(chunk)
            if journals[slot].count > chunkCount / 4 {
                journalFull[slot] = true
                journals[slot].removeAll(keepingCapacity: true)
            }
        }
    }

    private func applyJournal(slot: Int) {
        if journalFull[slot] {
            copyMasterTables(toSlot: slot)
            journalFull[slot] = false
            (journalMarks + slot * chunkCount).update(repeating: 0, count: chunkCount)
            journals[slot].removeAll(keepingCapacity: true)
            return
        }
        guard !journals[slot].isEmpty else { return }
        let residency = residencyTables[slot].contents().bindMemory(to: GaussianChunkResidency.self, capacity: chunkCount)
        let pages = pageTables[slot].contents().bindMemory(to: UInt32.self, capacity: chunkCount * pagesPerChunk)
        for chunk in journals[slot] {
            residency[chunk] = masterResidency[chunk]
            let row = chunk * pagesPerChunk
            for tier in 0 ..< pagesPerChunk {
                pages[row + tier] = masterPageTable[row + tier]
            }
            journalMarks[slot * chunkCount + chunk] = 0
        }
        journals[slot].removeAll(keepingCapacity: true)
    }

    private func copyMasterTables(toSlot slot: Int) {
        masterResidency.withUnsafeBytes { bytes in
            residencyTables[slot].contents().copyMemory(from: bytes.baseAddress!, byteCount: bytes.count)
        }
        masterPageTable.withUnsafeBytes { bytes in
            pageTables[slot].contents().copyMemory(from: bytes.baseAddress!, byteCount: bytes.count)
        }
    }

    // MARK: I/O

    /// Queues a request and starts it if a running slot is free. Nothing blocks on the queue:
    /// at most `maxRunningReads` of this pager's reads occupy a thread, the rest wait in the
    /// list in issue (priority) order until a worker finishes and pulls the next one.
    private func enqueue(_ request: GaussianPagerRead) {
        lock.lock()
        _pendingReads += 1
        _bytesInFlight += request.byteCount
        _pendingRequests.append(request)
        lock.unlock()
        startPendingReads()
    }

    /// Dispatches waiting requests while running slots are free.
    private func startPendingReads() {
        lock.lock()
        var starting: [GaussianPagerRead] = []
        while _runningReads < maxRunningReads, _pendingHead < _pendingRequests.count {
            starting.append(_pendingRequests[_pendingHead])
            _pendingHead += 1
            _runningReads += 1
        }
        if _pendingHead == _pendingRequests.count {
            _pendingRequests.removeAll(keepingCapacity: true)
            _pendingHead = 0
        } else if _pendingHead > 64, _pendingHead * 2 > _pendingRequests.count {
            _pendingRequests.removeFirst(_pendingHead)
            _pendingHead = 0
        }
        lock.unlock()
        for request in starting {
            GaussianPageManager.queue.async {
                let manager: GaussianPageManager
                switch request {
                case let .tier(tierRequest):
                    manager = tierRequest.manager
                    let result = manager.perform(tierRequest)
                    manager.complete(tierRequest, result: result)
                case let .coarse(coarseRequest):
                    manager = coarseRequest.manager
                    let result = manager.performCoarse(coarseRequest)
                    manager.completeCoarse(coarseRequest, result: result)
                }
                manager.lock.lock()
                manager._runningReads -= 1
                manager.lock.unlock()
                manager.startPendingReads()
            }
        }
    }

    /// The worker: the request's ranges into the pools, then the chunk's CRC when the request
    /// completes it.
    private func perform(_ request: GaussianPageReadRequest) -> Result<Void, GaussianPagingError> {
        lock.lock()
        let closed = _state == .closed || request.generation != _generation
        lock.unlock()
        if closed { return .failure(.closed) }
        do {
            let coreBase = corePool.contents()
            for range in request.core {
                try source.read(offset: range.fileOffset, count: range.byteCount, into: coreBase + range.poolOffset)
            }
            if let shPool {
                let shBase = shPool.contents()
                for range in request.sh {
                    try source.read(offset: range.fileOffset, count: range.byteCount, into: shBase + range.poolOffset)
                }
            }
        } catch let error as GaussianPagingError {
            return .failure(error)
        } catch {
            return .failure(.ioFailure(errno: EIO))
        }
        if request.verify, !verifyChunk(request) {
            return .failure(.corrupt(chunk: request.chunkIndex))
        }
        return .success(())
    }

    /// The CRC over the chunk's resident bytes in file order — the core tiers from their pool
    /// slots in rank order, then the harmonics — against the index entry's.
    private func verifyChunk(_ request: GaussianPageReadRequest) -> Bool {
        let entry = index.chunks[request.chunkIndex]
        let count = Int(entry.splatCount)
        let firstTier = request.firstRank / ranksPerPage
        let tierCount = (count + ranksPerPage - 1) / ranksPerPage
        guard request.residentSlots.count == firstTier else { return false }
        var crc = UntoldGSCRC32.initialValue
        func slot(_ tier: Int) -> Int {
            tier < firstTier ? Int(request.residentSlots[tier]) : Int(request.slots[tier - firstTier])
        }
        let coreBase = UnsafeRawPointer(corePool.contents())
        for tier in 0 ..< tierCount {
            let ranks = min(ranksPerPage, count - tier * ranksPerPage)
            let bytes = UnsafeRawBufferPointer(start: coreBase + slot(tier) * ranksPerPage * UntoldGSFormat.coreRecordSize, count: ranks * UntoldGSFormat.coreRecordSize)
            UntoldGSCRC32.update(&crc, bytes)
        }
        if let shPool, shBytesPerSplat > 0 {
            let shBase = UnsafeRawPointer(shPool.contents())
            for tier in 0 ..< tierCount {
                let ranks = min(ranksPerPage, count - tier * ranksPerPage)
                let bytes = UnsafeRawBufferPointer(start: shBase + slot(tier) * ranksPerPage * shBytesPerSplat, count: ranks * shBytesPerSplat)
                UntoldGSCRC32.update(&crc, bytes)
            }
        }
        return UntoldGSCRC32.finalize(crc) == entry.crc32
    }

    private func complete(_ request: GaussianPageReadRequest, result: Result<Void, GaussianPagingError>) {
        lock.lock()
        _pendingReads -= 1
        _bytesInFlight -= request.byteCount
        _stats.pendingReads = _pendingReads
        _stats.bytesInFlight = _bytesInFlight
        if _state == .closed || request.generation != _generation {
            // Nobody will tick again: the completion is dropped here, into pool memory no frame
            // reads (the pools outlive the request through the manager it retains).
            if _eventLogEnabled {
                for slot in request.slots {
                    _eventLog.append(GaussianPagingEvent(tick: tick, kind: .dropped, chunk: request.chunkIndex, tier: request.firstRank / ranksPerPage, slot: slot, generation: 0, priority: 0))
                }
            }
        } else {
            inbox.append(GaussianPageCompletion(request: request, result: result))
        }
        let closeSource = _state == .closed && _pendingReads == 0
        lock.unlock()
        if closeSource {
            source.close()
        }
    }

    // MARK: Events

    private func log(_ kind: GaussianPagingEvent.Kind, chunk: Int, tier: Int, slot: UInt32, priority: Float = 0) {
        lock.lock()
        defer { lock.unlock() }
        guard _eventLogEnabled else { return }
        let generation = slot == kGaussianPageSlotInvalid ? 0 : slotGeneration[Int(slot)]
        _eventLog.append(GaussianPagingEvent(tick: tick, kind: kind, chunk: chunk, tier: tier, slot: slot, generation: generation, priority: priority))
    }
}

/// A FIFO of (chunk, tick) entries: pushed in tick order, expired from the head.
struct GaussianTickQueue {
    struct Entry {
        let chunk: Int32
        let tick: UInt32
    }

    private var entries: [Entry] = []
    private var first = 0

    var isEmpty: Bool {
        first >= entries.count
    }

    var count: Int {
        entries.count - first
    }

    var head: Entry? {
        first < entries.count ? entries[first] : nil
    }

    mutating func push(chunk: Int, tick: UInt32) {
        entries.append(Entry(chunk: Int32(chunk), tick: tick))
    }

    mutating func pop() {
        first += 1
        if first == entries.count {
            entries.removeAll(keepingCapacity: true)
            first = 0
        } else if first >= 1024, first * 2 >= entries.count {
            entries.removeFirst(first)
            first = 0
        }
    }
}

/// A min-heap of (chunk, tick) entries on the tick, ties on the chunk.
struct GaussianTickHeap {
    private var keys: [UInt64] = []

    var head: (chunk: Int32, tick: UInt32)? {
        guard let key = keys.first else { return nil }
        return (Int32(truncatingIfNeeded: key), UInt32(truncatingIfNeeded: key >> 32))
    }

    mutating func push(chunk: Int, tick: UInt32) {
        keys.append(UInt64(tick) << 32 | UInt64(UInt32(truncatingIfNeeded: chunk)))
        var index = keys.count - 1
        while index > 0 {
            let parent = (index - 1) >> 1
            guard keys[index] < keys[parent] else { break }
            keys.swapAt(index, parent)
            index = parent
        }
    }

    mutating func pop() {
        guard !keys.isEmpty else { return }
        let last = keys.removeLast()
        guard !keys.isEmpty else { return }
        keys[0] = last
        var index = 0
        let count = keys.count
        while true {
            let left = 2 * index + 1
            guard left < count else { break }
            let right = left + 1
            let child = right < count && keys[right] < keys[left] ? right : left
            guard keys[child] < keys[index] else { break }
            keys.swapAt(index, child)
            index = child
        }
    }
}

/// The best `capacity` candidates offered, by priority descending then chunk ascending: a
/// min-heap on that order whose root is the weakest kept, replaced by a stronger offer.
struct GaussianCandidateSelection {
    private var chunks: [Int32] = []
    private var priorities: [Float] = []
    private var tiers: [Int32] = []
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = max(1, capacity)
        chunks.reserveCapacity(self.capacity)
        priorities.reserveCapacity(self.capacity)
        tiers.reserveCapacity(self.capacity)
    }

    /// Whether the candidate at `a` is weaker than the one at `b`.
    private func weaker(_ a: Int, _ b: Int) -> Bool {
        priorities[a] < priorities[b] || (priorities[a] == priorities[b] && chunks[a] > chunks[b])
    }

    private mutating func swapAt(_ a: Int, _ b: Int) {
        chunks.swapAt(a, b)
        priorities.swapAt(a, b)
        tiers.swapAt(a, b)
    }

    private mutating func siftDown(from start: Int) {
        var index = start
        let count = chunks.count
        while true {
            let left = 2 * index + 1
            guard left < count else { break }
            let right = left + 1
            let child = right < count && weaker(right, left) ? right : left
            guard weaker(child, index) else { break }
            swapAt(index, child)
            index = child
        }
    }

    mutating func offer(chunk: Int, priority: Float, tiers missing: Int) {
        if chunks.count < capacity {
            chunks.append(Int32(chunk))
            priorities.append(priority)
            tiers.append(Int32(missing))
            var index = chunks.count - 1
            while index > 0 {
                let parent = (index - 1) >> 1
                guard weaker(index, parent) else { break }
                swapAt(index, parent)
                index = parent
            }
            return
        }
        // Weaker than the weakest kept, or equal: not taken.
        let weakest = priorities[0]
        guard priority > weakest || (priority == weakest && Int32(chunk) < chunks[0]) else { return }
        chunks[0] = Int32(chunk)
        priorities[0] = priority
        tiers[0] = Int32(missing)
        siftDown(from: 0)
    }

    /// The kept candidates, strongest first; the selection is emptied.
    mutating func drain(into result: inout [(chunk: Int, priority: Float, tiers: Int)]) {
        result.removeAll(keepingCapacity: true)
        result.reserveCapacity(chunks.count)
        for index in chunks.indices {
            result.append((Int(chunks[index]), priorities[index], Int(tiers[index])))
        }
        result.sort { $0.priority > $1.priority || ($0.priority == $1.priority && $0.chunk < $1.chunk) }
        chunks.removeAll(keepingCapacity: true)
        priorities.removeAll(keepingCapacity: true)
        tiers.removeAll(keepingCapacity: true)
    }
}

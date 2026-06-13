//
//  GeometryStreamingSystem.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import ModelIO
import simd

private struct TileRepresentationSwapWindow {
    var windowStart: Double
    var lastStatesByTarget: [String: String]
    var toggleCountsByTarget: [String: Int]
}

private struct TileLOD0VisibilityProbe {
    let tileId: String
    let parsedFrame: Int
    let renderEntityIds: Set<EntityID>
    let fallbackSummaryAtParse: String
    var warnedMissingVisibleSet: Bool = false
}

private struct TileRepresentationGapAuditSummary {
    var unloadedNoRepresentation: Int = 0
    var parsingNoRepresentation: Int = 0
    var failedNoRepresentation: Int = 0
    var parsedNoRepresentation: Int = 0
}

private struct TileRepresentationOverlapAuditSummary {
    var residentFullTiles: Int = 0
    var residentLODTiles: Int = 0
    var residentHLODTiles: Int = 0
    var visibleFullTiles: Int = 0
    var visibleLODTiles: Int = 0
    var visibleHLODTiles: Int = 0
    var fullAndLODVisibleTiles: Int = 0
    var fullAndHLODVisibleTiles: Int = 0
    var lodAndHLODVisibleTiles: Int = 0
    var fullAndFallbackResidentTiles: Int = 0
    var activeFadeTiles: Int = 0
    var waitingFadeTiles: Int = 0
}

enum TileFadeCompletion {
    case unloadHLOD
    case unloadLODLevel(Int)
}

struct ActiveTileRepresentationFade {
    let tileEntityId: EntityID
    let completion: TileFadeCompletion
    var elapsed: Float
    let duration: Float
    var waitsForIncomingVisibility: Bool
    let incomingRenderIds: Set<EntityID>
    let outgoingRenderIds: Set<EntityID>

    var allRenderIds: Set<EntityID> {
        incomingRenderIds.union(outgoingRenderIds)
    }
}

public class GeometryStreamingSystem: @unchecked Sendable {
    public static let shared = GeometryStreamingSystem()

    /// Enable/disable the streaming system
    public var enabled: Bool = true

    /// Maximum concurrent mesh loads
    public var maxConcurrentLoads: Int = 3

    /// Max unload operations processed each streaming update tick.
    /// Lower values reduce frame spikes when many entities leave range at once.
    public var maxUnloadsPerUpdate: Int = 12

    /// How often to check for load/unload (seconds) during steady-state streaming.
    public var updateInterval: Float = 0.1

    /// Tick interval used during initial hydration bursts (near-band backlog > 0).
    /// A fast tick drains the queue quickly rather than waiting the full updateInterval
    /// between each batch dispatch. Default: ~60 fps equivalent.
    public var burstTickInterval: Float = 0.016

    /// Maximum radius to query from octree (should cover largest unload radius)
    public var maxQueryRadius: Float = 500.0

    /// Maximum Y-axis distance between the camera and a tile's world-space Y centre
    /// before the tile is excluded from streaming consideration.
    ///
    /// For multi-floor buildings this prevents all 10 floors from being simultaneous
    /// load/unload candidates when the camera is on a single floor.  Without this gate
    /// every floor transition causes O(floors × tiles_per_floor) simultaneous unloads
    /// — a spike that starves the render loop and causes the Metal command-buffer
    /// semaphore to block.
    ///
    /// Default 5 m ≈ the current floor plus immediate vertical neighbours.
    /// Set to Float.greatestFiniteMagnitude to disable (open-world scenes with no floors).
    public var floorProximityGateY: Float = 5.0

    // MARK: - Near-Band Concurrency

    /// Fraction of an entity's streamingRadius that defines the "near band".
    /// Entities closer than (streamingRadius × nearBandFraction) are serialized so
    /// the closest mesh always appears before farther ones. Default: first third of range.
    public var nearBandFraction: Float = 0.33

    /// Maximum concurrent loads allowed within the near band.
    /// Setting this to 1 serializes near-band uploads, guaranteeing distance-ordered appearance.
    public var nearBandMaxConcurrentLoads: Int = 1

    // MARK: - Value-Based Eviction Weights

    /// Weight given to camera distance when scoring eviction candidates (0–1).
    /// Higher = farther entities are evicted first.
    public var evictionDistanceWeight: Float = 0.6

    /// Weight given to GPU memory size when scoring eviction candidates (0–1).
    /// Higher = larger meshes are evicted first when at equal distance.
    public var evictionSizeWeight: Float = 0.4

    /// Distance (metres) within which a currently-visible entity is protected from eviction.
    ///
    /// Entities that are both visible AND closer than this radius are never evicted — removing
    /// them would cause an obvious foreground pop. Entities beyond this radius CAN be evicted
    /// under memory pressure even while visible, because the visual cost of a distant pop is
    /// far lower than blocking a nearby mesh from loading entirely.
    ///
    /// Default: 30 m. Increase if you see unwanted pops on meshes that are far but prominent.
    /// Decrease if zoom-out → zoom-in residency deadlocks persist (far meshes blocking near ones).
    public var visibleEvictionProtectionRadius: Float = 30.0

    // MARK: - Interior Zone

    /// World-space AABB that defines the building interior, sourced from the manifest's
    /// `interior_zone` field (union of ExteriorShell tile bounds).
    /// When non-nil, tiles tagged `isInterior = true` are only allowed to load while the
    /// camera is inside this volume.  Nil for uniform_grid manifests (gate disabled).
    public var interiorZone: AABB?

    // MARK: - Tile Streaming

    /// Hard cap on simultaneous tile parses regardless of memory budget.
    /// Acts as a safety ceiling; the memory budget gate (below) is the primary throttle.
    /// 2 concurrent loads balances throughput for large scenes against the RAM spike
    /// risk of simultaneous mass dispatch.  Lower to 1 for memory-constrained devices
    /// or scenes with very large individual tiles (> 50 MB).
    public var maxConcurrentTileLoads: Int = 2

    /// Maximum concurrent per-tile LOD level loads (LOD1, LOD2, etc.).
    /// LOD assets are smaller than full tiles but still run a full ModelIO parse.
    /// Without a cap, every tile in LOD range is dispatched in a single update tick,
    /// which can trigger an OOM kill on scenes with many visible tiles.
    public var maxConcurrentLODLoads: Int = 4

    /// Maximum concurrent HLOD mesh loads.
    /// HLOD meshes cover far-field tiles and can be numerous in large outdoor scenes.
    /// Without a cap, every out-of-range tile triggers a simultaneous ModelIO parse,
    /// causing an OOM kill identical to the uncapped LOD pass problem.
    public var maxConcurrentHLODLoads: Int = 4

    /// When false, HLOD and per-tile LOD representations bypass runtime static batching.
    /// These representations are numerous and short-lived during bootstrap; batching them
    /// aggressively can create a large world-mutation storm that starves the renderer
    /// before the scene reaches a stable full-tile state.
    public var batchSecondaryTileRepresentations: Bool = false

    /// Hysteresis multiplier for per-tile LOD level transitions.
    /// A loaded LOD level is not unloaded until distance drops below
    /// (switchDistance × lodHysteresisFactor).  This prevents thrashing when the
    /// camera hovers near a boundary: the camera must move meaningfully inward
    /// before the current level is swapped out.
    /// Range (0, 1]. Default 0.90 = 10% inner band.
    public var lodHysteresisFactor: Float = 0.90

    /// Hysteresis multiplier for HLOD mesh transitions.
    /// The HLOD mesh is not unloaded (to make way for LOD levels) until distance
    /// drops below (hlodSwitchDistance × hlodHysteresisFactor).
    /// Range (0, 1]. Default 0.90.
    public var hlodHysteresisFactor: Float = 0.90

    /// Minimum time a tile HLOD or per-tile LOD representation should remain resident
    /// before the system allows another swap. This stabilizes bootstrap and boundary
    /// traversal by preventing rapid HLOD/LOD/full-tile churn in a narrow distance band.
    public var secondaryRepresentationMinDwellSeconds: Double = 1.0

    /// Emits focused diagnostics for tile representation gaps and LOD0 handoffs.
    /// This is intentionally runtime-enabled by default because the logs are throttled
    /// and the data is only collected for active tile entities.
    public var tileRepresentationDiagnosticsEnabled: Bool = true

    /// Minimum time a tile may spend parsing with no loaded fallback before the
    /// representation-gap diagnostic warns. This filters expected first-frame
    /// startup hydration while still catching LOD0 stalls.
    public var tileRepresentationGapDwellSeconds: Double = 0.5

    /// Number of streaming-system frames LOD0 may remain absent from the published
    /// visible set before warning. Culling/visible-set publication can legitimately
    /// lag parse completion by several frames during tile bursts, so this warns only
    /// on persistent handoff gaps.
    public var lod0VisibilityWarningFrameDelay: Int = 12

    /// Maximum tile unload operations processed per streaming update tick.
    /// Capping unloads prevents a single-frame blank on fast camera movement or
    /// teleports: when many tiles leave range at once, GPU buffer releases are
    /// spread across several ticks rather than all landing on one frame.
    public var maxTileUnloadsPerUpdate: Int = 2

    /// Seconds a `.parsed` tile may remain loaded after exceeding its `unloadRadius`
    /// before it is torn down.  The grace period prevents rapid load/unload oscillation
    /// at tile boundaries: a tile that briefly drifts outside its radius stays resident
    /// long enough for the camera to return.
    /// In-flight (`.parsing`) tiles are never grace-delayed — they carry no visible
    /// geometry and are cancelled immediately when out of range.
    public var unloadGracePeriod: Float = 3.0

    /// Minimum seconds a parsed full tile remains resident before normal unload
    /// or geometry-pressure eviction may tear it down. This prevents large
    /// floor/facade tiles from appearing briefly and disappearing again while the
    /// camera settles near a streaming boundary.
    public var minimumParsedTileResidentSeconds: Double = 8.0

    /// Total CPU memory (MB) allowed to be in-flight across all concurrent tile parses.
    /// Small tiles consume little budget and can parse in parallel; a single large tile
    /// may saturate the budget and serialize naturally.
    /// At least one tile is always allowed to parse even if it exceeds the budget alone.
    public var tileParseMemoryBudgetMB: Float = 200.0

    /// Maximum time in seconds a tile may stay in .parsing before it is force-failed.
    /// Protects against ModelIO hanging indefinitely on unsupported asset content
    /// (e.g. an unsupported image format inside a USDC file) which would otherwise
    /// permanently exhaust the concurrency slots and freeze all future tile loads.
    public var tileParseTimeoutSeconds: Double = 60.0

    /// Maximum time in seconds a mesh load may stay in .loading before it is force-reset.
    /// Covers OOC uploads, cold rehydration, and MeshResourceManager-backed disk loads.
    /// Without this a single hung load can permanently consume one of the global mesh
    /// streaming slots and starve all subsequent mesh work.
    public var meshLoadTimeoutSeconds: Double = 60.0

    /// Tile entities currently being parsed, mapped to their declared file size in bytes.
    /// Used to track the total parse memory in flight for the budget gate.
    var activeTileLoads: [EntityID: Int] = [:]

    /// Tile entities currently in the .parsed state.
    /// Mirrors loadedStreamingEntities but for tile-level entities.
    /// Enables out-of-range checks for tiles that fall outside the octree query radius.
    var loadedTileEntities: Set<EntityID> = []

    /// Tile entities currently in the .parsing state.
    /// Enables cancellation of in-progress tile parses when the camera moves away
    /// before the load completes (e.g. fast movement or teleport).
    var loadingTileEntities: Set<EntityID> = []

    /// Maps capturedMeshEntityId → tile stub EntityID so OCC upload completions
    /// can quickly update the parent tile's visual readiness counters (O(1) lookup).
    var meshEntityToTileEntity: [EntityID: EntityID] = [:]

    /// Maps quadtreeNodeId parent prefix → union AABB of all child tile stubs.
    /// Built once per loadTiledScene call from v4 quadtree manifests.
    /// Used by the hierarchy-aware tile load gate: child tiles whose parent region
    /// is fully occluded by loaded geometry are skipped without being queued.
    /// Empty for v3 uniform-grid manifests (tiles have no quadtreeNodeId).
    var tileHierarchyIndex: [String: (min: simd_float3, max: simd_float3)] = [:]

    /// Tile stub entities that currently have an HLOD mesh loaded.
    /// Used to find and unload HLOD meshes for tiles that drift outside the query radius.
    var loadedHLODEntities: Set<EntityID> = []

    /// Tile stub entities that currently have at least one per-tile LOD level loaded.
    /// Used to reach tiles that drift outside the octree query radius for cleanup.
    var loadedLODEntities: Set<EntityID> = []

    /// Number of per-tile LOD level loads currently in flight (.loading state).
    /// Protected by stateLock.  Mirrors the role of loadingTileEntities.count for
    /// full tiles — caps concurrent ModelIO parses so we don't OOM on mass dispatch.
    var lodLoadingCount: Int = 0

    /// Number of HLOD mesh loads currently in flight (.loading hlodState).
    /// Protected by stateLock.  Same role as lodLoadingCount — prevents simultaneous
    /// mass dispatch of 100+ HLOD parses that would OOM-kill the process.
    var hlodLoadingCount: Int = 0

    var activeTileRepresentationFades: [ActiveTileRepresentationFade] = []

    // MARK: - Camera Velocity (4.5 predictive loading)

    /// Exponential smoothing factor for camera velocity (0 = no smoothing, 1 = frozen).
    public var velocitySmoothing: Float = 0.85

    /// How far ahead (seconds) to project the camera position when scoring tile candidates.
    /// Tiles close to the predicted future position are prioritised as if the camera
    /// were already there, reducing pop-in during forward movement.
    /// Keep short (0.5 s) — longer values project too far and cause nearly every tile
    /// in the scene to score as "in range" simultaneously at normal walk/fly speeds.
    public var velocityLookAheadTime: Float = 0.5

    /// Minimum camera speed (m/s) before predictive loading activates.
    /// Below this threshold the look-ahead offset is zeroed out so that slow panning
    /// or micro-jitter does not artificially inflate the candidate distance set.
    public var velocityLookAheadMinSpeed: Float = 1.5

    var lastCameraPosition: simd_float3?
    var cameraVelocity: simd_float3 = .zero
    var lastCameraForward: simd_float3 = .init(0, 0, -1)
    var lastViewProjMatrix: simd_float4x4 = matrix_identity_float4x4

    // MARK: - Frustum Gate

    /// When true, mesh and tile load candidates are tested against the camera frustum
    /// before being dispatched.  Entities fully outside the frustum are skipped this
    /// tick and reconsidered on approach / rotation.  Does NOT affect unloads —
    /// meshes are never evicted solely because the camera turns away from them.
    ///
    /// Default: true.  Set to false for scenes where content appears in all directions
    /// simultaneously (e.g., 360 panoramas) to avoid a one-frame pop when rotating.
    public var enableFrustumGate: Bool = true

    /// World-unit padding added to each frustum side plane before the gate test.
    /// A generous pad (default 5 m) prevents meshes from popping in when rotating
    /// quickly: content slightly outside the current frustum but about to enter it
    /// is still queued for loading.
    public var frustumGatePadding: Float = 5.0

    /// Frustum padding used exclusively for tile-level load candidates.
    /// Tiles are coarser than individual mesh stubs — a single tile popping in
    /// from the side is far more jarring than a missing mesh.  A wider pad (default
    /// 20 m) keeps tiles queued for loading even when they sit at the edge of the
    /// view frustum during fast rotation.  Increase for large outdoor tiles; decrease
    /// for small indoor tiles where behind-camera loads genuinely waste parse time.
    public var tileFrustumGatePadding: Float = 20.0

    // MARK: - Load Priority

    /// When true, tile load candidates within the same priority tier are sorted by
    /// view-importance score (projected solid angle × view alignment) instead of
    /// raw distance.  A large tile that fills the center of view loads before a
    /// small tile at the same distance on the periphery.
    /// Default: true.  Set to false to revert to pure distance ordering.
    public var enableImportanceSort: Bool = true

    /// Minimum view-alignment weight for tiles at the frustum edge.
    /// Remaps the dot-product alignment from [0, 1] to [minWeight, 1.0] so a
    /// peripheral tile still contributes its solid angle rather than scoring zero.
    /// Range [0, 1].  Default 0.2.
    public var viewAlignmentMinWeight: Float = 0.2

    /// When true, tile load candidates are additionally weighted by how much
    /// of their screen-space footprint is already covered by closer loaded tiles.
    /// A tile 100% covered by a loaded occluder scores 0 and is deprioritised
    /// without being excluded — it will still load once the slot is free.
    /// Default: true.  Set to false to disable occlusion weighting.
    public var enableOcclusionSort: Bool = true

    /// Coverage fraction at which a tile is treated as fully occluded and
    /// receives occlusionScore = occlusionMinWeight.  A tile 85% covered by
    /// loaded geometry is unlikely to contribute meaningfully to the visible scene.
    /// Range (0, 1].  Default 0.85.
    public var occlusionFullThreshold: Float = 0.85

    /// Minimum occlusionScore returned even for tiles classified as fully blocked.
    /// Tile AABBs are used as opaque proxies, but the actual geometry may be sparse,
    /// glass, or have open areas.  A non-zero floor ensures no tile is permanently
    /// pushed to the back of the load queue solely because another tile's bounding
    /// box overlaps it in screen space — it will still load, just later.
    /// Range [0, 1).  Default 0.05.  Set to 0 to restore hard zero behaviour.
    public var occlusionMinWeight: Float = 0.05

    /// Score multiplier applied to tiles whose parent region is fully covered by
    /// loaded geometry (hierarchy gate).  A very small value ensures these tiles
    /// sort far below unoccluded candidates and are effectively deferred, while
    /// still allowing them to load when no better candidates exist — avoiding
    /// permanent holes when the camera snaps toward previously-occluded geometry.
    /// Range [0, 1).  Default 0.005.  Set to 0.0 to restore the old hard-skip.
    public var hierarchyOcclusionPenalty: Float = 0.005

    // Screen-space rectangle in NDC [-1, 1] × [-1, 1].
    // Used to represent the projected AABB footprint of a tile for occlusion scoring.
    struct TileOccluder { let rect: ScreenRect; let distance: Float }
    struct TileRepresentationCandidate {
        let entityId: EntityID
        let distance: Float
        let priority: Int
        let urgency: Int
        let solidAngle: Float
        let viewAlignment: Float
        let occlusionScore: Float
        let levelIndex: Int
    }

    struct ScreenRect {
        var minX: Float
        var minY: Float
        var maxX: Float
        var maxY: Float

        var area: Float {
            max(0, maxX - minX) * max(0, maxY - minY)
        }

        func intersectionArea(with other: ScreenRect) -> Float {
            let ix = max(0, min(maxX, other.maxX) - max(minX, other.minX))
            let iy = max(0, min(maxY, other.maxY) - max(minY, other.minY))
            return ix * iy
        }
    }

    // MARK: - OS Memory Pressure

    /// Set by the MemoryBudgetManager pressure callback (background queue).
    /// Checked and cleared at the start of each update() tick (main thread) so that
    /// all eviction work stays on the same thread as the rest of the streaming system.
    var pendingPressureRelief: Bool = false
    var pressureIsAggressive: Bool = false

    let stateLock = NSLock()
    var timeSinceLastUpdate: Float = 0
    var timeSinceCameraDiagLog: Float = 0
    var lastCameraWallDiagTime: Double = 0.0
    var sessionStartWallTime: Double = 0.0
    /// Peak streaming tick duration (ms) since the last heartbeat — reset each heartbeat.
    var peakTickMs: Double = 0.0
    var activeLoads: Set<EntityID> = []
    var activeLoadStartTimes: [EntityID: Double] = [:]
    /// Subset of activeLoads that belong to the near band. Tracked separately so the
    /// near-band concurrency limit can be enforced independently of the global limit.
    var activeNearBandLoads: Set<EntityID> = []
    var loadedStreamingEntities: Set<EntityID> = [] // Track loaded entities for efficient unload checks
    var currentFrame: Int = 0
    var lastLoadCandidateCount: Int = 0
    var lastTileLoadCandidateCount: Int = 0
    var lastPendingLoadBacklog: Int = 0
    var diagnostics: GeometryStreamingDiagnosticsSnapshot = .init()
    var cumulativeAsyncLoadMs: Double = 0.0
    var completedAsyncLoads: Int = 0
    fileprivate var tileSwapWindow: [EntityID: TileRepresentationSwapWindow] = [:]
    private var tileRepresentationGapLastLogTime: [EntityID: Double] = [:]
    private var lod0VisibilityProbes: [EntityID: TileLOD0VisibilityProbe] = [:]
    private var tileLOD0HandoffPending: Set<EntityID> = []
    private var lastTileGapSummaryLogTime: Double = 0

    /// First-detection timestamps (CFAbsoluteTime) keyed by entity ID.
    /// Records when each entity first appeared as a load candidate so we can measure
    /// scheduler latency: time from entering range to actual dispatch.
    /// Accessed only from update() and its synchronous callees — no lock needed.
    var firstRangeTimestamps: [EntityID: Double] = [:]

    private init() {
        // Register OS memory pressure handlers.
        // The callbacks fire on a background queue, so we only set a flag here.
        // Actual eviction happens on the next update() tick (main thread).
        MemoryBudgetManager.shared.onMemoryPressureWarning = { [weak self] in
            guard let self else { return }
            withStateLock {
                self.pendingPressureRelief = true
                self.pressureIsAggressive = false
            }
        }
        MemoryBudgetManager.shared.onMemoryPressureCritical = { [weak self] in
            guard let self else { return }
            NativeTextureLoader.purgeSharedCache()
            withStateLock {
                self.pendingPressureRelief = true
                self.pressureIsAggressive = true
            }
        }
    }

    @inline(__always)
    func withStateLock<T>(_ body: () throws -> T) rethrows -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return try body()
    }

    func reserveActiveLoad(entityId: EntityID) -> Bool {
        withStateLock {
            if activeLoads.contains(entityId) {
                return false
            }
            activeLoads.insert(entityId)
            activeLoadStartTimes[entityId] = CFAbsoluteTimeGetCurrent()
            return true
        }
    }

    func releaseActiveLoad(entityId: EntityID) {
        withStateLock {
            _ = activeLoads.remove(entityId)
            _ = activeLoadStartTimes.removeValue(forKey: entityId)
        }
    }

    func activeLoadCountSnapshot() -> Int {
        withStateLock { activeLoads.count }
    }

    func activeLoadStartTimesSnapshot() -> [(entityId: EntityID, startTime: Double)] {
        withStateLock { activeLoadStartTimes.map { ($0.key, $0.value) } }
    }

    func reserveNearBandLoad(entityId: EntityID) {
        _ = withStateLock { activeNearBandLoads.insert(entityId) }
    }

    func releaseNearBandLoad(entityId: EntityID) {
        withStateLock { _ = activeNearBandLoads.remove(entityId) }
    }

    func activeNearBandLoadCount() -> Int {
        withStateLock { activeNearBandLoads.count }
    }

    func reserveActiveTileLoad(entityId: EntityID, fileSizeBytes: Int) -> Bool {
        withStateLock {
            guard activeTileLoads[entityId] == nil else { return false }
            activeTileLoads[entityId] = fileSizeBytes
            return true
        }
    }

    func releaseActiveTileLoad(entityId: EntityID) {
        withStateLock { _ = activeTileLoads.removeValue(forKey: entityId) }
    }

    func activeTileLoadCount() -> Int {
        withStateLock { activeTileLoads.count }
    }

    func activeTileLoadEntityIdsSnapshot() -> [EntityID] {
        withStateLock { Array(activeTileLoads.keys) }
    }

    /// Sum of declared file sizes (bytes) for all tiles currently being parsed.
    func activeParseBytesInFlight() -> Int {
        withStateLock { activeTileLoads.values.reduce(0, +) }
    }

    func activeLODLoadCount() -> Int {
        withStateLock { lodLoadingCount }
    }

    func incrementLODLoadCount() {
        withStateLock { lodLoadingCount += 1 }
    }

    func decrementLODLoadCount() {
        withStateLock { lodLoadingCount = max(0, lodLoadingCount - 1) }
    }

    func activeHLODLoadCount() -> Int {
        withStateLock { hlodLoadingCount }
    }

    func incrementHLODLoadCount() {
        withStateLock { hlodLoadingCount += 1 }
    }

    func decrementHLODLoadCount() {
        withStateLock { hlodLoadingCount = max(0, hlodLoadingCount - 1) }
    }

    func markLoadedTileEntity(_ entityId: EntityID) {
        withStateLock { _ = loadedTileEntities.insert(entityId) }
    }

    func tileUnloadDwellSatisfied(_ tileComp: TileComponent, now: CFAbsoluteTime) -> Bool {
        guard tileComp.pendingUnloadSince > 0,
              now - tileComp.pendingUnloadSince >= Double(unloadGracePeriod)
        else {
            return false
        }

        guard tileComp.state == .parsed,
              tileComp.parsedResidentSince > 0,
              minimumParsedTileResidentSeconds > 0
        else {
            return true
        }

        return now - tileComp.parsedResidentSince >= minimumParsedTileResidentSeconds
    }

    func unmarkLoadedTileEntity(_ entityId: EntityID) {
        withStateLock { _ = loadedTileEntities.remove(entityId) }
    }

    func loadedTileEntitiesSnapshot() -> [EntityID] {
        withStateLock { Array(loadedTileEntities) }
    }

    func markLoadingTileEntity(_ entityId: EntityID) {
        withStateLock { _ = loadingTileEntities.insert(entityId) }
    }

    func unmarkLoadingTileEntity(_ entityId: EntityID) {
        withStateLock { _ = loadingTileEntities.remove(entityId) }
    }

    func loadingTileEntitiesSnapshot() -> [EntityID] {
        withStateLock { Array(loadingTileEntities) }
    }

    func markLoadedHLODEntity(_ entityId: EntityID) {
        withStateLock { _ = loadedHLODEntities.insert(entityId) }
    }

    func unmarkLoadedHLODEntity(_ entityId: EntityID) {
        withStateLock { _ = loadedHLODEntities.remove(entityId) }
    }

    func loadedHLODEntitiesSnapshot() -> [EntityID] {
        withStateLock { Array(loadedHLODEntities) }
    }

    func markLoadedLODEntity(_ entityId: EntityID) {
        withStateLock { _ = loadedLODEntities.insert(entityId) }
    }

    func unmarkLoadedLODEntity(_ entityId: EntityID) {
        withStateLock { _ = loadedLODEntities.remove(entityId) }
    }

    func loadedLODEntitiesSnapshot() -> [EntityID] {
        withStateLock { Array(loadedLODEntities) }
    }

    // MARK: - Frustum Gate Helpers

    /// Builds a padded CPU frustum from the active camera's current view-projection
    /// matrix, adjusted for the scene-root transform.  Returns nil if no active camera
    /// is available (e.g. before the first frame).
    ///
    /// - Parameter sidePad: World-unit padding applied to each frustum side plane.
    ///   Pass nil to use `frustumGatePadding` (the default for mesh-level candidates).
    ///   Pass `tileFrustumGatePadding` for tile-level candidates.
    func buildStreamingFrustum(sidePad: Float? = nil) -> Frustum? {
        guard let cameraId = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: cameraId)
        else { return nil }

        let effectiveView = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        let viewProj = simd_mul(renderInfo.perspectiveSpace, effectiveView)

        let ndcNear: Float = renderInfo.reverseZEnabled ? 1.0 : 0.0
        let ndcFar: Float = renderInfo.reverseZEnabled ? 0.0 : 1.0
        var frustum = buildFrustum(from: viewProj, ndcNear: ndcNear, ndcFar: ndcFar)
        frustum = padFrustum(frustum, sidePad: sidePad ?? frustumGatePadding)
        return frustum
    }

    func loadedStreamingEntitiesSnapshot() -> [EntityID] {
        withStateLock { Array(loadedStreamingEntities) }
    }

    func markLoadedStreamingEntity(_ entityId: EntityID) {
        withStateLock {
            _ = loadedStreamingEntities.insert(entityId)
        }
    }

    func unmarkLoadedStreamingEntity(_ entityId: EntityID) {
        withStateLock {
            _ = loadedStreamingEntities.remove(entityId)
        }
    }

    /// Called every frame from the engine's update loop
    public func update(cameraPosition: simd_float3, deltaTime: Float) {
        guard enabled else {
            withStateLock {
                diagnostics.updateFrame = currentFrame
                diagnostics.updateTriggered = false
                diagnostics.updateWorkMs = 0
            }
            return
        }

        currentFrame += 1
        MeshResourceManager.shared.currentFrame = currentFrame // Keep cache LRU updated
        advanceTileRepresentationFades(deltaTime: deltaTime)

        let activeLoadsAtStart = activeLoadCountSnapshot()

        // Throttle updates. Switch to a fast tick when there is a pending near-band
        // backlog so initial hydration bursts drain quickly. Reverts to the normal
        // updateInterval once the backlog clears.
        // OS pressure bypass: if a pressure flag is pending, skip the throttle entirely so
        // eviction runs on the very next update() call (≤ 1 frame / ~11 ms at 90 fps).
        // Without this, a .critical signal that arrives right after a tick waits up to
        // updateInterval (100 ms) before eviction — longer than visionOS's kill window.
        let effectiveInterval = lastPendingLoadBacklog > 0 ? burstTickInterval : updateInterval
        timeSinceLastUpdate += deltaTime
        var shouldRunUpdate = false
        withStateLock { shouldRunUpdate = timeSinceLastUpdate >= effectiveInterval || pendingPressureRelief }
        guard shouldRunUpdate else {
            withStateLock {
                diagnostics.updateFrame = currentFrame
                diagnostics.updateTriggered = false
                diagnostics.updateWorkMs = 0
                diagnostics.activeLoadsAtUpdateStart = activeLoadsAtStart
            }
            return
        }
        timeSinceLastUpdate = 0
        let updateStart = CFAbsoluteTimeGetCurrent()
        if sessionStartWallTime == 0.0 {
            sessionStartWallTime = updateStart
            lastCameraWallDiagTime = updateStart
        }

        // Use Octree for efficient spatial query - only check nearby entities for loading
        // Query with the max unload radius to catch all potentially relevant entities
        // Transform camera position into entity space (un-shifted by scene root).
        let effectiveCameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraPosition)

        // ── Camera velocity (4.5 predictive loading) ───────────────────────────
        // Compute an exponentially-smoothed velocity from frame-to-frame displacement.
        // Used to project a look-ahead position for tile candidate scoring so tiles
        // in the direction of travel are prioritised before the camera reaches them.
        let dt = max(deltaTime, 0.001)
        if let last = lastCameraPosition {
            let rawVelocity = (effectiveCameraPosition - last) / dt
            cameraVelocity = velocitySmoothing * cameraVelocity + (1.0 - velocitySmoothing) * rawVelocity
        } else {
            cameraVelocity = .zero
        }
        lastCameraPosition = effectiveCameraPosition
        // Only apply predictive offset when moving fast enough that look-ahead is meaningful.
        // Below velocityLookAheadMinSpeed (e.g. slow pan, jitter) the candidate set would be
        // inflated without any benefit, potentially triggering spurious tile dispatches.
        let speed = simd_length(cameraVelocity)
        let predictivePosition: simd_float3 = speed >= velocityLookAheadMinSpeed
            ? effectiveCameraPosition + cameraVelocity * velocityLookAheadTime
            : effectiveCameraPosition

        // Periodic heartbeat — uses wall-clock time so it fires every 5 s of real time
        // regardless of deltaTime magnitude or tick throttling.
        let wallNow = CFAbsoluteTimeGetCurrent()
        if wallNow - lastCameraWallDiagTime >= 5.0 {
            lastCameraWallDiagTime = wallNow
            let bStats = MemoryBudgetManager.shared.getStats()
            let bPct = Int((bStats.geometryUtilization * 100).rounded())
            let tilesLoaded = loadedTileEntitiesSnapshot().count
            let tilesLoading = loadingTileEntitiesSnapshot().count
            let bSys = BatchingSystem.shared.diagnosticSummary()
            let capturedPeak = peakTickMs
            peakTickMs = 0.0
            Logger.log(
                message: "[StreamingHB] t=\(Int(wallNow - sessionStartWallTime))s cam=(\(String(format: "%.1f", effectiveCameraPosition.x)),\(String(format: "%.1f", effectiveCameraPosition.y)),\(String(format: "%.1f", effectiveCameraPosition.z))) geom=\(bStats.meshMemoryUsed / (1024 * 1024))MB(\(bPct)%) tiles=\(tilesLoaded)loaded/\(tilesLoading)loading peakTickMs=\(String(format: "%.1f", capturedPeak)) shadowCasters=\(RenderPasses.lastShadowCasterCount) \(bSys)",
                category: LogCategory.streamingHeartbeat.rawValue
            )
        }

        let nearbyEntities = OctreeSystem.shared.queryNear(point: effectiveCameraPosition, radius: maxQueryRadius)

        // Build a padded frustum once per tick for the load-gate test.
        // nil when no camera is available; the gate is simply skipped that tick.
        let streamingFrustum: Frustum? = enableFrustumGate ? buildStreamingFrustum() : nil
        // Tile candidates use a wider pad (tileFrustumGatePadding) because tiles are
        // coarser than mesh stubs — a single tile pop-in is far more noticeable.
        let tileStreamingFrustum: Frustum? = enableFrustumGate ? buildStreamingFrustum(sidePad: tileFrustumGatePadding) : nil

        // Extract camera forward and view-projection matrix for tile importance scoring.
        // viewProjMatrixValid is tick-local: it resets to false every update so a
        // missing or unavailable camera cannot leave a stale VP matrix active.
        // Occlusion scoring is disabled for the tick when the flag is false.
        var viewProjMatrixValid = false
        if let cameraId = CameraSystem.shared.activeCamera,
           let cc = scene.get(component: CameraComponent.self, for: cameraId)
        {
            let ev = SceneRootTransform.shared.effectiveViewMatrix(cc.viewSpace)
            // The third row of the view matrix is -cameraForward in right-handed view space.
            let fwd = simd_float3(-ev.columns.0.z, -ev.columns.1.z, -ev.columns.2.z)
            let len = simd_length(fwd)
            if len > 1e-6 { lastCameraForward = fwd / len }
            lastViewProjMatrix = simd_mul(renderInfo.perspectiveSpace, ev)
            viewProjMatrixValid = true
        }

        var loadCandidates: [(EntityID, Float, Int, Float)] = [] // (entity, distance, priority, importance)
        var unloadCandidates: [(EntityID, Float)] = [] // (entity, distance)

        // Check nearby entities for loading
        for entityId in nearbyEntities {
            // Check if entity still exists (Octree may contain stale IDs)
            guard scene.exists(entityId) else {
                continue
            }

            guard let streaming = scene.get(component: StreamingComponent.self, for: entityId) else {
                continue
            }

            let distance = calculateDistance(entityId: entityId, cameraPosition: effectiveCameraPosition)

            switch streaming.state {
            case .unloaded:
                // Small epsilon to handle floating-point boundary cases (e.g., 200.0001 vs 200.0)
                if distance <= streaming.streamingRadius + 1.0 {
                    // Interior gate: skip loading interior tiles when the camera is outside
                    // the building's interior zone.  Only active when the manifest provides
                    // an interior_zone and the tile is tagged isInterior = true.
                    if let zone = interiorZone,
                       let tc = scene.get(component: TileComponent.self, for: entityId),
                       tc.isInterior,
                       !zone.contains(effectiveCameraPosition)
                    {
                        continue
                    }
                    // Frustum gate: skip loading if the entity AABB is entirely outside the
                    // current camera frustum.  Only applied when a frustum is available and
                    // the entity has local bounds; otherwise the candidate is always queued.
                    if let f = streamingFrustum,
                       let local = scene.get(component: LocalTransformComponent.self, for: entityId),
                       let world = scene.get(component: WorldTransformComponent.self, for: entityId)
                    {
                        let (center, halfExtent) = worldAABB_CenterExtent(
                            localMin: local.boundingBox.min,
                            localMax: local.boundingBox.max,
                            worldMatrix: world.space
                        )
                        if !isAABBInFrustum(center: center, halfExtent: halfExtent, frustum: f) {
                            continue
                        }
                    }
                    // Record first-detection time once; used to measure tick-to-dispatch latency.
                    if firstRangeTimestamps[entityId] == nil {
                        firstRangeTimestamps[entityId] = CFAbsoluteTimeGetCurrent()
                    }
                    loadCandidates.append((entityId, distance, streaming.priority, importanceScore(entityId: entityId, distance: distance)))
                }

            case .loaded:
                streaming.lastVisibleFrame = currentFrame
                if distance > streaming.unloadRadius {
                    unloadCandidates.append((entityId, distance))
                }

            case .loading, .unloading:
                break // In progress, skip
            }
        }

        // ── Tile parse timeout guard ───────────────────────────────────────────
        // ModelIO can hang indefinitely on certain assets (e.g. unsupported image
        // formats embedded in USDC files).  When that happens the Task's completion
        // callback never fires, the concurrency slot stays reserved, and streaming
        // freezes permanently.  Detect stuck parses and force them to .failed so
        // the slot is freed and normal exponential-backoff retry applies.
        // releaseActiveTileLoad uses removeValue(forKey:) and is idempotent — the
        // Task's own defer{} release fires later but is safely a no-op.
        let timeoutNow = CFAbsoluteTimeGetCurrent()
        let tileTimeoutCandidates = Set(loadingTileEntitiesSnapshot()).union(activeTileLoadEntityIdsSnapshot())
        for entityId in tileTimeoutCandidates {
            guard scene.exists(entityId),
                  let tc = scene.get(component: TileComponent.self, for: entityId),
                  tc.state == .parsing || tc.state == .unloading,
                  tc.parseStartTime > 0,
                  timeoutNow - tc.parseStartTime > tileParseTimeoutSeconds
            else { continue }

            Logger.logWarning(
                message: "[TileStreaming] Tile '\(tc.tileId)' parse timed out after \(Int(tileParseTimeoutSeconds))s while state=\(String(describing: tc.state)) — forcing teardown.",
                category: LogCategory.tileStreaming.rawValue
            )
            tc.loadTask?.cancel()
            tc.loadTask = nil
            tc.parseStartTime = 0

            // Clear async loading progress for the hung inner Task.  setEntityMeshAsync
            // tracks capturedMeshEntityId in AssetLoadingState; if ModelIO or texture
            // decoding ignores cooperative cancellation, the normal finish path may never
            // run and loadingCount() would stay elevated.
            let hungMeshId = tc.meshEntityId
            tc.meshEntityId = .invalid
            if hungMeshId != .invalid {
                Task { await AssetLoadingState.shared.finishLoading(entityId: hungMeshId) }
            }

            tc.totalOCCStubs = 0
            tc.uploadedOCCStubs = 0
            tc.pendingUnloadSince = 0
            if tc.state == .parsing {
                tc.failureCount += 1
                tc.lastFailureTime = timeoutNow
                tc.state = .failed
            } else {
                tc.state = .unloaded
            }
            unmarkLoadingTileEntity(entityId)
            releaseActiveTileLoad(entityId: entityId)
        }

        // ── Mesh load timeout guard ───────────────────────────────────────────
        // Unlike tile parses, regular mesh/OOC uploads do not pass through a dedicated
        // tile timeout path. If one hangs in ModelIO, a texture decode, or a shared file
        // load, the entity remains in activeLoads forever and the mesh scheduler starves.
        for (entityId, startTime) in activeLoadStartTimesSnapshot() {
            guard timeoutNow - startTime > meshLoadTimeoutSeconds else { continue }
            guard scene.exists(entityId),
                  let streaming = scene.get(component: StreamingComponent.self, for: entityId),
                  streaming.state == .loading
            else {
                releaseActiveLoad(entityId: entityId)
                releaseNearBandLoad(entityId: entityId)
                continue
            }

            Logger.logWarning(
                message: "[GeometryStreaming] Mesh load timed out for entity \(entityId) after \(Int(meshLoadTimeoutSeconds))s — resetting to .unloaded."
            )
            streaming.loadTask?.cancel()
            streaming.loadTask = nil
            streaming.state = .unloaded
            releaseActiveLoad(entityId: entityId)
            releaseNearBandLoad(entityId: entityId)
            firstRangeTimestamps.removeValue(forKey: entityId)
        }

        // ── Tile-level streaming pass ──────────────────────────────────────────
        // Tile stubs (TileComponent, no StreamingComponent) are included in the
        // same octree query above.  When a stub enters its streaming radius the
        // full tile USDC is parsed and registered via setEntityMeshAsync (.auto
        // policy).  Concurrency is governed by a memory budget gate (4.4) instead
        // of a hard count: small tiles parse in parallel; one large tile saturates
        // the budget naturally.

        // Build the occluder list once per tick from already-loaded tiles.
        // Manifest-stored bounds (LocalTransformComponent) are available for all
        // tiles regardless of load state, so only the .parsed filter is needed —
        // no chicken-and-egg problem.  Sorted ascending by distance so the coverage
        // accumulation loop can exit early once it passes the candidate's distance.
        var tileOccluders: [TileOccluder] = []
        if enableOcclusionSort, viewProjMatrixValid {
            for eid in loadedTileEntitiesSnapshot() {
                guard scene.exists(eid),
                      let tc = scene.get(component: TileComponent.self, for: eid),
                      tc.state == .parsed,
                      let local = scene.get(component: LocalTransformComponent.self, for: eid)
                else { continue }
                let dist = calculateDistance(entityId: eid, cameraPosition: effectiveCameraPosition)
                let rect = projectAABBToScreen(
                    min: local.boundingBox.min, max: local.boundingBox.max,
                    viewProj: lastViewProjMatrix,
                    allowNearPlaneExpansion: false // discard tiles clipping the near plane
                )
                guard rect.area > 1e-6 else { continue } // behind or clipping camera — not a valid occluder
                tileOccluders.append(TileOccluder(rect: rect, distance: dist))
            }
            tileOccluders.sort { $0.distance < $1.distance }
        }

        // Hierarchy gate: compute which parent regions are fully occluded by loaded
        // geometry.  One test per parent region instead of one per child tile.
        var occludedParentRegions: Set<String> = []
        if enableOcclusionSort, !tileOccluders.isEmpty, !tileHierarchyIndex.isEmpty,
           viewProjMatrixValid
        {
            for (prefix, aabb) in tileHierarchyIndex {
                let rect = projectAABBToScreen(
                    min: aabb.min, max: aabb.max,
                    viewProj: lastViewProjMatrix,
                    allowNearPlaneExpansion: false
                )
                guard rect.area > 1e-6 else { continue }
                // Use closest-point distance so a large parent region is not
                // classified as occluded when the camera is near its near face.
                // Center distance would pass the occluder depth gate for any
                // occluder closer than the center, which can block child tiles
                // that are right in front of the camera.
                let clamped = simd_clamp(effectiveCameraPosition, aabb.min, aabb.max)
                let dist = simd_length(clamped - effectiveCameraPosition)
                let score = tileOcclusionScore(candidateRect: rect, distance: dist,
                                               occluders: tileOccluders)
                if score <= occlusionMinWeight {
                    occludedParentRegions.insert(prefix)
                }
            }
        }

        var tileLoadCandidates: [(EntityID, Float, Int, Float, Float, Float)] = [] // (entity, effectiveDist, priority, solidAngle, viewAlignment, occlusionScore)
        var hierarchyGateSkipCount = 0
        for entityId in nearbyEntities {
            guard scene.exists(entityId) else { continue }
            guard let tileComp = scene.get(component: TileComponent.self, for: entityId)
            else { continue }

            // 4.2: Promote failed tiles to .unloaded once their retry backoff expires.
            if tileComp.state == .failed {
                let elapsed = CFAbsoluteTimeGetCurrent() - tileComp.lastFailureTime
                if elapsed >= tileComp.retryDelaySeconds {
                    tileComp.state = .unloaded
                } else {
                    continue
                }
            }

            guard tileComp.state == .unloaded else { continue }

            // Floor-proximity gate: skip tile stubs whose Y centre is too far from the
            // camera.  Without this, all 10 floors are simultaneous load candidates
            // inside a multi-floor building — O(floor_count × tiles_per_floor) work
            // per tick that spikes when the camera crosses a floor boundary.
            // Tiles already PARSED are not affected (unload is governed by their own
            // unloadRadius); the gate only suppresses new load dispatches for distant floors.
            if tileComp.isInterior,
               floorProximityGateY < Float.greatestFiniteMagnitude,
               tileComp.hasFloorMetadata
            {
                let yDist = abs(tileComp.worldYCenter - effectiveCameraPosition.y)
                if yDist > floorProximityGateY { continue }
            }

            let distance = calculateDistance(entityId: entityId, cameraPosition: effectiveCameraPosition)

            // 4.5: Use predictive distance (min of actual vs look-ahead) so tiles in
            // the direction of travel are queued before the camera physically arrives.
            let predictiveDist = calculateDistance(entityId: entityId, cameraPosition: predictivePosition)
            let effectiveDist = min(distance, predictiveDist)

            // Use effectivePrefetchRadius (midpoint of stream/unload gap by default) so
            // the tile starts loading in the background before the camera reaches the
            // visual display zone.  By the time the camera enters streamingRadius the
            // parse is already complete and the geometry appears without a blank frame.
            if effectiveDist <= tileComp.effectivePrefetchRadius + 1.0 {
                // LOD gate: if this tile has LOD levels and the camera is beyond the
                // finest switch distance, the LOD system already covers the visual.
                // Do not queue the full tile — loading it would immediately displace
                // the LOD mesh and defeat the purpose of per-tile LOD streaming.
                // The full tile is only loaded once the camera closes to within the
                // finest LOD switch distance (i.e. full-detail zone).
                if !tileComp.lodLevels.isEmpty,
                   let finestSwitch = tileComp.lodLevels.first?.switchDistance,
                   effectiveDist > finestSwitch
                {
                    continue
                }

                // Frustum gate: tile stubs have identity world transform so their
                // local AABB equals their world AABB.  Uses tileStreamingFrustum which
                // applies tileFrustumGatePadding (wider than the mesh-level pad) to
                // prevent tile pop-in during fast rotation on coarse tile boundaries.
                if !tilePassesStreamingFrustum(entityId: entityId, frustum: tileStreamingFrustum) { continue }

                let (sa, va) = tileImportanceComponents(
                    entityId: entityId,
                    distance: effectiveDist,
                    cameraPosition: effectiveCameraPosition,
                    cameraForward: lastCameraForward
                )
                // Occlusion score: fraction of this tile's screen footprint NOT
                // covered by closer loaded tiles.  1.0 = fully visible, 0 = fully
                // blocked.  Skipped when occluder list is empty (no loaded tiles yet)
                // or when occlusion sort is disabled.
                var occ: Float
                if enableOcclusionSort, !tileOccluders.isEmpty,
                   let local = scene.get(component: LocalTransformComponent.self, for: entityId)
                {
                    let rect = projectAABBToScreen(
                        min: local.boundingBox.min, max: local.boundingBox.max,
                        viewProj: lastViewProjMatrix
                    )
                    occ = tileOcclusionScore(candidateRect: rect, distance: effectiveDist,
                                             occluders: tileOccluders)
                } else {
                    occ = 1.0
                }

                // Hierarchy penalty: if any ancestor region is fully covered by loaded
                // geometry, apply a strong priority penalty instead of a hard skip.
                // The tile remains in the candidate list so it can still load when all
                // slots are free — preventing permanent holes when the camera snaps
                // toward previously-occluded geometry.
                if let nodeId = tileComp.quadtreeNodeId, !occludedParentRegions.isEmpty {
                    var ancestor = nodeId
                    while let parentPrefix = tileNodeParentPrefix(ancestor) {
                        if occludedParentRegions.contains(parentPrefix) {
                            occ *= hierarchyOcclusionPenalty
                            hierarchyGateSkipCount += 1
                            break
                        }
                        ancestor = parentPrefix
                    }
                }

                tileLoadCandidates.append((entityId, effectiveDist, tileComp.priority, sa, va, occ))
            }
        }
        lastTileLoadCandidateCount = tileLoadCandidates.count
        if !tileLoadCandidates.isEmpty {
            // Geometry budget gate: if geometry memory is already under pressure, run
            // eviction before dispatching any new tile parses.  A tile load can consume
            // tens of MB in one shot, so we check here rather than relying solely on the
            // per-mesh admission gate inside setEntityMeshAsync.
            if MemoryBudgetManager.shared.shouldEvictGeometry() {
                TextureStreamingSystem.shared.shedTextureMemory(
                    cameraPosition: effectiveCameraPosition, maxEntities: 4
                )
                let lruEvicted = evictLRU(cameraPosition: effectiveCameraPosition, maxEvictions: 8)
                // evictLRU only reclaims OCC/out-of-core stubs.  When all loaded geometry is
                // from the fullLoad path (0 OCC stubs), lruEvicted is always 0 and the budget
                // never clears, permanently blocking the tile load loop.  evictTileGeometry
                // handles fullLoad tiles, HLODs, and LODs as a second-stage pass.
                if MemoryBudgetManager.shared.shouldEvictGeometry() {
                    let tileEvicted = evictTileGeometry(cameraPosition: effectiveCameraPosition, maxEvictions: 2)
                    if lruEvicted == 0, tileEvicted == 0 {
                        Logger.logWarning(
                            message: "[TileStreaming] Geometry budget over threshold but no eviction candidates found — consider reducing scene size or shared bucket memory.",
                            category: LogCategory.tileStreaming.rawValue
                        )
                    }
                }
            }

            // Normalize solid angles relative to the largest candidate so the
            // score is scale-invariant across different scene sizes.
            let maxSA = tileLoadCandidates.max(by: { $0.3 < $1.3 })?.3 ?? 1.0
            let saFloor = max(maxSA, 1e-6)
            tileLoadCandidates.sort { lhs, rhs in
                if lhs.2 != rhs.2 { return lhs.2 > rhs.2 } // priority descending
                if enableImportanceSort {
                    let lScore = (lhs.3 / saFloor) * lhs.4 * lhs.5 // solidAngleNorm × viewAlignment × occlusionScore
                    let rScore = (rhs.3 / saFloor) * rhs.4 * rhs.5
                    if abs(lScore - rScore) > 0.001 { return lScore > rScore }
                }
                return lhs.1 < rhs.1 // fallback: closer first
            }
            for (entityId, _, _, _, _, _) in tileLoadCandidates {
                // Hard cap: never exceed maxConcurrentTileLoads regardless of budget.
                guard activeTileLoadCount() < maxConcurrentTileLoads else { break }
                // Re-check overall geometry budget after each dispatch.
                guard !MemoryBudgetManager.shared.shouldEvictGeometry() else { break }
                // 4.4: Memory budget gate — allow if adding this tile stays within budget
                // OR if nothing is currently parsing (guarantees at least one tile always loads).
                guard let tileComp = scene.get(component: TileComponent.self, for: entityId) else { continue }
                let inFlightMB = Float(activeParseBytesInFlight()) / (1024.0 * 1024.0)
                let tileMB = Float(tileComp.fileSizeBytes) / (1024.0 * 1024.0)
                guard activeTileLoadCount() == 0 || inFlightMB + tileMB <= tileParseMemoryBudgetMB else {
                    continue // too expensive right now; a smaller tile may still fit
                }
                loadTile(entityId: entityId)
            }
        }

        // ── Per-tile LOD streaming pass ────────────────────────────────────────
        // LOD load work is admitted before HLOD work because LOD covers mid/near-field
        // tiles where empty red bounds are most visible. Candidate sorting mirrors the
        // full tile path so nearby, screen-dominant tiles win load slots first.
        var lodLoadCandidates: [TileRepresentationCandidate] = []
        for entityId in nearbyEntities {
            guard scene.exists(entityId) else { continue }
            guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
                  !tileComp.lodLevels.isEmpty else { continue }

            let dist = calculateDistance(entityId: entityId, cameraPosition: effectiveCameraPosition)

            // Keep loaded LOD coverage while HLOD is loading or resident. The renderer can
            // cull/select the appropriate representation, but destroying the old LOD on the
            // same tick the HLOD becomes loaded creates visible secondary-representation pops.
            if tileComp.hlodSwitchDistance > 0 {
                let hlodLoaded = tileComp.hlodState == .loaded
                let hlodLoading = tileComp.hlodState == .loading
                let beyondHLOD = dist >= tileComp.hlodSwitchDistance
                let inHLODHysteresisBand = dist >= tileComp.hlodSwitchDistance * hlodHysteresisFactor
                if beyondHLOD || hlodLoading || (hlodLoaded && inHLODHysteresisBand) {
                    continue
                }
            }

            // Find the target LOD index with hysteresis.
            // If level i is currently the active level (loaded or loading), its unload
            // threshold is lowered to switchDistance × lodHysteresisFactor so the camera
            // must move meaningfully inward before the level is swapped out.
            // Levels that are not currently active use the full switchDistance threshold.
            let currentlyActiveIndex = tileComp.lodLevels.indices.first(where: {
                let s = tileComp.lodLevels[$0].state
                return s == .loaded || s == .loading
            })

            var targetIndex: Int? = nil
            for (i, level) in tileComp.lodLevels.enumerated() {
                let threshold: Float = (currentlyActiveIndex == i)
                    ? level.switchDistance * lodHysteresisFactor
                    : level.switchDistance
                if dist >= threshold { targetIndex = i }
            }
            let canTransitionLOD = tileComp.lastLODTransitionTime == 0 ||
                timeoutNow - tileComp.lastLODTransitionTime >= secondaryRepresentationMinDwellSeconds

            let hasLoadedLOD = tileComp.lodLevels.contains { $0.state == .loaded }
            let hasVisibleFallback = hasLoadedLOD || tileComp.hlodState == .loaded
            let needsLOD0HandoffFallback = tileLOD0HandoffPending.contains(entityId) && !hasVisibleFallback
            let fallbackTargetIndex = targetIndex ?? ((!tileHasUsableFullGeometry(tileComp) || needsLOD0HandoffFallback) ? tileComp.lodLevels.indices.first : nil)
            let fallbackUrgency = (tileComp.state == .parsing && !hasVisibleFallback) || needsLOD0HandoffFallback ? 100 : 0

            switch tileComp.state {
            case .unloaded, .failed, .parsing:
                if let target = fallbackTargetIndex {
                    lodLoadCandidates.append(makeTileRepresentationCandidate(
                        entityId: entityId,
                        distance: dist,
                        priority: tileComp.priority,
                        levelIndex: target,
                        cameraPosition: effectiveCameraPosition,
                        tileOccluders: tileOccluders,
                        urgency: fallbackUrgency
                    ))
                } else if canTransitionLOD {
                    unloadAllLODLevels(entityId: entityId)
                }
            case .parsed:
                if tileHasUsableFullGeometry(tileComp), !tileLOD0HandoffPending.contains(entityId) {
                    if !beginFadeFromTileFallbacksToFullTile(entityId: entityId, tileComp: tileComp) {
                        unloadAllLODLevels(entityId: entityId)
                    }
                } else if let target = fallbackTargetIndex {
                    lodLoadCandidates.append(makeTileRepresentationCandidate(
                        entityId: entityId,
                        distance: dist,
                        priority: tileComp.priority,
                        levelIndex: target,
                        cameraPosition: effectiveCameraPosition,
                        tileOccluders: tileOccluders,
                        urgency: fallbackUrgency
                    ))
                }
            case .unloading:
                // Keep active LOD visible during the full-tile load for continuity.
                break
            }
        }
        sortTileRepresentationCandidates(&lodLoadCandidates)
        for candidate in lodLoadCandidates {
            guard scene.exists(candidate.entityId),
                  let tileComp = scene.get(component: TileComponent.self, for: candidate.entityId),
                  candidate.levelIndex < tileComp.lodLevels.count
            else { continue }

            let currentlyActiveIndex = tileComp.lodLevels.indices.first(where: {
                let s = tileComp.lodLevels[$0].state
                return s == .loaded || s == .loading
            })
            let canTransitionLOD = tileComp.lastLODTransitionTime == 0 ||
                timeoutNow - tileComp.lastLODTransitionTime >= secondaryRepresentationMinDwellSeconds

            if tileComp.lodLevels[candidate.levelIndex].state == .unloaded,
               currentlyActiveIndex == nil || canTransitionLOD
            {
                guard activeLODLoadCount() < maxConcurrentLODLoads else { break }
                loadLODLevel(entityId: candidate.entityId, levelIndex: candidate.levelIndex)
            }

            for i in tileComp.lodLevels.indices where i != candidate.levelIndex {
                if canTransitionLOD,
                   tileComp.lodLevels[candidate.levelIndex].state == .loaded,
                   tileComp.lodLevels[i].state != .unloaded
                {
                    let startedFade = beginTileRepresentationFade(
                        tileEntityId: candidate.entityId,
                        incomingRenderIds: lodRenderDescendantIds(tileComp, levelIndex: candidate.levelIndex),
                        outgoingRenderIds: lodRenderDescendantIds(tileComp, levelIndex: i),
                        completion: .unloadLODLevel(i)
                    )
                    if !startedFade {
                        unloadLODLevel(entityId: candidate.entityId, levelIndex: i)
                    }
                }
            }
        }

        // ── HLOD streaming pass ────────────────────────────────────────────────
        // HLODs are sorted too, but are admitted after full-tile and LOD candidates.
        // This gives nearby/mid-field coverage first chance at load slots while still
        // allowing far-field proxies to fill their own cap during cold scene startup.
        var hlodLoadCandidates: [TileRepresentationCandidate] = []
        for entityId in nearbyEntities {
            guard scene.exists(entityId) else { continue }
            guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
                  tileComp.hlodURL != nil,
                  tileComp.hlodSwitchDistance > 0 else { continue }

            let dist = calculateDistance(entityId: entityId, cameraPosition: effectiveCameraPosition)
            let canTransitionHLOD = tileComp.lastHLODTransitionTime == 0 ||
                timeoutNow - tileComp.lastHLODTransitionTime >= secondaryRepresentationMinDwellSeconds

            if dist > tileComp.hlodSwitchDistance, tileComp.hlodState == .loaded {
                retireLODLevelsCoveredByHLOD(entityId: entityId, tileComp: tileComp)
            }

            switch tileComp.state {
            case .unloaded, .failed:
                if dist > tileComp.hlodSwitchDistance {
                    if tileComp.hlodState == .unloaded {
                        hlodLoadCandidates.append(makeTileRepresentationCandidate(
                            entityId: entityId,
                            distance: dist,
                            priority: tileComp.priority,
                            levelIndex: -1,
                            cameraPosition: effectiveCameraPosition,
                            tileOccluders: tileOccluders
                        ))
                    }
                } else if dist < tileComp.hlodSwitchDistance * hlodHysteresisFactor {
                    // Camera has moved meaningfully inside the switch distance —
                    // HLOD is no longer needed.  The hysteresis band
                    // [switchDistance * factor, switchDistance) keeps the HLOD
                    // resident while the camera lingers at the boundary.
                    if canTransitionHLOD,
                       tileComp.hlodState != .unloaded,
                       tileHasLoadedLOD(tileComp) || tileHasUsableFullGeometry(tileComp)
                    {
                        var incoming: Set<EntityID> = []
                        if tileHasUsableFullGeometry(tileComp) {
                            incoming = fullTileRenderDescendantIds(tileEntityId: entityId)
                        } else if let loadedLOD = tileComp.lodLevels.indices.first(where: { tileComp.lodLevels[$0].state == .loaded }) {
                            incoming = lodRenderDescendantIds(tileComp, levelIndex: loadedLOD)
                        }
                        let startedFade = beginTileRepresentationFade(
                            tileEntityId: entityId,
                            incomingRenderIds: incoming,
                            outgoingRenderIds: hlodRenderDescendantIds(tileComp),
                            completion: .unloadHLOD
                        )
                        if !startedFade {
                            unloadHLOD(entityId: entityId)
                        }
                    }
                }
            // else: inside hysteresis band — keep current HLOD state.
            case .parsed:
                // Full geometry must be renderable before HLOD coverage is dropped.
                if tileHasUsableFullGeometry(tileComp),
                   !tileLOD0HandoffPending.contains(entityId),
                   tileComp.hlodState != .unloaded
                {
                    let startedFade = beginTileRepresentationFade(
                        tileEntityId: entityId,
                        incomingRenderIds: fullTileRenderDescendantIds(tileEntityId: entityId),
                        outgoingRenderIds: hlodRenderDescendantIds(tileComp),
                        completion: .unloadHLOD
                    )
                    if !startedFade {
                        unloadHLOD(entityId: entityId)
                    }
                }
            case .parsing, .unloading:
                // Keep HLOD visible during full-tile load for a seamless transition.
                break
            }
        }
        sortTileRepresentationCandidates(&hlodLoadCandidates)
        for candidate in hlodLoadCandidates {
            guard activeHLODLoadCount() < maxConcurrentHLODLoads else { break }
            guard scene.exists(candidate.entityId),
                  let tileComp = scene.get(component: TileComponent.self, for: candidate.entityId),
                  tileComp.hlodState == .unloaded
            else { continue }
            loadHLOD(entityId: candidate.entityId)
        }

        // Also check loaded entities that might now be out of range
        // (they may not be in the octree query if they're far away)
        let nearbySet = Set(nearbyEntities) // O(1) lookup

        // ── Tile unload pass ───────────────────────────────────────────────────
        // Grace period: both .parsed and .parsing tiles stay resident for
        // unloadGracePeriod seconds after exceeding unloadRadius before being torn
        // down.  .parsed tiles need the grace window to avoid visible pop-out at tile
        // boundaries.  .parsing tiles also honour the grace period: letting an in-flight
        // parse complete (1–2 s) before cancelling prevents tight load-cancel cycles when
        // the camera oscillates near the unload boundary.  Immediate cancellation of
        // .parsing tiles was a false economy — the cancelled Task still ran to completion
        // and consumed its slot before the state reset, so the tile was immediately
        // re-dispatched on the next tick, cycling indefinitely.
        // All three passes use min(actual, predictive) distance, matching the load pass,
        // so a tile the camera is approaching is not torn down mid-parse.
        var tileUnloadCandidates: [EntityID] = []
        let now = CFAbsoluteTimeGetCurrent()

        // 1. Tiles still within the octree query but beyond their unload radius.
        for entityId in nearbyEntities {
            guard scene.exists(entityId) else { continue }
            guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
                  tileComp.state == .parsed || tileComp.state == .parsing
            else { continue }
            let distance = calculateDistance(entityId: entityId, cameraPosition: effectiveCameraPosition)
            let predictiveUnloadDist = calculateDistance(entityId: entityId, cameraPosition: predictivePosition)
            let effectiveUnloadDist = min(distance, predictiveUnloadDist)

            if effectiveUnloadDist <= tileComp.unloadRadius {
                // Back in range (actual or predictive) — reset grace timer so a future
                // exit starts fresh rather than expiring against a stale timestamp.
                if tileComp.pendingUnloadSince != 0 { tileComp.pendingUnloadSince = 0 }
            } else {
                // Beyond unload radius for both actual and predictive positions.
                // Both .parsing and .parsed honour the grace period (see comment above).
                if tileComp.pendingUnloadSince == 0 {
                    tileComp.pendingUnloadSince = now
                } else if tileUnloadDwellSatisfied(tileComp, now: now) {
                    tileUnloadCandidates.append(entityId)
                }
            }
        }

        // 2. Parsed tiles that fell entirely outside the octree query radius.
        var staleTileIds: [EntityID] = []
        let tileSnapshot = loadedTileEntitiesSnapshot()
        for entityId in tileSnapshot {
            if nearbySet.contains(entityId) { continue } // already handled in pass 1
            guard scene.exists(entityId) else {
                staleTileIds.append(entityId)
                continue
            }
            guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
                  tileComp.state == .parsed
            else { continue }
            let distance = calculateDistance(entityId: entityId, cameraPosition: effectiveCameraPosition)
            let predictiveUnloadDist2 = calculateDistance(entityId: entityId, cameraPosition: predictivePosition)
            let effectiveUnloadDist2 = min(distance, predictiveUnloadDist2)
            if effectiveUnloadDist2 > tileComp.unloadRadius {
                if tileComp.pendingUnloadSince == 0 {
                    tileComp.pendingUnloadSince = now
                } else if tileUnloadDwellSatisfied(tileComp, now: now) {
                    tileUnloadCandidates.append(entityId)
                }
            } else if tileComp.pendingUnloadSince != 0 {
                tileComp.pendingUnloadSince = 0
            }
        }

        // 3. Parsing tiles that fell entirely outside the octree query radius (e.g. fast
        //    movement or teleport while a parse was in flight).  Without this check they
        //    finish parsing, appear far away for one tick, then get unloaded — causing
        //    ghost geometry flashes on camera jumps.  These tiles are genuinely far away
        //    (> maxQueryRadius = 500 m) so no grace period is applied — the camera cannot
        //    oscillate at a 500 m boundary.  Predictive distance is still used so a fast-
        //    approaching camera does not cancel a parse it is about to need.
        let loadingTileSnapshot = loadingTileEntitiesSnapshot()
        for entityId in loadingTileSnapshot {
            if nearbySet.contains(entityId) { continue } // already handled in pass 1
            guard scene.exists(entityId) else {
                unmarkLoadingTileEntity(entityId)
                continue
            }
            guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
                  tileComp.state == .parsing
            else { continue }
            let distance = calculateDistance(entityId: entityId, cameraPosition: effectiveCameraPosition)
            let predictiveUnloadDist3 = calculateDistance(entityId: entityId, cameraPosition: predictivePosition)
            let effectiveUnloadDist3 = min(distance, predictiveUnloadDist3)
            if effectiveUnloadDist3 > tileComp.unloadRadius {
                tileUnloadCandidates.append(entityId)
            }
        }

        for staleId in staleTileIds {
            unmarkLoadedTileEntity(staleId)
        }
        // Cap tile unloads per tick to spread GPU buffer releases across frames,
        // preventing a one-frame blank when many tiles leave range simultaneously.
        let cappedUnloads = tileUnloadCandidates.prefix(maxTileUnloadsPerUpdate)
        for entityId in cappedUnloads {
            unloadTile(entityId: entityId)
        }

        // ── HLOD out-of-range cleanup ──────────────────────────────────────────
        // Tiles with a loaded HLOD mesh that fell outside the octree query radius
        // (e.g. fast movement or teleport) must be cleaned up here; they won't
        // appear in nearbyEntities so the HLOD pass above cannot reach them.
        let hlodSnapshot = loadedHLODEntitiesSnapshot()
        for entityId in hlodSnapshot {
            if nearbySet.contains(entityId) { continue } // already handled above
            guard scene.exists(entityId) else {
                unmarkLoadedHLODEntity(entityId)
                continue
            }
            unloadHLOD(entityId: entityId)
        }

        // ── LOD out-of-range cleanup ───────────────────────────────────────────
        // Same as HLOD cleanup: tiles with an active LOD level that drifted outside
        // the octree query radius are cleaned up here.
        let lodSnapshot = loadedLODEntitiesSnapshot()
        for entityId in lodSnapshot {
            if nearbySet.contains(entityId) { continue }
            guard scene.exists(entityId) else {
                unmarkLoadedLODEntity(entityId)
                continue
            }
            unloadAllLODLevels(entityId: entityId)
        }

        var staleEntityIds: [EntityID] = []

        let trackedLoadedSnapshot = loadedStreamingEntitiesSnapshot()
        for entityId in trackedLoadedSnapshot {
            // Skip if already processed via octree query
            if nearbySet.contains(entityId) { continue }

            // Check if entity still exists first (handles destroyed/recreated entities)
            guard scene.exists(entityId) else {
                staleEntityIds.append(entityId)
                continue
            }

            guard let streaming = scene.get(component: StreamingComponent.self, for: entityId),
                  streaming.state == .loaded
            else { continue }

            let distance = calculateDistance(entityId: entityId, cameraPosition: effectiveCameraPosition)
            if distance > streaming.unloadRadius {
                unloadCandidates.append((entityId, distance))
            }
        }

        // Clean up stale entity IDs
        for staleId in staleEntityIds {
            unmarkLoadedStreamingEntity(staleId)
        }

        // Process unloads first (free memory), but cap per update to smooth spikes.
        unloadCandidates.sort { lhs, rhs in lhs.1 > rhs.1 } // farthest first
        let unloadBudget = max(1, maxUnloadsPerUpdate)
        var processedUnloads = 0
        for (entityId, _) in unloadCandidates.prefix(unloadBudget) {
            unloadMesh(entityId: entityId)
            processedUnloads += 1
        }

        // Sort load candidates: high priority first, then by screen-space importance
        // (bounding radius / distance). Falls back to distance when importance sorting
        // is disabled or two candidates have the same importance score.
        loadCandidates.sort { lhs, rhs in
            if lhs.2 != rhs.2 { return lhs.2 > rhs.2 } // priority descending
            if enableImportanceSort { return lhs.3 > rhs.3 } // larger screen footprint first
            return lhs.1 < rhs.1 // fallback: closer first
        }

        // Check memory budget BEFORE starting new loads.
        // Without this guard, all in-range stubs can upload simultaneously, pushing
        // GPU memory past the OS kill threshold on Vision Pro.
        var evictionTriggered = false
        var evictedByLRU = 0

        // OS memory pressure relief — flag is set from a background queue callback;
        // we drain it here on the main update thread so all eviction stays single-threaded.
        var pendingPressure = false
        var aggressivePressure = false
        withStateLock {
            pendingPressure = pendingPressureRelief
            aggressivePressure = pressureIsAggressive
            pendingPressureRelief = false
            pressureIsAggressive = false
        }
        if pendingPressure {
            let maxEntities = aggressivePressure ? 20 : 8
            TextureStreamingSystem.shared.shedTextureMemory(
                cameraPosition: effectiveCameraPosition, maxEntities: maxEntities
            )
            // Cap per-call evictions to prevent a single pressure event from monopolising
            // the frame. 16 entities per pass bounds synchronous unloadMesh work; any
            // remaining geometry is evicted on subsequent ticks until pressure clears.
            evictedByLRU += evictLRU(cameraPosition: effectiveCameraPosition, maxEvictions: 16)
            if aggressivePressure {
                // Second pass for critical pressure: push harder to free geometry.
                evictedByLRU += evictLRU(cameraPosition: effectiveCameraPosition, maxEvictions: 16)

                // TODO: release .untold OCC CPU heap entries under critical pressure
                // (CPURuntimeEntry Data blobs per stub entity).
            }
            evictionTriggered = true
        }

        // Texture-first relief: if combined GPU memory (mesh + texture) is high but
        // geometry alone is not, downgrade textures on distant entities before
        // considering geometry eviction. A texture resolution drop on a far wall is
        // far less noticeable than a missing mesh.
        if MemoryBudgetManager.shared.shouldEvict(), !MemoryBudgetManager.shared.shouldEvictGeometry() {
            TextureStreamingSystem.shared.shedTextureMemory(cameraPosition: effectiveCameraPosition)
        }

        if MemoryBudgetManager.shared.shouldEvictGeometry() {
            // Shed texture quality first; geometry eviction is the last resort.
            TextureStreamingSystem.shared.shedTextureMemory(
                cameraPosition: effectiveCameraPosition, maxEntities: 8
            )
            evictionTriggered = true
            evictedByLRU = evictLRU(cameraPosition: effectiveCameraPosition)
            if MemoryBudgetManager.shared.shouldEvictGeometry() {
                evictedByLRU += evictTileGeometry(cameraPosition: effectiveCameraPosition, maxEvictions: 4)
            }
        }

        // Partition candidates into near band and rest band.
        // Near band (distance ≤ streamingRadius × nearBandFraction) is serialized so the
        // closest meshes always appear in distance order. Rest band uses remaining slots freely.
        var nearBandCandidates: [(EntityID, Float, Int, Float)] = []
        var restBandCandidates: [(EntityID, Float, Int, Float)] = []
        for candidate in loadCandidates {
            let (entityId, distance, priority, importance) = candidate
            let radius = scene.get(component: StreamingComponent.self, for: entityId)?.streamingRadius ?? Float.greatestFiniteMagnitude
            if radius < Float.greatestFiniteMagnitude, distance <= radius * nearBandFraction {
                nearBandCandidates.append((entityId, distance, priority, importance))
            } else {
                restBandCandidates.append((entityId, distance, priority, importance))
            }
        }

        let availableSlots = maxConcurrentLoads - activeLoadCountSnapshot()
        lastLoadCandidateCount = loadCandidates.count
        lastPendingLoadBacklog = max(0, loadCandidates.count - max(0, availableSlots))
        var startedLoads = 0

        // [Instrumentation] Log queue depth every tick that has candidates.
        // Helps confirm whether near-band serialization is building a backlog.
        if !loadCandidates.isEmpty {
            Logger.log(
                message: "[OOC-Timing] Queue: near=\(nearBandCandidates.count) rest=\(restBandCandidates.count) activeNear=\(activeNearBandLoadCount()) activeTotal=\(activeLoadCountSnapshot()) slots=\(availableSlots) backlog=\(lastPendingLoadBacklog)",
                category: LogCategory.oocTiming.rawValue
            )
        }

        // Determine effective near-band concurrency for this tick.
        //
        // Default (nearBandMaxConcurrentLoads = 1): serializes near-band loads so the
        // closest mesh always appears before farther ones — prevents random pop-in order
        // across different objects.
        //
        // Burst exception: when every near-band candidate shares the same root asset
        // (i.e., all are sub-meshes of one USDZ), the distance-ordering goal is already
        // satisfied at the asset level and per-mesh serialization only wastes slots.
        // In that case, allow the full global concurrency — the per-asset texture lock
        // is the actual safety gate against MDLAsset races.
        let nearBandEffectiveMax: Int = {
            guard nearBandCandidates.count > 1 else { return nearBandMaxConcurrentLoads }
            var commonRoot: EntityID? = nil
            for (entityId, _, _, _) in nearBandCandidates {
                guard let r = scene.get(component: DerivedAssetNodeComponent.self, for: entityId)?.assetRootEntityId else {
                    return nearBandMaxConcurrentLoads // non-OOC entity → keep default ordering
                }
                if commonRoot == nil { commonRoot = r }
                else if commonRoot != r { return nearBandMaxConcurrentLoads } // multiple roots → keep ordering
            }
            return commonRoot != nil ? maxConcurrentLoads : nearBandMaxConcurrentLoads
        }()

        // Geometry-only gate: texture memory does not block mesh loads.
        // Texture pressure is managed independently by TextureStreamingSystem.
        if !MemoryBudgetManager.shared.shouldEvictGeometry() {
            // Near band: serialized by default; expanded to maxConcurrentLoads for single-root bursts.
            let nearSlots = max(0, min(
                nearBandEffectiveMax - activeNearBandLoadCount(),
                availableSlots - startedLoads
            ))
            var nearDispatched = 0
            for (entityId, _, _, _) in nearBandCandidates {
                guard nearDispatched < nearSlots else { break }
                // Skip OOC child entities whose CPU data isn't registered yet.
                // Dispatching them wastes a slot on a disk-path fallback that will fail —
                // CPU entries are populated by the registration system shortly after this tick.
                // Cold roots are exempt: they rehydrate intentionally from disk.
                // Skip .untold OCC stubs whose CPU data isn't registered yet.
                if ProgressiveAssetLoader.shared.hasCPURuntimeData(for: entityId) == false,
                   scene.get(component: DerivedAssetNodeComponent.self, for: entityId) != nil
                {
                    continue
                }
                // Per-candidate geometry budget check: evict if this mesh won't fit.
                if let runtimeEntry = ProgressiveAssetLoader.shared.retrieveCPURuntimeEntry(for: entityId),
                   !MemoryBudgetManager.shared.canAcceptMesh(sizeBytes: runtimeEntry.estimatedGPUBytes)
                {
                    evictedByLRU += evictLRU(cameraPosition: effectiveCameraPosition)
                    evictionTriggered = true
                    guard MemoryBudgetManager.shared.canAcceptMesh(sizeBytes: runtimeEntry.estimatedGPUBytes) else { continue }
                }
                loadMesh(entityId: entityId, isNearBand: true)
                startedLoads += 1
                nearDispatched += 1
            }

            // Rest band: remaining global slots
            let restSlots = max(0, availableSlots - startedLoads)
            var restDispatched = 0
            for (entityId, _, _, _) in restBandCandidates {
                guard restDispatched < restSlots else { break }
                // Skip .untold OCC stubs whose CPU data isn't registered yet.
                if ProgressiveAssetLoader.shared.hasCPURuntimeData(for: entityId) == false,
                   scene.get(component: DerivedAssetNodeComponent.self, for: entityId) != nil
                {
                    continue
                }
                // Per-candidate geometry budget check for out-of-core rest-band entities.
                if let runtimeEntry = ProgressiveAssetLoader.shared.retrieveCPURuntimeEntry(for: entityId),
                   !MemoryBudgetManager.shared.canAcceptMesh(sizeBytes: runtimeEntry.estimatedGPUBytes)
                {
                    evictedByLRU += evictLRU(cameraPosition: effectiveCameraPosition)
                    evictionTriggered = true
                    guard MemoryBudgetManager.shared.canAcceptMesh(sizeBytes: runtimeEntry.estimatedGPUBytes) else { continue }
                }
                loadMesh(entityId: entityId, isNearBand: false)
                startedLoads += 1
                restDispatched += 1
            }
        }

        auditLOD0FallbackHandoffs(tileFrustum: tileStreamingFrustum)

        if tileRepresentationDiagnosticsEnabled {
            auditTileRepresentationDiagnostics(
                nearbyEntities: nearbyEntities,
                cameraPosition: effectiveCameraPosition,
                tileFrustum: tileStreamingFrustum
            )
        }

        let updateWorkMs = (CFAbsoluteTimeGetCurrent() - updateStart) * 1000.0
        peakTickMs = max(peakTickMs, updateWorkMs)
        let activeLoadsAtEnd = activeLoadCountSnapshot()
        withStateLock {
            diagnostics.updateFrame = currentFrame
            diagnostics.updateTriggered = true
            diagnostics.updateWorkMs = updateWorkMs
            diagnostics.nearbyEntitiesQueried = nearbyEntities.count
            diagnostics.unloadCandidates = unloadCandidates.count
            diagnostics.processedUnloads = processedUnloads
            diagnostics.loadCandidates = loadCandidates.count
            diagnostics.startedLoads = startedLoads
            diagnostics.availableLoadSlots = availableSlots
            diagnostics.activeLoadsAtUpdateStart = activeLoadsAtStart
            diagnostics.activeLoadsAtUpdateEnd = activeLoadsAtEnd
            diagnostics.evictionTriggered = evictionTriggered
            diagnostics.evictionsPerformed = evictedByLRU
            diagnostics.tilesSkippedByHierarchyGate = hierarchyGateSkipCount
        }
    }

    func recordLoadCompletion(success: Bool, asyncLoadMs: Double, applyMs: Double, wasLODReload: Bool) {
        withStateLock {
            diagnostics.lastAsyncLoadMs = asyncLoadMs
            diagnostics.lastApplyLoadedMeshMs = applyMs
            if wasLODReload {
                diagnostics.lastAsyncReloadLODMs = asyncLoadMs
            }
            if success {
                completedAsyncLoads += 1
                cumulativeAsyncLoadMs += asyncLoadMs
            } else {
                diagnostics.lastFailedAsyncLoadMs = asyncLoadMs
            }
            if completedAsyncLoads > 0 {
                diagnostics.averageAsyncLoadMs = cumulativeAsyncLoadMs / Double(completedAsyncLoads)
            } else {
                diagnostics.averageAsyncLoadMs = 0
            }
        }
    }

    func updateLastUnloadDuration(_ unloadMs: Double) {
        withStateLock {
            diagnostics.lastUnloadMeshMs = unloadMs
        }
    }

    /// Returns bounding-radius / distance — a proxy for how large the entity appears
    /// on screen.  Used to sort load candidates so objects with a bigger screen footprint
    /// are streamed in before smaller ones at a similar distance.
    func importanceScore(entityId: EntityID, distance: Float) -> Float {
        let radius: Float
        if let local = scene.get(component: LocalTransformComponent.self, for: entityId) {
            let half = (local.boundingBox.max - local.boundingBox.min) * 0.5
            radius = max(max(half.x, half.y), half.z)
        } else {
            radius = 1.0
        }
        return radius / max(distance, 1.0)
    }

    /// Returns the two raw importance components for a tile load candidate.
    ///
    /// - `solidAngle`: projected silhouette area of the tile AABB as seen from the
    ///   camera, divided by distance².  Proportional to how many pixels the tile
    ///   occupies.  Unnormalized — the caller normalizes across the full candidate set.
    /// - `viewAlignment`: how centered the tile is in the camera's view, remapped
    ///   from [0, 1] to [viewAlignmentMinWeight, 1.0] so peripheral tiles are
    ///   penalised but not zeroed.
    ///
    /// Tile stubs have identity world transforms so local AABB == world AABB;
    /// no matrix multiply is needed to get world-space half-extents.
    func tileImportanceComponents(
        entityId: EntityID,
        distance: Float,
        cameraPosition: simd_float3,
        cameraForward: simd_float3
    ) -> (solidAngle: Float, viewAlignment: Float) {
        guard let local = scene.get(component: LocalTransformComponent.self, for: entityId)
        else { return (0, 1) }

        let half = (local.boundingBox.max - local.boundingBox.min) * 0.5
        let center = (local.boundingBox.min + local.boundingBox.max) * 0.5

        // Unit vector from camera to tile center.
        // Falls back to cameraForward when the camera is inside the tile (distance ≈ 0).
        let raw = center - cameraPosition
        let rawLen = simd_length(raw)
        let dir = rawLen > 1e-4 ? raw / rawLen : cameraForward

        // Projected silhouette area of the AABB seen from direction dir:
        //   2 × (hy·hz·|dx| + hx·hz·|dy| + hx·hy·|dz|)
        // Captures the actual visible footprint of anisotropic tiles (floors, walls)
        // that radius/distance treats as spheres and systematically undersizes.
        let projectedArea = 2.0 * (half.y * half.z * abs(dir.x)
            + half.x * half.z * abs(dir.y)
            + half.x * half.y * abs(dir.z))
        let solidAngle = projectedArea / max(distance * distance, 1.0)

        // View alignment: direction from camera to the CLOSEST AABB surface point,
        // not the center.  For large anisotropic tiles (a 400 m facade, a wide floor
        // slab) the center can be far off-axis while the visible surface is directly
        // in front — using the center underranks these tiles when they matter most.
        // The closest point represents "the part the camera is actually pointing toward."
        // Falls back to cameraForward when the camera is inside the AABB (distance ≈ 0).
        let closestPoint = simd_clamp(cameraPosition, local.boundingBox.min, local.boundingBox.max)
        let rawClose = closestPoint - cameraPosition
        let closeLen = simd_length(rawClose)
        let closeDir = closeLen > 1e-4 ? rawClose / closeLen : cameraForward
        let alignment = max(0, simd_dot(cameraForward, closeDir))
        let viewAlignment = viewAlignmentMinWeight + (1.0 - viewAlignmentMinWeight) * alignment

        return (solidAngle, viewAlignment)
    }

    /// Projects an AABB into NDC screen space using the cached view-projection matrix.
    ///
    /// All 8 corners are transformed.  Corners with w ≤ 0 (behind the near plane)
    /// are skipped; what happens next depends on `allowNearPlaneExpansion`:
    ///
    ///   true  (candidates): expands the rect to the screen edges so partially-clipped
    ///         tiles don't undercount their footprint — a tile the camera is near should
    ///         not be penalised by a smaller-than-real occluder target.
    ///
    ///   false (occluders):  returns a zero-area rect immediately.  A tile whose AABB
    ///         clips the near plane — e.g. an ExteriorShell the camera is standing inside
    ///         — would otherwise expand to fill the screen and drive every candidate's
    ///         occlusionScore to 0.
    ///
    /// If every corner is behind the camera a zero-area rect is returned in both modes.
    func projectAABBToScreen(min bbMin: simd_float3, max bbMax: simd_float3,
                             viewProj: simd_float4x4,
                             allowNearPlaneExpansion: Bool = true) -> ScreenRect
    {
        let corners: [simd_float3] = [
            bbMin,
            simd_float3(bbMax.x, bbMin.y, bbMin.z),
            simd_float3(bbMin.x, bbMax.y, bbMin.z),
            simd_float3(bbMin.x, bbMin.y, bbMax.z),
            simd_float3(bbMax.x, bbMax.y, bbMin.z),
            simd_float3(bbMax.x, bbMin.y, bbMax.z),
            simd_float3(bbMin.x, bbMax.y, bbMax.z),
            bbMax,
        ]
        var ndcMinX = Float.greatestFiniteMagnitude
        var ndcMinY = Float.greatestFiniteMagnitude
        var ndcMaxX: Float = -Float.greatestFiniteMagnitude
        var ndcMaxY: Float = -Float.greatestFiniteMagnitude
        var anyBehind = false
        var hasValid = false

        for c in corners {
            let clip = viewProj * simd_float4(c, 1)
            guard clip.w > 1e-6 else { anyBehind = true; continue }
            hasValid = true
            let nx = clip.x / clip.w
            let ny = clip.y / clip.w
            ndcMinX = min(ndcMinX, nx); ndcMaxX = max(ndcMaxX, nx)
            ndcMinY = min(ndcMinY, ny); ndcMaxY = max(ndcMaxY, ny)
        }

        guard hasValid else { return ScreenRect(minX: 0, minY: 0, maxX: 0, maxY: 0) }

        if anyBehind {
            guard allowNearPlaneExpansion else {
                // Occluder mode: discard near-plane-clipped tiles rather than expanding
                // them to full-screen, which would falsely drive candidate scores to 0.
                return ScreenRect(minX: 0, minY: 0, maxX: 0, maxY: 0)
            }
            // Candidate mode: expand conservatively so the footprint isn't undercounted.
            ndcMinX = min(ndcMinX, -1); ndcMaxX = max(ndcMaxX, 1)
            ndcMinY = min(ndcMinY, -1); ndcMaxY = max(ndcMaxY, 1)
        }
        return ScreenRect(minX: max(-1, ndcMinX), minY: max(-1, ndcMinY),
                          maxX: min(1, ndcMaxX), maxY: min(1, ndcMaxY))
    }

    /// Maps a ScreenRect to the 8×8 NDC grid cells it overlaps, as a UInt64 bitmask.
    ///
    /// The screen is divided into 64 cells (8 columns × 8 rows) each 0.25 NDC units wide.
    /// Bit i represents cell (i / 8, i % 8).  Cell boundaries that fall inside a rect are
    /// included conservatively (floor of the upper bound) so occluder coverage is never
    /// understated.  Using a bitmask means unioning two overlapping occluders with `|`
    /// produces the correct union area — no double-counting.
    func rectToScreenMask(_ rect: ScreenRect) -> UInt64 {
        // A zero-area rect (e.g. from an all-behind-camera tile) maps min == max to the
        // same cell on each axis, passing the c0 <= c1 guard and producing a spurious
        // single-cell mask.  Reject before any cell computation.
        guard rect.area > 1e-6 else { return 0 }
        let gridN = 8
        let scale = Float(gridN) * 0.5 // maps NDC [-1, 1] → [0, gridN]
        let c0 = max(0, Int(floor((rect.minX + 1.0) * scale)))
        let c1 = min(gridN - 1, Int(floor((rect.maxX + 1.0) * scale)))
        let r0 = max(0, Int(floor((rect.minY + 1.0) * scale)))
        let r1 = min(gridN - 1, Int(floor((rect.maxY + 1.0) * scale)))
        guard c0 <= c1, r0 <= r1 else { return 0 }
        var mask: UInt64 = 0
        for r in r0 ... r1 {
            for c in c0 ... c1 {
                mask |= 1 << UInt64(r * gridN + c)
            }
        }
        return mask
    }

    /// Returns the fraction of `candidateRect` NOT covered by the union of closer
    /// loaded-tile occluders.  1.0 = fully visible, occlusionMinWeight = fully blocked.
    ///
    /// Coverage is computed on an 8×8 NDC grid using bitmask union (|) so overlapping
    /// occluders are never double-counted.  Occluders must be sorted ascending by
    /// distance for the early-exit to work.
    ///
    /// The return value is floored at occlusionMinWeight (default 0.05) rather than 0
    /// so a tile classified as fully blocked by AABB heuristics still has a small chance
    /// of loading — tile AABBs are opaque proxies and may over-occlude glass, sparse
    /// meshes, or concave geometry.
    func tileOcclusionScore(candidateRect: ScreenRect, distance: Float,
                            occluders: [TileOccluder]) -> Float
    {
        let candidateMask = rectToScreenMask(candidateRect)
        guard candidateMask != 0 else { return 1.0 }
        let candidateCells = candidateMask.nonzeroBitCount

        // Convert the threshold fraction to a cell count once; avoids repeated division.
        let thresholdCells = Int((Float(candidateCells) * occlusionFullThreshold).rounded(.up))

        var unionMask: UInt64 = 0
        for occluder in occluders {
            guard occluder.distance < distance else { break }
            unionMask |= rectToScreenMask(occluder.rect)
            // Early exit when enough cells are covered — floor at occlusionMinWeight so
            // over-conservative AABB coverage (glass, sparse mesh) doesn't hard-block loads.
            if (unionMask & candidateMask).nonzeroBitCount >= thresholdCells {
                return occlusionMinWeight
            }
        }

        let coveredCells = (unionMask & candidateMask).nonzeroBitCount
        return max(occlusionMinWeight, 1.0 - Float(coveredCells) / Float(candidateCells))
    }

    func tilePassesStreamingFrustum(entityId: EntityID, frustum: Frustum?) -> Bool {
        guard CameraSystem.shared.activeCamera != nil else { return true }
        guard let f = frustum,
              let local = scene.get(component: LocalTransformComponent.self, for: entityId)
        else { return true }
        let center = (local.boundingBox.min + local.boundingBox.max) * 0.5
        let halfExtent = (local.boundingBox.max - local.boundingBox.min) * 0.5
        return isAABBInFrustum(center: center, halfExtent: halfExtent, frustum: f)
    }

    func makeTileRepresentationCandidate(
        entityId: EntityID,
        distance: Float,
        priority: Int,
        levelIndex: Int,
        cameraPosition: simd_float3,
        tileOccluders: [TileOccluder],
        urgency: Int = 0
    ) -> TileRepresentationCandidate {
        let (solidAngle, viewAlignment) = tileImportanceComponents(
            entityId: entityId,
            distance: distance,
            cameraPosition: cameraPosition,
            cameraForward: lastCameraForward
        )

        let occlusionScore: Float
        if enableOcclusionSort, !tileOccluders.isEmpty,
           let local = scene.get(component: LocalTransformComponent.self, for: entityId)
        {
            let rect = projectAABBToScreen(
                min: local.boundingBox.min, max: local.boundingBox.max,
                viewProj: lastViewProjMatrix
            )
            occlusionScore = tileOcclusionScore(
                candidateRect: rect,
                distance: distance,
                occluders: tileOccluders
            )
        } else {
            occlusionScore = 1.0
        }

        return TileRepresentationCandidate(
            entityId: entityId,
            distance: distance,
            priority: priority,
            urgency: urgency,
            solidAngle: solidAngle,
            viewAlignment: viewAlignment,
            occlusionScore: occlusionScore,
            levelIndex: levelIndex
        )
    }

    func sortTileRepresentationCandidates(_ candidates: inout [TileRepresentationCandidate]) {
        let maxSA = candidates.max(by: { $0.solidAngle < $1.solidAngle })?.solidAngle ?? 1.0
        let saFloor = max(maxSA, 1e-6)
        candidates.sort { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            if lhs.urgency != rhs.urgency { return lhs.urgency > rhs.urgency }
            if enableImportanceSort {
                let lScore = (lhs.solidAngle / saFloor) * lhs.viewAlignment * lhs.occlusionScore
                let rScore = (rhs.solidAngle / saFloor) * rhs.viewAlignment * rhs.occlusionScore
                if abs(lScore - rScore) > 0.001 { return lScore > rScore }
            }
            return lhs.distance < rhs.distance
        }
    }

    /// Returns the parent prefix for a spatial node ID, handling both manifest formats:
    ///
    /// - Underscore format (v4 inline annotation):
    ///     `"F02_Q_0_0_0"` → `"F02_Q_0_0"`  (drop from last `_` onward)
    /// - Compact format (pre-annotated phase12 quadtree):
    ///     `"F02Q100"` → `"F02Q10"`           (drop last digit of the path)
    ///
    /// Returns nil when the node has no parent (root nodes like `"F02_Q"` or `"F02Q"`).
    func tileNodeParentPrefix(_ nodeId: String) -> String? {
        // Underscore format: separator is the last underscore.
        if let lastUnder = nodeId.lastIndex(of: "_") {
            let prefix = String(nodeId[..<lastUnder])
            return prefix.isEmpty ? nil : prefix
        }
        // Compact format: F{floor}Q{digits} — the path begins after the first 'Q'.
        if let qIdx = nodeId.firstIndex(of: "Q") {
            let pathStart = nodeId.index(after: qIdx)
            let path = String(nodeId[pathStart...])
            guard !path.isEmpty, path.allSatisfy(\.isNumber) else { return nil }
            // "F02Q" + path.dropLast() — root when path is one digit ("F02Q1" → "F02Q")
            let parentPath = String(path.dropLast())
            return String(nodeId[...qIdx]) + parentPath
        }
        return nil
    }

    /// Builds tileHierarchyIndex from all registered TileComponent entities.
    /// Groups tiles by their quadtreeNodeId parent prefix and unions their AABBs.
    /// Called once after loadTiledScene completes tile stub registration.
    func buildTileHierarchyIndex() {
        var index: [String: (min: simd_float3, max: simd_float3)] = [:]
        let tileComponentId = getComponentId(for: TileComponent.self)
        let entities = queryEntitiesWithComponentIds([tileComponentId], in: scene)
        for entityId in entities {
            guard let tc = scene.get(component: TileComponent.self, for: entityId),
                  let nodeId = tc.quadtreeNodeId, nodeId.count > 1,
                  let local = scene.get(component: LocalTransformComponent.self, for: entityId)
            else { continue }
            guard let prefix = tileNodeParentPrefix(nodeId) else { continue }
            let bbMin = local.boundingBox.min
            let bbMax = local.boundingBox.max
            if let existing = index[prefix] {
                index[prefix] = (simd_min(existing.min, bbMin), simd_max(existing.max, bbMax))
            } else {
                index[prefix] = (bbMin, bbMax)
            }
        }
        tileHierarchyIndex = index
    }

    func tileHasUsableFullGeometry(_ tileComp: TileComponent) -> Bool {
        guard tileComp.state == .parsed else { return false }
        return tileComp.visualState == .usable || tileComp.visualState == .complete
    }

    func tileHasLoadedLOD(_ tileComp: TileComponent) -> Bool {
        tileComp.lodLevels.contains { $0.state == .loaded }
    }

    func calculateDistance(entityId: EntityID, cameraPosition: simd_float3) -> Float {
        guard let transform = scene.get(component: WorldTransformComponent.self, for: entityId),
              let local = scene.get(component: LocalTransformComponent.self, for: entityId)
        else { return Float.infinity }

        // Transform the camera into entity-local space so that streamingRadius and
        // unloadRadius are scale-invariant. Without this, applying scaleTo(0.1) on a
        // parent compresses all child world-space positions by 10×, collapsing every
        // stub into streaming range simultaneously and exhausting the memory budget.
        // With this approach, streamingRadius is effectively in model-local units:
        //   scale 1.0  → same result as world-space comparison (backward compatible)
        //   scale 0.1  → camera must be within streamingRadius *local* units, which
        //               is streamingRadius×0.1 world-space metres — matching the
        //               proportionally smaller scene footprint.
        // If worldMatrix is degenerate (zero scale), inverse produces infinities and
        // simd_distance returns infinity, so the entity is safely skipped.
        let inv = transform.space.inverse
        let localCamera4 = inv * simd_float4(cameraPosition, 1.0)
        let localCamera = simd_float3(localCamera4.x, localCamera4.y, localCamera4.z)

        // Use closest point on AABB rather than bounding box center.
        // This ensures large flat meshes (exterior walls, floors) load as soon as
        // the camera reaches their *surface*, not their center. Without this, a wall
        // spanning 1600 units has its center hundreds of units away even when the
        // camera is right against it, so small interior objects closer to their own
        // centers would incorrectly load first.
        // When the camera is inside the AABB the closest point equals the camera
        // position, giving distance = 0, which correctly loads the enclosing mesh.
        let closestPoint = simd_clamp(localCamera, local.boundingBox.min, local.boundingBox.max)
        return simd_distance(localCamera, closestPoint)
    }

    /// Force load an entity's mesh immediately
    public func forceLoad(entityId: EntityID) async {
        guard let streaming = scene.get(component: StreamingComponent.self, for: entityId),
              streaming.state == .unloaded
        else { return }

        streaming.state = .loading

        let success = await loadMeshAsync(
            entityId: entityId,
            filename: streaming.assetFilename,
            withExtension: streaming.assetExtension,
            assetName: streaming.assetName
        )

        withWorldMutationGate {
            if success {
                streaming.state = .loaded
                streaming.lastVisibleFrame = currentFrame
                markLoadedStreamingEntity(entityId)
            } else {
                streaming.state = .unloaded
            }
        }
    }

    /// Force unload an entity's mesh immediately
    public func forceUnload(entityId: EntityID) {
        unloadMesh(entityId: entityId)
    }

    /// Register an entity that already has its mesh loaded (called by enableStreaming)
    public func registerLoadedEntity(_ entityId: EntityID) {
        markLoadedStreamingEntity(entityId)
    }

    /// Returns the current frame counter so callers can seed `lastVisibleFrame` on
    /// newly registered entities without holding the state lock themselves.
    public func currentFrameSnapshot() -> Int {
        withStateLock { currentFrame }
    }

    /// Remove an entity from streaming tracking sets.
    public func unregisterEntity(_ entityId: EntityID) {
        withWorldMutationGate {
            if let streaming = scene.get(component: StreamingComponent.self, for: entityId) {
                streaming.loadTask?.cancel()
                streaming.loadTask = nil
                if streaming.state == .loading || streaming.state == .unloading {
                    streaming.state = .unloaded
                }
            }
            releaseActiveLoad(entityId: entityId)
            unmarkLoadedStreamingEntity(entityId)
        }
    }

    /// Remove a tile stub entity from all tile-level tracking sets.
    /// Called by `removeTileComponent` when a tile entity is destroyed so that
    /// stale entity IDs do not linger in the streaming system's tracking state
    /// (loadedTileEntities, loadingTileEntities, activeTileLoads, meshEntityToTileEntity).
    public func unregisterTileEntity(_ entityId: EntityID) {
        withStateLock {
            _ = loadedTileEntities.remove(entityId)
            _ = loadingTileEntities.remove(entityId)
            _ = activeTileLoads.removeValue(forKey: entityId)
            _ = meshEntityToTileEntity.removeValue(forKey: entityId)
        }
    }

    /// Immediately unload every currently `.parsed` or `.parsing` tile, bypassing
    /// the normal 3-second grace period and the 2-per-tick unload cap.
    ///
    /// Call this when the user intentionally leaves the full-scale session
    /// (e.g. entering calibration mode in a spatial app).  Without an explicit
    /// unload the streaming system relies on the distance-based unload pass to
    /// reclaim full-load tile GPU memory; that pass runs at 2 tiles/tick with a
    /// 3-second grace period, meaning a 200-tile scene can take 10+ seconds to
    /// fully free.  During that window `MemoryBudgetManager.shouldEvictGeometry()`
    /// stays `true` — because full-load tile geometry is tracked there but is
    /// NOT in `loadedStreamingEntities` and therefore cannot be freed by
    /// `evictLRU` — which hard-breaks the tile load loop in the next session,
    /// causing the scene to appear frozen until the slow unload completes.
    ///
    /// **Why `.parsing` tiles are also cancelled:**
    /// A tile in `.parsing` state has a background Task running `setEntityMeshAsync`.
    /// If that Task completes *after* this call returns and `tc.state` is still
    /// `.parsing`, the Task's success path marks the tile `.parsed`, registers GPU
    /// memory in `MemoryBudgetManager`, and adds children to batching — silently
    /// recreating the exact memory-budget blockage this API is meant to prevent.
    /// Calling `unloadTile()` on a `.parsing` tile sets state to `.unloading` before
    /// cancelling the Task; the completion callback then finds `.unloading` instead
    /// of `.parsing`, takes the cleanup path, and never enters the success path.
    ///
    /// This API frees GPU memory immediately so the next full-scale session can
    /// start loading tiles with a clean memory budget.
    public func forceUnloadAllParsedTiles() {
        withWorldMutationGate {
            let tileFadeComponentId = getComponentId(for: TileRepresentationFadeComponent.self)
            let fadingEntities = queryEntitiesWithComponentIds([tileFadeComponentId], in: scene)
            for entityId in fadingEntities {
                scene.remove(component: TileRepresentationFadeComponent.self, from: entityId)
            }
            activeTileRepresentationFades.removeAll(keepingCapacity: true)
        }

        // Cancel in-flight (.parsing) tiles first so their Tasks cannot complete
        // through the success path after this call returns.
        let parsingSnapshot = loadingTileEntitiesSnapshot()
        for entityId in parsingSnapshot {
            unloadTile(entityId: entityId) // sets state to .unloading; Task cleanup deferred
        }
        // Unload already-.parsed tiles synchronously (destroys mesh children immediately).
        let parsedSnapshot = loadedTileEntitiesSnapshot()
        for entityId in parsedSnapshot {
            unloadTile(entityId: entityId)
        }
        // Also tear down any HLOD and per-tile LOD representations that are
        // still resident so they don't hold GPU memory across sessions.
        let hlodSnapshot = loadedHLODEntitiesSnapshot()
        for entityId in hlodSnapshot {
            unloadHLOD(entityId: entityId)
        }
        let lodSnapshot = loadedLODEntitiesSnapshot()
        for entityId in lodSnapshot {
            unloadAllLODLevels(entityId: entityId)
        }
    }

    /// Reset internal state (useful for tests and scene changes)
    public func reset() {
        withWorldMutationGate {
            let streamingComponentId = getComponentId(for: StreamingComponent.self)
            let entities = queryEntitiesWithComponentIds([streamingComponentId], in: scene)

            for entityId in entities {
                guard let streaming = scene.get(component: StreamingComponent.self, for: entityId) else {
                    continue
                }
                streaming.loadTask?.cancel()
                streaming.loadTask = nil
                if streaming.state == .loading || streaming.state == .unloading {
                    streaming.state = .unloaded
                }
            }

            // Cancel any in-flight tile parse tasks so completions that arrive
            // after a scene reload do not attempt to write into the new scene's ECS.
            let tileComponentId = getComponentId(for: TileComponent.self)
            let tileEntities = queryEntitiesWithComponentIds([tileComponentId], in: scene)
            for entityId in tileEntities {
                if let tc = scene.get(component: TileComponent.self, for: entityId) {
                    tc.loadTask?.cancel()
                    tc.loadTask = nil
                    if tc.state == .parsing { tc.state = .unloaded }
                    tc.pendingUnloadSince = 0
                    tc.parsedResidentSince = 0
                    // Cancel any in-flight HLOD load and reset state.
                    tc.hlodLoadTask?.cancel()
                    tc.hlodLoadTask = nil
                    tc.hlodEntityId = nil
                    tc.hlodState = .unloaded

                    // Cancel any in-flight per-tile LOD loads and reset state.
                    for i in tc.lodLevels.indices {
                        tc.lodLevels[i].loadTask?.cancel()
                        tc.lodLevels[i].loadTask = nil
                        tc.lodLevels[i].entityId = .invalid
                        tc.lodLevels[i].state = .unloaded
                    }
                }
            }
            let tileFadeComponentId = getComponentId(for: TileRepresentationFadeComponent.self)
            let fadingEntities = queryEntitiesWithComponentIds([tileFadeComponentId], in: scene)
            for entityId in fadingEntities {
                scene.remove(component: TileRepresentationFadeComponent.self, from: entityId)
            }
            activeTileRepresentationFades.removeAll(keepingCapacity: true)
            withStateLock {
                loadedHLODEntities.removeAll()
                loadedLODEntities.removeAll()
                lodLoadingCount = 0
                hlodLoadingCount = 0
            }

            SystemEventBus.shared.clearPendingEvents()
            withStateLock {
                activeLoads.removeAll()
                activeLoadStartTimes.removeAll()
                loadedStreamingEntities.removeAll()
                // Clear tile-level tracking sets so stale IDs from the previous scene
                // do not pollute the next scene's streaming passes.
                loadedTileEntities.removeAll()
                loadingTileEntities.removeAll()
                activeTileLoads.removeAll()
                meshEntityToTileEntity.removeAll()
            }
            timeSinceLastUpdate = 0
            currentFrame = 0
            lastLoadCandidateCount = 0
            lastTileLoadCandidateCount = 0
            lastPendingLoadBacklog = 0
            diagnostics = .init()
            cumulativeAsyncLoadMs = 0
            completedAsyncLoads = 0
            tileSwapWindow.removeAll()
            tileRepresentationGapLastLogTime.removeAll()
            lod0VisibilityProbes.removeAll()
            tileLOD0HandoffPending.removeAll()
            lastTileGapSummaryLogTime = 0
            lastCameraPosition = nil
            cameraVelocity = .zero
            firstRangeTimestamps.removeAll()
            interiorZone = nil
            tileHierarchyIndex.removeAll()
        }
        NativeTextureLoader.purgeSharedCache()
    }

    /// Get streaming statistics
    public func getStats() -> GeometryStreamingStats {
        let streamingComponentId = getComponentId(for: StreamingComponent.self)
        let entities = queryEntitiesWithComponentIds([streamingComponentId], in: scene)

        var loaded = 0
        var loading = 0
        var unloaded = 0

        for entityId in entities {
            guard let streaming = scene.get(component: StreamingComponent.self, for: entityId) else {
                continue
            }

            switch streaming.state {
            case .loaded: loaded += 1
            case .loading: loading += 1
            case .unloaded, .unloading: unloaded += 1
            }
        }

        // Fold in tile entity counts — tiles use TileComponent, not StreamingComponent.
        let tilesLoaded = loadedTileEntitiesSnapshot().count
        let tilesLoading = loadingTileEntitiesSnapshot().count
        let tileComponentId = getComponentId(for: TileComponent.self)
        let totalTiles = queryEntitiesWithComponentIds([tileComponentId], in: scene).count
        let tilesUnloaded = max(0, totalTiles - tilesLoaded - tilesLoading)

        return GeometryStreamingStats(
            totalStreamingEntities: entities.count + totalTiles,
            loadedCount: loaded + tilesLoaded,
            loadingCount: loading + tilesLoading,
            unloadedCount: unloaded + tilesUnloaded,
            activeLoads: activeLoadCountSnapshot() + activeTileLoadCount(),
            loadCandidates: lastLoadCandidateCount + lastTileLoadCandidateCount,
            pendingLoadBacklog: lastPendingLoadBacklog
        )
    }

    public func getDiagnosticsSnapshot() -> GeometryStreamingDiagnosticsSnapshot {
        withStateLock { diagnostics }
    }

    func tileFallbackSummary(_ tileComp: TileComponent) -> String {
        let lodSummary = tileComp.lodLevels.enumerated()
            .filter { _, level in level.state != .unloaded }
            .map { index, level in "lod\(index + 1)=\(level.state)" }
            .joined(separator: ",")
        let lodText = lodSummary.isEmpty ? "lod=none" : lodSummary
        return "hlod=\(tileComp.hlodState) \(lodText)"
    }

    func canReleaseLOD0Fallback(
        entityId _: EntityID,
        tileComp: TileComponent,
        renderEntityIds: Set<EntityID>
    ) -> Bool {
        guard tileHasUsableFullGeometry(tileComp) else { return false }
        guard !renderEntityIds.isEmpty else { return true }

        let visibleSet = Set(visibleEntityIds)
        return renderEntityIds.contains { visibleSet.contains($0) }
    }

    func fullTileHasVisibleCoverage(entityId: EntityID, tileComp: TileComponent) -> Bool {
        guard tileHasUsableFullGeometry(tileComp) else { return false }
        let renderIds = fullTileRenderDescendantIds(tileEntityId: entityId)
        return canReleaseLOD0Fallback(entityId: entityId, tileComp: tileComp, renderEntityIds: renderIds)
    }

    func canUnloadTileFallback(entityId: EntityID, tileComp: TileComponent, removingLODLevel levelIndex: Int? = nil, removingHLOD: Bool = false) -> Bool {
        let visibleSet = Set(visibleEntityIds)

        if removingHLOD {
            let removingIds = hlodRenderDescendantIds(tileComp)
            if !removingIds.contains(where: { visibleSet.contains($0) }) {
                return true
            }
        }

        if let levelIndex {
            let removingIds = lodRenderDescendantIds(tileComp, levelIndex: levelIndex)
            if !removingIds.contains(where: { visibleSet.contains($0) }) {
                return true
            }
        }

        if fullTileHasVisibleCoverage(entityId: entityId, tileComp: tileComp) {
            return true
        }

        if tileComp.hlodState == .loaded, !removingHLOD {
            let renderIds = hlodRenderDescendantIds(tileComp)
            if renderIds.contains(where: { visibleSet.contains($0) }) {
                return true
            }
        }

        for (index, level) in tileComp.lodLevels.enumerated()
            where level.state == .loaded && index != levelIndex
        {
            let renderIds = lodRenderDescendantIds(tileComp, levelIndex: index)
            if renderIds.contains(where: { visibleSet.contains($0) }) {
                return true
            }
        }

        return false
    }

    func releaseLOD0FallbackCoverage(entityId: EntityID) {
        var fadeStarted = false
        if let tileComp = scene.get(component: TileComponent.self, for: entityId) {
            fadeStarted = beginFadeFromTileFallbacksToFullTile(entityId: entityId, tileComp: tileComp)
        }

        clearLOD0FallbackBookkeeping(entityId: entityId)

        if !fadeStarted {
            unloadHLOD(entityId: entityId)
            unloadAllLODLevels(entityId: entityId)
        }
    }

    func clearLOD0FallbackBookkeeping(entityId: EntityID) {
        tileLOD0HandoffPending.remove(entityId)
        if !tileRepresentationDiagnosticsEnabled {
            lod0VisibilityProbes.removeValue(forKey: entityId)
        }
    }

    func recordLOD0Promotion(
        entityId: EntityID,
        tileId: String,
        renderEntityIds: Set<EntityID>,
        fallbackSummary: String
    ) {
        let visibleSet = Set(visibleEntityIds)
        let visibleSetCount = renderEntityIds.filter { visibleSet.contains($0) }.count
        let renderVisibleCount = renderEntityIds.filter {
            scene.get(component: RenderComponent.self, for: $0)?.isVisible == true
        }.count

        if !renderEntityIds.isEmpty, visibleSetCount == 0 {
            tileLOD0HandoffPending.insert(entityId)
        } else {
            tileLOD0HandoffPending.remove(entityId)
        }

        lod0VisibilityProbes[entityId] = TileLOD0VisibilityProbe(
            tileId: tileId,
            parsedFrame: currentFrame,
            renderEntityIds: renderEntityIds,
            fallbackSummaryAtParse: fallbackSummary
        )

        if tileRepresentationDiagnosticsEnabled {
            Logger.log(
                message: "[TileStreaming][LOD0] Tile '\(tileId)' promoted parsedFrame=\(currentFrame) render=\(renderEntityIds.count) renderVisible=\(renderVisibleCount) visibleSet=\(visibleSetCount) fallbackAtParse={\(fallbackSummary)}",
                category: LogCategory.tileStreaming.rawValue
            )
        }
    }

    private func auditTileRepresentationDiagnostics(
        nearbyEntities: [EntityID],
        cameraPosition: simd_float3,
        tileFrustum: Frustum?
    ) {
        auditRepresentationGaps(
            nearbyEntities: nearbyEntities,
            cameraPosition: cameraPosition,
            tileFrustum: tileFrustum
        )
        auditRepresentationOverlaps()
        auditLOD0VisibilityProbes(tileFrustum: tileFrustum)
    }

    private func auditRepresentationOverlaps() {
        let visibleSet = Set(visibleEntityIds)
        var summary = TileRepresentationOverlapAuditSummary()
        let fadingTiles = Set(activeTileRepresentationFades.map(\.tileEntityId))
        let waitingFadeTiles = Set(activeTileRepresentationFades.filter(\.waitsForIncomingVisibility).map(\.tileEntityId))
        let fullTileEntities = Set(loadedTileEntitiesSnapshot())
        let lodTileEntities = Set(loadedLODEntitiesSnapshot())
        let hlodTileEntities = Set(loadedHLODEntitiesSnapshot())
        let tileEntities = fullTileEntities
            .union(lodTileEntities)
            .union(hlodTileEntities)
            .union(fadingTiles)
            .union(waitingFadeTiles)

        for entityId in tileEntities {
            guard scene.exists(entityId),
                  let tileComp = scene.get(component: TileComponent.self, for: entityId)
            else { continue }

            let fullIds = fullTileEntities.contains(entityId)
                ? fullTileRenderDescendantIds(tileEntityId: entityId)
                : []
            let lodIds: Set<EntityID> = lodTileEntities.contains(entityId)
                ? tileComp.lodLevels.indices.reduce(into: Set<EntityID>()) { result, index in
                    guard tileComp.lodLevels[index].state == .loaded else { return }
                    result.formUnion(lodRenderDescendantIds(tileComp, levelIndex: index))
                }
                : []
            let hlodIds = hlodTileEntities.contains(entityId) && tileComp.hlodState == .loaded
                ? hlodRenderDescendantIds(tileComp)
                : []

            let hasFullResident = !fullIds.isEmpty && tileHasUsableFullGeometry(tileComp)
            let hasLODResident = !lodIds.isEmpty
            let hasHLODResident = !hlodIds.isEmpty
            let fullVisible = hasFullResident && fullIds.contains { visibleSet.contains($0) }
            let lodVisible = hasLODResident && lodIds.contains { visibleSet.contains($0) }
            let hlodVisible = hasHLODResident && hlodIds.contains { visibleSet.contains($0) }

            if hasFullResident { summary.residentFullTiles += 1 }
            if hasLODResident { summary.residentLODTiles += 1 }
            if hasHLODResident { summary.residentHLODTiles += 1 }
            if fullVisible { summary.visibleFullTiles += 1 }
            if lodVisible { summary.visibleLODTiles += 1 }
            if hlodVisible { summary.visibleHLODTiles += 1 }
            if fullVisible, lodVisible { summary.fullAndLODVisibleTiles += 1 }
            if fullVisible, hlodVisible { summary.fullAndHLODVisibleTiles += 1 }
            if lodVisible, hlodVisible { summary.lodAndHLODVisibleTiles += 1 }
            if hasFullResident, hasLODResident || hasHLODResident {
                summary.fullAndFallbackResidentTiles += 1
            }
            if fadingTiles.contains(entityId) { summary.activeFadeTiles += 1 }
            if waitingFadeTiles.contains(entityId) { summary.waitingFadeTiles += 1 }
        }

        withStateLock {
            diagnostics.residentFullTileRepresentations = summary.residentFullTiles
            diagnostics.residentLODRepresentations = summary.residentLODTiles
            diagnostics.residentHLODRepresentations = summary.residentHLODTiles
            diagnostics.visibleFullTileRepresentations = summary.visibleFullTiles
            diagnostics.visibleLODRepresentations = summary.visibleLODTiles
            diagnostics.visibleHLODRepresentations = summary.visibleHLODTiles
            diagnostics.fullAndLODVisibleOverlapTiles = summary.fullAndLODVisibleTiles
            diagnostics.fullAndHLODVisibleOverlapTiles = summary.fullAndHLODVisibleTiles
            diagnostics.lodAndHLODVisibleOverlapTiles = summary.lodAndHLODVisibleTiles
            diagnostics.fullAndFallbackResidentOverlapTiles = summary.fullAndFallbackResidentTiles
            diagnostics.activeTileRepresentationFades = summary.activeFadeTiles
            diagnostics.waitingTileRepresentationFades = summary.waitingFadeTiles
        }
    }

    private func auditLOD0FallbackHandoffs(tileFrustum _: Frustum?) {
        guard !tileLOD0HandoffPending.isEmpty else { return }

        let visibleSet = Set(visibleEntityIds)
        var releases: [EntityID] = []

        for entityId in tileLOD0HandoffPending {
            guard scene.exists(entityId),
                  let tileComp = scene.get(component: TileComponent.self, for: entityId),
                  tileComp.state == .parsed,
                  let probe = lod0VisibilityProbes[entityId]
            else {
                releases.append(entityId)
                continue
            }

            let visibleSetCount = probe.renderEntityIds.filter { visibleSet.contains($0) }.count
            if visibleSetCount > 0 {
                releases.append(entityId)
                continue
            }

            // Do not release fallback coverage on a timeout or frustum miss. The
            // RenderComponent can already be marked visible while the published
            // visibleEntityIds set is still lagging; releasing here creates an
            // uncovered LOD0 handoff window. Out-of-range cleanup will tear down
            // stale representations when the tile genuinely leaves streaming range.
        }

        for entityId in releases {
            releaseLOD0FallbackCoverage(entityId: entityId)
        }
    }

    private func auditRepresentationGaps(
        nearbyEntities: [EntityID],
        cameraPosition: simd_float3,
        tileFrustum: Frustum?
    ) {
        let now = CFAbsoluteTimeGetCurrent()
        var summary = TileRepresentationGapAuditSummary()

        for entityId in nearbyEntities {
            guard scene.exists(entityId),
                  let tileComp = scene.get(component: TileComponent.self, for: entityId)
            else { continue }

            let distance = calculateDistance(entityId: entityId, cameraPosition: cameraPosition)
            guard distance <= tileComp.streamingRadius + 1.0,
                  tilePassesStreamingFrustum(entityId: entityId, frustum: tileFrustum)
            else { continue }

            let hasFull = tileHasUsableFullGeometry(tileComp)
            let loadedLODCount = tileComp.lodLevels.filter { $0.state == .loaded }.count
            let loadingLODCount = tileComp.lodLevels.filter { $0.state == .loading }.count
            let hasLoadedHLOD = tileComp.hlodState == .loaded
            let hasVisibleFallback = loadedLODCount > 0 || hasLoadedHLOD

            guard !hasFull, !hasVisibleFallback else {
                tileRepresentationGapLastLogTime.removeValue(forKey: entityId)
                continue
            }

            switch tileComp.state {
            case .unloaded:
                summary.unloadedNoRepresentation += 1
                continue
            case .parsing:
                summary.parsingNoRepresentation += 1
                guard tileComp.parseStartTime > 0,
                      now - tileComp.parseStartTime >= tileRepresentationGapDwellSeconds
                else { continue }
            case .failed:
                summary.failedNoRepresentation += 1
            case .parsed:
                summary.parsedNoRepresentation += 1
            case .unloading:
                continue
            }

            let lastLog = tileRepresentationGapLastLogTime[entityId] ?? 0
            guard now - lastLog >= 2.0 else { continue }
            tileRepresentationGapLastLogTime[entityId] = now

            withStateLock {
                diagnostics.tileRepresentationGapWarnings += 1
            }

            Logger.logWarning(
                message: "[TileStreaming][Gap] Tile '\(tileComp.tileId)' has no visible representation in display range. dist=\(String(format: "%.1f", distance))m state=\(tileComp.state) visual=\(tileComp.visualState) fullUsable=\(hasFull) hlod=\(tileComp.hlodState) loadedLOD=\(loadedLODCount) loadingLOD=\(loadingLODCount) activeFullLoads=\(activeTileLoadCount())",
                category: LogCategory.tileStreaming.rawValue
            )
        }

        if summary.unloadedNoRepresentation > 0,
           now - lastTileGapSummaryLogTime >= 2.0
        {
            lastTileGapSummaryLogTime = now
            Logger.log(
                message: "[TileStreaming][GapSummary] unloadedNoRep=\(summary.unloadedNoRepresentation) parsingNoRep=\(summary.parsingNoRepresentation) failedNoRep=\(summary.failedNoRepresentation) parsedNoRep=\(summary.parsedNoRepresentation) activeFullLoads=\(activeTileLoadCount()) maxFullLoads=\(maxConcurrentTileLoads) activeLODLoads=\(activeLODLoadCount()) maxLODLoads=\(maxConcurrentLODLoads) activeHLODLoads=\(activeHLODLoadCount()) maxHLODLoads=\(maxConcurrentHLODLoads)",
                category: LogCategory.tileStreaming.rawValue
            )
        }
    }

    private func auditLOD0VisibilityProbes(tileFrustum: Frustum?) {
        guard !lod0VisibilityProbes.isEmpty else { return }

        let visibleSet = Set(visibleEntityIds)
        var removals: [EntityID] = []

        for (entityId, var probe) in lod0VisibilityProbes {
            guard scene.exists(entityId),
                  let tileComp = scene.get(component: TileComponent.self, for: entityId),
                  tileComp.state == .parsed
            else {
                removals.append(entityId)
                continue
            }

            let visibleSetCount = probe.renderEntityIds.filter { visibleSet.contains($0) }.count
            let renderVisibleCount = probe.renderEntityIds.filter {
                scene.get(component: RenderComponent.self, for: $0)?.isVisible == true
            }.count
            let ageFrames = currentFrame - probe.parsedFrame

            if visibleSetCount > 0 {
                Logger.log(
                    message: "[TileStreaming][LOD0] Tile '\(probe.tileId)' first visible after \(ageFrames) frame(s). visibleSet=\(visibleSetCount)/\(probe.renderEntityIds.count) renderVisible=\(renderVisibleCount) fallbackAtParse={\(probe.fallbackSummaryAtParse)}",
                    category: LogCategory.tileStreaming.rawValue
                )
                releaseLOD0FallbackCoverage(entityId: entityId)
                removals.append(entityId)
                continue
            }

            if ageFrames >= lod0VisibilityWarningFrameDelay,
               !probe.warnedMissingVisibleSet,
               tilePassesStreamingFrustum(entityId: entityId, frustum: tileFrustum)
            {
                probe.warnedMissingVisibleSet = true
                lod0VisibilityProbes[entityId] = probe
                withStateLock {
                    diagnostics.lod0VisibilityWarnings += 1
                    if tileComp.hlodState == .loaded || tileComp.lodLevels.contains(where: { $0.state == .loaded }) {
                        diagnostics.lod0VisibilityWarningsWithFallback += 1
                    } else {
                        diagnostics.lod0VisibilityWarningsNoFallback += 1
                    }
                }
                Logger.logWarning(
                    message: "[TileStreaming][LOD0] Tile '\(probe.tileId)' parsed but LOD0 render entities have not entered the visible set after \(ageFrames) frame(s). render=\(probe.renderEntityIds.count) renderVisible=\(renderVisibleCount) visual=\(tileComp.visualState) fallbackNow={\(tileFallbackSummary(tileComp))} fallbackAtParse={\(probe.fallbackSummaryAtParse)}",
                    category: LogCategory.tileStreaming.rawValue
                )
            }

            // Keep the probe alive until LOD0 enters visibleEntityIds. A high age is
            // diagnostic signal, not proof that the fallback can be dropped safely.
        }

        for entityId in removals {
            lod0VisibilityProbes.removeValue(forKey: entityId)
        }
    }
}

public struct GeometryStreamingDiagnosticsSnapshot: Sendable {
    public var updateFrame: Int = 0
    public var updateTriggered: Bool = false
    public var updateWorkMs: Double = 0.0
    public var nearbyEntitiesQueried: Int = 0
    public var unloadCandidates: Int = 0
    public var processedUnloads: Int = 0
    public var loadCandidates: Int = 0
    public var startedLoads: Int = 0
    public var availableLoadSlots: Int = 0
    public var activeLoadsAtUpdateStart: Int = 0
    public var activeLoadsAtUpdateEnd: Int = 0
    public var evictionTriggered: Bool = false
    public var evictionsPerformed: Int = 0
    public var lastAsyncLoadMs: Double = 0.0
    public var averageAsyncLoadMs: Double = 0.0
    public var lastApplyLoadedMeshMs: Double = 0.0
    public var lastAsyncReloadLODMs: Double = 0.0
    public var lastUnloadMeshMs: Double = 0.0
    public var lastFailedAsyncLoadMs: Double = 0.0
    public var tileSwapWarnings: Int = 0
    public var tilesSkippedByHierarchyGate: Int = 0
    public var tileRepresentationGapWarnings: Int = 0
    public var lod0VisibilityWarnings: Int = 0
    public var lod0VisibilityWarningsWithFallback: Int = 0
    public var lod0VisibilityWarningsNoFallback: Int = 0
    public var residentFullTileRepresentations: Int = 0
    public var residentLODRepresentations: Int = 0
    public var residentHLODRepresentations: Int = 0
    public var visibleFullTileRepresentations: Int = 0
    public var visibleLODRepresentations: Int = 0
    public var visibleHLODRepresentations: Int = 0
    public var fullAndLODVisibleOverlapTiles: Int = 0
    public var fullAndHLODVisibleOverlapTiles: Int = 0
    public var lodAndHLODVisibleOverlapTiles: Int = 0
    public var fullAndFallbackResidentOverlapTiles: Int = 0
    public var activeTileRepresentationFades: Int = 0
    public var waitingTileRepresentationFades: Int = 0

    public init() {}
}

extension GeometryStreamingSystem {
    func recordTileRepresentationSwap(entityId: EntityID, tileId: String, representation: String) {
        guard let swapEvent = tileRepresentationSwapEvent(representation) else { return }

        let now = CFAbsoluteTimeGetCurrent()
        let warningThreshold = 4
        let windowSeconds = 5.0

        let existing = tileSwapWindow[entityId]
        var window: TileRepresentationSwapWindow
        if let existing, now - existing.windowStart <= windowSeconds {
            window = existing
        } else {
            window = TileRepresentationSwapWindow(
                windowStart: now,
                lastStatesByTarget: [:],
                toggleCountsByTarget: [:]
            )
        }

        let previousState = window.lastStatesByTarget[swapEvent.target]
        if let previousState, previousState != swapEvent.state {
            window.toggleCountsByTarget[swapEvent.target, default: 0] += 1
        }
        window.lastStatesByTarget[swapEvent.target] = swapEvent.state

        let toggles = window.toggleCountsByTarget[swapEvent.target] ?? 0
        tileSwapWindow[entityId] = window

        if toggles == warningThreshold {
            Logger.logWarning(
                message: "[TileStreaming] Swap thrash detected for tile '\(tileId)' — \(toggles) \(swapEvent.target) load-state toggles in \(Int(windowSeconds))s (latest=\(representation)).",
                category: LogCategory.tileStreaming.rawValue
            )
            withStateLock {
                diagnostics.tileSwapWarnings += 1
            }
        }
    }

    private func tileRepresentationSwapEvent(_ representation: String) -> (target: String, state: String)? {
        let parts = representation.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }

        let state = parts[1]
        guard state == "loaded" || state == "unloaded" else { return nil }

        let target = parts[0]
        guard target == "hlod" || target.hasPrefix("lod") else { return nil }

        return (target, state)
    }
}

/// Statistics for geometry streaming
public struct GeometryStreamingStats: CustomStringConvertible {
    public var totalStreamingEntities: Int
    public var loadedCount: Int
    public var loadingCount: Int
    public var unloadedCount: Int
    public var activeLoads: Int
    public var loadCandidates: Int
    public var pendingLoadBacklog: Int

    public var description: String {
        "Streaming: \(loadedCount) loaded, \(loadingCount) loading, \(unloadedCount) unloaded (\(activeLoads) active, \(loadCandidates) candidates, \(pendingLoadBacklog) backlog)"
    }
}

// MARK: - Debug Helpers

public extension GeometryStreamingSystem {
    /// Print streaming and cache stats to console (for debugging)
    func printStats() {
        let streamingStats = getStats()
        let cacheStats = MeshResourceManager.shared.getStats()
        let memoryStats = MemoryBudgetManager.shared.getStats()

        Logger.log(message: """
        ┌─ Streaming Stats ─────────────────────────────
        │ Entities: \(streamingStats.loadedCount) loaded, \(streamingStats.loadingCount) loading, \(streamingStats.unloadedCount) unloaded
        │ Active loads: \(streamingStats.activeLoads)/\(maxConcurrentLoads)
        ├─ Cache Stats ────────────────────────────────────
        │ Cached files: \(cacheStats.cachedMeshCount)
        │ Total refs: \(cacheStats.totalReferences)
        │ Evictable: \(cacheStats.evictableCount)
        │ Memory: \(cacheStats.totalMemoryBytes / 1024) KB
        ├─ Memory Budget ──────────────────────────────────
        │ Used: \(memoryStats.meshMemoryUsed / 1024 / 1024) MB / \(memoryStats.budgetLimit / 1024 / 1024) MB (\(Int(memoryStats.utilizationPercent * 100))%)
        │ Tracked entities: \(memoryStats.trackedEntityCount)
        └──────────────────────────────────────────────────
        """)
    }
}

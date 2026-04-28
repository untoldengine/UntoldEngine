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

    /// When true, load candidates within the same priority tier are sorted by
    /// screen-space importance (bounding radius / distance) instead of raw distance.
    /// Objects that subtend a larger solid angle in the camera view are loaded first,
    /// so a large building at 50 m beats a small prop at 45 m.
    /// Default: true.  Set to false to revert to pure distance ordering.
    public var enableImportanceSort: Bool = true

    // MARK: - OS Memory Pressure

    /// Set by the MemoryBudgetManager pressure callback (background queue).
    /// Checked and cleared at the start of each update() tick (main thread) so that
    /// all eviction work stays on the same thread as the rest of the streaming system.
    var pendingPressureRelief: Bool = false
    var pressureIsAggressive: Bool = false

    let stateLock = NSLock()
    var timeSinceLastUpdate: Float = 0
    var timeSinceCameraDiagLog: Float = 0
    var activeLoads: Set<EntityID> = []
    var activeLoadStartTimes: [EntityID: Double] = [:]
    /// Subset of activeLoads that belong to the near band. Tracked separately so the
    /// near-band concurrency limit can be enforced independently of the global limit.
    var activeNearBandLoads: Set<EntityID> = []
    var loadedStreamingEntities: Set<EntityID> = [] // Track loaded entities for efficient unload checks
    var currentFrame: Int = 0
    var lastLoadCandidateCount: Int = 0
    var lastPendingLoadBacklog: Int = 0
    var diagnostics: GeometryStreamingDiagnosticsSnapshot = .init()
    var cumulativeAsyncLoadMs: Double = 0.0
    var completedAsyncLoads: Int = 0
    var tileSwapWindow: [EntityID: (windowStart: Double, swaps: Int)] = [:]

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

        // Periodic camera position log — confirms the XR headset position is flowing through
        // to the streaming system. Fires every 5 s so it is readable in a test session without
        // being noisy in steady-state. Check these values are changing when physically walking
        // on Vision Pro; a frozen value indicates the ARKit→ECS sync is broken.
        timeSinceCameraDiagLog += deltaTime
        if timeSinceCameraDiagLog >= 5.0 {
            timeSinceCameraDiagLog = 0
            Logger.log(message: "[GeometryStreaming] camera pos: (\(String(format: "%.2f", effectiveCameraPosition.x)), \(String(format: "%.2f", effectiveCameraPosition.y)), \(String(format: "%.2f", effectiveCameraPosition.z))) loaded=\(loadedStreamingEntities.count)", category: LogCategory.xrCamera.rawValue)
        }

        let nearbyEntities = OctreeSystem.shared.queryNear(point: effectiveCameraPosition, radius: maxQueryRadius)

        // Build a padded frustum once per tick for the load-gate test.
        // nil when no camera is available; the gate is simply skipped that tick.
        let streamingFrustum: Frustum? = enableFrustumGate ? buildStreamingFrustum() : nil
        // Tile candidates use a wider pad (tileFrustumGatePadding) because tiles are
        // coarser than mesh stubs — a single tile pop-in is far more noticeable.
        let tileStreamingFrustum: Frustum? = enableFrustumGate ? buildStreamingFrustum(sidePad: tileFrustumGatePadding) : nil

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
                message: "[TileStreaming] Tile '\(tc.tileId)' parse timed out after \(Int(tileParseTimeoutSeconds))s while state=\(String(describing: tc.state)) — forcing teardown."
            )
            tc.loadTask?.cancel()
            tc.loadTask = nil
            tc.parseStartTime = 0

            // Force-release the AssetLoadingGate for the hung inner Task.
            // setEntityMeshAsync opens the gate via AssetLoadingState.shared.startLoading(entityId:)
            // using capturedMeshEntityId.  Since loadTextures() ignores Swift cooperative
            // cancellation, the gate never closes on its own — isLoadingAny stays permanently
            // true and the render loop freezes.  Calling finishLoading here closes the gate
            // so the render loop resumes on the next frame.
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
        var tileLoadCandidates: [(EntityID, Float, Int, Float)] = [] // (entity, effectiveDist, priority, importance)
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
                if let f = tileStreamingFrustum,
                   let local = scene.get(component: LocalTransformComponent.self, for: entityId)
                {
                    let center = (local.boundingBox.min + local.boundingBox.max) * 0.5
                    let halfExtent = (local.boundingBox.max - local.boundingBox.min) * 0.5
                    if !isAABBInFrustum(center: center, halfExtent: halfExtent, frustum: f) {
                        continue
                    }
                }
                tileLoadCandidates.append((entityId, effectiveDist, tileComp.priority, importanceScore(entityId: entityId, distance: effectiveDist)))
            }
        }
        if !tileLoadCandidates.isEmpty {
            // Geometry budget gate: if geometry memory is already under pressure, run
            // eviction before dispatching any new tile parses.  A tile load can consume
            // tens of MB in one shot, so we check here rather than relying solely on the
            // per-mesh admission gate inside setEntityMeshAsync.
            if MemoryBudgetManager.shared.shouldEvictGeometry() {
                TextureStreamingSystem.shared.shedTextureMemory(
                    cameraPosition: effectiveCameraPosition, maxEntities: 4
                )
                _ = evictLRU(cameraPosition: effectiveCameraPosition, maxEvictions: 8)
            }

            tileLoadCandidates.sort { lhs, rhs in
                if lhs.2 != rhs.2 { return lhs.2 > rhs.2 } // priority descending
                if enableImportanceSort { return lhs.3 > rhs.3 } // larger screen footprint first
                return lhs.1 < rhs.1 // fallback: closer first
            }
            for (entityId, _, _, _) in tileLoadCandidates {
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

        // ── HLOD streaming pass ────────────────────────────────────────────────
        // For tiles that have an HLOD mesh configured: load the coarse mesh when the
        // camera is beyond hlodSwitchDistance and the tile is not yet loading/loaded.
        // Unload the HLOD when the full tile becomes .parsed (smooth hand-off).
        // During .parsing the HLOD stays visible so there is no blank frame while the
        // full geometry is uploading.
        for entityId in nearbyEntities {
            guard scene.exists(entityId) else { continue }
            guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
                  tileComp.hlodURL != nil,
                  tileComp.hlodSwitchDistance > 0 else { continue }

            let dist = calculateDistance(entityId: entityId, cameraPosition: effectiveCameraPosition)
            let canTransitionHLOD = tileComp.lastHLODTransitionTime == 0 ||
                timeoutNow - tileComp.lastHLODTransitionTime >= secondaryRepresentationMinDwellSeconds

            switch tileComp.state {
            case .unloaded, .failed:
                if dist > tileComp.hlodSwitchDistance {
                    if tileComp.hlodState == .unloaded {
                        guard activeHLODLoadCount() < maxConcurrentHLODLoads else { continue }
                        loadHLOD(entityId: entityId)
                    }
                } else if dist < tileComp.hlodSwitchDistance * hlodHysteresisFactor {
                    // Camera has moved meaningfully inside the switch distance —
                    // HLOD is no longer needed.  The hysteresis band
                    // [switchDistance * factor, switchDistance) keeps the HLOD
                    // resident while the camera lingers at the boundary.
                    if canTransitionHLOD, tileComp.hlodState != .unloaded { unloadHLOD(entityId: entityId) }
                }
            // else: inside hysteresis band — keep current HLOD state.
            case .parsed:
                // Full geometry is resident — HLOD hand-off complete.
                // No dwell here: unload promptly so HLOD and full tile are not
                // both resident simultaneously consuming GPU memory.
                if tileComp.hlodState != .unloaded { unloadHLOD(entityId: entityId) }
            case .parsing, .unloading:
                // Keep HLOD visible during full-tile load for a seamless transition.
                break
            }
        }

        // ── Per-tile LOD streaming pass ────────────────────────────────────────
        // For tiles that have LOD levels: show the appropriate coarser mesh when
        // the tile is unloaded and the camera is between the LOD switch distances.
        // Levels are sorted ascending by switchDistance (finest first), so the
        // active index is the last one whose switchDistance ≤ current distance.
        // Only one level is active at a time; all others are unloaded.
        for entityId in nearbyEntities {
            guard scene.exists(entityId) else { continue }
            guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
                  !tileComp.lodLevels.isEmpty else { continue }

            let dist = calculateDistance(entityId: entityId, cameraPosition: effectiveCameraPosition)

            // LOD levels are only active while HLOD is not resident.
            // If HLOD is loaded or loading (including the hysteresis band where dist is
            // slightly below hlodSwitchDistance), keep LOD levels clear to avoid showing
            // both representations simultaneously.  Only when HLOD is unloaded (or
            // unloading) do we let the LOD pass activate.
            if tileComp.hlodSwitchDistance > 0 {
                let hlodResident = tileComp.hlodState == .loaded || tileComp.hlodState == .loading
                let beyondHLOD = dist >= tileComp.hlodSwitchDistance
                if beyondHLOD || hlodResident {
                    unloadAllLODLevels(entityId: entityId)
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

            switch tileComp.state {
            case .unloaded, .failed:
                if let target = targetIndex {
                    for i in tileComp.lodLevels.indices {
                        if i == target {
                            if tileComp.lodLevels[i].state == .unloaded, currentlyActiveIndex == nil || canTransitionLOD {
                                // Hard cap: never exceed maxConcurrentLODLoads.
                                // Without this, every tile in LOD range is dispatched
                                // simultaneously on initial load, triggering an OOM kill.
                                guard activeLODLoadCount() < maxConcurrentLODLoads else { break }
                                loadLODLevel(entityId: entityId, levelIndex: i)
                            }
                        } else {
                            if canTransitionLOD, tileComp.lodLevels[i].state != .unloaded {
                                unloadLODLevel(entityId: entityId, levelIndex: i)
                            }
                        }
                    }
                } else if canTransitionLOD {
                    // Camera is inside the finest LOD's switch distance — full tile
                    // will load via the tile load pass; drop any active LOD level.
                    unloadAllLODLevels(entityId: entityId)
                }
            case .parsed:
                // Full geometry resident — all LOD levels can be dropped.
                // No dwell: unload immediately so LOD proxies don't stay resident
                // alongside the full tile geometry.
                unloadAllLODLevels(entityId: entityId)
            case .parsing, .unloading:
                // Keep active LOD visible during the full-tile load for continuity.
                break
            }
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
                } else if now - tileComp.pendingUnloadSince >= Double(unloadGracePeriod) {
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
                } else if now - tileComp.pendingUnloadSince >= Double(unloadGracePeriod) {
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

                // Release CPU-heap (MDLAsset + CPUMeshEntry buffers) for all warm OOC roots.
                // evictLRU only frees GPU Metal buffers tracked by MemoryBudgetManager; the OS
                // measures total process memory, which includes the CPU mesh heap that
                // ProgressiveAssetLoader keeps alive. Releasing it here can free several hundred
                // MB on a heavy geometry scene. The rehydration context (URL + policy) survives,
                // so re-approach triggers a transparent cold re-stream from disk.
                let warmRoots = ProgressiveAssetLoader.shared.allWarmRootEntityIds()
                for rootId in warmRoots {
                    ProgressiveAssetLoader.shared.releaseWarmAsset(rootEntityId: rootId)
                }
                if !warmRoots.isEmpty {
                    print("[GeometryStreaming] Critical pressure: released CPU heap for \(warmRoots.count) OOC root(s)")
                }
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
                if let rootId = scene.get(component: DerivedAssetNodeComponent.self, for: entityId)?.assetRootEntityId {
                    // Skip entities whose CPU data isn't registered yet (pre-streaming slot jam).
                    if !ProgressiveAssetLoader.shared.isColdRoot(rootId),
                       ProgressiveAssetLoader.shared.retrieveCPUMesh(for: entityId) == nil,
                       !ProgressiveAssetLoader.shared.hasCPULODData(for: entityId)
                    {
                        continue
                    }
                    // Defer dispatch until background prewarm releases the per-asset texture lock.
                    // Dispatching while prewarm holds the lock blocks the first batch for the full
                    // remaining prewarm duration (~1-2 s). Wait until lockWait ≈ 0.
                    if ProgressiveAssetLoader.shared.isPrewarmActive(for: rootId) {
                        continue
                    }
                }
                // Per-candidate geometry budget check: evict if this mesh won't fit.
                if let cpuEntry = ProgressiveAssetLoader.shared.retrieveCPUMesh(for: entityId),
                   !MemoryBudgetManager.shared.canAcceptMesh(sizeBytes: cpuEntry.estimatedGPUBytes)
                {
                    evictedByLRU += evictLRU(cameraPosition: effectiveCameraPosition)
                    evictionTriggered = true
                    guard MemoryBudgetManager.shared.canAcceptMesh(sizeBytes: cpuEntry.estimatedGPUBytes) else { continue }
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
                // Same guard: skip OOC child entities whose CPU data isn't ready yet.
                if let rootId = scene.get(component: DerivedAssetNodeComponent.self, for: entityId)?.assetRootEntityId {
                    if !ProgressiveAssetLoader.shared.isColdRoot(rootId),
                       ProgressiveAssetLoader.shared.retrieveCPUMesh(for: entityId) == nil,
                       !ProgressiveAssetLoader.shared.hasCPULODData(for: entityId)
                    {
                        continue
                    }
                    // Defer until background prewarm releases the texture lock.
                    if ProgressiveAssetLoader.shared.isPrewarmActive(for: rootId) {
                        continue
                    }
                }
                // Per-candidate geometry budget check for out-of-core rest-band entities.
                if let cpuEntry = ProgressiveAssetLoader.shared.retrieveCPUMesh(for: entityId),
                   !MemoryBudgetManager.shared.canAcceptMesh(sizeBytes: cpuEntry.estimatedGPUBytes)
                {
                    evictedByLRU += evictLRU(cameraPosition: effectiveCameraPosition)
                    evictionTriggered = true
                    guard MemoryBudgetManager.shared.canAcceptMesh(sizeBytes: cpuEntry.estimatedGPUBytes) else { continue }
                }
                loadMesh(entityId: entityId, isNearBand: false)
                startedLoads += 1
                restDispatched += 1
            }
        }

        let updateWorkMs = (CFAbsoluteTimeGetCurrent() - updateStart) * 1000.0
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
            lastPendingLoadBacklog = 0
            diagnostics = .init()
            cumulativeAsyncLoadMs = 0
            completedAsyncLoads = 0
            tileSwapWindow.removeAll()
            lastCameraPosition = nil
            cameraVelocity = .zero
            firstRangeTimestamps.removeAll()
            interiorZone = nil
        }
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

        return GeometryStreamingStats(
            totalStreamingEntities: entities.count,
            loadedCount: loaded,
            loadingCount: loading,
            unloadedCount: unloaded,
            activeLoads: activeLoadCountSnapshot(),
            loadCandidates: lastLoadCandidateCount,
            pendingLoadBacklog: lastPendingLoadBacklog
        )
    }

    public func getDiagnosticsSnapshot() -> GeometryStreamingDiagnosticsSnapshot {
        withStateLock { diagnostics }
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

    public init() {}
}

extension GeometryStreamingSystem {
    func recordTileRepresentationSwap(entityId: EntityID, tileId: String, representation: String) {
        let now = CFAbsoluteTimeGetCurrent()
        let warningThreshold = 6
        let windowSeconds = 5.0

        let updated: (windowStart: Double, swaps: Int) = {
            guard let existing = tileSwapWindow[entityId] else {
                return (now, 1)
            }
            if now - existing.windowStart > windowSeconds {
                return (now, 1)
            }
            return (existing.windowStart, existing.swaps + 1)
        }()

        tileSwapWindow[entityId] = updated
        if updated.swaps == warningThreshold {
            Logger.logWarning(
                message: "[TileStreaming] Swap thrash detected for tile '\(tileId)' — \(updated.swaps) representation changes in \(Int(windowSeconds))s (latest=\(representation))."
            )
            withStateLock {
                diagnostics.tileSwapWarnings += 1
            }
        }
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

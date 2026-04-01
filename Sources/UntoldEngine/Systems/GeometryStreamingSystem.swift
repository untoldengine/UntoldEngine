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

    /// Tile entities currently being parsed, mapped to their declared file size in bytes.
    /// Used to track the total parse memory in flight for the budget gate.
    private var activeTileLoads: [EntityID: Int] = [:]

    /// Tile entities currently in the .parsed state.
    /// Mirrors loadedStreamingEntities but for tile-level entities.
    /// Enables out-of-range checks for tiles that fall outside the octree query radius.
    private var loadedTileEntities: Set<EntityID> = []

    /// Tile entities currently in the .parsing state.
    /// Enables cancellation of in-progress tile parses when the camera moves away
    /// before the load completes (e.g. fast movement or teleport).
    private var loadingTileEntities: Set<EntityID> = []

    /// Maps capturedMeshEntityId → tile stub EntityID so OCC upload completions
    /// can quickly update the parent tile's visual readiness counters (O(1) lookup).
    private var meshEntityToTileEntity: [EntityID: EntityID] = [:]

    /// Tile stub entities that currently have an HLOD mesh loaded.
    /// Used to find and unload HLOD meshes for tiles that drift outside the query radius.
    private var loadedHLODEntities: Set<EntityID> = []

    /// Tile stub entities that currently have at least one per-tile LOD level loaded.
    /// Used to reach tiles that drift outside the octree query radius for cleanup.
    private var loadedLODEntities: Set<EntityID> = []

    /// Number of per-tile LOD level loads currently in flight (.loading state).
    /// Protected by stateLock.  Mirrors the role of loadingTileEntities.count for
    /// full tiles — caps concurrent ModelIO parses so we don't OOM on mass dispatch.
    private var lodLoadingCount: Int = 0

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

    private var lastCameraPosition: simd_float3? = nil
    private var cameraVelocity: simd_float3 = .zero

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

    // MARK: - OS Memory Pressure

    /// Set by the MemoryBudgetManager pressure callback (background queue).
    /// Checked and cleared at the start of each update() tick (main thread) so that
    /// all eviction work stays on the same thread as the rest of the streaming system.
    private var pendingPressureRelief: Bool = false
    private var pressureIsAggressive: Bool = false

    private let stateLock = NSLock()
    private var timeSinceLastUpdate: Float = 0
    private var timeSinceCameraDiagLog: Float = 0
    private var activeLoads: Set<EntityID> = []
    /// Subset of activeLoads that belong to the near band. Tracked separately so the
    /// near-band concurrency limit can be enforced independently of the global limit.
    private var activeNearBandLoads: Set<EntityID> = []
    private var loadedStreamingEntities: Set<EntityID> = [] // Track loaded entities for efficient unload checks
    private var currentFrame: Int = 0
    private var lastLoadCandidateCount: Int = 0
    private var lastPendingLoadBacklog: Int = 0
    private var diagnostics: GeometryStreamingDiagnosticsSnapshot = .init()
    private var cumulativeAsyncLoadMs: Double = 0.0
    private var completedAsyncLoads: Int = 0

    /// First-detection timestamps (CFAbsoluteTime) keyed by entity ID.
    /// Records when each entity first appeared as a load candidate so we can measure
    /// scheduler latency: time from entering range to actual dispatch.
    /// Accessed only from update() and its synchronous callees — no lock needed.
    private var firstRangeTimestamps: [EntityID: Double] = [:]

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
    private func withStateLock<T>(_ body: () throws -> T) rethrows -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return try body()
    }

    private func reserveActiveLoad(entityId: EntityID) -> Bool {
        withStateLock {
            if activeLoads.contains(entityId) {
                return false
            }
            activeLoads.insert(entityId)
            return true
        }
    }

    private func releaseActiveLoad(entityId: EntityID) {
        withStateLock {
            _ = activeLoads.remove(entityId)
        }
    }

    private func activeLoadCountSnapshot() -> Int {
        withStateLock { activeLoads.count }
    }

    private func reserveNearBandLoad(entityId: EntityID) {
        _ = withStateLock { activeNearBandLoads.insert(entityId) }
    }

    private func releaseNearBandLoad(entityId: EntityID) {
        withStateLock { _ = activeNearBandLoads.remove(entityId) }
    }

    private func activeNearBandLoadCount() -> Int {
        withStateLock { activeNearBandLoads.count }
    }

    private func reserveActiveTileLoad(entityId: EntityID, fileSizeBytes: Int) -> Bool {
        withStateLock {
            guard activeTileLoads[entityId] == nil else { return false }
            activeTileLoads[entityId] = fileSizeBytes
            return true
        }
    }

    private func releaseActiveTileLoad(entityId: EntityID) {
        withStateLock { _ = activeTileLoads.removeValue(forKey: entityId) }
    }

    private func activeTileLoadCount() -> Int {
        withStateLock { activeTileLoads.count }
    }

    /// Sum of declared file sizes (bytes) for all tiles currently being parsed.
    private func activeParseBytesInFlight() -> Int {
        withStateLock { activeTileLoads.values.reduce(0, +) }
    }

    private func activeLODLoadCount() -> Int {
        withStateLock { lodLoadingCount }
    }

    private func incrementLODLoadCount() {
        withStateLock { lodLoadingCount += 1 }
    }

    private func decrementLODLoadCount() {
        withStateLock { lodLoadingCount = max(0, lodLoadingCount - 1) }
    }

    private func markLoadedTileEntity(_ entityId: EntityID) {
        withStateLock { _ = loadedTileEntities.insert(entityId) }
    }

    private func unmarkLoadedTileEntity(_ entityId: EntityID) {
        withStateLock { _ = loadedTileEntities.remove(entityId) }
    }

    private func loadedTileEntitiesSnapshot() -> [EntityID] {
        withStateLock { Array(loadedTileEntities) }
    }

    private func markLoadingTileEntity(_ entityId: EntityID) {
        withStateLock { _ = loadingTileEntities.insert(entityId) }
    }

    private func unmarkLoadingTileEntity(_ entityId: EntityID) {
        withStateLock { _ = loadingTileEntities.remove(entityId) }
    }

    private func loadingTileEntitiesSnapshot() -> [EntityID] {
        withStateLock { Array(loadingTileEntities) }
    }

    private func markLoadedHLODEntity(_ entityId: EntityID) {
        withStateLock { _ = loadedHLODEntities.insert(entityId) }
    }

    private func unmarkLoadedHLODEntity(_ entityId: EntityID) {
        withStateLock { _ = loadedHLODEntities.remove(entityId) }
    }

    private func loadedHLODEntitiesSnapshot() -> [EntityID] {
        withStateLock { Array(loadedHLODEntities) }
    }

    private func markLoadedLODEntity(_ entityId: EntityID) {
        withStateLock { _ = loadedLODEntities.insert(entityId) }
    }

    private func unmarkLoadedLODEntity(_ entityId: EntityID) {
        withStateLock { _ = loadedLODEntities.remove(entityId) }
    }

    private func loadedLODEntitiesSnapshot() -> [EntityID] {
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
    private func buildStreamingFrustum(sidePad: Float? = nil) -> Frustum? {
        guard let cameraId = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: cameraId)
        else { return nil }

        let effectiveView = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        let viewProj = simd_mul(renderInfo.perspectiveSpace, effectiveView)

        let ndcNear: Float = renderInfo.reverseZEnabled ? 1.0 : 0.0
        let ndcFar: Float  = renderInfo.reverseZEnabled ? 0.0 : 1.0
        var frustum = buildFrustum(from: viewProj, ndcNear: ndcNear, ndcFar: ndcFar)
        frustum = padFrustum(frustum, sidePad: sidePad ?? frustumGatePadding)
        return frustum
    }

    /// Returns true if the world-space AABB defined by (center, halfExtent) intersects
    /// or overlaps the frustum.  Uses the standard separating-axis / signed-distance
    /// test: the AABB is outside if its projected interval onto any plane normal is
    /// entirely on the negative (outside) side.
    @inline(__always)
    private func isAABBInFrustum(center: simd_float3, halfExtent: simd_float3, frustum: Frustum) -> Bool {
        for plane in frustum.planes {
            // Effective radius of the AABB projected onto the plane normal.
            let r = abs(plane.n.x) * halfExtent.x
                  + abs(plane.n.y) * halfExtent.y
                  + abs(plane.n.z) * halfExtent.z
            // Signed distance from the AABB center to the plane.
            let dist = simd_dot(plane.n, center) + plane.d
            if dist < -r { return false } // fully outside this plane
        }
        return true
    }

    private func loadedStreamingEntitiesSnapshot() -> [EntityID] {
        withStateLock { Array(loadedStreamingEntities) }
    }

    private func markLoadedStreamingEntity(_ entityId: EntityID) {
        withStateLock {
            _ = loadedStreamingEntities.insert(entityId)
        }
    }

    private func unmarkLoadedStreamingEntity(_ entityId: EntityID) {
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
        let hasPendingPressure: Bool = withStateLock { pendingPressureRelief }
        let effectiveInterval = lastPendingLoadBacklog > 0 ? burstTickInterval : updateInterval
        timeSinceLastUpdate += deltaTime
        guard timeSinceLastUpdate >= effectiveInterval || hasPendingPressure else {
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

        var loadCandidates: [(EntityID, Float, Int)] = [] // (entity, distance, priority)
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
                    loadCandidates.append((entityId, distance, streaming.priority))
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
        for entityId in loadingTileEntitiesSnapshot() {
            guard scene.exists(entityId),
                  let tc = scene.get(component: TileComponent.self, for: entityId),
                  tc.state == .parsing,
                  tc.parseStartTime > 0,
                  timeoutNow - tc.parseStartTime > tileParseTimeoutSeconds
            else { continue }

            Logger.logWarning(
                message: "[TileStreaming] Tile '\(tc.tileId)' parse timed out after \(Int(tileParseTimeoutSeconds))s — forcing .failed (attempt \(tc.failureCount + 1))."
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

            tc.failureCount += 1
            tc.lastFailureTime = timeoutNow
            tc.state = .failed
            unmarkLoadingTileEntity(entityId)
            releaseActiveTileLoad(entityId: entityId)
        }

        // ── Tile-level streaming pass ──────────────────────────────────────────
        // Tile stubs (TileComponent, no StreamingComponent) are included in the
        // same octree query above.  When a stub enters its streaming radius the
        // full tile USDC is parsed and registered via setEntityMeshAsync (.auto
        // policy).  Concurrency is governed by a memory budget gate (4.4) instead
        // of a hard count: small tiles parse in parallel; one large tile saturates
        // the budget naturally.
        var tileLoadCandidates: [(EntityID, Float, Int)] = []
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
                tileLoadCandidates.append((entityId, effectiveDist, tileComp.priority))
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
                evictLRU(cameraPosition: effectiveCameraPosition, maxEvictions: 8)
            }

            tileLoadCandidates.sort { lhs, rhs in
                if lhs.2 != rhs.2 { return lhs.2 > rhs.2 } // priority descending
                return lhs.1 < rhs.1                        // effective distance ascending
            }
            for (entityId, _, _) in tileLoadCandidates {
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

            switch tileComp.state {
            case .unloaded, .failed:
                if dist > tileComp.hlodSwitchDistance {
                    if tileComp.hlodState == .unloaded { loadHLOD(entityId: entityId) }
                } else {
                    // Camera crossed inside the switch distance — HLOD no longer needed.
                    if tileComp.hlodState != .unloaded { unloadHLOD(entityId: entityId) }
                }
            case .parsed:
                // Full geometry is resident — HLOD hand-off complete.
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

            // LOD levels are only active between streamingRadius and hlodSwitchDistance.
            // Outside that band the HLOD pass (above) or the tile load pass handles things.
            if tileComp.hlodSwitchDistance > 0, dist >= tileComp.hlodSwitchDistance {
                unloadAllLODLevels(entityId: entityId)
                continue
            }

            // Find the target LOD index: last level whose switchDistance ≤ dist.
            var targetIndex: Int? = nil
            for (i, level) in tileComp.lodLevels.enumerated() {
                if dist >= level.switchDistance { targetIndex = i }
            }

            switch tileComp.state {
            case .unloaded, .failed:
                if let target = targetIndex {
                    for i in tileComp.lodLevels.indices {
                        if i == target {
                            if tileComp.lodLevels[i].state == .unloaded {
                                // Hard cap: never exceed maxConcurrentLODLoads.
                                // Without this, every tile in LOD range is dispatched
                                // simultaneously on initial load, triggering an OOM kill.
                                guard activeLODLoadCount() < maxConcurrentLODLoads else { break }
                                loadLODLevel(entityId: entityId, levelIndex: i)
                            }
                        } else {
                            if tileComp.lodLevels[i].state != .unloaded {
                                unloadLODLevel(entityId: entityId, levelIndex: i)
                            }
                        }
                    }
                } else {
                    // Camera is inside the finest LOD's switch distance — full tile
                    // will load via the tile load pass; drop any active LOD level.
                    unloadAllLODLevels(entityId: entityId)
                }
            case .parsed:
                // Full geometry resident — all LOD levels can be dropped.
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

        for staleId in staleTileIds { unmarkLoadedTileEntity(staleId) }
        // Cap tile unloads per tick to spread GPU buffer releases across frames,
        // preventing a one-frame blank when many tiles leave range simultaneously.
        let cappedUnloads = tileUnloadCandidates.prefix(maxTileUnloadsPerUpdate)
        for entityId in cappedUnloads { unloadTile(entityId: entityId) }

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

        // Sort load candidates: high priority first, then closest
        loadCandidates.sort { lhs, rhs in
            if lhs.2 != rhs.2 { return lhs.2 > rhs.2 } // priority
            return lhs.1 < rhs.1 // distance
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
        }

        // Partition candidates into near band and rest band.
        // Near band (distance ≤ streamingRadius × nearBandFraction) is serialized so the
        // closest meshes always appear in distance order. Rest band uses remaining slots freely.
        var nearBandCandidates: [(EntityID, Float, Int)] = []
        var restBandCandidates: [(EntityID, Float, Int)] = []
        for candidate in loadCandidates {
            let (entityId, distance, priority) = candidate
            let radius = scene.get(component: StreamingComponent.self, for: entityId)?.streamingRadius ?? Float.greatestFiniteMagnitude
            if radius < Float.greatestFiniteMagnitude, distance <= radius * nearBandFraction {
                nearBandCandidates.append((entityId, distance, priority))
            } else {
                restBandCandidates.append((entityId, distance, priority))
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
            for (entityId, _, _) in nearBandCandidates {
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
            for (entityId, _, _) in nearBandCandidates {
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
            for (entityId, _, _) in restBandCandidates {
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

    private func loadMesh(entityId: EntityID, isNearBand: Bool = false) {
        guard let streaming = scene.get(component: StreamingComponent.self, for: entityId),
              streaming.state == .unloaded
        else { return }
        guard reserveActiveLoad(entityId: entityId) else { return }
        if isNearBand { reserveNearBandLoad(entityId: entityId) }

        streaming.state = .loading
        BatchingSystem.shared.notifyEntityStreamingStarted(entityId: entityId)

        // [Instrumentation] Measure scheduler latency: time from first range-detection to dispatch.
        if let firstDetected = firstRangeTimestamps.removeValue(forKey: entityId) {
            let tickToDispatchMs = (CFAbsoluteTimeGetCurrent() - firstDetected) * 1000.0
            Logger.log(
                message: "[OOC-Timing] Entity \(entityId): tick-to-dispatch=\(String(format: "%.1f", tickToDispatchMs))ms band=\(isNearBand ? "near" : "rest")",
                category: LogCategory.oocTiming.rawValue
            )
        }

        // Check if entity has LOD component and CPU LOD data (LOD+OOC path)
        let hasLOD = scene.get(component: LODComponent.self, for: entityId) != nil
        let hasCPULODData = hasLOD && ProgressiveAssetLoader.shared.hasCPULODData(for: entityId)

        let filename = streaming.assetFilename
        let ext = streaming.assetExtension
        let assetName = streaming.assetName

        let task = Task {
            let asyncLoadStart = CFAbsoluteTimeGetCurrent()
            let success = if hasCPULODData {
                // LOD+OOC entity: upload all LOD levels from CPU registry (no disk I/O)
                await uploadActiveLODFromCPU(entityId: entityId)
            } else if hasLOD {
                // LOD entity (disk-based): reload all LOD levels and set correct one for current distance
                await reloadLODEntity(entityId: entityId)
            } else {
                // Regular entity: load single mesh from disk / cache
                await loadMeshAsync(
                    entityId: entityId,
                    filename: filename,
                    withExtension: ext,
                    assetName: assetName
                )
            }
            let asyncLoadMs = (CFAbsoluteTimeGetCurrent() - asyncLoadStart) * 1000.0

            var applyMs: Double = 0
            withWorldMutationGate {
                let applyStart = CFAbsoluteTimeGetCurrent()

                // Guard against the cooperative-cancellation race: unloadTile may have
                // freed this entity while the GPU upload was in flight (Swift Task
                // cancellation is cooperative — the task runs to completion even after
                // cancel() is called).  If the entity no longer exists, skip all state
                // updates but still release the active load slot so future uploads are
                // not blocked.
                guard scene.exists(entityId) else {
                    releaseActiveLoad(entityId: entityId)
                    if isNearBand { releaseNearBandLoad(entityId: entityId) }
                    return
                }

                if success {
                    if let s = scene.get(component: StreamingComponent.self, for: entityId) {
                        s.state = .loaded
                        s.lastVisibleFrame = currentFrame

                        // Emit residency event
                        if let render = scene.get(component: RenderComponent.self, for: entityId) {
                            let event = AssetResidencyChangedEvent(
                                entityId: entityId,
                                assetURL: render.assetURL,
                                meshName: render.assetName,
                                isResident: true
                            )
                            Logger.log(message: "[Batching] queuing residency event for entity=\(entityId)")
                            SystemEventBus.shared.queueResidencyChange(event)
                        } else {
                            Logger.log(message: "[Batching] NO RenderComponent on entity=\(entityId) — residency event NOT queued")
                        }
                    }
                    markLoadedStreamingEntity(entityId)
                    // 4.1: Update the parent tile's visual readiness counter.
                    incrementParentTileOCCCount(for: entityId)
                    SystemIntegrationMonitor.shared.recordStreamingLoad()
                } else {
                    // Load failed - reset to unloaded so it can retry
                    if let s = scene.get(component: StreamingComponent.self, for: entityId) {
                        s.state = .unloaded
                    }
                    Logger.logError(message: "Failed to stream mesh for entity \(entityId)")
                }
                releaseActiveLoad(entityId: entityId)
                if isNearBand { releaseNearBandLoad(entityId: entityId) }
                applyMs = (CFAbsoluteTimeGetCurrent() - applyStart) * 1000.0
            }
            recordLoadCompletion(success: success, asyncLoadMs: asyncLoadMs, applyMs: applyMs, wasLODReload: hasLOD)
        }

        streaming.loadTask = task
    }

    /// Trigger a full tile parse + upload for a manifest tile stub.
    ///
    /// Called by the tile streaming pass in update() when a TileComponent entity
    /// enters its streaming radius.  Sets state to .parsing, spawns a Task that
    /// calls setEntityMeshAsync on a dedicated child entity, then transitions to
    /// .parsed (or .failed with retry backoff on error).
    ///
    // MARK: - HLOD Load / Unload

    /// Loads the coarse HLOD mesh for a tile stub as a child entity.
    /// Called when the camera is beyond `hlodSwitchDistance` and the tile is unloaded.
    /// HLOD entities are rendered through the standard model pass (no batching) and
    /// are unloaded automatically when the full tile parse completes.
    private func loadHLOD(entityId: EntityID) {
        guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
              let hlodURL = tileComp.hlodURL,
              tileComp.hlodState == .unloaded else { return }

        tileComp.hlodState = .loading

        var hlodEntityId: EntityID = .invalid
        withWorldMutationGate {
            let id = createEntity()
            registerTransformComponent(entityId: id)
            registerSceneGraphComponent(entityId: id)
            setParent(childId: id, parentId: entityId)
            hlodEntityId = id
        }

        guard hlodEntityId != .invalid else {
            tileComp.hlodState = .unloaded
            return
        }

        tileComp.hlodEntityId = hlodEntityId
        markLoadedHLODEntity(entityId)

        let capturedHlodId = hlodEntityId
        let capturedTileId = entityId
        let filename = hlodURL.deletingPathExtension().path
        let ext = hlodURL.pathExtension
        let tileId = tileComp.tileId

        let task = Task { [weak self] in
            guard let self else { return }
            setEntityMeshAsync(
                entityId: capturedHlodId,
                filename: filename,
                withExtension: ext,
                streamingPolicy: .immediate,
                blockRenderLoop: false
            ) { [weak self] success in
                guard let self else { return }
                withWorldMutationGate {
                    guard let tc = scene.get(component: TileComponent.self, for: capturedTileId),
                          tc.hlodState == .loading else {
                        // Cancelled while loading — destroy the entity if it still exists.
                        if scene.exists(capturedHlodId) {
                            destroyEntity(entityId: capturedHlodId)
                            finalizePendingDestroys()
                        }
                        return
                    }
                    if success {
                        tc.hlodState = .loaded

                        // Tag HLOD geometry for static batching — same path as a
                        // fullLoad tile.  Without this every HLOD submesh becomes a
                        // separate draw call, which is worse than the batched full tile.
                        setEntityStaticBatchComponent(entityId: capturedHlodId)
                        self.queueResidencyEventsForRenderDescendants(capturedHlodId)
                        let hlodRenderIds = self.collectRenderDescendantIds(capturedHlodId)
                        if !hlodRenderIds.isEmpty {
                            BatchingSystem.shared.notifyTileParsedEntities(hlodRenderIds)
                        }

                        Logger.log(message: "[HLOD] Tile '\(tileId)' HLOD loaded.")
                    } else {
                        if scene.exists(capturedHlodId) {
                            destroyEntity(entityId: capturedHlodId)
                            finalizePendingDestroys()
                        }
                        tc.hlodEntityId = nil
                        tc.hlodState = .unloaded
                        self.unmarkLoadedHLODEntity(capturedTileId)
                        Logger.logError(message: "[HLOD] Tile '\(tileId)' HLOD failed to load.")
                    }
                }
            }
        }

        withWorldMutationGate {
            scene.get(component: TileComponent.self, for: entityId)?.hlodLoadTask = task
        }
    }

    /// Tears down the HLOD child entity for a tile stub.
    /// Safe to call regardless of current hlodState — no-ops if already unloaded.
    private func unloadHLOD(entityId: EntityID) {
        guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
              tileComp.hlodState != .unloaded else { return }

        // Set .unloading BEFORE cancel() so any in-flight completion callback
        // that checks hlodState sees .unloading (not .loading) and discards its result.
        tileComp.hlodState = .unloading
        tileComp.hlodLoadTask?.cancel()
        tileComp.hlodLoadTask = nil

        // Capture before the withWorldMutationGate block clears it.
        let capturedHlodEntityId = tileComp.hlodEntityId

        withWorldMutationGate {
            if let hlodEntityId = tileComp.hlodEntityId, scene.exists(hlodEntityId) {
                destroyEntity(entityId: hlodEntityId)
                finalizePendingDestroys()
            }
            tileComp.hlodEntityId = nil
            tileComp.hlodState = .unloaded
        }

        // Force-release the AssetLoadingGate that setEntityMeshAsync opened via
        // startLoading(entityId: capturedHlodEntityId).  Task.cancel() is cooperative —
        // the inner Task may still be running after we destroy the entity, and its
        // completion callback will find the entity gone and return early without calling
        // finishLoading, leaving the gate permanently elevated and the render loop frozen.
        // finishLoading is idempotent: if the Task already called it, this is a no-op.
        if let hlodId = capturedHlodEntityId {
            Task { await AssetLoadingState.shared.finishLoading(entityId: hlodId) }
        }

        unmarkLoadedHLODEntity(entityId)
        Logger.log(message: "[HLOD] Tile '\(tileComp.tileId)' HLOD unloaded.")
    }

    // MARK: - Per-tile LOD level load / unload

    /// Load one LOD level for a tile stub.  Creates a child entity, calls
    /// setEntityMeshAsync, and on success tags the geometry for static batching
    /// — identical lifecycle to loadHLOD but indexed into tileComp.lodLevels.
    private func loadLODLevel(entityId: EntityID, levelIndex: Int) {
        guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
              levelIndex < tileComp.lodLevels.count,
              tileComp.lodLevels[levelIndex].state == .unloaded else { return }

        let level = tileComp.lodLevels[levelIndex]
        tileComp.lodLevels[levelIndex].state = .loading

        var lodEntityId: EntityID = .invalid
        withWorldMutationGate {
            let id = createEntity()
            registerTransformComponent(entityId: id)
            registerSceneGraphComponent(entityId: id)
            setParent(childId: id, parentId: entityId)
            lodEntityId = id
        }

        guard lodEntityId != .invalid else {
            tileComp.lodLevels[levelIndex].state = .unloaded
            return
        }

        tileComp.lodLevels[levelIndex].entityId = lodEntityId
        markLoadedLODEntity(entityId)
        incrementLODLoadCount()

        let capturedLodId = lodEntityId
        let capturedTileId = entityId
        let capturedIndex = levelIndex
        let filename = level.url.deletingPathExtension().path
        let ext = level.url.pathExtension
        let tileId = tileComp.tileId

        let task = Task { [weak self] in
            guard let self else { return }
            setEntityMeshAsync(
                entityId: capturedLodId,
                filename: filename,
                withExtension: ext,
                streamingPolicy: .immediate,
                blockRenderLoop: false
            ) { [weak self] success in
                guard let self else { return }
                withWorldMutationGate {
                    guard let tc = scene.get(component: TileComponent.self, for: capturedTileId),
                          capturedIndex < tc.lodLevels.count,
                          tc.lodLevels[capturedIndex].state == .loading else {
                        // Cancelled while loading — destroy the entity if it still exists.
                        if scene.exists(capturedLodId) {
                            destroyEntity(entityId: capturedLodId)
                            finalizePendingDestroys()
                        }
                        return
                    }
                    if success {
                        tc.lodLevels[capturedIndex].state = .loaded
                        self.decrementLODLoadCount()
                        setEntityStaticBatchComponent(entityId: capturedLodId)
                        self.queueResidencyEventsForRenderDescendants(capturedLodId)
                        let renderIds = self.collectRenderDescendantIds(capturedLodId)
                        if !renderIds.isEmpty {
                            BatchingSystem.shared.notifyTileParsedEntities(renderIds)
                        }
                        Logger.log(message: "[LOD] Tile '\(tileId)' LOD level \(capturedIndex + 1) loaded.")
                    } else {
                        if scene.exists(capturedLodId) {
                            destroyEntity(entityId: capturedLodId)
                            finalizePendingDestroys()
                        }
                        tc.lodLevels[capturedIndex].entityId = .invalid
                        tc.lodLevels[capturedIndex].state = .unloaded
                        self.decrementLODLoadCount()
                        self.unmarkLoadedLODEntity(capturedTileId)
                        Logger.logError(message: "[LOD] Tile '\(tileId)' LOD level \(capturedIndex + 1) failed to load.")
                    }
                }
            }
        }

        withWorldMutationGate {
            scene.get(component: TileComponent.self, for: entityId)?.lodLevels[capturedIndex].loadTask = task
        }
    }

    /// Tear down one LOD level for a tile stub.  Safe to call regardless of
    /// current state — no-ops if already unloaded.
    private func unloadLODLevel(entityId: EntityID, levelIndex: Int) {
        guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
              levelIndex < tileComp.lodLevels.count,
              tileComp.lodLevels[levelIndex].state != .unloaded else { return }

        // Set .unloading BEFORE cancel() so an in-flight completion sees it and discards.
        // If the level was still .loading, the completion callback will not decrement the
        // counter (it guards on state == .loading), so we must do it here.
        let wasLoading = tileComp.lodLevels[levelIndex].state == .loading
        tileComp.lodLevels[levelIndex].state = .unloading
        tileComp.lodLevels[levelIndex].loadTask?.cancel()
        tileComp.lodLevels[levelIndex].loadTask = nil
        if wasLoading { decrementLODLoadCount() }

        // Capture before the withWorldMutationGate block clears it.
        let capturedLodEntityId = tileComp.lodLevels[levelIndex].entityId

        withWorldMutationGate {
            let lodEntityId = tileComp.lodLevels[levelIndex].entityId
            if lodEntityId != .invalid, scene.exists(lodEntityId) {
                destroyEntity(entityId: lodEntityId)
                finalizePendingDestroys()
            }
            tileComp.lodLevels[levelIndex].entityId = .invalid
            tileComp.lodLevels[levelIndex].state = .unloaded
        }

        // Same gate-release fix as unloadHLOD — see comment there for full rationale.
        if capturedLodEntityId != .invalid {
            Task { await AssetLoadingState.shared.finishLoading(entityId: capturedLodEntityId) }
        }

        // Unmark when no levels remain active.
        if let tc = scene.get(component: TileComponent.self, for: entityId),
           tc.lodLevels.allSatisfy({ $0.state == .unloaded })
        {
            unmarkLoadedLODEntity(entityId)
        }

        Logger.log(message: "[LOD] Tile '\(tileComp.tileId)' LOD level \(levelIndex + 1) unloaded.")
    }

    /// Unload every LOD level for a tile stub.  Called when the full tile reaches
    /// .parsed (full geometry takes over) or when the tile is being torn down.
    private func unloadAllLODLevels(entityId: EntityID) {
        guard let tileComp = scene.get(component: TileComponent.self, for: entityId) else { return }
        for i in tileComp.lodLevels.indices {
            if tileComp.lodLevels[i].state != .unloaded {
                unloadLODLevel(entityId: entityId, levelIndex: i)
            }
        }
    }

    /// Why a child entity?  setEntityMeshAsync loads the RenderComponent directly
    /// onto the entity it receives.  For single-mesh tiles that would be the tile
    /// stub itself, leaving unloadTile's collectDescendants with nothing to destroy
    /// (0 children → GPU mesh stays visible).  Creating a child entity before the
    /// load guarantees collectDescendants always finds and destroys the geometry,
    /// regardless of how many meshes the tile contains.
    private func loadTile(entityId: EntityID) {
        guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
              tileComp.state == .unloaded
        else { return }
        guard reserveActiveTileLoad(entityId: entityId, fileSizeBytes: tileComp.fileSizeBytes) else { return }

        tileComp.state = .parsing
        tileComp.parseStartTime = CFAbsoluteTimeGetCurrent()
        markLoadingTileEntity(entityId)

        // LoadingSystem.getResourceURL handles absolute paths (prefix "/").
        // Splitting into stem + extension matches how the resource search handles
        // all other asset loads, including cross-bundle and external-basePath scenarios.
        let tileURL = tileComp.tileURL
        let tileId = tileComp.tileId
        let filename = tileURL.deletingPathExtension().path
        let ext = tileURL.pathExtension

        Logger.log(message: "[TileStreaming] Dispatching load for tile '\(tileId)'")

        // Create a dedicated mesh entity as a child of the tile stub before
        // spawning the load Task.  setEntityMeshAsync will attach all geometry
        // (RenderComponent, child mesh entities) to meshEntityId, not to the
        // stub.  unloadTile's collectDescendants then finds meshEntityId and
        // destroys it — freeing all GPU buffers — without touching the stub.
        var meshEntityId: EntityID = .invalid
        withWorldMutationGate {
            let id = createEntity()
            registerTransformComponent(entityId: id)
            registerSceneGraphComponent(entityId: id)
            setParent(childId: id, parentId: entityId)
            meshEntityId = id
        }

        let capturedMeshEntityId = meshEntityId
        // Register lookup so OCC upload completions can update this tile's visual state.
        withStateLock { meshEntityToTileEntity[capturedMeshEntityId] = entityId }

        // Store so the parse-timeout guard can force-release the AssetLoadingGate
        // if setEntityMeshAsync's inner Task hangs (e.g. ModelIO blocking in loadTextures()).
        tileComp.meshEntityId = capturedMeshEntityId

        let task = Task { [weak self] in
            // If self was deallocated before the task body executes (e.g. game
            // shutdown), the completion will never fire and the slot will remain
            // reserved — acceptable since the system is being torn down anyway.
            guard let self else { return }
            // .auto policy: the admission gate and memory budget system decide whether
            // to use fullLoad or outOfCore based on the tile's file size and available
            // RAM.  For the expected 15–20 MB tile range this resolves to fullLoad
            // (parse + immediate GPU upload), treating the tile as an atomic unit.
            setEntityMeshAsync(
                entityId: capturedMeshEntityId,
                filename: filename,
                withExtension: ext,
                streamingPolicy: .auto
            ) { [weak self] success in
                guard let self else { return }
                // Slot release is unconditional — deferred so it runs on all paths
                // (success, failure, early return from the cancelled-state guard).
                defer { self.releaseActiveTileLoad(entityId: entityId) }
                withWorldMutationGate {
                    guard let tc = scene.get(component: TileComponent.self, for: entityId) else { return }

                    // Guard against the zombie-loaded-state bug: unloadTile may have
                    // run and set state to .unloading while setEntityMeshAsync was in
                    // flight.  If we are no longer .parsing, the tile was cancelled.
                    // setEntityMeshAsync has now fully exited, so all background-thread
                    // ECS mutations for this tile are complete.  The completion fires on
                    // the main thread, so cleanup can run directly here.
                    guard tc.state == .parsing else {
                        if scene.exists(capturedMeshEntityId) {
                            let descendants = collectTileDescendants(capturedMeshEntityId)
                            for d in descendants { destroyEntity(entityId: d) }
                            destroyEntity(entityId: capturedMeshEntityId)
                            finalizePendingDestroys()
                        }
                        withStateLock { _ = meshEntityToTileEntity.removeValue(forKey: capturedMeshEntityId) }
                        ProgressiveAssetLoader.shared.removeOutOfCoreAsset(rootEntityId: entityId)
                        if let tc2 = scene.get(component: TileComponent.self, for: entityId) {
                            tc2.state = .unloaded
                        }
                        unmarkLoadedTileEntity(entityId)
                        Logger.log(message: "[TileStreaming] Tile '\(tileId)' cancelled load cleaned up.")
                        return
                    }

                    self.unmarkLoadingTileEntity(entityId)
                    tc.loadTask = nil
                    tc.parseStartTime = 0
                    tc.meshEntityId = .invalid

                    if success {
                        // Count OCC stubs to seed visual state tracking (4.1).
                        // Eager tiles have 0 stubs and are immediately .complete.
                        let occCount = self.countOCCDescendants(capturedMeshEntityId)
                        tc.totalOCCStubs = occCount
                        tc.uploadedOCCStubs = 0
                        tc.failureCount = 0   // clear retry counter on successful parse
                        tc.state = .parsed
                        self.markLoadedTileEntity(entityId)

                        // Full geometry is now resident — unload the coarse HLOD mesh
                        // and any per-tile LOD levels that were showing while loading.
                        self.unloadHLOD(entityId: entityId)
                        self.unloadAllLODLevels(entityId: entityId)

                        // Tag the tile's mesh hierarchy for cell-based static batching.
                        // setEntityStaticBatchComponent walks the full child tree and
                        // attaches StaticBatchComponent to every entity that has a
                        // RenderComponent (eager/small tiles) or StreamingComponent
                        // (OCC stubs awaiting GPU upload).  For OCC stubs the batch
                        // residency handler fires automatically when each stub's GPU
                        // upload completes, so no manual generateBatches() call is needed.
                        setEntityStaticBatchComponent(entityId: capturedMeshEntityId)

                        // For fullLoad tiles (occCount == 0) the RenderComponent is
                        // already present on capturedMeshEntityId and its children —
                        // they bypass the OCC upload path that normally queues the
                        // residency event.  Queue the event explicitly here so the
                        // batching system picks them up on the next flushEvents() call.
                        if occCount == 0 {
                            self.queueResidencyEventsForRenderDescendants(capturedMeshEntityId)
                            // Notify the batching system so it can bypass the quiescence
                            // delay for this tile's cells.  All render entities are resident
                            // now; their residency events will arrive on the next flushEvents()
                            // call, and the batching tick will promote their cells immediately.
                            let tileRenderIds = self.collectRenderDescendantIds(capturedMeshEntityId)
                            if !tileRenderIds.isEmpty {
                                BatchingSystem.shared.notifyTileParsedEntities(tileRenderIds)
                            }
                        }

                        Logger.log(message: "[TileStreaming] Tile '\(tileId)' parsed (\(occCount) OCC stubs pending GPU upload).")
                    } else {
                        // Destroy the pre-created child entity on failure so it
                        // doesn't leak as an empty, invisible stub.
                        if scene.exists(capturedMeshEntityId) {
                            destroyEntity(entityId: capturedMeshEntityId)
                            finalizePendingDestroys()
                        }
                        withStateLock { _ = meshEntityToTileEntity.removeValue(forKey: capturedMeshEntityId) }
                        // 4.2: Record failure for exponential-backoff retry.
                        tc.failureCount += 1
                        tc.lastFailureTime = CFAbsoluteTimeGetCurrent()
                        tc.state = .failed
                        Logger.logError(message: "[TileStreaming] Tile '\(tileId)' failed to parse (attempt \(tc.failureCount)) — retry in \(String(format: "%.0f", tc.retryDelaySeconds)) s.")
                    }
                }
            }
        }

        // Store the task so teardown can cancel an in-flight load.
        // This runs on the main thread in the same update() tick as the Task
        // creation above, so there is no race with unloadTile (which can only
        // be called in a future tick).
        withWorldMutationGate {
            scene.get(component: TileComponent.self, for: entityId)?.loadTask = task
        }
    }

    /// Walk the entity subtree rooted at `entityId` and queue an
    /// AssetResidencyChangedEvent for every entity that already has a RenderComponent.
    /// Called from the loadTile completion for fullLoad (non-OCC) tiles whose geometry
    /// is immediately resident — they never go through the OCC upload path that normally
    /// queues the event, so we queue it explicitly here.
    private func queueResidencyEventsForRenderDescendants(_ entityId: EntityID) {
        if let render = scene.get(component: RenderComponent.self, for: entityId) {
            let event = AssetResidencyChangedEvent(
                entityId: entityId,
                assetURL: render.assetURL,
                meshName: render.assetName,
                isResident: true
            )
            SystemEventBus.shared.queueResidencyChange(event)
        }
        for childId in getEntityChildren(parentId: entityId) {
            queueResidencyEventsForRenderDescendants(childId)
        }
    }

    /// Recursively collect the IDs of all descendants (including `entityId` itself)
    /// that have a RenderComponent.  Used to hand off the full set of render-ready
    /// entities to the BatchingSystem after a fullLoad tile finishes parsing.
    private func collectRenderDescendantIds(_ entityId: EntityID) -> Set<EntityID> {
        var result: Set<EntityID> = []
        collectRenderDescendantIds(entityId, into: &result)
        return result
    }

    private func collectRenderDescendantIds(_ entityId: EntityID, into result: inout Set<EntityID>) {
        if scene.get(component: RenderComponent.self, for: entityId) != nil {
            result.insert(entityId)
        }
        for childId in getEntityChildren(parentId: entityId) {
            collectRenderDescendantIds(childId, into: &result)
        }
    }

    /// Recursively count OCC stub descendants (entities with StreamingComponent).
    /// Used to seed TileComponent.totalOCCStubs after a tile parse completes.
    private func countOCCDescendants(_ parentId: EntityID) -> Int {
        var count = 0
        for childId in getEntityChildren(parentId: parentId) {
            if scene.get(component: StreamingComponent.self, for: childId) != nil {
                count += 1
            }
            count += countOCCDescendants(childId)
        }
        return count
    }

    /// Increment the uploaded OCC stub counter on the parent tile of `entityId`.
    /// Called each time an OCC streaming upload completes successfully so the tile's
    /// visual state (4.1) advances toward .complete.
    ///
    /// Hierarchy: OCC stub → capturedMeshEntityId → tile stub (TileComponent).
    /// Uses the meshEntityToTileEntity lookup for O(1) tile resolution.
    private func incrementParentTileOCCCount(for entityId: EntityID) {
        // Climb one level to find capturedMeshEntityId (the direct mesh parent).
        guard let sg = scene.get(component: ScenegraphComponent.self, for: entityId) else { return }
        let meshParentId = sg.parent
        guard meshParentId != .invalid else { return }

        // Resolve tile entity via the lookup table registered at parse time.
        let tileEntityId: EntityID? = withStateLock { meshEntityToTileEntity[meshParentId] }
        guard let tileId = tileEntityId,
              let tileComp = scene.get(component: TileComponent.self, for: tileId)
        else { return }

        tileComp.uploadedOCCStubs = min(tileComp.uploadedOCCStubs + 1, tileComp.totalOCCStubs)
    }

    /// Recursively collect all descendants of `parentId`, cancelling any in-flight
    /// streaming tasks along the way.  Must be called from the main thread while
    /// holding the world-mutation gate.
    private func collectTileDescendants(_ parentId: EntityID) -> [EntityID] {
        var result: [EntityID] = []
        for childId in getEntityChildren(parentId: parentId) {
            if let streaming = scene.get(component: StreamingComponent.self, for: childId) {
                streaming.loadTask?.cancel()
                streaming.loadTask = nil
                unmarkLoadedStreamingEntity(childId)
            }
            // Remove first-detection timestamp so phantom entries do not accumulate after
            // tile teardown.  Without this, stale keys from unloaded OCC stubs that never
            // reached dispatch would linger in firstRangeTimestamps indefinitely.
            firstRangeTimestamps.removeValue(forKey: childId)
            result.append(childId)
            result.append(contentsOf: collectTileDescendants(childId))
        }
        return result
    }

    /// Tear down a parsed tile: cancel any in-flight parse, destroy all child entities,
    /// release CPU/GPU resources, and reset the TileComponent stub to .unloaded so the
    /// tile can be re-streamed on the next approach.
    ///
    /// Called by the tile unload pass in update() when a parsed tile moves beyond its
    /// unloadRadius.  All world-mutation work runs inside withWorldMutationGate so it
    /// interleaves safely with other ECS writes.
    private func unloadTile(entityId: EntityID) {
        guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
              tileComp.state == .parsed || tileComp.state == .parsing
        else { return }

        let tileId = tileComp.tileId
        let wasParsing = tileComp.state == .parsing

        withWorldMutationGate {
            // Mark as unloading to prevent the load pass from re-dispatching this tick.
            tileComp.state = .unloading

            // Cancel any in-flight parse task and clear tracking state.
            // The completion callback guards tc.state == .parsing and will find .unloading
            // instead — so it discards the result.  We must NOT release the active-tile
            // slot here to avoid a double-release (the completion's defer does it).
            tileComp.loadTask?.cancel()
            tileComp.loadTask = nil

            if wasParsing {
                // Remove from the .parsing tracking set; the .parsed set was never touched.
                unmarkLoadingTileEntity(entityId)

                // The load Task is still running on the background thread.
                // setEntityMeshAsync may be actively creating or accessing child entities
                // right now — destroying them here would be an unsynchronised concurrent
                // write into the ECS.  Bail out and let loadTile's completion callback
                // dispatch the cleanup to the main thread once the Task has fully exited.
                return
            }

            // ── Tile was fully parsed: safe to destroy descendants immediately ──────

            // Remove meshEntityToTileEntity entries for all direct children of the tile
            // stub (i.e. capturedMeshEntityId values registered at parse time).  Must
            // happen before destroyEntity so the entity IDs are still valid for lookup.
            let directChildren = getEntityChildren(parentId: entityId)
            withStateLock {
                for childId in directChildren {
                    _ = meshEntityToTileEntity.removeValue(forKey: childId)
                }
            }

            let descendants = collectTileDescendants(entityId)

            // destroyEntity + finalizePendingDestroys handles GPU buffer release,
            // OctreeSystem removal, MeshResourceManager deref, and MemoryBudgetManager
            // unregister via ComponentRegistry.cleanupAll.
            for descendantId in descendants {
                destroyEntity(entityId: descendantId)
            }
            if !descendants.isEmpty {
                finalizePendingDestroys()
            }

            // Release CPU-heap MDLAsset / CPUMeshEntry for this tile root if it was
            // loaded out-of-core (large tiles above the admission threshold).
            ProgressiveAssetLoader.shared.removeOutOfCoreAsset(rootEntityId: entityId)

            // Reset visual state counters for the next load cycle.
            tileComp.totalOCCStubs = 0
            tileComp.uploadedOCCStubs = 0
            tileComp.pendingUnloadSince = 0

            // Reset stub so the next approach triggers a fresh loadTile() call.
            tileComp.state = .unloaded
            tileComp.parseStartTime = 0
            unmarkLoadedTileEntity(entityId)

            Logger.log(message: "[TileStreaming] Tile '\(tileId)' unloaded (\(descendants.count) child entities destroyed).")
        }
    }

    /// Reload all LOD levels for an LOD entity and set display to correct LOD for current distance
    private func reloadLODEntity(entityId: EntityID) async -> Bool {
        // Guard against the cooperative-cancellation race: bail out early if the entity has
        // been freed or its slot reused (version mismatch) so subsequent scene.get() calls
        // do not generate spurious 1016 "entity missing" errors.
        guard scene.exists(entityId) else { return false }

        let lodInfo: [(index: Int, url: URL, assetName: String, maxDistance: Float)] = {
            guard let lodComponent = scene.get(component: LODComponent.self, for: entityId) else {
                return []
            }
            var info: [(Int, URL, String, Float)] = []
            for (index, level) in lodComponent.lodLevels.enumerated() {
                if let url = level.url {
                    let name = level.assetName ?? url.deletingPathExtension().lastPathComponent
                    info.append((index, url, name, level.maxDistance))
                }
            }
            return info
        }()

        guard !lodInfo.isEmpty else {
            Logger.logError(message: "LOD entity has no LOD levels with URLs")
            return false
        }

        // Load all LOD level meshes
        var loadedMeshes: [Int: [Mesh]] = [:]
        var anySuccess = false

        for (lodIndex, url, assetName, _) in lodInfo {
            if let meshes = await MeshResourceManager.shared.loadMesh(url: url, meshName: assetName) {
                // Retain for this entity
                MeshResourceManager.shared.retain(url: url, meshName: assetName, for: entityId)
                loadedMeshes[lodIndex] = meshes
                anySuccess = true
            } else {
                Logger.logWarning(message: "Failed to reload LOD\(lodIndex) for entity \(entityId)")
            }
        }

        guard anySuccess else {
            Logger.logError(message: "Failed to reload any LOD levels for entity \(entityId)")
            return false
        }

        withWorldMutationGate {
            guard let lodComponent = scene.get(component: LODComponent.self, for: entityId),
                  let renderComponent = scene.get(component: RenderComponent.self, for: entityId)
            else { return }

            // Update all LOD level meshes - create fresh copies for each LOD level
            for (lodIndex, meshes) in loadedMeshes {
                guard lodIndex < lodComponent.lodLevels.count else { continue }

                // Create a unique Skin instance for each LOD level to avoid sharing issues
                let levelSkin = Skin()
                // IMPORTANT: Create copies of meshes with fresh uniform buffers for this entity
                // Without this, multiple entities sharing the same cached mesh would overwrite
                // each other's uniform data during rendering, causing entities to disappear
                var updatedMeshes = meshes.map { $0.copyWithNewUniformBuffers() }
                for i in updatedMeshes.indices {
                    if updatedMeshes[i].skin == nil {
                        updatedMeshes[i].skin = levelSkin
                    }
                }

                lodComponent.lodLevels[lodIndex].mesh = updatedMeshes
                lodComponent.lodLevels[lodIndex].residencyState = .resident
            }

            // Calculate camera distance to select correct LOD
            var selectedLOD = lodComponent.lodLevels.count - 1 // Default to lowest detail

            if let camera = CameraSystem.shared.activeCamera,
               let cameraComponent = scene.get(component: CameraComponent.self, for: camera),
               let transform = scene.get(component: WorldTransformComponent.self, for: entityId),
               let local = scene.get(component: LocalTransformComponent.self, for: entityId)
            {
                let cameraPos = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
                let center = (local.boundingBox.min + local.boundingBox.max) * 0.5
                let worldCenter = transform.space * simd_float4(center, 1.0)
                let distance = simd_distance(cameraPos, simd_float3(worldCenter.x, worldCenter.y, worldCenter.z))

                // Find appropriate LOD for this distance
                for (index, level) in lodComponent.lodLevels.enumerated() {
                    if distance <= level.maxDistance, lodComponent.isLODResident(index) {
                        selectedLOD = index
                        break
                    }
                }
            }

            // Set render component to show the correct LOD
            if selectedLOD < lodComponent.lodLevels.count, lodComponent.isLODResident(selectedLOD) {
                let lodLevel = lodComponent.lodLevels[selectedLOD]
                renderComponent.mesh = lodLevel.mesh
                if let url = lodLevel.url {
                    renderComponent.assetURL = url
                    renderComponent.assetName = lodLevel.assetName ?? url.deletingPathExtension().lastPathComponent
                }
                lodComponent.currentLOD = selectedLOD
                lodComponent.desiredLOD = selectedLOD
                lodComponent.isUsingFallback = false
            }
        }

        return true
    }

    /// Upload one out-of-core stub entity from CPU-resident MDLMesh data to Metal.
    ///
    /// Called instead of the disk-based `MeshResourceManager` path when the entity was
    /// registered by the out-of-core stub system. CPU→Metal copy happens here; no USDZ
    /// re-read is required. The CPU data is NOT cleared after upload so that future
    /// eviction+reload cycles can re-upload from the same in-memory source.
    private func uploadFromCPUEntry(
        entityId: EntityID,
        cpuEntry: ProgressiveAssetLoader.CPUMeshEntry
    ) async -> Bool {
        // Guard against the cooperative-cancellation race: the parent tile may have been
        // unloaded while this Task was in flight (Swift Task cancellation is cooperative —
        // the task runs to completion even after cancel() is called).  If the entity slot
        // has been freed or reused by a new entity (version mismatch), bail out early so
        // subsequent scene.get() calls do not generate spurious 1016 "entity missing" errors.
        guard scene.exists(entityId) else { return false }

        // Serialize texture loading per asset and ensure loadTextures() has been called.
        // MDLAsset is not thread-safe. The lock prevents two concurrent uploads from the
        // same asset racing on MDLTexture internal state.
        // ensureTexturesLoaded() is a no-op after the first call per asset — it calls
        // asset.loadTextures() exactly once, deferred from parse time to first-upload time
        // so the full texture decompression spike doesn't happen before any mesh is rendered.
        let rootEntityId = scene.get(component: DerivedAssetNodeComponent.self, for: entityId)?.assetRootEntityId
        var lockWaitMs: Double = 0
        var textureMs: Double = 0
        if let rootId = rootEntityId {
            // [Instrumentation] Measure time blocked waiting for the per-asset texture lock.
            let lockStart = CFAbsoluteTimeGetCurrent()
            ProgressiveAssetLoader.shared.acquireAssetTextureLock(for: rootId)
            lockWaitMs = (CFAbsoluteTimeGetCurrent() - lockStart) * 1000.0

            // [Instrumentation] Measure ensureTexturesLoaded duration.
            // Non-zero only on the FIRST upload from this asset; subsequent calls are no-ops.
            let textureStart = CFAbsoluteTimeGetCurrent()
            // Always call ensureTexturesLoaded before makeMeshesFromCPUBuffers. This calls
            // asset.loadTextures() exactly once per asset — USDZ-embedded textures require it
            // before MTKTextureLoader can decode them. The lock scope ends here: the MDLAsset
            // is in a stable read-only state after loadTextures() and concurrent GPU uploads
            // from the same asset are safe without the lock.
            ProgressiveAssetLoader.shared.ensureTexturesLoaded(for: rootId)
            textureMs = (CFAbsoluteTimeGetCurrent() - textureStart) * 1000.0
            ProgressiveAssetLoader.shared.releaseAssetTextureLock(for: rootId)
        }
        // [Instrumentation] Measure CPU→Metal buffer copy time.
        let copyStart = CFAbsoluteTimeGetCurrent()
        let meshes = Mesh.makeMeshesFromCPUBuffers(
            object: cpuEntry.object,
            vertexDescriptor: cpuEntry.vertexDescriptor,
            textureLoader: cpuEntry.textureLoader,
            device: cpuEntry.device,
            flip: true
        )
        let copyMs = (CFAbsoluteTimeGetCurrent() - copyStart) * 1000.0
        Logger.log(
            message: "[OOC-Timing] Entity \(entityId) '\(cpuEntry.uniqueAssetName)': lockWait=\(String(format: "%.1f", lockWaitMs))ms textures=\(String(format: "%.1f", textureMs))ms cpuToMetal=\(String(format: "%.1f", copyMs))ms",
            category: LogCategory.oocTiming.rawValue
        )

        guard !meshes.isEmpty else {
            Logger.logError(
                message: "[OutOfCore] CPU→Metal upload failed for entity \(entityId) ('\(cpuEntry.uniqueAssetName)')",
                category: LogCategory.oocStatus.rawValue
            )
            return false
        }

        // Stamp the unique asset name so the RenderComponent matches the StreamingComponent.
        let namedMeshes = meshes.map { m -> Mesh in
            var copy = m
            copy.assetName = cpuEntry.uniqueAssetName
            return copy
        }

        withWorldMutationGate {
            // Guard against the cooperative-cancellation race: unloadTile may have freed
            // this entity while the CPU→Metal copy was in flight.  If the entity no longer
            // exists, skip registration — the outer Task's scene.exists guard will clean up.
            guard scene.exists(entityId) else { return }
            registerRenderComponent(
                entityId: entityId,
                meshes: namedMeshes,
                url: cpuEntry.url,
                assetName: cpuEntry.uniqueAssetName
            )
        }

        // Register Metal allocation with the budget manager so shouldEvict() sees these
        // GPU bytes. Without this the budget gate in update() is blind to out-of-core uploads
        // and will never throttle them — defeating the memory-pressure guard entirely.
        // Texture bytes are estimated rather than exact: TextureStreamingSystem will update
        // the value with the real figure once streaming completes. Even an estimate is far
        // better than 0 — it closes the tracking gap that lets the budget over-admit entities.
        let meshSize = calculateMeshArrayMemory(namedMeshes)
        // Register 0 for texture bytes at upload time. With independent geometry/texture
        // budget pools, the geometry gate (canAcceptMesh / shouldEvictGeometry) is unaffected
        // by texture usage, so a zero estimate no longer causes over-admission. The estimate
        // (4 MB × slots) massively over-filled the texture pool on geometry-heavy scenes,
        // making shouldEvict() permanently true and triggering no-op shedTextureMemory calls
        // every tick. TextureStreamingSystem registers the real value after streaming.
        MemoryBudgetManager.shared.registerMesh(
            entityId: entityId,
            meshSizeBytes: meshSize,
            textureSizeBytes: 0
        )

        // CPU data is intentionally kept alive in ProgressiveAssetLoader.cpuMeshRegistry
        // so eviction + re-approach triggers another uploadFromCPUEntry, not a disk read.
        return true
    }

    /// Upload all LOD levels for an LOD+OOC entity from the CPU registry (no disk I/O).
    ///
    /// Mirrors `reloadLODEntity` but reads MDLObject data from `ProgressiveAssetLoader.cpuLODRegistry`
    /// instead of re-reading from disk. After all levels are uploaded, the render component is set to
    /// the LOD level appropriate for the current camera distance — identical selection logic to `reloadLODEntity`.
    private func uploadActiveLODFromCPU(entityId: EntityID) async -> Bool {
        // Guard against the cooperative-cancellation race: bail out early if the entity has
        // been freed or its slot reused (version mismatch) so subsequent scene.get() calls
        // do not generate spurious 1016 "entity missing" errors.
        guard scene.exists(entityId) else { return false }

        // Determine root entity for texture lock serialization.
        let rootEntityId = scene.get(component: DerivedAssetNodeComponent.self, for: entityId)?
            .assetRootEntityId ?? entityId

        // If the root asset has gone cold, re-parse from disk to restore CPU entries.
        if ProgressiveAssetLoader.shared.isColdRoot(rootEntityId) {
            guard let context = ProgressiveAssetLoader.shared.rehydrationContext(for: rootEntityId) else {
                Logger.logError(
                    message: "[OutOfCore] LOD+OOC entity \(entityId): root \(rootEntityId) is cold with no rehydration context",
                    category: LogCategory.oocStatus.rawValue
                )
                return false
            }
            let ok = await rehydrateColdAsset(rootEntityId: rootEntityId, context: context)
            guard ok else { return false }
        }

        guard let allLODEntries = ProgressiveAssetLoader.shared.retrieveAllCPULODMeshes(for: entityId),
              !allLODEntries.isEmpty
        else {
            Logger.logError(
                message: "[OutOfCore] LOD+OOC entity \(entityId): no CPU LOD entries found",
                category: LogCategory.oocStatus.rawValue
            )
            return false
        }

        // Ensure loadTextures() has been called before any MTKTextureLoader decoding.
        // The lock scope covers only ensureTexturesLoaded — the MDLAsset is read-only after
        // that point and concurrent GPU uploads across LOD levels are safe without it.
        ProgressiveAssetLoader.shared.acquireAssetTextureLock(for: rootEntityId)
        ProgressiveAssetLoader.shared.ensureTexturesLoaded(for: rootEntityId)
        ProgressiveAssetLoader.shared.releaseAssetTextureLock(for: rootEntityId)

        // Upload every LOD level from CPU to Metal.
        var uploadedMeshes: [Int: [Mesh]] = [:]
        for (lodIndex, cpuEntry) in allLODEntries {
            let meshes = Mesh.makeMeshesFromCPUBuffers(
                object: cpuEntry.object,
                vertexDescriptor: cpuEntry.vertexDescriptor,
                textureLoader: cpuEntry.textureLoader,
                device: cpuEntry.device,
                flip: true
            )
            guard !meshes.isEmpty else {
                Logger.logWarning(
                    message: "[OutOfCore] LOD+OOC entity \(entityId): CPU→Metal failed for LOD\(lodIndex), skipping level",
                    category: LogCategory.oocStatus.rawValue
                )
                continue
            }
            let levelSkin = Skin()
            var namedMeshes = meshes.map { m -> Mesh in var copy = m; copy.assetName = cpuEntry.uniqueAssetName; return copy }
            for i in namedMeshes.indices where namedMeshes[i].skin == nil {
                namedMeshes[i].skin = levelSkin
            }
            uploadedMeshes[lodIndex] = namedMeshes
        }

        guard !uploadedMeshes.isEmpty else {
            Logger.logError(
                message: "[OutOfCore] LOD+OOC entity \(entityId): all LOD level uploads failed",
                category: LogCategory.oocStatus.rawValue
            )
            return false
        }

        withWorldMutationGate {
            guard let lodComponent = scene.get(component: LODComponent.self, for: entityId) else { return }

            // Store uploaded meshes in LOD levels and mark resident.
            for (lodIndex, meshes) in uploadedMeshes {
                guard lodIndex < lodComponent.lodLevels.count else { continue }
                lodComponent.lodLevels[lodIndex].mesh = meshes
                lodComponent.lodLevels[lodIndex].residencyState = .resident
            }

            // Select correct LOD for current camera distance (same logic as reloadLODEntity).
            var selectedLOD = lodComponent.lodLevels.count - 1
            if let camera = CameraSystem.shared.activeCamera,
               let cameraComponent = scene.get(component: CameraComponent.self, for: camera),
               let transform = scene.get(component: WorldTransformComponent.self, for: entityId),
               let local = scene.get(component: LocalTransformComponent.self, for: entityId)
            {
                let cameraPos = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
                let center = (local.boundingBox.min + local.boundingBox.max) * 0.5
                let worldCenter = transform.space * simd_float4(center, 1.0)
                let distance = simd_distance(cameraPos, simd_float3(worldCenter.x, worldCenter.y, worldCenter.z))
                for (index, level) in lodComponent.lodLevels.enumerated() {
                    if distance <= level.maxDistance, lodComponent.isLODResident(index) {
                        selectedLOD = index
                        break
                    }
                }
            }

            if selectedLOD < lodComponent.lodLevels.count, lodComponent.isLODResident(selectedLOD) {
                let lodLevel = lodComponent.lodLevels[selectedLOD]
                if let cpuEntry = ProgressiveAssetLoader.shared.retrieveCPULODMesh(for: entityId, lodIndex: selectedLOD) {
                    registerRenderComponent(entityId: entityId, meshes: lodLevel.mesh, url: cpuEntry.url, assetName: cpuEntry.uniqueAssetName)
                }
                lodComponent.currentLOD = selectedLOD
                lodComponent.desiredLOD = selectedLOD
                lodComponent.isUsingFallback = false
            }
        }

        // Register total GPU allocation (all levels) with the budget manager.
        // Texture bytes registered as 0 — see uploadFromCPUEntry for the reasoning.
        // TextureStreamingSystem replaces this with the real value after streaming.
        let totalMeshSize = uploadedMeshes.values.reduce(0) { $0 + calculateMeshArrayMemory($1) }
        MemoryBudgetManager.shared.registerMesh(entityId: entityId, meshSizeBytes: totalMeshSize, textureSizeBytes: 0)

        Logger.log(
            message: "[OutOfCore] LOD+OOC entity \(entityId): uploaded \(uploadedMeshes.count) LOD level(s) from CPU",
            category: LogCategory.oocStatus.rawValue
        )
        return true
    }

    /// Re-parse a cold root asset from disk and restore all child CPU entries.
    ///
    /// At most one re-parse Task runs per root at a time: `getOrCreateRehydrationTask` ensures
    /// concurrent child entity requests all await the same `Task<Bool, Never>` rather than
    /// each launching a duplicate re-parse. Once complete, the root transitions back to warm
    /// via `markAsWarm` and all child `CPUMeshEntry` objects are restored in `cpuMeshRegistry`.
    private func rehydrateColdAsset(
        rootEntityId: EntityID,
        context: ProgressiveAssetLoader.RootRehydrationContext
    ) async -> Bool {
        let task = ProgressiveAssetLoader.shared.getOrCreateRehydrationTask(for: rootEntityId) {
            Task {
                Logger.log(
                    message: "[OutOfCore] Cold re-stream: re-parsing '\(context.url.lastPathComponent)' for root \(rootEntityId)",
                    category: LogCategory.oocStatus.rawValue
                )
                guard let assetData = await Mesh.parseAssetAsync(
                    url: context.url,
                    vertexDescriptor: vertexDescriptor.model,
                    device: renderInfo.device
                ) else {
                    Logger.logError(
                        message: "[OutOfCore] Cold re-stream: parseAssetAsync failed for root \(rootEntityId)",
                        category: LogCategory.oocStatus.rawValue
                    )
                    ProgressiveAssetLoader.shared.clearRehydrationTask(for: rootEntityId)
                    return false
                }

                let children = ProgressiveAssetLoader.shared.getChildren(for: rootEntityId)
                let filename = context.url.deletingPathExtension().lastPathComponent
                let ext = context.url.pathExtension

                // Detect whether this is a LOD+OOC asset by checking if the re-parsed
                // top-level objects form LOD groups (same detection as registration time).
                let topLevelNames = assetData.topLevelObjects.map {
                    ($0 as? MDLMesh)?.parent?.name ?? $0.name
                }
                let lodDetection = detectImportedLODGroups(fromSourceNames: topLevelNames)

                if !lodDetection.groups.isEmpty, !children.isEmpty {
                    // LOD+OOC: rebuild cpuLODRegistry from detected groups.
                    // Groups are sorted by baseName (same order as at registration time),
                    // so children[groupIdx] corresponds to lodDetection.groups[groupIdx].
                    var nameToObject: [String: MDLObject] = [:]
                    for obj in assetData.topLevelObjects {
                        let name = (obj as? MDLMesh)?.parent?.name ?? obj.name
                        nameToObject[name] = obj
                    }
                    var restoredEntries = 0
                    for (groupIdx, group) in lodDetection.groups.enumerated() {
                        guard groupIdx < children.count else { break }
                        let groupEntityId = children[groupIdx]
                        for level in group.levels {
                            guard let obj = nameToObject[level.sourceName] else { continue }
                            let estimatedGPUBytes: Int = {
                                guard let mdlMesh = obj as? MDLMesh else { return 0 }
                                let stride = Int((mdlMesh.vertexDescriptor.layouts.firstObject as? MDLVertexBufferLayout)?.stride ?? 48)
                                return mdlMesh.vertexCount * stride + mdlMesh.vertexCount * 3 * 4
                            }()
                            let entry = ProgressiveAssetLoader.CPUMeshEntry(
                                object: obj,
                                vertexDescriptor: vertexDescriptor.model,
                                textureLoader: assetData.textureLoader,
                                device: renderInfo.device,
                                url: context.url,
                                filename: filename,
                                withExtension: ext,
                                uniqueAssetName: level.sourceName,
                                estimatedGPUBytes: estimatedGPUBytes,
                                residencyPolicy: context.loadingPolicy
                            )
                            ProgressiveAssetLoader.shared.storeCPULODMesh(entry, for: groupEntityId, lodIndex: level.lodIndex)
                            restoredEntries += 1
                        }
                    }
                    ProgressiveAssetLoader.shared.storeAsset(assetData.asset, for: rootEntityId)
                    ProgressiveAssetLoader.shared.markAsWarm(rootEntityId: rootEntityId)
                    Logger.log(
                        message: "[OutOfCore] Cold re-stream complete (LOD+OOC): root \(rootEntityId) is warm (\(restoredEntries) LOD entries restored across \(lodDetection.groups.count) group(s))",
                        category: LogCategory.oocStatus.rawValue
                    )
                } else {
                    // Regular OOC: rebuild cpuMeshRegistry, one entry per child stub entity.
                    for (i, obj) in assetData.topLevelObjects.enumerated() {
                        guard i < children.count else { break }
                        let childId = children[i]
                        let baseName = (obj as? MDLMesh)?.parent?.name ?? obj.name
                        let uniqueName = "\(baseName)#\(i)"
                        let estimatedGPUBytes: Int = {
                            guard let mdlMesh = obj as? MDLMesh else { return 0 }
                            let stride = Int((mdlMesh.vertexDescriptor.layouts.firstObject as? MDLVertexBufferLayout)?.stride ?? 48)
                            let vertexBytes = mdlMesh.vertexCount * stride
                            let indexBytes = mdlMesh.vertexCount * 3 * 4
                            return vertexBytes + indexBytes
                        }()
                        let entry = ProgressiveAssetLoader.CPUMeshEntry(
                            object: obj,
                            vertexDescriptor: vertexDescriptor.model,
                            textureLoader: assetData.textureLoader,
                            device: renderInfo.device,
                            url: context.url,
                            filename: filename,
                            withExtension: ext,
                            uniqueAssetName: uniqueName,
                            estimatedGPUBytes: estimatedGPUBytes,
                            residencyPolicy: context.loadingPolicy
                        )
                        ProgressiveAssetLoader.shared.storeCPUMesh(entry, for: childId)
                    }
                    ProgressiveAssetLoader.shared.storeAsset(assetData.asset, for: rootEntityId)
                    ProgressiveAssetLoader.shared.markAsWarm(rootEntityId: rootEntityId)
                    Logger.log(
                        message: "[OutOfCore] Cold re-stream complete: root \(rootEntityId) is warm (\(min(assetData.topLevelObjects.count, children.count)) entries restored)",
                        category: LogCategory.oocStatus.rawValue
                    )
                }
                return true
            }
        }
        return await task.value
    }

    /// Load mesh asynchronously - returns true on success, false on failure
    private func loadMeshAsync(
        entityId: EntityID,
        filename: String,
        withExtension ext: String,
        assetName: String?
    ) async -> Bool {
        // Guard against the cooperative-cancellation race: bail out early if the entity has
        // been freed or its slot reused (version mismatch) so subsequent scene.get() calls
        // do not generate spurious 1016 "entity missing" errors.
        guard scene.exists(entityId) else { return false }

        // Out-of-core fast path: entity has CPU-resident MDLMesh data from stub registration.
        // Upload from RAM — no disk I/O, no MeshResourceManager parse.
        if let cpuEntry = ProgressiveAssetLoader.shared.retrieveCPUMesh(for: entityId) {
            return await uploadFromCPUEntry(entityId: entityId, cpuEntry: cpuEntry)
        }

        // Out-of-core cold re-stream path: CPU data was released via releaseWarmAsset() but
        // the entity has a rehydration context (URL + policy). Re-parse from disk, restore
        // all child CPU entries, then upload this entity from the freshly-parsed data.
        if let rootId = scene.get(component: DerivedAssetNodeComponent.self, for: entityId)?.assetRootEntityId,
           ProgressiveAssetLoader.shared.isColdRoot(rootId),
           let context = ProgressiveAssetLoader.shared.rehydrationContext(for: rootId)
        {
            let rehydrated = await rehydrateColdAsset(rootEntityId: rootId, context: context)
            if rehydrated,
               let cpuEntry = ProgressiveAssetLoader.shared.retrieveCPUMesh(for: entityId)
            {
                return await uploadFromCPUEntry(entityId: entityId, cpuEntry: cpuEntry)
            }
            Logger.logError(
                message: "[OutOfCore] Cold re-stream failed for entity \(entityId)",
                category: LogCategory.oocStatus.rawValue
            )
            return false
        }

        // Build URL
        guard let url = LoadingSystem.shared.resourceURL(
            forResource: filename,
            withExtension: ext,
            subResource: nil
        ) else {
            Logger.logError(message: "Could not find resource: \(filename).\(ext)")
            return false
        }

        // Determine mesh name (use assetName if provided, otherwise filename)
        let meshName = assetName ?? filename

        // Load from cache or file
        guard let meshes = await MeshResourceManager.shared.loadMesh(url: url, meshName: meshName) else {
            Logger.logError(message: "Failed to load mesh: \(meshName) from \(filename).\(ext)")
            return false
        }

        // Retain the mesh for this entity
        MeshResourceManager.shared.retain(url: url, meshName: meshName, for: entityId)

        withWorldMutationGate {
            // Guard against the cooperative-cancellation race: entity may have been
            // destroyed by unloadTile while the disk/cache load was in flight.
            guard scene.exists(entityId) else { return }
            if let render = scene.get(component: RenderComponent.self, for: entityId) {
                // Create copies of meshes with fresh uniform buffers for this entity
                // Without this, multiple entities sharing cached meshes would overwrite
                // each other's uniform data during rendering
                var entityMeshes = meshes.map { $0.copyWithNewUniformBuffers() }

                // Ensure skin is set up (required for shader validation)
                // Meshes without skeletons need a default Skin()
                let skin = Skin()
                for index in entityMeshes.indices {
                    if entityMeshes[index].skin == nil {
                        entityMeshes[index].skin = skin
                    }
                }

                render.mesh = entityMeshes
                render.assetURL = url
                render.assetName = meshName
            } else {
                // Create render component if needed
                // Note: registerRenderComponent should also handle buffer creation
                let entityMeshes = meshes.map { $0.copyWithNewUniformBuffers() }
                registerRenderComponent(entityId: entityId, meshes: entityMeshes, url: url, assetName: meshName)
            }

            // Register with memory budget.
            // Mesh objects from MeshResourceManager carry actual MTLTexture allocation sizes,
            // so use the real texture footprint here rather than a placeholder zero.
            let meshSize = calculateMeshArrayMemory(meshes)
            let textureSize = meshes.reduce(0) { $0 + $1.textureMemorySize }
            MemoryBudgetManager.shared.registerMesh(
                entityId: entityId,
                meshSizeBytes: meshSize,
                textureSizeBytes: textureSize
            )
        }

        return true
    }

    /// Estimate GPU texture memory for an MDLObject by counting texture slots in its materials.
    ///
    /// Uses a conservative 1024×1024 RGBA (4 bytes/pixel) placeholder per slot. The actual GPU
    /// cost depends on compression (ASTC/BCn) and mip-map count, so this is an upper bound
    /// rather than an exact value. Even a coarse estimate is far better than zero — it closes
    /// the budget tracking gap between upload time and first texture stream.
    ///
    /// Call this after `ensureTexturesLoaded()` so that MDLMaterialProperty slots carry
    /// `.texture` values for USDZ-embedded images.
    private func estimateTextureSizeBytes(from object: MDLObject) -> Int {
        let textureSemantics: [MDLMaterialSemantic] = [
            .baseColor, .emission, .tangentSpaceNormal, .roughness, .metallic,
            .ambientOcclusion, .opacity, .bump, .specular, .displacement,
        ]
        var textureSlots = 0

        func scan(_ obj: MDLObject) {
            if let mesh = obj as? MDLMesh,
               let submeshes = mesh.submeshes?.compactMap({ $0 as? MDLSubmesh })
            {
                for submesh in submeshes {
                    guard let material = submesh.material else { continue }
                    for semantic in textureSemantics {
                        if let prop = material.property(with: semantic),
                           prop.type == .texture || prop.type == .URL
                        {
                            textureSlots += 1
                        }
                    }
                }
            }
            let childObjects = obj.children.objects
            for i in 0 ..< childObjects.count {
                scan(childObjects[i])
            }
        }
        scan(object)

        // 1024 × 1024 × 4 bytes (RGBA uncompressed) per slot — conservative upper bound.
        return textureSlots * (1024 * 1024 * 4)
    }

    private func unloadMesh(entityId: EntityID) {
        guard let streaming = scene.get(component: StreamingComponent.self, for: entityId),
              streaming.state == .loaded
        else { return }

        // Clear first-detection timestamp so a future re-approach records a fresh baseline.
        firstRangeTimestamps.removeValue(forKey: entityId)

        let unloadStart = CFAbsoluteTimeGetCurrent()
        withWorldMutationGate {
            streaming.state = .unloading
            BatchingSystem.shared.notifyEntityRetiring(entityId: entityId)

            // Cancel any pending load
            streaming.loadTask?.cancel()
            streaming.loadTask = nil

            // Capture asset info before clearing for event
            var assetURL = URL(fileURLWithPath: "")
            var meshName = ""
            if let render = scene.get(component: RenderComponent.self, for: entityId) {
                assetURL = render.assetURL
                meshName = render.assetName
            }

            // Release mesh reference (don't clean up - cache may still need it)
            MeshResourceManager.shared.release(entityId: entityId)

            // Clear render component mesh (but don't call cleanUp - cache owns it)
            if let render = scene.get(component: RenderComponent.self, for: entityId) {
                render.mesh = [] // Just clear reference, don't clean up GPU resources
            }

            // If entity has LOD, clear all LOD level meshes
            if let lodComponent = scene.get(component: LODComponent.self, for: entityId) {
                for i in lodComponent.lodLevels.indices {
                    lodComponent.lodLevels[i].mesh = []
                    lodComponent.lodLevels[i].residencyState = .notResident
                }
            }

            // Unregister from memory budget
            MemoryBudgetManager.shared.unregisterMesh(entityId: entityId)

            // Remove from loaded tracking set
            unmarkLoadedStreamingEntity(entityId)

            streaming.state = .unloaded

            // Emit residency event (mesh evicted)
            let event = AssetResidencyChangedEvent(
                entityId: entityId,
                assetURL: assetURL,
                meshName: meshName,
                isResident: false
            )
            SystemEventBus.shared.queueResidencyChange(event)
            SystemIntegrationMonitor.shared.recordStreamingUnload()
        }
        let unloadMs = (CFAbsoluteTimeGetCurrent() - unloadStart) * 1000.0
        updateLastUnloadDuration(unloadMs)
    }

    /// Evict loaded entities under memory pressure, prioritising by value score.
    ///
    /// Score = `evictionDistanceWeight × distanceFactor + evictionSizeWeight × sizeFactor`.
    /// Entities with high distance and large GPU footprint are evicted first, protecting
    /// nearby small meshes that are most valuable for scene coverage near the camera.
    /// LRU frame is retained as a tiebreaker for equal-score candidates.
    ///
    /// Visibility guard is distance-aware: entities within `visibleEvictionProtectionRadius`
    /// are never evicted while visible (prevents foreground popping). Entities beyond that
    /// radius may be evicted even while visible — a distant pop is cheaper than a nearby
    /// mesh failing to load under memory pressure.
    private func evictLRU(cameraPosition: simd_float3, maxEvictions: Int = Int.max) -> Int {
        // First, evict any unused cached files
        MeshResourceManager.shared.evictUnused()

        var candidates: [(entityId: EntityID, score: Float, lastFrame: Int, distance: Float)] = []
        var staleEntityIds: [EntityID] = []

        let trackedLoadedSnapshot = loadedStreamingEntitiesSnapshot()
        // Use geometryBudget as the denominator: evictLRU is purely a geometry eviction
        // pass, so sizing the score against the geometry pool (not the combined budget)
        // gives an accurate picture of how much of that pool each candidate consumes.
        let budget = Float(max(1, MemoryBudgetManager.shared.geometryBudget))

        for entityId in trackedLoadedSnapshot {
            guard scene.exists(entityId) else {
                staleEntityIds.append(entityId)
                continue
            }
            guard let streaming = scene.get(component: StreamingComponent.self, for: entityId),
                  streaming.state == .loaded
            else { continue }

            let distance = calculateDistance(entityId: entityId, cameraPosition: cameraPosition)
            let distanceFactor = min(1.0, distance / maxQueryRadius)

            let meshBytes = Float(MemoryBudgetManager.shared.getMemorySize(for: entityId) ?? 0)
            let sizeFactor = min(1.0, meshBytes / budget)

            let score = evictionDistanceWeight * distanceFactor + evictionSizeWeight * sizeFactor
            candidates.append((entityId, score, streaming.lastVisibleFrame, distance))
        }

        for staleId in staleEntityIds {
            unmarkLoadedStreamingEntity(staleId)
        }

        // Sort: highest eviction score first; LRU frame as tiebreaker.
        candidates.sort {
            if abs($0.score - $1.score) > 0.001 { return $0.score > $1.score }
            return $0.lastFrame < $1.lastFrame
        }

        let visibleSet = Set(visibleEntityIds)
        var evictedCount = 0
        for candidate in candidates {
            // Stop when geometry-only pressure clears — texture memory is managed
            // independently by TextureStreamingSystem and should not force extra
            // geometry evictions.
            guard MemoryBudgetManager.shared.shouldEvictGeometry() else { break }

            // Per-call cap: spreads large eviction bursts across multiple ticks so a single
            // pressure event cannot monopolise the frame. Remaining entities are evicted on
            // subsequent ticks (each still passes the shouldEvictGeometry() check above).
            if evictedCount >= maxEvictions { break }

            // Distance-aware visibility guard.
            // Close visible meshes (< visibleEvictionProtectionRadius) are protected — evicting
            // them would cause an obvious foreground pop. Far visible meshes are evictable under
            // memory pressure; a distant pop is less harmful than a nearby mesh failing to load.
            if visibleSet.contains(candidate.entityId), candidate.distance < visibleEvictionProtectionRadius {
                continue
            }

            unloadMesh(entityId: candidate.entityId)
            evictedCount += 1
        }
        return evictedCount
    }

    private func recordLoadCompletion(success: Bool, asyncLoadMs: Double, applyMs: Double, wasLODReload: Bool) {
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

    private func updateLastUnloadDuration(_ unloadMs: Double) {
        withStateLock {
            diagnostics.lastUnloadMeshMs = unloadMs
        }
    }

    private func calculateDistance(entityId: EntityID, cameraPosition: simd_float3) -> Float {
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
            }

            SystemEventBus.shared.clearPendingEvents()
            withStateLock {
                activeLoads.removeAll()
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
            lastCameraPosition = nil
            cameraVelocity = .zero
            firstRangeTimestamps.removeAll()
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

    public init() {}
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

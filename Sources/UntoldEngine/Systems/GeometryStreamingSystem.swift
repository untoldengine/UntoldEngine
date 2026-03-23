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

    private let stateLock = NSLock()
    private var timeSinceLastUpdate: Float = 0
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

    private init() {}

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
        withStateLock { activeNearBandLoads.insert(entityId) }
    }

    private func releaseNearBandLoad(entityId: EntityID) {
        withStateLock { _ = activeNearBandLoads.remove(entityId) }
    }

    private func activeNearBandLoadCount() -> Int {
        withStateLock { activeNearBandLoads.count }
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
        let effectiveInterval = lastPendingLoadBacklog > 0 ? burstTickInterval : updateInterval
        timeSinceLastUpdate += deltaTime
        guard timeSinceLastUpdate >= effectiveInterval else {
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
        let nearbyEntities = OctreeSystem.shared.queryNear(point: effectiveCameraPosition, radius: maxQueryRadius)

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

        // Also check loaded entities that might now be out of range
        // (they may not be in the octree query if they're far away)
        let nearbySet = Set(nearbyEntities) // O(1) lookup
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
            Logger.log(message: "[OOC-Timing] Queue: near=\(nearBandCandidates.count) rest=\(restBandCandidates.count) activeNear=\(activeNearBandLoadCount()) activeTotal=\(activeLoadCountSnapshot()) slots=\(availableSlots) backlog=\(lastPendingLoadBacklog)")
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
                       !ProgressiveAssetLoader.shared.hasCPULODData(for: entityId) {
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
                       !ProgressiveAssetLoader.shared.hasCPULODData(for: entityId) {
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
            Logger.log(message: "[OOC-Timing] Entity \(entityId): tick-to-dispatch=\(String(format: "%.1f", tickToDispatchMs))ms band=\(isNearBand ? "near" : "rest")")
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
                            SystemEventBus.shared.queueResidencyChange(event)
                        }
                    }
                    markLoadedStreamingEntity(entityId)
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

    /// Reload all LOD levels for an LOD entity and set display to correct LOD for current distance
    private func reloadLODEntity(entityId: EntityID) async -> Bool {
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
                let cameraPos = cameraComponent.localPosition
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
        Logger.log(message: "[OOC-Timing] Entity \(entityId) '\(cpuEntry.uniqueAssetName)': lockWait=\(String(format: "%.1f", lockWaitMs))ms textures=\(String(format: "%.1f", textureMs))ms cpuToMetal=\(String(format: "%.1f", copyMs))ms")

        guard !meshes.isEmpty else {
            Logger.logError(message: "[OutOfCore] CPU→Metal upload failed for entity \(entityId) ('\(cpuEntry.uniqueAssetName)')")
            return false
        }

        // Stamp the unique asset name so the RenderComponent matches the StreamingComponent.
        let namedMeshes = meshes.map { m -> Mesh in
            var copy = m
            copy.assetName = cpuEntry.uniqueAssetName
            return copy
        }

        withWorldMutationGate {
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
        let meshSize = calculateMeshArrayMemory(namedMeshes)
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
        // Determine root entity for texture lock serialization.
        let rootEntityId = scene.get(component: DerivedAssetNodeComponent.self, for: entityId)?
            .assetRootEntityId ?? entityId

        // If the root asset has gone cold, re-parse from disk to restore CPU entries.
        if ProgressiveAssetLoader.shared.isColdRoot(rootEntityId) {
            guard let context = ProgressiveAssetLoader.shared.rehydrationContext(for: rootEntityId) else {
                Logger.logError(message: "[OutOfCore] LOD+OOC entity \(entityId): root \(rootEntityId) is cold with no rehydration context")
                return false
            }
            let ok = await rehydrateColdAsset(rootEntityId: rootEntityId, context: context)
            guard ok else { return false }
        }

        guard let allLODEntries = ProgressiveAssetLoader.shared.retrieveAllCPULODMeshes(for: entityId),
              !allLODEntries.isEmpty
        else {
            Logger.logError(message: "[OutOfCore] LOD+OOC entity \(entityId): no CPU LOD entries found")
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
                Logger.logWarning(message: "[OutOfCore] LOD+OOC entity \(entityId): CPU→Metal failed for LOD\(lodIndex), skipping level")
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
            Logger.logError(message: "[OutOfCore] LOD+OOC entity \(entityId): all LOD level uploads failed")
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
                let cameraPos = cameraComponent.localPosition
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
        let totalMeshSize = uploadedMeshes.values.reduce(0) { $0 + calculateMeshArrayMemory($1) }
        MemoryBudgetManager.shared.registerMesh(entityId: entityId, meshSizeBytes: totalMeshSize, textureSizeBytes: 0)

        Logger.log(message: "[OutOfCore] LOD+OOC entity \(entityId): uploaded \(uploadedMeshes.count) LOD level(s) from CPU")
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
                Logger.log(message: "[OutOfCore] Cold re-stream: re-parsing '\(context.url.lastPathComponent)' for root \(rootEntityId)")
                guard let assetData = await Mesh.parseAssetAsync(
                    url: context.url,
                    vertexDescriptor: vertexDescriptor.model,
                    device: renderInfo.device
                ) else {
                    Logger.logError(message: "[OutOfCore] Cold re-stream: parseAssetAsync failed for root \(rootEntityId)")
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
                    Logger.log(message: "[OutOfCore] Cold re-stream complete (LOD+OOC): root \(rootEntityId) is warm (\(restoredEntries) LOD entries restored across \(lodDetection.groups.count) group(s))")
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
                    Logger.log(message: "[OutOfCore] Cold re-stream complete: root \(rootEntityId) is warm (\(min(assetData.topLevelObjects.count, children.count)) entries restored)")
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
            Logger.logError(message: "[OutOfCore] Cold re-stream failed for entity \(entityId)")
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

            // Register with memory budget
            let meshSize = calculateMeshArrayMemory(meshes)
            MemoryBudgetManager.shared.registerMesh(
                entityId: entityId,
                meshSizeBytes: meshSize,
                textureSizeBytes: 0
            )
        }

        return true
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
    private func evictLRU(cameraPosition: simd_float3) -> Int {
        // First, evict any unused cached files
        MeshResourceManager.shared.evictUnused()

        var candidates: [(entityId: EntityID, score: Float, lastFrame: Int, distance: Float)] = []
        var staleEntityIds: [EntityID] = []

        let trackedLoadedSnapshot = loadedStreamingEntitiesSnapshot()
        let budget = Float(max(1, MemoryBudgetManager.shared.meshBudget))

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

        let center = (local.boundingBox.min + local.boundingBox.max) * 0.5
        let worldCenter = transform.space * simd_float4(center, 1.0)
        return simd_distance(cameraPosition, simd_float3(worldCenter.x, worldCenter.y, worldCenter.z))
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

            SystemEventBus.shared.clearPendingEvents()
            withStateLock {
                activeLoads.removeAll()
                loadedStreamingEntities.removeAll()
            }
            timeSinceLastUpdate = 0
            currentFrame = 0
            lastLoadCandidateCount = 0
            lastPendingLoadBacklog = 0
            diagnostics = .init()
            cumulativeAsyncLoadMs = 0
            completedAsyncLoads = 0
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

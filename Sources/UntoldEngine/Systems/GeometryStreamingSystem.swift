//
//  GeometryStreamingSystem.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import simd

public class GeometryStreamingSystem {
    public static let shared = GeometryStreamingSystem()

    /// Enable/disable the streaming system
    public var enabled: Bool = true

    /// Maximum concurrent mesh loads
    public var maxConcurrentLoads: Int = 3

    /// How often to check for load/unload (seconds)
    public var updateInterval: Float = 0.1

    /// Maximum radius to query from octree (should cover largest unload radius)
    public var maxQueryRadius: Float = 500.0

    private var timeSinceLastUpdate: Float = 0
    private var activeLoads: Set<EntityID> = []
    private var loadedStreamingEntities: Set<EntityID> = [] // Track loaded entities for efficient unload checks
    private var currentFrame: Int = 0

    private init() {}

    /// Called every frame from the engine's update loop
    public func update(cameraPosition: simd_float3, deltaTime: Float) {
        guard enabled else { return }

        currentFrame += 1
        MeshResourceManager.shared.currentFrame = currentFrame // Keep cache LRU updated

        // Throttle updates
        timeSinceLastUpdate += deltaTime
        guard timeSinceLastUpdate >= updateInterval else { return }
        timeSinceLastUpdate = 0

        // Use Octree for efficient spatial query - only check nearby entities for loading
        // Query with the max unload radius to catch all potentially relevant entities
        let nearbyEntities = OctreeSystem.shared.queryNear(point: cameraPosition, radius: maxQueryRadius)

        var loadCandidates: [(EntityID, Float, Int)] = [] // (entity, distance, priority)
        var unloadCandidates: [EntityID] = []

        // Check nearby entities for loading
        for entityId in nearbyEntities {
            // Check if entity still exists (Octree may contain stale IDs)
            guard scene.exists(entityId) else {
                continue
            }
            
            guard let streaming = scene.get(component: StreamingComponent.self, for: entityId) else {
                continue
            }

            let distance = calculateDistance(entityId: entityId, cameraPosition: cameraPosition)

            switch streaming.state {
            case .unloaded:
                // Small epsilon to handle floating-point boundary cases (e.g., 200.0001 vs 200.0)
                if distance <= streaming.streamingRadius + 1.0 {
                    loadCandidates.append((entityId, distance, streaming.priority))
                }

            case .loaded:
                streaming.lastVisibleFrame = currentFrame
                if distance > streaming.unloadRadius {
                    unloadCandidates.append(entityId)
                }

            case .loading, .unloading:
                break // In progress, skip
            }
        }

        // Also check loaded entities that might now be out of range
        // (they may not be in the octree query if they're far away)
        let nearbySet = Set(nearbyEntities) // O(1) lookup
        var staleEntityIds: [EntityID] = []
        
        for entityId in loadedStreamingEntities {
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

            let distance = calculateDistance(entityId: entityId, cameraPosition: cameraPosition)
            if distance > streaming.unloadRadius {
                unloadCandidates.append(entityId)
            }
        }
        
        // Clean up stale entity IDs
        for staleId in staleEntityIds {
            loadedStreamingEntities.remove(staleId)
        }

        // Process unloads first (free memory)
        for entityId in unloadCandidates {
            unloadMesh(entityId: entityId)
        }

        // Sort load candidates: high priority first, then closest
        loadCandidates.sort { lhs, rhs in
            if lhs.2 != rhs.2 { return lhs.2 > rhs.2 } // priority
            return lhs.1 < rhs.1 // distance
        }

        // Load within concurrent limit
        let availableSlots = maxConcurrentLoads - activeLoads.count
        for (entityId, _, _) in loadCandidates.prefix(availableSlots) {
            loadMesh(entityId: entityId)
        }

        // Memory pressure check
        if MemoryBudgetManager.shared.shouldEvict() {
            evictLRU()
        }
    }

    private func loadMesh(entityId: EntityID) {
        guard let streaming = scene.get(component: StreamingComponent.self, for: entityId),
              streaming.state == .unloaded,
              !activeLoads.contains(entityId)
        else { return }

        streaming.state = .loading
        activeLoads.insert(entityId)

        // Check if entity has LOD component
        let hasLOD = scene.get(component: LODComponent.self, for: entityId) != nil

        let filename = streaming.assetFilename
        let ext = streaming.assetExtension
        let assetName = streaming.assetName

        let task = Task {
            var success: Bool

            if hasLOD {
                // LOD entity: reload all LOD levels and set correct one for current distance
                success = await self.reloadLODEntity(entityId: entityId)
            } else {
                // Regular entity: load single mesh
                success = await self.loadMeshAsync(
                    entityId: entityId,
                    filename: filename,
                    withExtension: ext,
                    assetName: assetName
                )
            }

            // Update state on completion
            await MainActor.run {
                if success {
                    if let s = scene.get(component: StreamingComponent.self, for: entityId) {
                        s.state = .loaded
                        s.lastVisibleFrame = self.currentFrame

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
                    self.loadedStreamingEntities.insert(entityId)
                    SystemIntegrationMonitor.shared.recordStreamingLoad()
                } else {
                    // Load failed - reset to unloaded so it can retry
                    if let s = scene.get(component: StreamingComponent.self, for: entityId) {
                        s.state = .unloaded
                    }
                    Logger.logError(message: "Failed to stream mesh for entity \(entityId)")
                }
                self.activeLoads.remove(entityId)
            }
        }

        streaming.loadTask = task
    }

    /// Reload all LOD levels for an LOD entity and set display to correct LOD for current distance
    private func reloadLODEntity(entityId: EntityID) async -> Bool {
        // Gather LOD level info on main thread
        let lodInfo: [(index: Int, url: URL, assetName: String, maxDistance: Float)] = await MainActor.run {
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
        }

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

        // Update components on main thread
        await MainActor.run {
            guard let lodComponent = scene.get(component: LODComponent.self, for: entityId),
                  let renderComponent = scene.get(component: RenderComponent.self, for: entityId)
            else { return }

            // Update all LOD level meshes
            let skin = Skin()
            for (lodIndex, meshes) in loadedMeshes {
                guard lodIndex < lodComponent.lodLevels.count else { continue }

                var updatedMeshes = meshes
                for i in updatedMeshes.indices {
                    if updatedMeshes[i].skin == nil {
                        updatedMeshes[i].skin = skin
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

    /// Load mesh asynchronously - returns true on success, false on failure
    private func loadMeshAsync(
        entityId: EntityID,
        filename: String,
        withExtension ext: String,
        assetName: String?
    ) async -> Bool {
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

        // Update render component on main thread
        await MainActor.run {
            if let render = scene.get(component: RenderComponent.self, for: entityId) {
                render.mesh = meshes
                render.assetURL = url
                render.assetName = meshName

                // Ensure skin is set up (required for shader validation)
                // Meshes without skeletons need a default Skin()
                let skin = Skin()
                for index in render.mesh.indices {
                    if render.mesh[index].skin == nil {
                        render.mesh[index].skin = skin
                    }
                }
            } else {
                // Create render component if needed
                registerRenderComponent(entityId: entityId, meshes: meshes, url: url, assetName: meshName)
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

        streaming.state = .unloading

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
        loadedStreamingEntities.remove(entityId)

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

    private func evictLRU() {
        // First, evict any unused cached files
        MeshResourceManager.shared.evictUnused()

        // Use tracked loaded entities instead of querying all entities
        var candidates: [(EntityID, Int)] = [] // (entity, lastVisibleFrame)
        var staleEntityIds: [EntityID] = []

        for entityId in loadedStreamingEntities {
            // Check if entity still exists
            guard scene.exists(entityId) else {
                staleEntityIds.append(entityId)
                continue
            }
            
            guard let streaming = scene.get(component: StreamingComponent.self, for: entityId),
                  streaming.state == .loaded
            else { continue }

            candidates.append((entityId, streaming.lastVisibleFrame))
        }
        
        // Clean up stale entity IDs
        for staleId in staleEntityIds {
            loadedStreamingEntities.remove(staleId)
        }

        // Sort by oldest first
        candidates.sort { $0.1 < $1.1 }

        // Evict until memory pressure relieved
        for (entityId, _) in candidates {
            guard MemoryBudgetManager.shared.shouldEvict() else { break }

            // Don't evict currently visible entities
            if visibleEntityIds.contains(entityId) { continue }

            unloadMesh(entityId: entityId)
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

        if success {
            streaming.state = .loaded
            streaming.lastVisibleFrame = currentFrame
            loadedStreamingEntities.insert(entityId)
        } else {
            streaming.state = .unloaded
        }
    }

    /// Force unload an entity's mesh immediately
    public func forceUnload(entityId: EntityID) {
        unloadMesh(entityId: entityId)
    }

    /// Register an entity that already has its mesh loaded (called by enableStreaming)
    public func registerLoadedEntity(_ entityId: EntityID) {
        loadedStreamingEntities.insert(entityId)
    }

    /// Reset internal state (useful for tests and scene changes)
    public func reset() {
        activeLoads.removeAll()
        loadedStreamingEntities.removeAll()
        timeSinceLastUpdate = 0
        currentFrame = 0
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
            activeLoads: activeLoads.count
        )
    }
}

/// Statistics for geometry streaming
public struct GeometryStreamingStats: CustomStringConvertible {
    public var totalStreamingEntities: Int
    public var loadedCount: Int
    public var loadingCount: Int
    public var unloadedCount: Int
    public var activeLoads: Int

    public var description: String {
        "Streaming: \(loadedCount) loaded, \(loadingCount) loading, \(unloadedCount) unloaded (\(activeLoads) active)"
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

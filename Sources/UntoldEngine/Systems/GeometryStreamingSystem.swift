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
            guard let streaming = scene.get(component: StreamingComponent.self, for: entityId) else {
                continue
            }

            let distance = calculateDistance(entityId: entityId, cameraPosition: cameraPosition)

            switch streaming.state {
            case .unloaded:
                if distance <= streaming.streamingRadius {
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
        for entityId in loadedStreamingEntities {
            // Skip if already processed via octree query
            if nearbyEntities.contains(entityId) { continue }

            guard let streaming = scene.get(component: StreamingComponent.self, for: entityId),
                  streaming.state == .loaded
            else { continue }

            let distance = calculateDistance(entityId: entityId, cameraPosition: cameraPosition)
            if distance > streaming.unloadRadius {
                unloadCandidates.append(entityId)
            }
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

        let filename = streaming.assetFilename
        let ext = streaming.assetExtension
        let assetName = streaming.assetName

        let task = Task {
            // Load mesh asynchronously
            await loadMeshAsync(
                entityId: entityId,
                filename: filename,
                withExtension: ext,
                assetName: assetName
            )

            // Update state on completion
            await MainActor.run {
                if let s = scene.get(component: StreamingComponent.self, for: entityId) {
                    s.state = .loaded
                    s.lastVisibleFrame = self.currentFrame
                }
                self.activeLoads.remove(entityId)
                self.loadedStreamingEntities.insert(entityId) // Track loaded entity

                Logger.log(message: "✅ Streamed in mesh for entity \(entityId)")
            }
        }

        streaming.loadTask = task
    }

    private func loadMeshAsync(
        entityId: EntityID,
        filename: String,
        withExtension ext: String,
        assetName: String?
    ) async {
        // Use existing async mesh loading
        await setEntityMeshAsync(
            entityId: entityId,
            filename: filename,
            withExtension: ext,
            assetName: assetName
        )

        // Register with memory budget
        await MainActor.run {
            if let rc = scene.get(component: RenderComponent.self, for: entityId) {
                let meshSize = calculateMeshArrayMemory(rc.mesh)
                let textureSize = calculateMeshArrayTotalMemory(rc.mesh) - meshSize
                MemoryBudgetManager.shared.registerMesh(
                    entityId: entityId,
                    meshSizeBytes: meshSize,
                    textureSizeBytes: textureSize
                )
            }
        }
    }

    private func unloadMesh(entityId: EntityID) {
        guard let streaming = scene.get(component: StreamingComponent.self, for: entityId),
              streaming.state == .loaded
        else { return }

        streaming.state = .unloading

        // Cancel any pending load
        streaming.loadTask?.cancel()
        streaming.loadTask = nil

        // Clean up mesh GPU resources before clearing
        if let render = scene.get(component: RenderComponent.self, for: entityId) {
            // Call cleanUp on each mesh to release GPU buffers
            for i in 0 ..< render.mesh.count {
                render.mesh[i].cleanUp()
            }
            render.mesh = []
        }

        // Unregister from memory budget
        MemoryBudgetManager.shared.unregisterMesh(entityId: entityId)

        // Clear from entity mesh map
        entityMeshMap.removeValue(forKey: entityId)

        // Remove from loaded tracking set
        loadedStreamingEntities.remove(entityId)

        streaming.state = .unloaded

        Logger.log(message: "🗑️ Streamed out mesh for entity \(entityId)")
    }

    private func evictLRU() {
        // Use tracked loaded entities instead of querying all entities
        var candidates: [(EntityID, Int)] = [] // (entity, lastVisibleFrame)

        for entityId in loadedStreamingEntities {
            guard let streaming = scene.get(component: StreamingComponent.self, for: entityId),
                  streaming.state == .loaded
            else { continue }

            candidates.append((entityId, streaming.lastVisibleFrame))
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

        await loadMeshAsync(
            entityId: entityId,
            filename: streaming.assetFilename,
            withExtension: streaming.assetExtension,
            assetName: streaming.assetName
        )
        streaming.state = .loaded
        loadedStreamingEntities.insert(entityId)
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
public struct GeometryStreamingStats {
    public var totalStreamingEntities: Int
    public var loadedCount: Int
    public var loadingCount: Int
    public var unloadedCount: Int
    public var activeLoads: Int
}

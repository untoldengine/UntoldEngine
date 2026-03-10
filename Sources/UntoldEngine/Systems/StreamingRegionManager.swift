//
//  StreamingRegionManager.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

public class StreamingRegionManager {
    public static let shared = StreamingRegionManager()

    // Configuration
    public var enabled: Bool = true
    public var streamingRadius: Float = 100.0 // Load within this distance
    public var unloadRadius: Float = 150.0 // Unload beyond this distance
    public var maxConcurrentLoads: Int = 3 // Load max 3 at once
    public var checkInterval: Float = 0.5 // Check every 0.5 seconds

    // Internal state
    private var regions: [UUID: StreamingRegion] = [:]
    private let regionLock = NSLock()
    private var activeLoadTasks: [UUID: Task<Void, Never>] = [:]
    private var timeSinceLastCheck: Float = 0

    private init() {}
}

// MARK: - Region Management

public extension StreamingRegionManager {
    /// Register a new streaming region
    func registerRegion(_ region: StreamingRegion) {
        regionLock.lock()
        defer { regionLock.unlock() }
        regions[region.id] = region
        Logger.log(message: "Registered streaming region \(region.id)")
    }

    /// Remove a region
    func unregisterRegion(id: UUID) {
        regionLock.lock()
        defer { regionLock.unlock() }
        regions.removeValue(forKey: id)
    }

    /// Get a specific region
    func getRegion(id: UUID) -> StreamingRegion? {
        regionLock.lock()
        defer { regionLock.unlock() }
        return regions[id]
    }

    /// Get all registered regions
    func getAllRegions() -> [StreamingRegion] {
        regionLock.lock()
        defer { regionLock.unlock() }
        return Array(regions.values)
    }

    /// Check if a region is loaded
    func isRegionLoaded(id: UUID) -> Bool {
        regionLock.lock()
        defer { regionLock.unlock() }
        return regions[id]?.state == .loaded
    }
}

public extension StreamingRegionManager {
    /// Called every frame to check for load/unload
    func update(cameraPosition: simd_float3, deltaTime: Float) {
        guard enabled else { return }

        // Only check periodically, not every frame
        timeSinceLastCheck += deltaTime
        if timeSinceLastCheck < checkInterval { return }
        timeSinceLastCheck = 0

        // Find what to load and unload
        let toLoad = findRegionsToLoad(cameraPosition)
        let toUnload = findRegionsToUnload(cameraPosition)

        // Unload first to free memory
        for regionId in toUnload {
            Task { await unloadRegion(id: regionId) }
        }

        // Load new regions (respect concurrent limit)
        let availableSlots = maxConcurrentLoads - activeLoadTasks.count
        for regionId in toLoad.prefix(availableSlots) {
            let task = Task { await loadRegion(id: regionId) }
            activeLoadTasks[regionId] = task
        }
    }
}

// MARK: - Region Selection

extension StreamingRegionManager {
    /// Find regions that should be loaded
    private func findRegionsToLoad(_ cameraPos: simd_float3) -> [UUID] {
        var candidates: [(id: UUID, distance: Float, priority: Int)] = []

        regionLock.lock()
        for (id, region) in regions where region.state == .unloaded {
            let distance = region.bounds.distanceToPoint(cameraPos)
            if distance <= streamingRadius {
                candidates.append((id, distance, region.priority))
            }
        }
        regionLock.unlock()

        // Sort: high priority first, then close distance
        candidates.sort { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.distance < rhs.distance
        }

        return candidates.map(\.id)
    }

    /// Find regions that should be unloaded
    private func findRegionsToUnload(_ cameraPos: simd_float3) -> [UUID] {
        var toUnload: [UUID] = []

        regionLock.lock()
        for (id, region) in regions where region.state == .loaded {
            let distance = region.bounds.distanceToPoint(cameraPos)
            if distance > unloadRadius {
                toUnload.append(id)
            }
        }
        regionLock.unlock()

        return toUnload
    }
}

// MARK: - Loading

extension StreamingRegionManager {
    /// Load a region asynchronously
    private func loadRegion(id: UUID) async {
        // Mark as loading
        regionLock.lock()
        guard var region = regions[id], region.state == .unloaded else {
            regionLock.unlock()
            return
        }
        region.state = .loading
        regions[id] = region
        regionLock.unlock()

        // Check memory
        if !MemoryBudgetManager.shared.canAccept(sizeBytes: region.estimatedMemorySize) {
            Logger.logWarning(message: "Cannot load region \(id): insufficient memory")

            // Try to free memory
            if MemoryBudgetManager.shared.shouldEvict() {
                let candidates = MemoryBudgetManager.shared.getEvictionCandidatesToTarget()
                for entityId in candidates {
                    MemoryBudgetManager.shared.unregisterMesh(entityId: entityId)
                    destroyEntity(entityId: entityId)
                }
            }

            // Mark as unloaded and return
            regionLock.lock()
            region.state = .unloaded
            regions[id] = region
            regionLock.unlock()
            return
        }

        // Load all assets in this region
        var loadedEntities: [EntityID] = []
        for asset in region.assets {
            let entity = createEntity()
            await setEntityMeshAsync(entityId: entity, filename: asset.filename, withExtension: asset.fileExtension)
            loadedEntities.append(entity)

            // Register memory usage for root entity
            registerEntityMemory(entityId: entity)

            // Register memory usage for all child entities (multi-mesh assets)
            let children = getEntityChildren(parentId: entity)
            for childId in children {
                registerEntityMemory(entityId: childId)
            }
        }

        // Mark as loaded
        regionLock.lock()
        region.state = .loaded
        region.loadedEntities = loadedEntities
        regions[id] = region
        activeLoadTasks.removeValue(forKey: id)
        regionLock.unlock()

        // Emit residency events for each loaded entity (for LOD/Batching integration)
        for (index, entity) in loadedEntities.enumerated() {
            let asset = region.assets[index]
            let assetURL = URL(fileURLWithPath: asset.filename + "." + asset.fileExtension)

            SystemEventBus.shared.queueResidencyChange(
                AssetResidencyChangedEvent(
                    entityId: entity,
                    assetURL: assetURL,
                    meshName: asset.filename,
                    isResident: true
                )
            )

            // Also emit for children (multi-mesh assets)
            let children = getEntityChildren(parentId: entity)
            for childId in children {
                SystemEventBus.shared.queueResidencyChange(
                    AssetResidencyChangedEvent(
                        entityId: childId,
                        assetURL: assetURL,
                        meshName: asset.filename,
                        isResident: true
                    )
                )
            }
        }

        // Record stats
        SystemIntegrationMonitor.shared.recordRegionLoad()

        Logger.log(message: "✅ Loaded region \(id) with \(loadedEntities.count) entities")
    }

    /// Force load a region (public API)
    public func forceLoadRegion(id: UUID) async -> Bool {
        await loadRegion(id: id)
        return isRegionLoaded(id: id)
    }

    /// Register an entity's mesh memory with the budget manager
    private func registerEntityMemory(entityId: EntityID) {
        guard let rc = scene.get(component: RenderComponent.self, for: entityId),
              !rc.mesh.isEmpty
        else {
            return
        }

        let meshSize = calculateMeshArrayMemory(rc.mesh)
        let textureSize = calculateMeshArrayTotalMemory(rc.mesh) - meshSize
        MemoryBudgetManager.shared.registerMesh(
            entityId: entityId,
            meshSizeBytes: meshSize,
            textureSizeBytes: textureSize
        )
    }
}

// MARK: - Unloading

extension StreamingRegionManager {
    /// Unload a region asynchronously
    private func unloadRegion(id: UUID) async {
        // Mark as unloading
        regionLock.lock()
        guard var region = regions[id], region.state == .loaded else {
            regionLock.unlock()
            return
        }
        region.state = .unloading
        let assets = region.assets
        regions[id] = region
        regionLock.unlock()

        // Emit residency events BEFORE destroying (so LOD/Batching can update)
        for (index, entity) in region.loadedEntities.enumerated() {
            let asset = index < assets.count ? assets[index] : AssetReference(filename: "unknown", withExtension: "usdz")
            let assetURL = URL(fileURLWithPath: asset.filename + "." + asset.fileExtension)

            // Emit for children first (multi-mesh assets)
            let children = getEntityChildren(parentId: entity)
            for childId in children {
                SystemEventBus.shared.queueResidencyChange(
                    AssetResidencyChangedEvent(
                        entityId: childId,
                        assetURL: assetURL,
                        meshName: asset.filename,
                        isResident: false
                    )
                )
            }

            // Emit for root entity
            SystemEventBus.shared.queueResidencyChange(
                AssetResidencyChangedEvent(
                    entityId: entity,
                    assetURL: assetURL,
                    meshName: asset.filename,
                    isResident: false
                )
            )
        }

        // Unregister memory for all entities (including children) before destroying
        for entity in region.loadedEntities {
            // Unregister children first (multi-mesh assets)
            let children = getEntityChildren(parentId: entity)
            for childId in children {
                MemoryBudgetManager.shared.unregisterMesh(entityId: childId)
            }

            // Unregister root entity
            MemoryBudgetManager.shared.unregisterMesh(entityId: entity)

            // Destroy entity (this also destroys children)
            destroyEntity(entityId: entity)
        }

        // Mark as unloaded
        regionLock.lock()
        region.state = .unloaded
        region.loadedEntities = []
        regions[id] = region
        regionLock.unlock()

        // Record stats
        SystemIntegrationMonitor.shared.recordRegionUnload()

        Logger.log(message: "🗑️  Unloaded region \(id)")
    }

    /// Force unload a region (public API)
    public func forceUnloadRegion(id: UUID) async -> Bool {
        await unloadRegion(id: id)
        return !isRegionLoaded(id: id)
    }
}

// MARK: - Stats

public struct StreamingStats {
    // Region counts
    public var totalRegions: Int
    public var loadedRegions: Int
    public var loadingRegions: Int
    public var activeLoads: Int

    // Entity counts (including children)
    public var totalRootEntities: Int
    public var totalEntitiesWithChildren: Int

    // Region-specific memory (only streaming region entities)
    public var regionMemory: Int // Actual memory used by streaming region entities
    public var estimatedMemory: Int // User-specified estimate from region.estimatedMemorySize

    /// Total engine memory (all entities, not just streaming)
    public var totalEngineMemory: Int // From MemoryBudgetManager (entire engine)
}

public extension StreamingRegionManager {
    func getStats() -> StreamingStats {
        regionLock.lock()
        defer { regionLock.unlock() }

        var loadedCount = 0
        var loadingCount = 0
        var estimatedMemory = 0
        var rootEntityCount = 0
        var totalEntityCount = 0
        var regionMemory = 0

        for region in regions.values {
            switch region.state {
            case .loaded:
                loadedCount += 1
                estimatedMemory += region.estimatedMemorySize

                // Count root entities and calculate region memory
                rootEntityCount += region.loadedEntities.count

                // Count all entities including children and sum their memory
                for entity in region.loadedEntities {
                    totalEntityCount += 1

                    // Add root entity memory
                    if let size = MemoryBudgetManager.shared.getMemorySize(for: entity) {
                        regionMemory += size
                    }

                    // Add children memory
                    let children = getEntityChildren(parentId: entity)
                    totalEntityCount += children.count
                    for childId in children {
                        if let size = MemoryBudgetManager.shared.getMemorySize(for: childId) {
                            regionMemory += size
                        }
                    }
                }

            case .loading:
                loadingCount += 1

            default:
                break
            }
        }

        // Get total engine memory from MemoryBudgetManager
        let memStats = MemoryBudgetManager.shared.getStats()

        return StreamingStats(
            totalRegions: regions.count,
            loadedRegions: loadedCount,
            loadingRegions: loadingCount,
            activeLoads: activeLoadTasks.count,
            totalRootEntities: rootEntityCount,
            totalEntitiesWithChildren: totalEntityCount,
            regionMemory: regionMemory,
            estimatedMemory: estimatedMemory,
            totalEngineMemory: memStats.meshMemoryUsed + memStats.textureMemoryUsed
        )
    }

    func getLoadedRegions() -> [StreamingRegion] {
        regionLock.lock()
        defer { regionLock.unlock() }
        return regions.values.filter { $0.state == .loaded }
    }
}

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

public class StreamingRegionManager: @unchecked Sendable {
    public static let shared = StreamingRegionManager()

    // Configuration
    public var enabled: Bool = true
    public var streamingRadius: Float = 100.0 // Load within this distance
    public var unloadRadius: Float = 150.0 // Unload beyond this distance
    public var maxConcurrentLoads: Int = 3 // Load max 3 at once
    public var checkInterval: Float = 0.5 // Check every 0.5 seconds

    // Internal state
    private var regions: [UUID: StreamingRegion] = [:]
    private var activeLoadTasks: [UUID: Task<Void, Never>] = [:]
    private var timeSinceLastCheck: Float = 0
    private let stateLock = NSLock()

    private init() {}

    @discardableResult
    @inline(__always)
    private func withStateLock<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }
}

// MARK: - Region Management

public extension StreamingRegionManager {
    /// Register a new streaming region
    func registerRegion(_ region: StreamingRegion) {
        withStateLock {
            regions[region.id] = region
        }
        Logger.log(message: "Registered streaming region \(region.id)")
    }

    /// Remove a region
    func unregisterRegion(id: UUID) {
        withStateLock {
            regions.removeValue(forKey: id)
            activeLoadTasks.removeValue(forKey: id)?.cancel()
        }
    }

    /// Get a specific region
    func getRegion(id: UUID) -> StreamingRegion? {
        withStateLock {
            regions[id]
        }
    }

    /// Get all registered regions
    func getAllRegions() -> [StreamingRegion] {
        withStateLock {
            Array(regions.values)
        }
    }

    /// Check if a region is loaded
    func isRegionLoaded(id: UUID) -> Bool {
        withStateLock {
            regions[id]?.state == .loaded
        }
    }
}

public extension StreamingRegionManager {
    /// Called every frame to check for load/unload
    func update(cameraPosition: simd_float3, deltaTime: Float) {
        let snapshot: (regions: [UUID: StreamingRegion], availableSlots: Int, activeLoadIDs: Set<UUID>)? = withStateLock {
            guard enabled else { return nil }

            // Only check periodically, not every frame
            timeSinceLastCheck += deltaTime
            if timeSinceLastCheck < checkInterval { return nil }
            timeSinceLastCheck = 0

            let activeLoadIDs = Set(activeLoadTasks.keys)
            let availableSlots = max(0, maxConcurrentLoads - activeLoadIDs.count)
            return (regions, availableSlots, activeLoadIDs)
        }

        guard let snapshot else { return }

        // Find what to load and unload
        let toLoad = findRegionsToLoad(cameraPosition, regions: snapshot.regions)
            .filter { !snapshot.activeLoadIDs.contains($0) }
        let toUnload = findRegionsToUnload(cameraPosition, regions: snapshot.regions)

        // Unload first to free memory
        for regionId in toUnload {
            Task {
                await unloadRegion(id: regionId)
            }
        }

        // Load new regions (respect concurrent limit)
        for regionId in toLoad.prefix(snapshot.availableSlots) {
            let task = Task {
                await loadRegion(id: regionId)
            }
            withStateLock {
                activeLoadTasks[regionId] = task
            }
        }
    }
}

// MARK: - Region Selection

extension StreamingRegionManager {
    /// Find regions that should be loaded
    private func findRegionsToLoad(_ cameraPos: simd_float3, regions: [UUID: StreamingRegion]) -> [UUID] {
        var candidates: [(id: UUID, distance: Float, priority: Int)] = []

        for (id, region) in regions where region.state == .unloaded {
            let distance = region.bounds.distanceToPoint(cameraPos)
            if distance <= streamingRadius {
                candidates.append((id, distance, region.priority))
            }
        }

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
    private func findRegionsToUnload(_ cameraPos: simd_float3, regions: [UUID: StreamingRegion]) -> [UUID] {
        var toUnload: [UUID] = []

        for (id, region) in regions where region.state == .loaded {
            let distance = region.bounds.distanceToPoint(cameraPos)
            if distance > unloadRadius {
                toUnload.append(id)
            }
        }

        return toUnload
    }
}

// MARK: - Loading

extension StreamingRegionManager {
    /// Load a region asynchronously
    private func loadRegion(id: UUID) async {
        defer {
            withStateLock {
                activeLoadTasks.removeValue(forKey: id)
            }
        }

        // Mark as loading
        guard var region = withStateLock({ () -> StreamingRegion? in
            guard var region = regions[id], region.state == .unloaded else {
                return nil
            }
            region.state = .loading
            regions[id] = region
            return region
        }) else {
            return
        }

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
            region.state = .unloaded
            withStateLock {
                if regions[id] != nil {
                    regions[id] = region
                }
            }
            return
        }

        // Load all assets in this region
        var loadedEntities: [EntityID] = []
        for asset in region.assets {
            let entity = createEntity()
            setEntityMeshAsync(entityId: entity, filename: asset.filename, withExtension: asset.fileExtension)
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
        region.state = .loaded
        region.loadedEntities = loadedEntities
        withStateLock {
            if regions[id] != nil {
                regions[id] = region
            }
        }

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
        guard var region = withStateLock({ () -> StreamingRegion? in
            guard var region = regions[id], region.state == .loaded else {
                return nil
            }
            region.state = .unloading
            regions[id] = region
            return region
        }) else {
            return
        }
        let assets = region.assets

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
        region.state = .unloaded
        region.loadedEntities = []
        withStateLock {
            if regions[id] != nil {
                regions[id] = region
            }
        }

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
        let snapshot = withStateLock {
            (regions: Array(regions.values), activeLoads: activeLoadTasks.count)
        }

        var loadedCount = 0
        var loadingCount = 0
        var estimatedMemory = 0
        var rootEntityCount = 0
        var totalEntityCount = 0
        var regionMemory = 0

        for region in snapshot.regions {
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
            totalRegions: snapshot.regions.count,
            loadedRegions: loadedCount,
            loadingRegions: loadingCount,
            activeLoads: snapshot.activeLoads,
            totalRootEntities: rootEntityCount,
            totalEntitiesWithChildren: totalEntityCount,
            regionMemory: regionMemory,
            estimatedMemory: estimatedMemory,
            totalEngineMemory: memStats.meshMemoryUsed + memStats.textureMemoryUsed
        )
    }

    func getLoadedRegions() -> [StreamingRegion] {
        withStateLock {
            regions.values.filter { $0.state == .loaded }
        }
    }
}

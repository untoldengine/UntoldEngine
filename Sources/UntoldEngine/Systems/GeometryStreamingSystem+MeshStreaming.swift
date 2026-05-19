//
//  GeometryStreamingSystem+MeshStreaming.swift
//  UntoldEngine
//
//  OOC mesh streaming: loadMesh, unloadMesh, and all async loading helpers
//  (loadMeshAsync, uploadFromRuntimeEntry, reloadLODEntity).
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

extension GeometryStreamingSystem {
    func loadMesh(entityId: EntityID, isNearBand: Bool = false) {
        guard let streaming = scene.get(component: StreamingComponent.self, for: entityId),
              streaming.state == .unloaded
        else { return }
        // StreamingComponent is internal and subordinate to tile ownership (Rule 4).
        // Entities with StreamingComponent that are not under a TileComponent are not
        // valid streaming targets in the unified architecture.
        guard isTileOwned(entityId: entityId) else { return }
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

        let hasLOD = scene.get(component: LODComponent.self, for: entityId) != nil

        let filename = streaming.assetFilename
        let ext = streaming.assetExtension
        let assetName = streaming.assetName

        let task = Task {
            let asyncLoadStart = CFAbsoluteTimeGetCurrent()
            let success = if hasLOD {
                // LOD entity: reload all LOD levels and set correct one for current distance
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

                guard let s = scene.get(component: StreamingComponent.self, for: entityId),
                      s.state == .loading
                else {
                    releaseActiveLoad(entityId: entityId)
                    if isNearBand { releaseNearBandLoad(entityId: entityId) }
                    return
                }

                if success {
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
                    markLoadedStreamingEntity(entityId)
                    // 4.1: Update the parent tile's visual readiness counter.
                    incrementParentTileOCCCount(for: entityId)
                    SystemIntegrationMonitor.shared.recordStreamingLoad()
                } else {
                    // Load failed - reset to unloaded so it can retry
                    s.state = .unloaded
                    handleError(.meshStreamingFailed, entityId)
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
    func reloadLODEntity(entityId: EntityID) async -> Bool {
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
            handleError(.noLODLevels, entityId)
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
            handleError(.lodReloadFailed, entityId)
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

    /// Upload a .untold OCC stub entity from its CPU-resident RuntimeAssetNode (no disk I/O).
    ///
    /// Called by loadMeshAsync when ProgressiveAssetLoader.hasCPURuntimeData returns true.
    /// Calls makeMeshes(from:) off the main thread to create Metal buffers, then registers
    /// the RenderComponent on the main thread. No texture lock is needed — RuntimeAssetNode
    /// vertex/index data is self-contained in value-type Data blobs.
    func uploadFromRuntimeEntry(
        entityId: EntityID,
        runtimeEntry: ProgressiveAssetLoader.CPURuntimeEntry
    ) async -> Bool {
        guard scene.exists(entityId) else { return false }

        let estimatedUploadMB = Float(runtimeEntry.estimatedGPUBytes) / (1024.0 * 1024.0)
        let preBudgetStats = MemoryBudgetManager.shared.getStats()
        let availGeomMB = Float(max(0, preBudgetStats.geometryBudget - preBudgetStats.meshMemoryUsed)) / (1024.0 * 1024.0)
        Logger.log(
            message: "[TileUpload] Entity \(entityId) '\(runtimeEntry.uniqueAssetName)': estimatedGPU=\(String(format: "%.1f", estimatedUploadMB)) MB, geomAvailable=\(String(format: "%.1f", availGeomMB)) MB, geomUsed=\(String(format: "%.0f", preBudgetStats.geometryUtilization * 100))%",
            category: LogCategory.oocStatus.rawValue
        )

        let meshes = makeMeshes(from: runtimeEntry.node)

        guard !meshes.isEmpty else {
            handleError(.meshStreamingFailed, "CPU→Metal upload failed for '\(runtimeEntry.uniqueAssetName)' (estimated \(String(format: "%.1f", estimatedUploadMB)) MB, geomAvailable \(String(format: "%.1f", availGeomMB)) MB)", entityId)
            return false
        }

        let namedMeshes = meshes.map { m -> Mesh in
            var copy = m
            copy.assetName = runtimeEntry.uniqueAssetName
            return copy
        }

        withWorldMutationGate {
            guard scene.exists(entityId) else { return }
            registerRenderComponent(
                entityId: entityId,
                meshes: namedMeshes,
                url: runtimeEntry.url,
                assetName: runtimeEntry.uniqueAssetName
            )
        }

        let meshSize = calculateMeshArrayMemory(namedMeshes)
        MemoryBudgetManager.shared.registerMesh(
            entityId: entityId,
            meshSizeBytes: meshSize,
            textureSizeBytes: 0
        )

        return scene.exists(entityId)
    }
    /// Load mesh asynchronously - returns true on success, false on failure
    func loadMeshAsync(
        entityId: EntityID,
        filename: String,
        withExtension ext: String,
        assetName: String?
    ) async -> Bool {
        // Guard against the cooperative-cancellation race: bail out early if the entity has
        // been freed or its slot reused (version mismatch) so subsequent scene.get() calls
        // do not generate spurious 1016 "entity missing" errors.
        guard scene.exists(entityId) else { return false }

        // .untold OCC fast path: entity has CPU-resident RuntimeAssetNode from stub registration.
        // Upload from RAM via makeMeshes(from:) — no disk I/O, no MeshResourceManager parse.
        if let runtimeEntry = ProgressiveAssetLoader.shared.retrieveCPURuntimeEntry(for: entityId) {
            return await uploadFromRuntimeEntry(entityId: entityId, runtimeEntry: runtimeEntry)
        }

        // Build URL
        guard let url = LoadingSystem.shared.resourceURL(
            forResource: filename,
            withExtension: ext,
            subResource: nil
        ) else {
            handleError(.filenameNotFound, "\(filename).\(ext)")
            return false
        }

        // Determine mesh name (use assetName if provided, otherwise filename)
        let meshName = assetName ?? filename

        // Load from cache or file
        guard let meshes = await MeshResourceManager.shared.loadMesh(url: url, meshName: meshName) else {
            handleError(.assetLoadFailed, "\(meshName) from \(filename).\(ext)")
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

    func unloadMesh(entityId: EntityID) {
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

    /// Returns true if `entityId` is owned by a tile — i.e., the entity itself or any ancestor
    /// has a TileComponent.  StreamingComponent is only allowed to operate on tile-owned entities;
    /// this guard enforces Rule 4: StreamingComponent is subordinate to tile ownership.
    private func isTileOwned(entityId: EntityID) -> Bool {
        var current = entityId
        while current != .invalid {
            if scene.get(component: TileComponent.self, for: current) != nil {
                return true
            }
            guard let sg = scene.get(component: ScenegraphComponent.self, for: current) else {
                break
            }
            current = sg.parent
        }
        return false
    }
}

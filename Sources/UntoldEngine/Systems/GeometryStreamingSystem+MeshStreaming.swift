//
//  GeometryStreamingSystem+MeshStreaming.swift
//  UntoldEngine
//
//  OOC mesh streaming: loadMesh, unloadMesh, and all async loading helpers
//  (loadMeshAsync, uploadFromCPUEntry, uploadActiveLODFromCPU, reloadLODEntity,
//  rehydrateColdAsset, estimateTextureSizeBytes).
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import ModelIO
import simd

extension GeometryStreamingSystem {
    func loadMesh(entityId: EntityID, isNearBand: Bool = false) {
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
    func uploadFromCPUEntry(
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
    func uploadActiveLODFromCPU(entityId: EntityID) async -> Bool {
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
    func rehydrateColdAsset(
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
    func estimateTextureSizeBytes(from object: MDLObject) -> Int {
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
}

//
//  GeometryStreamingSystem+TileStreaming.swift
//  UntoldEngine
//
//  Tile lifecycle: HLOD load/unload, per-tile LOD load/unload, loadTile,
//  unloadTile, and the parent-child hierarchy helpers used by all three.
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
    /// Trigger a full tile parse + upload for a manifest tile stub.
    ///
    /// Called by the tile streaming pass in update() when a TileComponent entity
    /// enters its streaming radius.  Sets state to .parsing, spawns a Task that
    /// calls setEntityMeshAsync on a dedicated child entity, then transitions to
    /// .parsed (or .failed with retry backoff on error).
    ///
    // MARK: - HLOD Load / Unload

    func advanceTileRepresentationFades(deltaTime: Float) {
        guard !activeTileRepresentationFades.isEmpty else { return }

        var remaining: [ActiveTileRepresentationFade] = []
        var completed: [ActiveTileRepresentationFade] = []
        remaining.reserveCapacity(activeTileRepresentationFades.count)

        withWorldMutationGate {
            for var fade in activeTileRepresentationFades {
                if fade.waitsForIncomingVisibility {
                    let visibleSet = Set(visibleEntityIds)
                    let incomingVisible = fade.incomingRenderIds.contains { visibleSet.contains($0) }
                    if !incomingVisible {
                        for entityId in fade.allRenderIds where scene.exists(entityId) {
                            scene.get(component: TileRepresentationFadeComponent.self, for: entityId)?.progress = 0
                        }
                        remaining.append(fade)
                        continue
                    }
                    fade.waitsForIncomingVisibility = false
                }

                fade.elapsed += deltaTime
                let progress = simd_clamp(fade.elapsed / max(fade.duration, 0.001), 0.0, 1.0)

                for entityId in fade.allRenderIds where scene.exists(entityId) {
                    scene.get(component: TileRepresentationFadeComponent.self, for: entityId)?.progress = progress
                }

                if progress >= 1.0 {
                    for entityId in fade.allRenderIds where scene.exists(entityId) {
                        scene.remove(component: TileRepresentationFadeComponent.self, from: entityId)
                    }
                    completed.append(fade)
                } else {
                    remaining.append(fade)
                }
            }

            activeTileRepresentationFades = remaining
        }

        for fade in completed {
            if !fade.incomingRenderIds.isEmpty {
                BatchingSystem.shared.notifyTileEntitiesResident(fade.incomingRenderIds)
                TextureStreamingSystem.shared.notifyEntitiesReady(fade.incomingRenderIds)
            }

            switch fade.completion {
            case .unloadHLOD:
                unloadHLOD(entityId: fade.tileEntityId)
            case .unloadLODLevel(let levelIndex):
                unloadLODLevel(entityId: fade.tileEntityId, levelIndex: levelIndex)
            }
        }
    }

    func hasActiveTileRepresentationFade(entityId: EntityID, completion: TileFadeCompletion? = nil) -> Bool {
        activeTileRepresentationFades.contains { fade in
            guard fade.tileEntityId == entityId else { return false }
            guard let completion else { return true }
            return tileFadeCompletion(fade.completion, matches: completion)
        }
    }

    private func tileFadeCompletion(_ lhs: TileFadeCompletion, matches rhs: TileFadeCompletion) -> Bool {
        switch (lhs, rhs) {
        case (.unloadHLOD, .unloadHLOD):
            return true
        case (.unloadLODLevel(let a), .unloadLODLevel(let b)):
            return a == b
        default:
            return false
        }
    }

    @discardableResult
    func beginTileRepresentationFade(
        tileEntityId: EntityID,
        incomingRenderIds: Set<EntityID>,
        outgoingRenderIds: Set<EntityID>,
        completion: TileFadeCompletion
    ) -> Bool {
        guard LODConfig.shared.enableFadeTransitions else { return false }
        guard !incomingRenderIds.isEmpty, !outgoingRenderIds.isEmpty else { return false }
        guard !hasActiveTileRepresentationFade(entityId: tileEntityId, completion: completion) else { return true }

        let duration = max(LODConfig.shared.fadeTransitionTime, 0.001)

        withWorldMutationGate {
            for entityId in incomingRenderIds where scene.exists(entityId) {
                if scene.get(component: TileRepresentationFadeComponent.self, for: entityId) == nil {
                    registerComponent(entityId: entityId, componentType: TileRepresentationFadeComponent.self)
                }
                if let fade = scene.get(component: TileRepresentationFadeComponent.self, for: entityId) {
                    fade.progress = 0
                    fade.mode = 1.0
                }
            }

            for entityId in outgoingRenderIds where scene.exists(entityId) {
                if scene.get(component: TileRepresentationFadeComponent.self, for: entityId) == nil {
                    registerComponent(entityId: entityId, componentType: TileRepresentationFadeComponent.self)
                }
                if let fade = scene.get(component: TileRepresentationFadeComponent.self, for: entityId) {
                    fade.progress = 0
                    fade.mode = 2.0
                }
            }

            activeTileRepresentationFades.append(ActiveTileRepresentationFade(
                tileEntityId: tileEntityId,
                completion: completion,
                elapsed: 0,
                duration: duration,
                waitsForIncomingVisibility: true,
                incomingRenderIds: incomingRenderIds,
                outgoingRenderIds: outgoingRenderIds
            ))
        }

        BatchingSystem.shared.notifyTileEntitiesFading(incomingRenderIds.union(outgoingRenderIds))
        return true
    }

    func fullTileRenderDescendantIds(tileEntityId: EntityID) -> Set<EntityID> {
        collectRenderDescendantIds(tileEntityId).filter {
            scene.get(component: TileLODTagComponent.self, for: $0) == nil
        }
    }

    func lodRenderDescendantIds(_ tileComp: TileComponent, levelIndex: Int) -> Set<EntityID> {
        guard tileComp.lodLevels.indices.contains(levelIndex) else { return [] }
        let entityId = tileComp.lodLevels[levelIndex].entityId
        guard entityId != .invalid, scene.exists(entityId) else { return [] }
        return collectRenderDescendantIds(entityId)
    }

    func hlodRenderDescendantIds(_ tileComp: TileComponent) -> Set<EntityID> {
        guard let entityId = tileComp.hlodEntityId, scene.exists(entityId) else { return [] }
        return collectRenderDescendantIds(entityId)
    }

    @discardableResult
    func beginFadeFromTileFallbacksToFullTile(entityId: EntityID, tileComp: TileComponent) -> Bool {
        let incoming = fullTileRenderDescendantIds(tileEntityId: entityId)
        var started = false

        if tileComp.hlodState == .loaded {
            started = beginTileRepresentationFade(
                tileEntityId: entityId,
                incomingRenderIds: incoming,
                outgoingRenderIds: hlodRenderDescendantIds(tileComp),
                completion: .unloadHLOD
            ) || started
        }

        for i in tileComp.lodLevels.indices where tileComp.lodLevels[i].state == .loaded {
            started = beginTileRepresentationFade(
                tileEntityId: entityId,
                incomingRenderIds: incoming,
                outgoingRenderIds: lodRenderDescendantIds(tileComp, levelIndex: i),
                completion: .unloadLODLevel(i)
            ) || started
        }

        return started
    }

    /// Loads the coarse HLOD mesh for a tile stub as a child entity.
    /// Called when the camera is beyond `hlodSwitchDistance` and the tile is unloaded.
    /// HLOD entities are rendered through the standard model pass (no batching) and
    /// are unloaded automatically when the full tile parse completes.
    func loadHLOD(entityId: EntityID) {
        guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
              let hlodURL = tileComp.hlodURL,
              tileComp.hlodState == .unloaded else { return }

        tileComp.hlodState = .loading
        incrementHLODLoadCount()

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
            decrementHLODLoadCount()
            return
        }

        tileComp.hlodEntityId = hlodEntityId
        markLoadedHLODEntity(entityId)

        let capturedHlodId = hlodEntityId
        let capturedTileId = entityId
        let tileId = tileComp.tileId
        let capturedHlodURL = hlodURL

        let task = Task { [weak self] in
            guard let self else { return }

            // Resolve remote HLOD URLs to a local cached path before decomposing.
            let resolvedURL = await resolveAssetURL(capturedHlodURL, label: "HLOD '\(tileId)'")
            guard let resolvedURL else {
                withWorldMutationGate {
                    if scene.exists(capturedHlodId) {
                        destroyEntity(entityId: capturedHlodId)
                        finalizePendingDestroys()
                    }
                    if let tc = scene.get(component: TileComponent.self, for: capturedTileId) {
                        tc.hlodEntityId = nil
                        tc.hlodState = .unloaded
                    }
                    self.unmarkLoadedHLODEntity(capturedTileId)
                }
                decrementHLODLoadCount()
                return
            }
            let filename = resolvedURL.deletingPathExtension().path
            let ext = resolvedURL.pathExtension

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
                          tc.hlodState == .loading
                    else {
                        // Cancelled while loading — destroy the entity if it still exists.
                        if scene.exists(capturedHlodId) {
                            destroyEntity(entityId: capturedHlodId)
                            finalizePendingDestroys()
                        }
                        return
                    }
                    if success {
                        tc.hlodState = .loaded
                        tc.lastHLODTransitionTime = CFAbsoluteTimeGetCurrent()
                        self.recordTileRepresentationSwap(entityId: capturedTileId, tileId: tileId, representation: "hlod:loaded")
                        self.decrementHLODLoadCount()

                        // Tag HLOD render descendants for the LOD debug renderer
                        // (levelIndex 5 = cyan in lodDebugPalette — distinct from LOD0-4).
                        for rid in self.collectRenderDescendantIds(capturedHlodId) {
                            registerComponent(entityId: rid, componentType: TileLODTagComponent.self)
                            guard let tag = scene.get(component: TileLODTagComponent.self, for: rid) else {
                                handleError(.hlodTagRegistrationFailed, "Tile '\(tileId)'", rid)
                                continue
                            }
                            tag.levelIndex = 5
                        }

                        if self.batchSecondaryTileRepresentations {
                            // The completion already holds the world-mutation gate. Use the
                            // ungated helper so we do not briefly re-assert the render gate
                            // for every HLOD during startup.
                            setEntityStaticBatchComponentUngated(entityId: capturedHlodId)
                            let hlodRenderIds = self.collectRenderDescendantIds(capturedHlodId)
                            if !hlodRenderIds.isEmpty {
                                BatchingSystem.shared.notifyTileEntitiesResident(hlodRenderIds)
                            }
                        }

                        Logger.log(
                            message: "[TileStreaming][HLOD] Tile '\(tileId)' HLOD loaded.",
                            category: LogCategory.tileStreaming.rawValue
                        )
                    } else {
                        self.decrementHLODLoadCount()
                        if scene.exists(capturedHlodId) {
                            destroyEntity(entityId: capturedHlodId)
                            finalizePendingDestroys()
                        }
                        tc.hlodEntityId = nil
                        tc.hlodState = .unloaded
                        self.unmarkLoadedHLODEntity(capturedTileId)
                        handleError(.hlodLoadFailed, tileId)
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
    func unloadHLOD(entityId: EntityID) {
        guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
              tileComp.hlodState != .unloaded else { return }
        guard canUnloadTileFallback(entityId: entityId, tileComp: tileComp, removingHLOD: true) else { return }

        // Set .unloading BEFORE cancel() so any in-flight completion callback
        // that checks hlodState sees .unloading (not .loading) and discards its result.
        let wasHLODLoading = tileComp.hlodState == .loading
        tileComp.hlodState = .unloading
        tileComp.hlodLoadTask?.cancel()
        tileComp.hlodLoadTask = nil
        if wasHLODLoading { decrementHLODLoadCount() }

        // Capture before the withWorldMutationGate block clears it.
        let capturedHlodEntityId = tileComp.hlodEntityId

        // Remove HLOD render descendants from batching pending queues before
        // destroying them — same rationale as unloadLODLevel above.
        if let hlodId = capturedHlodEntityId {
            let renderIds = collectRenderDescendantIds(hlodId)
            if !renderIds.isEmpty {
                BatchingSystem.shared.notifyTileEntitiesUnloading(renderIds)
                TextureStreamingSystem.shared.cancelEntities(renderIds)
            }
        }

        withWorldMutationGate {
            if let hlodEntityId = tileComp.hlodEntityId, scene.exists(hlodEntityId) {
                destroyEntity(entityId: hlodEntityId)
                finalizePendingDestroys()
            }
            tileComp.hlodEntityId = nil
            tileComp.hlodState = .unloaded
            tileComp.lastHLODTransitionTime = CFAbsoluteTimeGetCurrent()
        }

        // Clear async loading progress that setEntityMeshAsync registered. Task.cancel()
        // is cooperative; the inner Task may still be running after we destroy the entity,
        // and its completion callback can return early without calling finishLoading.
        // finishLoading is idempotent: if the Task already called it, this is a no-op.
        if let hlodId = capturedHlodEntityId {
            Task { await AssetLoadingState.shared.finishLoading(entityId: hlodId) }
        }

        unmarkLoadedHLODEntity(entityId)
        recordTileRepresentationSwap(entityId: entityId, tileId: tileComp.tileId, representation: "hlod:unloaded")
        Logger.log(
            message: "[TileStreaming][HLOD] Tile '\(tileComp.tileId)' HLOD unloaded.",
            category: LogCategory.tileStreaming.rawValue
        )
    }

    // MARK: - Per-tile LOD level load / unload

    /// Load one LOD level for a tile stub.  Creates a child entity, calls
    /// setEntityMeshAsync, and on success tags the geometry for static batching
    /// — identical lifecycle to loadHLOD but indexed into tileComp.lodLevels.
    func loadLODLevel(entityId: EntityID, levelIndex: Int) {
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
        let capturedLodURL = level.url
        let tileId = tileComp.tileId

        let task = Task { [weak self] in
            guard let self else { return }

            // Resolve remote LOD URLs to a local cached path before decomposing.
            let resolvedURL = await resolveAssetURL(capturedLodURL, label: "LOD\(capturedIndex + 1) '\(tileId)'")
            guard let resolvedURL else {
                withWorldMutationGate {
                    if scene.exists(capturedLodId) {
                        destroyEntity(entityId: capturedLodId)
                        finalizePendingDestroys()
                    }
                    if let tc = scene.get(component: TileComponent.self, for: capturedTileId),
                       capturedIndex < tc.lodLevels.count
                    {
                        tc.lodLevels[capturedIndex].state = .unloaded
                        tc.lodLevels[capturedIndex].entityId = .invalid
                    }
                    self.unmarkLoadedLODEntity(capturedTileId)
                }
                decrementLODLoadCount()
                return
            }
            let filename = resolvedURL.deletingPathExtension().path
            let ext = resolvedURL.pathExtension

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
                          tc.lodLevels[capturedIndex].state == .loading
                    else {
                        // Cancelled while loading — destroy the entity if it still exists.
                        if scene.exists(capturedLodId) {
                            destroyEntity(entityId: capturedLodId)
                            finalizePendingDestroys()
                        }
                        return
                    }
                    if success {
                        tc.lodLevels[capturedIndex].state = .loaded
                        tc.lastLODTransitionTime = CFAbsoluteTimeGetCurrent()
                        tc.lastLoadedLODIndex = capturedIndex
                        self.recordTileRepresentationSwap(entityId: capturedTileId, tileId: tileId, representation: "lod\(capturedIndex + 1):loaded")
                        self.decrementLODLoadCount()
                        // Tag every render descendant so the LOD debug renderer can
                        // colour them by tile LOD level (levelIndex 1 = LOD1, 2 = LOD2…).
                        let tileLODIndex = capturedIndex + 1
                        for rid in self.collectRenderDescendantIds(capturedLodId) {
                            registerComponent(entityId: rid, componentType: TileLODTagComponent.self)
                            guard let tag = scene.get(component: TileLODTagComponent.self, for: rid) else {
                                handleError(.tileLODTagRegistrationFailed, "Tile '\(tileId)' LOD \(capturedIndex + 1)", rid)
                                continue
                            }
                            tag.levelIndex = tileLODIndex
                        }
                        if self.batchSecondaryTileRepresentations {
                            setEntityStaticBatchComponentUngated(entityId: capturedLodId)
                            let renderIds = self.collectRenderDescendantIds(capturedLodId)
                            if !renderIds.isEmpty {
                                BatchingSystem.shared.notifyTileEntitiesResident(renderIds)
                            }
                        }
                        Logger.log(
                            message: "[TileStreaming][LOD] Tile '\(tileId)' LOD level \(capturedIndex + 1) loaded.",
                            category: LogCategory.tileStreaming.rawValue
                        )
                    } else {
                        if scene.exists(capturedLodId) {
                            destroyEntity(entityId: capturedLodId)
                            finalizePendingDestroys()
                        }
                        tc.lodLevels[capturedIndex].entityId = .invalid
                        tc.lodLevels[capturedIndex].state = .unloaded
                        self.decrementLODLoadCount()
                        self.unmarkLoadedLODEntity(capturedTileId)
                        handleError(.tileLODLoadFailed, "LOD level \(capturedIndex + 1)", tileId)
                    }
                }
            }
        }

        withWorldMutationGate {
            guard let tc = scene.get(component: TileComponent.self, for: entityId),
                  capturedIndex < tc.lodLevels.count else { return }
            tc.lodLevels[capturedIndex].loadTask = task
        }
    }

    /// Tear down one LOD level for a tile stub.  Safe to call regardless of
    /// current state — no-ops if already unloaded.
    func unloadLODLevel(entityId: EntityID, levelIndex: Int) {
        guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
              levelIndex < tileComp.lodLevels.count,
              tileComp.lodLevels[levelIndex].state != .unloaded else { return }
        guard canUnloadTileFallback(entityId: entityId, tileComp: tileComp, removingLODLevel: levelIndex) else { return }

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

        // Remove render descendants from batching pending queues BEFORE destroying
        // them.  destroyEntity fires residency-evicted events which land in
        // pendingEntityRemovals, but any queued addition from the prior load would
        // cause a "entity is missing" error on the next tick().
        if capturedLodEntityId != .invalid {
            let renderIds = collectRenderDescendantIds(capturedLodEntityId)
            if !renderIds.isEmpty {
                BatchingSystem.shared.notifyTileEntitiesUnloading(renderIds)
                TextureStreamingSystem.shared.cancelEntities(renderIds)
            }
        }

        withWorldMutationGate {
            let lodEntityId = tileComp.lodLevels[levelIndex].entityId
            if lodEntityId != .invalid, scene.exists(lodEntityId) {
                destroyEntity(entityId: lodEntityId)
                finalizePendingDestroys()
            }
            tileComp.lodLevels[levelIndex].entityId = .invalid
            tileComp.lodLevels[levelIndex].state = .unloaded
            tileComp.lastLODTransitionTime = CFAbsoluteTimeGetCurrent()
            if tileComp.lastLoadedLODIndex == levelIndex {
                tileComp.lastLoadedLODIndex = nil
            }
        }

        // Same async loading-state cleanup as unloadHLOD — see comment there for rationale.
        if capturedLodEntityId != .invalid {
            Task { await AssetLoadingState.shared.finishLoading(entityId: capturedLodEntityId) }
        }

        // Unmark when no levels remain active.
        if let tc = scene.get(component: TileComponent.self, for: entityId),
           tc.lodLevels.allSatisfy({ $0.state == .unloaded })
        {
            unmarkLoadedLODEntity(entityId)
        }

        recordTileRepresentationSwap(entityId: entityId, tileId: tileComp.tileId, representation: "lod\(levelIndex + 1):unloaded")
        Logger.log(
            message: "[TileStreaming][LOD] Tile '\(tileComp.tileId)' LOD level \(levelIndex + 1) unloaded.",
            category: LogCategory.tileStreaming.rawValue
        )
    }

    /// Unload every LOD level for a tile stub.  Called when the full tile reaches
    /// .parsed (full geometry takes over) or when the tile is being torn down.
    func unloadAllLODLevels(entityId: EntityID) {
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
    func loadTile(entityId: EntityID) {
        guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
              tileComp.state == .unloaded
        else { return }
        guard reserveActiveTileLoad(entityId: entityId, fileSizeBytes: tileComp.fileSizeBytes) else { return }

        tileComp.state = .parsing
        // parseStartTime stays 0 until the download completes — the timeout guard
        // requires parseStartTime > 0, so the clock does not run during remote fetches.
        // It is set to the real time inside the Task after resolveAssetURL returns.
        tileComp.parseStartTime = 0
        markLoadingTileEntity(entityId)

        let tileURL = tileComp.tileURL
        let tileId = tileComp.tileId

        Logger.log(
            message: "[TileStreaming] Dispatching load for tile '\(tileId)'",
            category: LogCategory.tileStreaming.rawValue
        )

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

            // Resolve remote tile URLs to a local cached path before decomposing.
            // Local file URLs pass through unchanged.
            let resolvedURL = await resolveAssetURL(tileURL, label: "tile '\(tileId)'")
            guard let resolvedURL else {
                withWorldMutationGate {
                    if let tc = scene.get(component: TileComponent.self, for: entityId) {
                        tc.state = .unloaded
                        tc.parseStartTime = 0
                        tc.meshEntityId = .invalid
                    }
                }
                releaseActiveTileLoad(entityId: entityId)
                unmarkLoadingTileEntity(entityId)
                return
            }
            // Download complete — start the parse timeout clock now.
            // The guard above leaves parseStartTime = 0 during the remote fetch so
            // the 60-second limit only measures actual parse + GPU-upload work.
            withWorldMutationGate {
                scene.get(component: TileComponent.self, for: entityId)?.parseStartTime = CFAbsoluteTimeGetCurrent()
            }

            // LoadingSystem.getResourceURL handles absolute paths (prefix "/").
            // Splitting into stem + extension matches how the resource search handles
            // all other asset loads, including cross-bundle and external-basePath scenarios.
            let filename = resolvedURL.deletingPathExtension().path
            let ext = resolvedURL.pathExtension

            // .auto policy: the admission gate and memory budget system decide whether
            // to use fullLoad or outOfCore based on the tile's file size and available
            // RAM.  For the expected 15–20 MB tile range this resolves to fullLoad
            // (parse + immediate GPU upload), treating the tile as an atomic unit.
            setEntityMeshAsync(
                entityId: capturedMeshEntityId,
                filename: filename,
                withExtension: ext,
                streamingPolicy: .auto,
                blockRenderLoop: false
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
                            for d in descendants {
                                destroyEntity(entityId: d)
                            }
                            destroyEntity(entityId: capturedMeshEntityId)
                            finalizePendingDestroys()
                        }
                        withStateLock { _ = meshEntityToTileEntity.removeValue(forKey: capturedMeshEntityId) }
                        ProgressiveAssetLoader.shared.removeOutOfCoreAsset(rootEntityId: entityId)
                        if let tc2 = scene.get(component: TileComponent.self, for: entityId) {
                            tc2.state = .unloaded
                            tc2.parseStartTime = 0
                            tc2.meshEntityId = .invalid
                        }
                        unmarkLoadingTileEntity(entityId)
                        unmarkLoadedTileEntity(entityId)
                        Logger.log(
                            message: "[TileStreaming] Tile '\(tileId)' cancelled load cleaned up.",
                            category: LogCategory.tileStreaming.rawValue
                        )
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
                        tc.failureCount = 0 // clear retry counter on successful parse
                        tc.state = .parsed
                        tc.parsedResidentSince = CFAbsoluteTimeGetCurrent()
                        self.markLoadedTileEntity(entityId)
                        self.recordTileRepresentationSwap(entityId: entityId, tileId: tileId, representation: "tile:parsed")

                        // Tag the tile's mesh hierarchy for cell-based static batching.
                        // setEntityStaticBatchComponent walks the full child tree and
                        // attaches StaticBatchComponent to every entity that has a
                        // RenderComponent (eager/small tiles) or StreamingComponent
                        // (OCC stubs awaiting GPU upload).  For OCC stubs the batch
                        // residency handler fires automatically when each stub's GPU
                        // upload completes, so no manual generateBatches() call is needed.
                        // The completion already holds the world-mutation gate.
                        setEntityStaticBatchComponentUngated(entityId: capturedMeshEntityId)

                        let tileRenderIds = self.collectRenderDescendantIds(capturedMeshEntityId)
                        let selectableRenderIds = tileRenderIds.filter { hasEntitySceneChannel(entityId: $0, channel: .selectableGeometry) }
                        let hasFallbackCoverage = tc.hlodState == .loaded || tc.lodLevels.contains { $0.state == .loaded }
                        let canReleaseFallback = self.canReleaseLOD0Fallback(entityId: entityId, tileComp: tc, renderEntityIds: tileRenderIds)
                        let fullTileFadeStarted = hasFallbackCoverage
                            ? self.beginFadeFromTileFallbacksToFullTile(entityId: entityId, tileComp: tc)
                            : false

                        // For fullLoad tiles (occCount == 0) the RenderComponent is
                        // already present on capturedMeshEntityId and its children —
                        // they bypass the OCC upload path that normally queues the
                        // residency event.  Queue the event explicitly here so the
                        // batching system picks them up on the next flushEvents() call.
                        if occCount == 0 {
                            // All render entities are resident now; notify the batching
                            // system directly (bypasses the per-entity event storm).
                            // Also enqueue into the texture streaming burst queue so
                            // freshly loaded tile geometry gets its first texture upgrade
                            // before the regular visible-entity pass.
                            if !tileRenderIds.isEmpty, !fullTileFadeStarted {
                                BatchingSystem.shared.notifyTileEntitiesResident(tileRenderIds)
                                TextureStreamingSystem.shared.notifyEntitiesReady(tileRenderIds)
                            }
                        }

                        self.recordLOD0Promotion(
                            entityId: entityId,
                            tileId: tileId,
                            renderEntityIds: tileRenderIds,
                            fallbackSummary: self.tileFallbackSummary(tc)
                        )

                        // Drop fallback coverage only after LOD0 is present in the
                        // render-visible set.  A freshly parsed full tile can have
                        // RenderComponent.isVisible=true while visibleEntityIds is
                        // still frozen behind the loading gate/triple-buffer handoff.
                        // Keeping LOD/HLOD alive through that window avoids a visible
                        // hole during navigation.
                        if canReleaseFallback {
                            if fullTileFadeStarted {
                                self.clearLOD0FallbackBookkeeping(entityId: entityId)
                            } else {
                                self.releaseLOD0FallbackCoverage(entityId: entityId)
                            }
                        }

                        let budgetStats = MemoryBudgetManager.shared.getStats()
                        let geomPct = Int((budgetStats.geometryUtilization * 100).rounded())
                        let selectableNames = selectableRenderIds
                            .map { getEntityName(entityId: $0) }
                            .filter { !$0.isEmpty }
                            .sorted()
                            .prefix(8)
                            .joined(separator: ", ")
                        let selectableSuffix = selectableRenderIds.isEmpty
                            ? ""
                            : " selectable=[\(selectableNames)]"
                        Logger.log(
                            message: "[TileStreaming] Tile '\(tileId)' parsed (\(occCount) OCC stubs pending GPU upload, render=\(tileRenderIds.count), selectable=\(selectableRenderIds.count)). geom=\(budgetStats.meshMemoryUsed / (1024 * 1024))MB/\(budgetStats.geometryBudget / (1024 * 1024))MB (\(geomPct)%)\(selectableSuffix)",
                            category: LogCategory.tileStreaming.rawValue
                        )
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
                        handleError(.tileStreamingParseFailed, "attempt \(tc.failureCount), retry in \(String(format: "%.0f", tc.retryDelaySeconds))s", tileId)
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
    /// Recursively collect the IDs of all descendants (including `entityId` itself)
    /// that have a RenderComponent.  Used to hand off the full set of render-ready
    /// entities to the BatchingSystem after a fullLoad tile finishes parsing.
    func collectRenderDescendantIds(_ entityId: EntityID) -> Set<EntityID> {
        var result: Set<EntityID> = []
        collectRenderDescendantIds(entityId, into: &result)
        return result
    }

    func collectRenderDescendantIds(_ entityId: EntityID, into result: inout Set<EntityID>) {
        if scene.get(component: RenderComponent.self, for: entityId) != nil {
            result.insert(entityId)
        }
        for childId in getEntityChildren(parentId: entityId) {
            collectRenderDescendantIds(childId, into: &result)
        }
    }

    /// Recursively count OCC stub descendants (entities with StreamingComponent).
    /// Used to seed TileComponent.totalOCCStubs after a tile parse completes.
    func countOCCDescendants(_ parentId: EntityID) -> Int {
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
    func incrementParentTileOCCCount(for entityId: EntityID) {
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
    func collectTileDescendants(_ parentId: EntityID) -> [EntityID] {
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
    func unloadTile(entityId: EntityID) {
        guard let tileComp = scene.get(component: TileComponent.self, for: entityId),
              tileComp.state == .parsed || tileComp.state == .parsing
        else { return }

        let tileId = tileComp.tileId
        let wasParsing = tileComp.state == .parsing
        let unloadStart = CFAbsoluteTimeGetCurrent()

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
                // The load Task is still running on the background thread.
                // setEntityMeshAsync may be actively creating or accessing child entities
                // right now — destroying them here would be an unsynchronised concurrent
                // write into the ECS.  Bail out and let loadTile's completion callback
                // dispatch the cleanup to the main thread once the Task has fully exited.
                // Keep the tile in the parsing-tracking sets until the task actually exits
                // so the timeout watchdog can still reclaim the reserved parse slot if the
                // cancelled work never completes.
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

            // Full batching + texture cleanup before destroying.
            // notifyTileEntitiesUnloading handles BOTH pending-queue entries (entities
            // not yet committed by the batch tick) AND committed entityToCellMembership
            // entries (entities already processed by a previous batch tick).  Without the
            // committed-state cleanup, destroyed entity IDs that get recycled by the ECS
            // land in the wrong batch cell, causing "entity is missing" errors and meshes
            // that appear as green AABBs but never render.
            let renderDescendants = collectRenderDescendantIds(entityId)
            if !renderDescendants.isEmpty {
                BatchingSystem.shared.notifyTileEntitiesUnloading(renderDescendants)
                TextureStreamingSystem.shared.cancelEntities(renderDescendants)
            }

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
            tileComp.parsedResidentSince = 0

            // Reset stub so the next approach triggers a fresh loadTile() call.
            tileComp.state = .unloaded
            tileComp.parseStartTime = 0
            unmarkLoadedTileEntity(entityId)

            let unloadMs = (CFAbsoluteTimeGetCurrent() - unloadStart) * 1000.0
            let unloadSuffix = unloadMs > 50 ? " ⚠️ slow=\(String(format: "%.0f", unloadMs))ms" : ""
            Logger.log(
                message: "[TileStreaming] Tile '\(tileId)' unloaded (\(descendants.count) child entities destroyed).\(unloadSuffix)",
                category: LogCategory.tileStreaming.rawValue
            )
        }
    }

    // MARK: - Remote URL Resolution

    /// Resolves a URL to a local file URL, downloading it if it is remote.
    ///
    /// Returns `nil` and logs an error if the download fails after all retries,
    /// so callers can clean up their entities and abort the load.
    /// Local file URLs are returned unchanged without any network I/O.
    func resolveAssetURL(_ url: URL, label: String) async -> URL? {
        if url.scheme?.lowercased() == "http" {
            let error = RemoteAssetDownloader.DownloadError.insecureScheme("http")
            handleError(.remoteAssetDownloadFailed, error.localizedDescription, label)
            return nil
        }
        guard url.scheme?.lowercased() == "https" else {
            return url
        }
        do {
            return try await RemoteAssetDownloader.shared.localURL(for: url)
        } catch {
            handleError(.remoteAssetDownloadFailed, error.localizedDescription, label)
            return nil
        }
    }
}

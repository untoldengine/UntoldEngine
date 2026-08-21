//
//  GeometryStreamingSystem+GaussianStreaming.swift
//  UntoldEngine
//
//  Gaussian-splat streaming load dispatch and unload. The actual asset load goes through
//  the shared, public setEntityGaussianAsync (RegistrationSystem.swift) — gaussians have no
//  cache/OCC layer analogous to MeshResourceManager, so unlike mesh streaming there is no
//  separate streaming-only load helper, just the dispatch/completion wrapper below.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

extension GeometryStreamingSystem {
    /// Dispatches the async load for a streamed Gaussian-splat entity and installs the
    /// completion handling (state transition, residency event, monitor bookkeeping,
    /// active-load slot release). Called from `loadMesh` once it has already reserved the
    /// load slot and recorded scheduler-latency instrumentation — mirrors the structure of
    /// `loadMesh`'s own mesh-path `Task`, but calls the shared `setEntityGaussianAsync`
    /// instead of the mesh-only `loadMeshAsync`/`reloadLODEntity`, and skips
    /// `incrementParentTileOCCCount` — that counter tracks progressive upload of a tile's own
    /// OCC sub-meshes (`TileComponent.totalOCCStubs`), which splat props never contribute to;
    /// incrementing it here would inflate the numerator past a denominator it never grew,
    /// corrupting the tile's `visualState` completion fraction.
    func loadGaussianStreamingEntity(entityId: EntityID, streaming: StreamingComponent, isNearBand: Bool) {
        if scene.get(component: GaussianLODComponent.self, for: entityId) != nil {
            loadGaussianProgressiveStreamingEntity(entityId: entityId, streaming: streaming, isNearBand: isNearBand)
            return
        }

        let filename = streaming.assetFilename
        let ext = streaming.assetExtension

        dispatchGaussianLoad(entityId: entityId, streaming: streaming, isNearBand: isNearBand) {
            await setEntityGaussianAsync(entityId: entityId, filename: filename, withExtension: ext)
        }
    }

    /// Loads only the coarsest tier for a progressive Gaussian prop. Finer tiers are pulled
    /// later by `GaussianLODSystem` as the camera moves close enough to need them.
    func loadGaussianProgressiveStreamingEntity(entityId: EntityID, streaming: StreamingComponent, isNearBand: Bool) {
        dispatchGaussianLoad(entityId: entityId, streaming: streaming, isNearBand: isNearBand) {
            await self.loadInitialGaussianProgressiveTier(entityId: entityId)
        }
    }

    /// Runs `loader`, then applies its result through the shared completion path (state
    /// transition, residency event, monitor bookkeeping, active/near-band load release) and
    /// records load-time instrumentation — shared by both the plain and progressive Gaussian
    /// load entry points above, which previously duplicated this whole body and had already
    /// drifted (the progressive path was missing this timing instrumentation).
    private func dispatchGaussianLoad(
        entityId: EntityID,
        streaming: StreamingComponent,
        isNearBand: Bool,
        loader: @escaping @Sendable () async -> Bool
    ) {
        let task = Task {
            let asyncLoadStart = CFAbsoluteTimeGetCurrent()
            let success = await loader()
            let asyncLoadMs = (CFAbsoluteTimeGetCurrent() - asyncLoadStart) * 1000.0

            var applyMs: Double = 0
            withWorldMutationGate {
                let applyStart = CFAbsoluteTimeGetCurrent()
                completeGaussianStreamingLoad(entityId: entityId, isNearBand: isNearBand, success: success)
                applyMs = (CFAbsoluteTimeGetCurrent() - applyStart) * 1000.0
            }
            recordLoadCompletion(success: success, asyncLoadMs: asyncLoadMs, applyMs: applyMs, wasLODReload: false)
        }

        streaming.loadTask = task
    }

    /// Applies a completed Gaussian load's result to `StreamingComponent`/event bus/monitor.
    /// Must be called from within `withWorldMutationGate`.
    private func completeGaussianStreamingLoad(
        entityId: EntityID,
        isNearBand: Bool,
        success: Bool
    ) {
        // Guard against the cooperative-cancellation race, same as loadMesh's mesh path:
        // unloadGaussian may have freed this entity while the load was in flight.
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

            let event = AssetResidencyChangedEvent(
                entityId: entityId,
                assetURL: URL(fileURLWithPath: ""),
                meshName: s.assetFilename,
                isResident: true
            )
            SystemEventBus.shared.queueResidencyChange(event)
            markLoadedStreamingEntity(entityId)
            SystemIntegrationMonitor.shared.recordStreamingLoad()
        } else {
            s.state = .unloaded
            handleError(.meshStreamingFailed, entityId)
        }
        releaseActiveLoad(entityId: entityId)
        if isNearBand { releaseNearBandLoad(entityId: entityId) }
    }

    func loadInitialGaussianProgressiveTier(entityId: EntityID) async -> Bool {
        let coarsestIndex: Int? = withWorldMutationGate {
            guard let lod = scene.get(component: GaussianLODComponent.self, for: entityId),
                  !lod.lodLevels.isEmpty
            else { return nil }
            let index = lod.lodLevels.count - 1
            // Mark the slot .loading synchronously, same as requestGaussianLODLevelLoad does for
            // on-demand tiers — loadGaussianLODLevel's completion only commits while this still
            // reads .loading, so unloadGaussianProgressive resetting it to .notResident in the
            // meantime turns a stale completion into a safe no-op instead of resurrecting state.
            lod.lodLevels[index].residencyState = .loading
            return index
        }
        guard let coarsestIndex else { return false }
        return await loadGaussianLODLevel(entityId: entityId, lodIndex: coarsestIndex, makeCurrent: true)
    }

    public func requestGaussianLODLevelLoad(entityId: EntityID, lodIndex: Int) {
        withWorldMutationGate {
            guard scene.exists(entityId),
                  let lod = scene.get(component: GaussianLODComponent.self, for: entityId),
                  lodIndex >= 0,
                  lodIndex < lod.lodLevels.count
            else { return }

            guard lod.lodLevels[lodIndex].residencyState != .resident,
                  lod.lodLevels[lodIndex].residencyState != .loading
            else { return }

            lod.lodLevels[lodIndex].residencyState = .loading
            let task = Task { [weak self] in
                _ = await self?.loadGaussianLODLevel(entityId: entityId, lodIndex: lodIndex, makeCurrent: false)
            }
            lod.lodLevels[lodIndex].loadTask = task
        }
    }

    @discardableResult
    func loadGaussianLODLevel(entityId: EntityID, lodIndex: Int, makeCurrent: Bool) async -> Bool {
        let url: URL? = withWorldMutationGate {
            guard scene.exists(entityId),
                  let lod = scene.get(component: GaussianLODComponent.self, for: entityId),
                  lodIndex >= 0,
                  lodIndex < lod.lodLevels.count
            else { return nil }
            return lod.lodLevels[lodIndex].url
        }
        guard let url, let built = buildGaussianComponentFromUntoldGS(url: url) else {
            withWorldMutationGate {
                if let lod = scene.get(component: GaussianLODComponent.self, for: entityId),
                   lodIndex >= 0,
                   lodIndex < lod.lodLevels.count,
                   lod.lodLevels[lodIndex].residencyState == .loading
                {
                    lod.lodLevels[lodIndex].residencyState = .notResident
                    lod.lodLevels[lodIndex].loadTask = nil
                }
            }
            return false
        }

        return withWorldMutationGate {
            // residencyState == .loading confirms this is still the authoritative load for the
            // slot: unloadGaussianProgressive/removeEntityGaussianLOD reset it to .notResident on
            // teardown, and Task.cancel() is only cooperative (never observed mid-await here), so
            // without this re-check a cancelled-but-still-running load could resurrect buffers/
            // residency on an entity the streaming system already considers unloaded.
            guard scene.exists(entityId),
                  let lod = scene.get(component: GaussianLODComponent.self, for: entityId),
                  lodIndex >= 0,
                  lodIndex < lod.lodLevels.count,
                  lod.lodLevels[lodIndex].residencyState == .loading
            else { return false }

            lod.lodLevels[lodIndex].buffers = built.component
            lod.lodLevels[lodIndex].residencyState = .resident
            lod.lodLevels[lodIndex].loadTask = nil

            if makeCurrent {
                // Reuse the entity's existing GaussianComponent if it already has one — scene.assign
                // unconditionally re-initializes the component slot, which would drop the previous
                // instance (and every Metal buffer it retained) without releasing it.
                if let live = scene.get(component: GaussianComponent.self, for: entityId)
                    ?? scene.assign(to: entityId, component: GaussianComponent.self)
                {
                    copyGaussianComponentBuffers(from: built.component, to: live)
                    lod.currentLOD = lodIndex
                }
            }

            var totalBytes = 0
            for level in lod.lodLevels {
                guard let buffers = level.buffers else { continue }
                totalBytes += gaussianComponentEstimatedBytes(buffers)
            }
            MemoryBudgetManager.shared.registerMesh(entityId: entityId, meshSizeBytes: totalBytes)
            return true
        }
    }

    /// Tears down a streamed Gaussian-splat entity's GPU resources and removes it from the
    /// shared memory budget. Mirrors `unloadMesh` (`GeometryStreamingSystem+MeshStreaming.swift`)
    /// but skips the mesh-only bits (RenderComponent, LODComponent, MeshResourceManager,
    /// BatchingSystem static-batch retirement) that don't apply to splats.
    func unloadGaussian(entityId: EntityID) {
        guard let streaming = scene.get(component: StreamingComponent.self, for: entityId),
              streaming.state == .loaded
        else { return }

        firstRangeTimestamps.removeValue(forKey: entityId)

        let unloadStart = CFAbsoluteTimeGetCurrent()
        withWorldMutationGate {
            streaming.state = .unloading

            streaming.loadTask?.cancel()
            streaming.loadTask = nil

            // No-op for a plain (non-progressive) splat entity, since it has no
            // GaussianLODComponent — folds the progressive-only per-tier teardown in here
            // instead of a separate unloadGaussianProgressive sibling function.
            if let lod = scene.get(component: GaussianLODComponent.self, for: entityId) {
                lod.releaseAllLevelResources()
                lod.currentLOD = -1
                lod.desiredLOD = max(0, lod.lodLevels.count - 1)
            }

            removeEntityGaussian(entityId: entityId)

            // removeEntityGaussian already unregisters from MemoryBudgetManager, but the call
            // is idempotent, so calling it here too keeps this function correct even if
            // removeEntityGaussian's cleanup behavior changes later.
            MemoryBudgetManager.shared.unregisterMesh(entityId: entityId)

            unmarkLoadedStreamingEntity(entityId)

            streaming.state = .unloaded

            let event = AssetResidencyChangedEvent(
                entityId: entityId,
                assetURL: URL(fileURLWithPath: ""),
                meshName: streaming.assetFilename,
                isResident: false
            )
            SystemEventBus.shared.queueResidencyChange(event)
            SystemIntegrationMonitor.shared.recordStreamingUnload()
        }
        let unloadMs = (CFAbsoluteTimeGetCurrent() - unloadStart) * 1000.0
        updateLastUnloadDuration(unloadMs)
    }
}

private func gaussianComponentEstimatedBytes(_ component: GaussianComponent) -> Int {
    var total = 0
    total += component.encodedSplatData?.length ?? 0
    total += component.sphericalHarmonicsData?.length ?? 0
    for buffer in component.gaussianSortedIndices { total += buffer?.length ?? 0 }
    for buffer in component.gaussianVisibleIndices { total += buffer?.length ?? 0 }
    for buffer in component.gaussianVisibleCount { total += buffer?.length ?? 0 }
    for buffer in component.gaussianPrecomputedData { total += buffer?.length ?? 0 }
    for buffer in component.spaceUniform { total += buffer?.length ?? 0 }
    return total
}

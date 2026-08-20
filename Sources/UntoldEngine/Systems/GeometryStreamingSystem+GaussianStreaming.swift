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

        let task = Task {
            let asyncLoadStart = CFAbsoluteTimeGetCurrent()
            let success = await setEntityGaussianAsync(entityId: entityId, filename: filename, withExtension: ext)
            let asyncLoadMs = (CFAbsoluteTimeGetCurrent() - asyncLoadStart) * 1000.0

            var applyMs: Double = 0
            withWorldMutationGate {
                let applyStart = CFAbsoluteTimeGetCurrent()

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
                applyMs = (CFAbsoluteTimeGetCurrent() - applyStart) * 1000.0
            }
            recordLoadCompletion(success: success, asyncLoadMs: asyncLoadMs, applyMs: applyMs, wasLODReload: false)
        }

        streaming.loadTask = task
    }

    /// Loads only the coarsest tier for a progressive Gaussian prop. Finer tiers are pulled
    /// later by `GaussianLODSystem` as the camera moves close enough to need them.
    func loadGaussianProgressiveStreamingEntity(entityId: EntityID, streaming: StreamingComponent, isNearBand: Bool) {
        let task = Task {
            let success = await loadInitialGaussianProgressiveTier(entityId: entityId)

            withWorldMutationGate {
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
                    SystemEventBus.shared.queueResidencyChange(
                        AssetResidencyChangedEvent(
                            entityId: entityId,
                            assetURL: URL(fileURLWithPath: ""),
                            meshName: s.assetFilename,
                            isResident: true
                        )
                    )
                    markLoadedStreamingEntity(entityId)
                    SystemIntegrationMonitor.shared.recordStreamingLoad()
                } else {
                    s.state = .unloaded
                    handleError(.meshStreamingFailed, entityId)
                }

                releaseActiveLoad(entityId: entityId)
                if isNearBand { releaseNearBandLoad(entityId: entityId) }
            }
        }

        streaming.loadTask = task
    }

    func loadInitialGaussianProgressiveTier(entityId: EntityID) async -> Bool {
        let coarsestIndex: Int? = withWorldMutationGate {
            guard let lod = scene.get(component: GaussianLODComponent.self, for: entityId),
                  !lod.lodLevels.isEmpty
            else { return nil }
            return lod.lodLevels.count - 1
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
                   lodIndex < lod.lodLevels.count
                {
                    lod.lodLevels[lodIndex].residencyState = .notResident
                    lod.lodLevels[lodIndex].loadTask = nil
                }
            }
            return false
        }

        withWorldMutationGate {
            guard scene.exists(entityId),
                  let lod = scene.get(component: GaussianLODComponent.self, for: entityId),
                  lodIndex >= 0,
                  lodIndex < lod.lodLevels.count
            else { return }

            lod.lodLevels[lodIndex].buffers = built.component
            lod.lodLevels[lodIndex].residencyState = .resident
            lod.lodLevels[lodIndex].loadTask = nil

            if makeCurrent {
                if let live = scene.assign(to: entityId, component: GaussianComponent.self) {
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
        }

        return true
    }

    /// Tears down a streamed Gaussian-splat entity's GPU resources and removes it from the
    /// shared memory budget. Mirrors `unloadMesh` (`GeometryStreamingSystem+MeshStreaming.swift`)
    /// but skips the mesh-only bits (RenderComponent, LODComponent, MeshResourceManager,
    /// BatchingSystem static-batch retirement) that don't apply to splats.
    func unloadGaussian(entityId: EntityID) {
        if scene.get(component: GaussianLODComponent.self, for: entityId) != nil {
            unloadGaussianProgressive(entityId: entityId)
            return
        }

        guard let streaming = scene.get(component: StreamingComponent.self, for: entityId),
              streaming.state == .loaded
        else { return }

        firstRangeTimestamps.removeValue(forKey: entityId)

        let unloadStart = CFAbsoluteTimeGetCurrent()
        withWorldMutationGate {
            streaming.state = .unloading

            streaming.loadTask?.cancel()
            streaming.loadTask = nil

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

    func unloadGaussianProgressive(entityId: EntityID) {
        guard let streaming = scene.get(component: StreamingComponent.self, for: entityId),
              streaming.state == .loaded
        else { return }

        firstRangeTimestamps.removeValue(forKey: entityId)

        withWorldMutationGate {
            streaming.state = .unloading
            streaming.loadTask?.cancel()
            streaming.loadTask = nil

            if let lod = scene.get(component: GaussianLODComponent.self, for: entityId) {
                for index in lod.lodLevels.indices {
                    lod.lodLevels[index].loadTask?.cancel()
                    lod.lodLevels[index].loadTask = nil
                    lod.lodLevels[index].buffers = nil
                    lod.lodLevels[index].residencyState = .notResident
                }
                lod.currentLOD = -1
                lod.desiredLOD = max(0, lod.lodLevels.count - 1)
            }

            removeEntityGaussian(entityId: entityId)
            MemoryBudgetManager.shared.unregisterMesh(entityId: entityId)
            unmarkLoadedStreamingEntity(entityId)
            streaming.state = .unloaded
            SystemEventBus.shared.queueResidencyChange(
                AssetResidencyChangedEvent(
                    entityId: entityId,
                    assetURL: URL(fileURLWithPath: ""),
                    meshName: streaming.assetFilename,
                    isResident: false
                )
            )
            SystemIntegrationMonitor.shared.recordStreamingUnload()
        }
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

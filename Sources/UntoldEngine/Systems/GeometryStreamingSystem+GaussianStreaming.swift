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

//
//  GeometryStreamingSystem+Eviction.swift
//  UntoldEngine
//
//  LRU eviction: value-scored eviction pass used under geometry memory pressure.
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
    /// Evict loaded entities under memory pressure, prioritising by value score.
    ///
    /// Score = `evictionDistanceWeight × distanceFactor + evictionSizeWeight × sizeFactor`.
    /// Entities with high distance and large GPU footprint are evicted first, protecting
    /// nearby small meshes that are most valuable for scene coverage near the camera.
    /// LRU frame is retained as a tiebreaker for equal-score candidates.
    ///
    /// Visibility guard is distance-aware: entities within `visibleEvictionProtectionRadius`
    /// are never evicted while visible (prevents foreground popping). Entities beyond that
    /// radius may be evicted even while visible — a distant pop is cheaper than a nearby
    /// mesh failing to load under memory pressure.
    func evictLRU(cameraPosition: simd_float3, maxEvictions: Int = Int.max) -> Int {
        // First, evict any unused cached files
        MeshResourceManager.shared.evictUnused()

        var candidates: [(entityId: EntityID, score: Float, lastFrame: Int, distance: Float)] = []
        var staleEntityIds: [EntityID] = []

        let trackedLoadedSnapshot = loadedStreamingEntitiesSnapshot()
        // Use geometryBudget as the denominator: evictLRU is purely a geometry eviction
        // pass, so sizing the score against the geometry pool (not the combined budget)
        // gives an accurate picture of how much of that pool each candidate consumes.
        let budget = Float(max(1, MemoryBudgetManager.shared.geometryBudget))

        for entityId in trackedLoadedSnapshot {
            guard scene.exists(entityId) else {
                staleEntityIds.append(entityId)
                continue
            }
            guard let streaming = scene.get(component: StreamingComponent.self, for: entityId),
                  streaming.state == .loaded
            else { continue }

            let distance = calculateDistance(entityId: entityId, cameraPosition: cameraPosition)
            let distanceFactor = min(1.0, distance / maxQueryRadius)

            let meshBytes = Float(MemoryBudgetManager.shared.getMemorySize(for: entityId) ?? 0)
            let sizeFactor = min(1.0, meshBytes / budget)

            let score = evictionDistanceWeight * distanceFactor + evictionSizeWeight * sizeFactor
            candidates.append((entityId, score, streaming.lastVisibleFrame, distance))
        }

        for staleId in staleEntityIds {
            unmarkLoadedStreamingEntity(staleId)
        }

        // Sort: highest eviction score first; LRU frame as tiebreaker.
        candidates.sort {
            if abs($0.score - $1.score) > 0.001 { return $0.score > $1.score }
            return $0.lastFrame < $1.lastFrame
        }

        let visibleSet = Set(visibleEntityIds)
        var evictedCount = 0
        for candidate in candidates {
            // Stop when geometry-only pressure clears — texture memory is managed
            // independently by TextureStreamingSystem and should not force extra
            // geometry evictions.
            guard MemoryBudgetManager.shared.shouldEvictGeometry() else { break }

            // Per-call cap: spreads large eviction bursts across multiple ticks so a single
            // pressure event cannot monopolise the frame. Remaining entities are evicted on
            // subsequent ticks (each still passes the shouldEvictGeometry() check above).
            if evictedCount >= maxEvictions { break }

            // Distance-aware visibility guard.
            // Close visible meshes (< visibleEvictionProtectionRadius) are protected — evicting
            // them would cause an obvious foreground pop. Far visible meshes are evictable under
            // memory pressure; a distant pop is less harmful than a nearby mesh failing to load.
            if visibleSet.contains(candidate.entityId), candidate.distance < visibleEvictionProtectionRadius {
                continue
            }

            unloadMesh(entityId: candidate.entityId)
            evictedCount += 1
        }
        return evictedCount
    }

    /// Second-stage geometry relief for tile-owned geometry.
    ///
    /// Tile full-loads, HLODs, and per-tile LODs can consume substantial geometry memory
    /// while never entering loadedStreamingEntities. When the geometry budget is blocked by
    /// those representations, mesh-only eviction makes no progress and the streaming system
    /// can stall under permanent pressure.
    ///
    /// Protection floor: each tile's own `streamingRadius`, not the global
    /// `visibleEvictionProtectionRadius`.  A tile beyond its streaming radius is in the
    /// hysteresis zone — the load pass will not re-dispatch it until the camera re-enters
    /// `effectivePrefetchRadius`, so evicting it here does not cause immediate thrashing.
    /// Tiles AT or INSIDE their streaming radius are protected because they would be
    /// re-queued on the very next streaming tick.
    func evictTileGeometry(cameraPosition: simd_float3, maxEvictions: Int = Int.max) -> Int {
        enum TileEvictionKind {
            case fullTile
            case hlod
            case lod
        }

        var candidates: [(entityId: EntityID, kind: TileEvictionKind, distance: Float)] = []
        var seen: Set<EntityID> = []
        let now = CFAbsoluteTimeGetCurrent()

        for entityId in loadedTileEntitiesSnapshot() {
            guard scene.exists(entityId),
                  let tileComp = scene.get(component: TileComponent.self, for: entityId),
                  tileComp.state == .parsed
            else { continue }
            let distance = calculateDistance(entityId: entityId, cameraPosition: cameraPosition)
            // Protect tiles within their own streaming radius — they would be re-dispatched
            // immediately, causing a load/evict cycle that wastes bandwidth and CPU.
            guard distance > tileComp.streamingRadius else { continue }
            guard tileComp.parsedResidentSince == 0 ||
                now - tileComp.parsedResidentSince >= minimumParsedTileResidentSeconds
            else { continue }
            candidates.append((entityId, .fullTile, distance))
            seen.insert(entityId)
        }

        for entityId in loadedHLODEntitiesSnapshot() {
            guard !seen.contains(entityId),
                  scene.exists(entityId),
                  let tileComp = scene.get(component: TileComponent.self, for: entityId),
                  tileComp.hlodState == .loaded
            else { continue }
            let distance = calculateDistance(entityId: entityId, cameraPosition: cameraPosition)
            guard distance > tileComp.streamingRadius else { continue }
            candidates.append((entityId, .hlod, distance))
            seen.insert(entityId)
        }

        for entityId in loadedLODEntitiesSnapshot() {
            guard !seen.contains(entityId),
                  scene.exists(entityId),
                  let tileComp = scene.get(component: TileComponent.self, for: entityId),
                  tileComp.lodLevels.contains(where: { $0.state == .loaded })
            else { continue }
            let distance = calculateDistance(entityId: entityId, cameraPosition: cameraPosition)
            guard distance > tileComp.streamingRadius else { continue }
            candidates.append((entityId, .lod, distance))
        }

        candidates.sort { $0.distance > $1.distance }

        var evictedCount = 0
        for candidate in candidates {
            guard MemoryBudgetManager.shared.shouldEvictGeometry() else { break }
            guard evictedCount < maxEvictions else { break }

            switch candidate.kind {
            case .fullTile:
                unloadTile(entityId: candidate.entityId)
            case .hlod:
                unloadHLOD(entityId: candidate.entityId)
            case .lod:
                unloadAllLODLevels(entityId: candidate.entityId)
            }
            evictedCount += 1
        }

        return evictedCount
    }
}

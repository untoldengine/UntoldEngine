//
//  SpatialDebugBoundsCollector.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

public struct SpatialDebugBound {
    public var bounds: AABB
    public var color: simd_float4

    public init(bounds: AABB, color: simd_float4) {
        self.bounds = bounds
        self.color = color
    }
}

/// Collected spatial debug bounds for a single frame.
public struct SpatialDebugBoundsSnapshot {
    public var octreeLeafBounds: [SpatialDebugBound]
    public var staticBatchCellBounds: [SpatialDebugBound]
    /// Tile stub bounds drawn directly from TileComponent state, independent of
    /// octree leaf placement (tile stubs span multiple octree children and are
    /// stored at internal nodes, not leaves).
    public var tileBounds: [SpatialDebugBound]

    public init(
        octreeLeafBounds: [SpatialDebugBound] = [],
        staticBatchCellBounds: [SpatialDebugBound] = [],
        tileBounds: [SpatialDebugBound] = []
    ) {
        self.octreeLeafBounds = octreeLeafBounds
        self.staticBatchCellBounds = staticBatchCellBounds
        self.tileBounds = tileBounds
    }
}

/// Collects debug bounds from spatial systems without renderer coupling.
public final class SpatialDebugBoundsCollector: @unchecked Sendable {
    public static let shared = SpatialDebugBoundsCollector()

    private let defaultOctreeColor = simd_float4(1.0, 1.0, 1.0, 1.0)
    private let residencyLoadedColor = simd_float4(0.25, 0.95, 0.35, 1.0)
    private let residencyLoadingColor = simd_float4(1.00, 0.85, 0.20, 1.0)
    private let residencyUnloadedColor = simd_float4(1.00, 0.25, 0.25, 1.0)
    private let residencyMixedColor = simd_float4(1.00, 0.55, 0.15, 1.0)
    // Tile-specific residency colors
    private let tileHLODLoadedColor  = simd_float4(0.20, 0.90, 0.90, 1.0) // cyan  — coarse HLOD visible
    private let tileHLODLoadingColor = simd_float4(0.40, 0.70, 1.00, 1.0) // light blue — HLOD uploading
    private let tileFailedColor      = simd_float4(0.90, 0.20, 0.90, 1.0) // magenta — parse failed
    private let cullingVisibleColor = simd_float4(0.25, 0.95, 0.35, 1.0)
    private let cullingCulledColor = simd_float4(0.30, 0.60, 1.00, 1.0)
    private let cullingHiddenColor = simd_float4(0.55, 0.55, 0.55, 1.0)
    private let cullingMixedColor = simd_float4(1.00, 0.55, 0.15, 1.0)
    private let staticBatchCellPlainColor = simd_float4(0.95, 0.85, 0.30, 1.0)
    private let staticBatchCellLOD0Color = simd_float4(1.0, 0.0, 0.0, 1.0)
    private let staticBatchCellLOD1Color = simd_float4(0.0, 1.0, 0.0, 1.0)
    private let staticBatchCellLOD2Color = simd_float4(0.0, 0.0, 1.0, 1.0)
    private let staticBatchCellLODMixedColor = simd_float4(1.00, 0.55, 0.15, 1.0)

    private init() {}

    public func collectSnapshot() -> SpatialDebugBoundsSnapshot {
        let settings = SpatialDebugVisualization.shared
        guard settings.enabled else { return SpatialDebugBoundsSnapshot() }

        var snapshot = SpatialDebugBoundsSnapshot()

        if settings.showOctreeLeafBounds {
            let leafSnapshots = OctreeSystem.shared.getLeafNodeSnapshots(
                occupiedOnly: settings.octreeLeafOccupiedOnly
            )
            let visibleSet: Set<EntityID> = settings.octreeLeafColorMode == .culling
                ? RenderPasses.visibleEntitySetSnapshot()
                : Set<EntityID>()

            snapshot.octreeLeafBounds.reserveCapacity(leafSnapshots.count)
            for leaf in leafSnapshots {
                let color: simd_float4
                switch settings.octreeLeafColorMode {
                case .residency:
                    color = residencyColor(for: leaf.entityIds)
                case .culling:
                    color = cullingColor(for: leaf.entityIds, visibleSet: visibleSet)
                case .plain:
                    color = defaultOctreeColor
                }
                snapshot.octreeLeafBounds.append(
                    SpatialDebugBound(bounds: leaf.bounds, color: color)
                )
            }
        }

        if settings.showTileBounds {
            let tileComponentId = getComponentId(for: TileComponent.self)
            let tileEntities = queryEntitiesWithComponentIds([tileComponentId], in: scene)

            snapshot.tileBounds.reserveCapacity(tileEntities.count)
            for entityId in tileEntities {
                guard let tc = scene.get(component: TileComponent.self, for: entityId),
                      let local = scene.get(component: LocalTransformComponent.self, for: entityId)
                else { continue }

                let color = tileResidencyColor(for: tc)
                let bounds = AABB(min: local.boundingBox.min, max: local.boundingBox.max)
                snapshot.tileBounds.append(SpatialDebugBound(bounds: bounds, color: color))
            }
        }

        if settings.showStaticBatchCellBounds {
            let batchGroups = BatchingSystem.shared.batchGroups
            let cellSize = max(BatchingSystem.shared.getBatchCellSize(), 0.01)
            let visibleSet: Set<EntityID> = settings.staticBatchCellColorMode == .culling
                ? RenderPasses.visibleEntitySetSnapshot()
                : Set<EntityID>()

            var cellGroups: [BatchCellID: [BatchGroup]] = [:]
            cellGroups.reserveCapacity(batchGroups.count)
            for group in batchGroups {
                cellGroups[group.cellId, default: []].append(group)
            }

            snapshot.staticBatchCellBounds.reserveCapacity(cellGroups.count)
            for (cellId, groups) in cellGroups {
                guard !groups.isEmpty else { continue }
                let color = staticBatchCellColor(
                    cellId: cellId,
                    for: groups,
                    mode: settings.staticBatchCellColorMode,
                    visibleSet: visibleSet
                )
                snapshot.staticBatchCellBounds.append(
                    SpatialDebugBound(
                        bounds: staticBatchCellBounds(for: cellId, cellSize: cellSize),
                        color: color
                    )
                )
            }
        }

        return snapshot
    }

    private func residencyColor(for entityIds: [EntityID]) -> simd_float4 {
        // Tile stubs take priority — if any entity in this leaf is a tile stub,
        // color the leaf by the tile's streaming + HLOD state.
        for entityId in entityIds {
            guard scene.mask(for: entityId) != nil else { continue }
            guard let tc = scene.get(component: TileComponent.self, for: entityId) else { continue }

            switch tc.state {
            case .parsing:
                return residencyLoadingColor       // yellow — full tile uploading
            case .parsed:
                return residencyLoadedColor        // green  — full geometry visible
            case .failed:
                return tileFailedColor             // magenta — parse failed
            case .unloading:
                return residencyMixedColor         // orange — teardown in progress
            case .unloaded:
                // Tile is unloaded — show HLOD state instead.
                switch tc.hlodState {
                case .loaded:
                    return tileHLODLoadedColor     // cyan — coarse HLOD visible
                case .loading:
                    return tileHLODLoadingColor    // light blue — HLOD uploading
                case .unloading, .unloaded:
                    return residencyUnloadedColor  // red — nothing resident
                }
            }
        }

        // No tile stub in this leaf — fall back to StreamingComponent / LODComponent.
        var hasLoaded = false
        var hasLoading = false
        var hasUnloaded = false

        for entityId in entityIds {
            guard scene.mask(for: entityId) != nil else { continue }

            if let streaming = scene.get(component: StreamingComponent.self, for: entityId) {
                switch streaming.state {
                case .loaded:
                    hasLoaded = true
                case .loading, .unloading:
                    hasLoading = true
                case .unloaded:
                    hasUnloaded = true
                }
            } else if let lod = scene.get(component: LODComponent.self, for: entityId),
                      lod.currentLOD >= 0,
                      lod.currentLOD < lod.lodLevels.count
            {
                switch lod.lodLevels[lod.currentLOD].residencyState {
                case .resident:
                    hasLoaded = true
                case .loading:
                    hasLoading = true
                case .notResident:
                    hasUnloaded = true
                case .unknown:
                    break
                }
            }
        }

        if hasLoading { return residencyLoadingColor }
        if hasLoaded, hasUnloaded { return residencyMixedColor }
        if hasUnloaded { return residencyUnloadedColor }
        if hasLoaded { return residencyLoadedColor }
        return defaultOctreeColor
    }

    private func tileResidencyColor(for tc: TileComponent) -> simd_float4 {
        switch tc.state {
        case .parsing:   return residencyLoadingColor
        case .parsed:    return residencyLoadedColor
        case .failed:    return tileFailedColor
        case .unloading: return residencyMixedColor
        case .unloaded:
            switch tc.hlodState {
            case .loaded:            return tileHLODLoadedColor
            case .loading:           return tileHLODLoadingColor
            case .unloading, .unloaded: return residencyUnloadedColor
            }
        }
    }

    private func cullingColor(for entityIds: [EntityID], visibleSet: Set<EntityID>) -> simd_float4 {
        var hasVisible = false
        var hasCulled = false
        var hasHidden = false

        for entityId in entityIds {
            guard scene.mask(for: entityId) != nil else { continue }
            guard let render = scene.get(component: RenderComponent.self, for: entityId) else { continue }

            if !render.isVisible {
                hasHidden = true
                continue
            }

            if visibleSet.contains(entityId) {
                hasVisible = true
            } else {
                hasCulled = true
            }
        }

        let stateCount = (hasVisible ? 1 : 0) + (hasCulled ? 1 : 0) + (hasHidden ? 1 : 0)
        if stateCount > 1 { return cullingMixedColor }
        if hasVisible { return cullingVisibleColor }
        if hasCulled { return cullingCulledColor }
        if hasHidden { return cullingHiddenColor }
        return defaultOctreeColor
    }

    private func staticBatchCellColor(
        cellId: BatchCellID,
        for groups: [BatchGroup],
        mode: SpatialDebugBatchCellColorMode,
        visibleSet: Set<EntityID>
    ) -> simd_float4 {
        switch mode {
        case .plain:
            return staticBatchCellPlainColor
        case .culling:
            var hasVisible = false
            var hasCulled = false

            for group in groups {
                for entityId in group.entityIds {
                    if visibleSet.contains(entityId) {
                        hasVisible = true
                    } else {
                        hasCulled = true
                    }
                    if hasVisible, hasCulled {
                        return cullingMixedColor
                    }
                }
            }

            if hasVisible { return cullingVisibleColor }
            if hasCulled { return cullingCulledColor }
            return staticBatchCellPlainColor
        case .lod:
            var lodSet: Set<Int> = []
            lodSet.reserveCapacity(groups.count)
            for group in groups {
                lodSet.insert(group.lodIndex)
                if lodSet.count > 1 {
                    return staticBatchCellLODMixedColor
                }
            }

            guard let onlyLOD = lodSet.first else {
                return staticBatchCellPlainColor
            }

            switch onlyLOD {
            case 0:
                return staticBatchCellLOD0Color
            case 1:
                return staticBatchCellLOD1Color
            case 2:
                return staticBatchCellLOD2Color
            default:
                return staticBatchCellLODMixedColor
            }
        case .cell:
            return staticBatchCellColor(for: cellId)
        }
    }

    private func staticBatchCellColor(for cellId: BatchCellID) -> simd_float4 {
        // Stable per-cell pseudo-random hue so neighboring cells are easy to distinguish.
        let x = Int64(cellId.x)
        let y = Int64(cellId.y)
        let z = Int64(cellId.z)
        let signedSeed = (x &* 73_856_093) ^ (y &* 19_349_663) ^ (z &* 83_492_791)
        let seed = UInt64(bitPattern: signedSeed)

        let hue = Float(seed % 360) / 360.0
        let saturation: Float = 0.75
        let value: Float = 0.95
        let rgb = hsvToRgb(h: hue, s: saturation, v: value)
        return simd_float4(rgb.x, rgb.y, rgb.z, 1.0)
    }

    private func hsvToRgb(h: Float, s: Float, v: Float) -> simd_float3 {
        let scaled = h * 6.0
        let sector = Int(floor(scaled)) % 6
        let fraction = scaled - floor(scaled)

        let p = v * (1.0 - s)
        let q = v * (1.0 - fraction * s)
        let t = v * (1.0 - (1.0 - fraction) * s)

        switch sector {
        case 0:
            return simd_float3(v, t, p)
        case 1:
            return simd_float3(q, v, p)
        case 2:
            return simd_float3(p, v, t)
        case 3:
            return simd_float3(p, q, v)
        case 4:
            return simd_float3(t, p, v)
        default:
            return simd_float3(v, p, q)
        }
    }

    private func staticBatchCellBounds(for cellId: BatchCellID, cellSize: Float) -> AABB {
        let minPoint = simd_float3(
            Float(cellId.x) * cellSize,
            Float(cellId.y) * cellSize,
            Float(cellId.z) * cellSize
        )
        let maxPoint = minPoint + simd_float3(repeating: cellSize)
        return AABB(min: minPoint, max: maxPoint)
    }
}

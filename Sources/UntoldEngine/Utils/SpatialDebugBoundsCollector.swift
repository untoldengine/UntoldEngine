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

    public init(octreeLeafBounds: [SpatialDebugBound] = []) {
        self.octreeLeafBounds = octreeLeafBounds
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
    private let cullingVisibleColor = simd_float4(0.25, 0.95, 0.35, 1.0)
    private let cullingCulledColor = simd_float4(0.30, 0.60, 1.00, 1.0)
    private let cullingHiddenColor = simd_float4(0.55, 0.55, 0.55, 1.0)
    private let cullingMixedColor = simd_float4(1.00, 0.55, 0.15, 1.0)

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
                ? Set(visibleEntityIds)
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

        return snapshot
    }

    private func residencyColor(for entityIds: [EntityID]) -> simd_float4 {
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
}

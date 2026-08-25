//
//  PhysicsQuery.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// Scene queries against the physics world.
///
/// `raycast` routes to the active `PhysicsBackend` when it reports the
/// `.raycast` capability, so results come from real collider geometry. With no
/// backend installed — or a backend without the capability — it falls back to a
/// best-effort query against the engine's octree of entity bounds.
///
/// Fallback semantics (documented contract, intentionally approximate):
/// - Hits are entity **AABBs**, not collider shapes; `position`/`normal` are on
///   the box surface (the normal is the hit face's axis direction). A ray that
///   starts inside a box reports the hit at the ray origin with `distance` 0
///   and the normal pointing back along the ray.
/// - `filter.excludedEntities` is always honored. `filter.layerMask` is tested
///   against `RigidBodyComponent.layer` interpreted as a layer *index* (bit
///   `1 << layer` in the mask); entities without a `RigidBodyComponent` are
///   treated as layer 0, and layers ≥ 32 cannot be expressed in the mask and
///   always pass.
/// - Only entities registered with `OctreeSystem` (those with render bounds)
///   are considered.
///
/// Shapecast and overlap queries are deliberately not exposed yet; the
/// capability bits exist so backends can declare them ahead of phase 2.
public enum PhysicsQuery {
    /// Longest segment the octree fallback searches. `PhysicsRay`'s
    /// "unbounded" sentinel is `.greatestFiniteMagnitude` — which is finite —
    /// so the cap is applied with `min`, not a finiteness test; 1e6 m is
    /// comfortably beyond the octree's world bounds.
    static let fallbackUnboundedDistance: Float = 1.0e6

    public static func raycast(
        _ ray: PhysicsRay,
        filter: PhysicsQueryFilter = PhysicsQueryFilter()
    ) -> PhysicsRayHit? {
        if let backend = PhysicsBackendRegistry.shared.activeBackend(),
           backend.capabilities.contains(.raycast)
        {
            return backend.raycast(ray, filter: filter)
        }
        return octreeRaycast(ray, filter: filter)
    }

    // MARK: - Octree fallback

    static func octreeRaycast(
        _ ray: PhysicsRay,
        filter: PhysicsQueryFilter
    ) -> PhysicsRayHit? {
        let directionLength = simd_length(ray.direction)
        guard directionLength > .ulpOfOne else { return nil }
        let direction = ray.direction / directionLength

        let maxDistance = min(ray.maxDistance, fallbackUnboundedDistance)
        guard maxDistance > 0 else { return nil }

        // Tree-pruned broad phase: candidates arrive sorted by their ray-AABB
        // distance. For a ray starting OUTSIDE a box that distance equals the
        // hit distance below, so once it passes the best hit the candidate
        // cannot win and is skipped. For a ray starting INSIDE a box it is
        // the EXIT distance — an upper bound that can sort the box behind
        // farther candidates even though its reported hit distance is 0 — so
        // inside-origin candidates are always examined and the scan never
        // breaks out of the sorted order early.
        var best: PhysicsRayHit?
        for (entity, sortedDistance) in OctreeSystem.shared.query(
            rayOrigin: ray.origin,
            rayDirection: direction,
            maxDistance: maxDistance
        ) {
            guard passesFilter(entity, filter),
                  let bounds = OctreeSystem.shared.getBounds(for: entity)
            else { continue }

            let originInside = ray.origin.x >= bounds.min.x && ray.origin.x <= bounds.max.x
                && ray.origin.y >= bounds.min.y && ray.origin.y <= bounds.max.y
                && ray.origin.z >= bounds.min.z && ray.origin.z <= bounds.max.z
            if let currentBest = best, !originInside,
               sortedDistance >= currentBest.distance
            {
                continue
            }

            // Narrow phase recomputes the entry distance: the broad-phase
            // value is the exit distance for inside-the-box origins, where
            // the documented contract reports the hit at the origin instead.
            var tmin: Float = 0
            guard rayIntersectsAABB(
                rayOrigin: ray.origin,
                rayDir: direction,
                boxMin: bounds.min,
                boxMax: bounds.max,
                tmin: &tmin
            ) else { continue }

            let distance = max(0.0, tmin)
            guard distance <= maxDistance else { continue }
            if let currentBest = best, currentBest.distance <= distance { continue }

            let position = ray.origin + direction * distance
            let normal = distance > 0
                ? boxFaceNormal(at: position, bounds: bounds)
                : -direction
            best = PhysicsRayHit(
                entity: entity,
                position: position,
                normal: normal,
                distance: distance
            )
        }
        return best
    }

    private static func passesFilter(_ entity: EntityID, _ filter: PhysicsQueryFilter) -> Bool {
        if filter.excludedEntities.contains(entity) { return false }
        guard filter.layerMask != .max else { return true }

        let layer = scene.get(component: RigidBodyComponent.self, for: entity)?.layer ?? 0
        guard layer < 32 else { return true }
        return (filter.layerMask >> layer) & 1 != 0
    }

    /// Axis-aligned face normal of the box face nearest to a surface point.
    private static func boxFaceNormal(at point: simd_float3, bounds: AABB) -> simd_float3 {
        let halfExtents = simd_max((bounds.max - bounds.min) * 0.5, simd_float3(repeating: .ulpOfOne))
        let local = (point - bounds.center) / halfExtents

        var normal = simd_float3(local.x < 0 ? -1 : 1, 0, 0)
        var strongest = abs(local.x)
        if abs(local.y) > strongest {
            strongest = abs(local.y)
            normal = simd_float3(0, local.y < 0 ? -1 : 1, 0)
        }
        if abs(local.z) > strongest {
            normal = simd_float3(0, 0, local.z < 0 ? -1 : 1)
        }
        return normal
    }
}

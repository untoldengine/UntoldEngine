//
//  OctreeSystem.swift
//  UntoldEngine
//
//  Created for Geometry Streaming
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
import Foundation
import simd

/// Manages spatial partitioning for the scene
public class OctreeSystem: @unchecked Sendable {
    public static let shared = OctreeSystem()

    private let accessLock = NSRecursiveLock()

    /// World bounds for the octree
    public var worldBounds: AABB {
        get {
            accessLock.lock()
            defer { accessLock.unlock() }
            return _worldBounds
        }
        set {
            accessLock.lock()
            _worldBounds = newValue
            rebuildOctreeLocked()
            accessLock.unlock()
        }
    }

    /// Whether the system is enabled
    public var enabled: Bool {
        get {
            accessLock.lock()
            defer { accessLock.unlock() }
            return _enabled
        }
        set {
            accessLock.lock()
            _enabled = newValue
            accessLock.unlock()
        }
    }

    private var _worldBounds: AABB
    private var _enabled: Bool = true
    private var octree: Octree
    private var registeredEntities: Set<EntityID> = []
    private var dirtyEntities: Set<EntityID> = [] // Entities needing bounds update

    private init() {
        // Default world bounds: 2000 x 2000 x 2000 centered at origin
        let defaultBounds = AABB(
            min: simd_float3(repeating: -1000),
            max: simd_float3(repeating: 1000)
        )
        _worldBounds = defaultBounds
        octree = Octree(
            worldBounds: defaultBounds,
            maxDepth: 8,
            maxEntriesPerLeaf: 16,
            minNodeSize: 1.0
        )
    }

    /// Register an entity with the spatial system
    /// Call this when an entity gets a RenderComponent
    public func registerEntity(_ entityId: EntityID) {
        accessLock.lock()
        defer { accessLock.unlock() }
        guard _enabled else { return }
        guard !registeredEntities.contains(entityId) else { return }

        if let bounds = calculateWorldBounds(for: entityId) {
            octree.insert(entityId: entityId, bounds: bounds)
            registeredEntities.insert(entityId)
        }
    }

    /// Unregister an entity from the spatial system
    /// Call this when an entity is destroyed or loses its RenderComponent
    public func unregisterEntity(_ entityId: EntityID) {
        accessLock.lock()
        defer { accessLock.unlock() }
        guard registeredEntities.contains(entityId) else { return }

        octree.remove(entityId: entityId)
        registeredEntities.remove(entityId)
        dirtyEntities.remove(entityId)
    }

    /// Mark an entity as needing bounds update
    /// Call this when an entity's transform changes
    public func markDirty(_ entityId: EntityID) {
        accessLock.lock()
        defer { accessLock.unlock() }
        guard _enabled else { return }
        guard registeredEntities.contains(entityId) else { return }
        dirtyEntities.insert(entityId)
    }

    /// Update all dirty entity bounds
    /// Call this once per frame, after transforms are updated
    public func updateDirtyBounds() {
        accessLock.lock()
        defer { accessLock.unlock() }
        guard _enabled else { return }

        for entityId in dirtyEntities {
            if let bounds = calculateWorldBounds(for: entityId) {
                octree.update(entityId: entityId, newBounds: bounds)
            }
        }
        dirtyEntities.removeAll(keepingCapacity: true)
    }

    /// Query entities within a radius of the camera
    public func queryNearCamera(radius: Float) -> [EntityID] {
        accessLock.lock()
        defer { accessLock.unlock() }
        guard _enabled else { return [] }
        guard let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
        else { return [] }

        // Entities live in un-shifted world space; transform the camera position by the
        // inverse scene root so the spatial query matches entity positions.
        let effectivePos = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
        let sphere = BoundingSphere(center: effectivePos, radius: radius)
        return octree.query(sphere: sphere)
    }

    /// Query entities within a sphere
    public func query(sphere: BoundingSphere) -> [EntityID] {
        accessLock.lock()
        defer { accessLock.unlock() }
        guard _enabled else { return [] }
        return octree.query(sphere: sphere)
    }

    /// Query entities within a bounding box
    public func query(range: AABB) -> [EntityID] {
        accessLock.lock()
        defer { accessLock.unlock() }
        guard _enabled else { return [] }
        return octree.query(range: range)
    }

    /// Query entities within the frustum
    public func query(frustum: [simd_float4]) -> [EntityID] {
        accessLock.lock()
        defer { accessLock.unlock() }
        guard _enabled else { return [] }
        return octree.query(frustum: frustum)
    }

    /// Query entities within a radius of a point
    public func queryNear(point: simd_float3, radius: Float) -> [EntityID] {
        accessLock.lock()
        defer { accessLock.unlock() }
        guard _enabled else { return [] }
        let sphere = BoundingSphere(center: point, radius: radius)
        return octree.query(sphere: sphere)
    }

    /// Query entities whose AABBs are intersected by a ray.
    /// Returns `(EntityID, Float)` pairs sorted by intersection distance.
    public func query(
        rayOrigin: simd_float3,
        rayDirection: simd_float3,
        maxDistance: Float = .greatestFiniteMagnitude
    ) -> [(EntityID, Float)] {
        accessLock.lock()
        defer { accessLock.unlock() }
        guard _enabled else { return [] }
        return octree.query(rayOrigin: rayOrigin, rayDirection: rayDirection, maxDistance: maxDistance)
    }

    /// Get the stored bounds for an entity
    public func getBounds(for entityId: EntityID) -> AABB? {
        accessLock.lock()
        defer { accessLock.unlock() }
        return octree.getBounds(for: entityId)
    }

    /// Rebuild the entire octree
    /// Useful after loading a new scene or many changes
    public func rebuildOctree() {
        accessLock.lock()
        rebuildOctreeLocked()
        accessLock.unlock()
    }

    private func rebuildOctreeLocked() {
        octree = Octree(
            worldBounds: _worldBounds,
            maxDepth: 8,
            maxEntriesPerLeaf: 16,
            minNodeSize: 1.0
        )

        // Re-insert all registered entities
        for entityId in registeredEntities {
            if let bounds = calculateWorldBounds(for: entityId) {
                octree.insert(entityId: entityId, bounds: bounds)
            }
        }

        dirtyEntities.removeAll()
    }

    /// Clear all spatial data
    public func clear() {
        accessLock.lock()
        defer { accessLock.unlock() }
        octree.clear()
        registeredEntities.removeAll()
        dirtyEntities.removeAll()
    }

    /// Get octree statistics for debugging
    public var stats: OctreeStats {
        accessLock.lock()
        defer { accessLock.unlock() }
        return octree.stats
    }

    /// Snapshot leaf node bounds for debug visualization.
    public func getLeafNodeBounds(occupiedOnly: Bool = true) -> [AABB] {
        accessLock.lock()
        defer { accessLock.unlock() }
        guard _enabled else { return [] }
        return octree.leafNodeBounds(occupiedOnly: occupiedOnly)
    }

    /// Snapshot leaf nodes (bounds + entity IDs) for debug visualization.
    public func getLeafNodeSnapshots(occupiedOnly: Bool = true) -> [OctreeLeafSnapshot] {
        accessLock.lock()
        defer { accessLock.unlock() }
        guard _enabled else { return [] }
        return octree.leafNodeSnapshots(occupiedOnly: occupiedOnly)
    }

    /// Number of registered entities
    public var entityCount: Int {
        accessLock.lock()
        defer { accessLock.unlock() }
        return registeredEntities.count
    }

    /// Calculate world-space bounding box for an entity
    private func calculateWorldBounds(for entityId: EntityID) -> AABB? {
        guard let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId),
              let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId)
        else { return nil }

        // Get local bounds
        let localMin = localTransform.boundingBox.min
        let localMax = localTransform.boundingBox.max

        // Transform to world space
        let (worldMin, worldMax) = worldAABB_MinMax(
            localMin: localMin,
            localMax: localMax,
            worldMatrix: worldTransform.space
        )

        return AABB(min: worldMin, max: worldMax)
    }
}

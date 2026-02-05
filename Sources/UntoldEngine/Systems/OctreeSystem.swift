//
//  OctreeSystem.swift
//  UntoldEngine
//
//  Created for Geometry Streaming
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//
import Foundation
import simd

/// Manages spatial partitioning for the scene
public class OctreeSystem {
    public static let shared = OctreeSystem()

    /// World bounds for the octree
    public var worldBounds: AABB {
        didSet {
            rebuildOctree()
        }
    }

    /// Whether the system is enabled
    public var enabled: Bool = true

    private var octree: Octree
    private var registeredEntities: Set<EntityID> = []
    private var dirtyEntities: Set<EntityID> = [] // Entities needing bounds update

    private init() {
        // Default world bounds: 2000 x 2000 x 2000 centered at origin
        let defaultBounds = AABB(
            min: simd_float3(repeating: -1000),
            max: simd_float3(repeating: 1000)
        )
        worldBounds = defaultBounds
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
        guard enabled else { return }
        guard !registeredEntities.contains(entityId) else { return }

        if let bounds = calculateWorldBounds(for: entityId) {
            octree.insert(entityId: entityId, bounds: bounds)
            registeredEntities.insert(entityId)
        }
    }

    /// Unregister an entity from the spatial system
    /// Call this when an entity is destroyed or loses its RenderComponent
    public func unregisterEntity(_ entityId: EntityID) {
        guard registeredEntities.contains(entityId) else { return }

        octree.remove(entityId: entityId)
        registeredEntities.remove(entityId)
        dirtyEntities.remove(entityId)
    }

    /// Mark an entity as needing bounds update
    /// Call this when an entity's transform changes
    public func markDirty(_ entityId: EntityID) {
        guard enabled else { return }
        guard registeredEntities.contains(entityId) else { return }
        dirtyEntities.insert(entityId)
    }

    /// Update all dirty entity bounds
    /// Call this once per frame, after transforms are updated
    public func updateDirtyBounds() {
        guard enabled else { return }

        for entityId in dirtyEntities {
            if let bounds = calculateWorldBounds(for: entityId) {
                octree.update(entityId: entityId, newBounds: bounds)
            }
        }
        dirtyEntities.removeAll(keepingCapacity: true)
    }

    /// Query entities within a radius of the camera
    public func queryNearCamera(radius: Float) -> [EntityID] {
        guard enabled else { return [] }
        guard let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
        else { return [] }

        let sphere = BoundingSphere(center: cameraComponent.localPosition, radius: radius)
        return octree.query(sphere: sphere)
    }

    /// Query entities within a sphere
    public func query(sphere: BoundingSphere) -> [EntityID] {
        guard enabled else { return [] }
        return octree.query(sphere: sphere)
    }

    /// Query entities within a bounding box
    public func query(range: AABB) -> [EntityID] {
        guard enabled else { return [] }
        return octree.query(range: range)
    }

    /// Query entities within the frustum
    public func query(frustum: [simd_float4]) -> [EntityID] {
        guard enabled else { return [] }
        return octree.query(frustum: frustum)
    }

    /// Query entities within a radius of a point
    public func queryNear(point: simd_float3, radius: Float) -> [EntityID] {
        guard enabled else { return [] }
        let sphere = BoundingSphere(center: point, radius: radius)
        return octree.query(sphere: sphere)
    }

    /// Get the stored bounds for an entity
    public func getBounds(for entityId: EntityID) -> AABB? {
        octree.getBounds(for: entityId)
    }

    /// Rebuild the entire octree
    /// Useful after loading a new scene or many changes
    public func rebuildOctree() {
        octree = Octree(
            worldBounds: worldBounds,
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
        octree.clear()
        registeredEntities.removeAll()
        dirtyEntities.removeAll()
    }

    /// Get octree statistics for debugging
    public var stats: OctreeStats {
        octree.stats
    }

    /// Number of registered entities
    public var entityCount: Int {
        registeredEntities.count
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

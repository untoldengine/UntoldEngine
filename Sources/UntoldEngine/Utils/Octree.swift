//
//  Octree.swift
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

/// Entry stored in the Octree
public struct OctreeEntry {
    public let entityId: EntityID
    public var bounds: AABB

    public init(entityId: EntityID, bounds: AABB) {
        self.entityId = entityId
        self.bounds = bounds
    }
}

/// A node in the Octree
public class OctreeNode {
    public var bounds: AABB
    public var children: [OctreeNode]? // nil means leaf node
    public var entries: [OctreeEntry] // Only populated in leaf nodes
    public let depth: Int

    public init(bounds: AABB, depth: Int) {
        self.bounds = bounds
        self.depth = depth
        entries = []
        children = nil
    }

    /// Check if this is a leaf node
    public var isLeaf: Bool {
        children == nil
    }

    /// Total entries in this node and all descendants
    public var totalEntryCount: Int {
        if isLeaf {
            return entries.count
        }
        return children?.reduce(0) { $0 + $1.totalEntryCount } ?? 0
    }
}

/// Octree spatial data structure for efficient 3D queries
public class Octree {
    // MARK: - Configuration

    /// Maximum depth of the tree (prevents infinite subdivision)
    public let maxDepth: Int

    /// Maximum entries per leaf before subdivision
    public let maxEntriesPerLeaf: Int

    /// Minimum node size (prevents tiny nodes)
    public let minNodeSize: Float

    // MARK: - State

    public private(set) var root: OctreeNode
    private var entityToNode: [EntityID: OctreeNode] = [:]
    private var entityToBounds: [EntityID: AABB] = [:]
    public private(set) var entryCount: Int = 0

    // MARK: - Initialization

    /// Create an Octree with specified world bounds
    /// - Parameters:
    ///   - worldBounds: The total bounds of the world
    ///   - maxDepth: Maximum tree depth (default: 8)
    ///   - maxEntriesPerLeaf: Entries before subdivision (default: 16)
    ///   - minNodeSize: Minimum node dimension (default: 1.0)
    public init(
        worldBounds: AABB,
        maxDepth: Int = 8,
        maxEntriesPerLeaf: Int = 16,
        minNodeSize: Float = 1.0
    ) {
        self.maxDepth = maxDepth
        self.maxEntriesPerLeaf = maxEntriesPerLeaf
        self.minNodeSize = minNodeSize
        root = OctreeNode(bounds: worldBounds, depth: 0)
    }

    /// Create with default world bounds (-1000 to 1000 in all axes)
    public convenience init() {
        let defaultBounds = AABB(
            min: simd_float3(repeating: -1000),
            max: simd_float3(repeating: 1000)
        )
        self.init(worldBounds: defaultBounds)
    }

    // MARK: - Public API

    /// Insert an entity with its bounding box
    public func insert(entityId: EntityID, bounds: AABB) {
        // Remove if already exists (handles updates)
        if entityToBounds[entityId] != nil {
            remove(entityId: entityId)
        }

        let entry = OctreeEntry(entityId: entityId, bounds: bounds)
        insertEntry(entry, into: root)
        entityToBounds[entityId] = bounds
        entryCount += 1
    }

    /// Remove an entity from the tree
    @discardableResult
    public func remove(entityId: EntityID) -> Bool {
        guard let node = entityToNode[entityId] else {
            return false
        }

        node.entries.removeAll { $0.entityId == entityId }
        entityToNode.removeValue(forKey: entityId)
        entityToBounds.removeValue(forKey: entityId)
        entryCount -= 1
        return true
    }

    /// Update an entity's bounds (removes and re-inserts)
    public func update(entityId: EntityID, newBounds: AABB) {
        remove(entityId: entityId)
        insert(entityId: entityId, bounds: newBounds)
    }

    /// Query all entities within a bounding box
    public func query(range: AABB) -> [EntityID] {
        var results: [EntityID] = []
        queryNode(root, range: range, results: &results)
        return results
    }

    /// Query all entities within a sphere
    public func query(sphere: BoundingSphere) -> [EntityID] {
        var results: [EntityID] = []
        queryNode(root, sphere: sphere, results: &results)
        return results
    }

    /// Query all entities that intersect the frustum planes
    public func query(frustum: [simd_float4]) -> [EntityID] {
        var results: [EntityID] = []
        queryNode(root, frustum: frustum, results: &results)
        return results
    }

    /// Query all entities whose AABBs are intersected by a ray.
    /// Returns `(EntityID, Float)` pairs sorted by intersection distance.
    public func query(
        rayOrigin: simd_float3,
        rayDirection: simd_float3,
        maxDistance: Float = .greatestFiniteMagnitude
    ) -> [(EntityID, Float)] {
        var results: [(EntityID, Float)] = []
        queryNode(root, rayOrigin: rayOrigin, rayDirection: rayDirection, maxDistance: maxDistance, results: &results)
        results.sort { $0.1 < $1.1 }
        return results
    }

    /// Get the bounds of a stored entity
    public func getBounds(for entityId: EntityID) -> AABB? {
        entityToBounds[entityId]
    }

    /// Check if an entity exists in the tree
    public func contains(entityId: EntityID) -> Bool {
        entityToNode[entityId] != nil
    }

    /// Clear all entries from the tree
    public func clear() {
        root = OctreeNode(bounds: root.bounds, depth: 0)
        entityToNode.removeAll()
        entityToBounds.removeAll()
        entryCount = 0
    }

    /// Rebuild the tree (useful after many removals)
    public func rebuild() {
        let allEntries = entityToBounds
        clear()
        for (entityId, bounds) in allEntries {
            insert(entityId: entityId, bounds: bounds)
        }
    }

    // MARK: - Private Implementation

    private func insertEntry(_ entry: OctreeEntry, into node: OctreeNode) {
        // If not a leaf, find a child that fully contains the entry
        if let children = node.children {
            for child in children {
                if child.bounds.contains(entry.bounds) {
                    insertEntry(entry, into: child)
                    return
                }
            }
            // Entry spans multiple children, store at this level
            node.entries.append(entry)
            entityToNode[entry.entityId] = node
            return
        }

        // It's a leaf node
        node.entries.append(entry)
        entityToNode[entry.entityId] = node

        // Check if we need to subdivide
        if shouldSubdivide(node) {
            subdivide(node)
        }
    }

    private func shouldSubdivide(_ node: OctreeNode) -> Bool {
        // Don't subdivide if at max depth
        if node.depth >= maxDepth {
            return false
        }

        // Don't subdivide if node is too small
        let nodeSize = node.bounds.size
        if nodeSize.x < minNodeSize * 2 ||
            nodeSize.y < minNodeSize * 2 ||
            nodeSize.z < minNodeSize * 2
        {
            return false
        }

        // Subdivide if too many entries
        return node.entries.count > maxEntriesPerLeaf
    }

    private func subdivide(_ node: OctreeNode) {
        let childBounds = node.bounds.subdivide()
        node.children = childBounds.map { OctreeNode(bounds: $0, depth: node.depth + 1) }

        // Re-insert entries into children
        let entries = node.entries
        node.entries = []

        for entry in entries {
            entityToNode.removeValue(forKey: entry.entityId)
            insertEntry(entry, into: node)
        }
    }

    private func queryNode(_ node: OctreeNode, range: AABB, results: inout [EntityID]) {
        // Early out if range doesn't intersect this node
        guard node.bounds.intersects(range) else {
            return
        }

        // Check entries at this node
        for entry in node.entries {
            if entry.bounds.intersects(range) {
                results.append(entry.entityId)
            }
        }

        // Recurse into children
        if let children = node.children {
            for child in children {
                queryNode(child, range: range, results: &results)
            }
        }
    }

    private func queryNode(_ node: OctreeNode, sphere: BoundingSphere, results: inout [EntityID]) {
        // Early out if sphere doesn't intersect this node
        guard node.bounds.intersects(sphere) else {
            return
        }

        // Check entries at this node
        for entry in node.entries {
            if entry.bounds.intersects(sphere) {
                results.append(entry.entityId)
            }
        }

        // Recurse into children
        if let children = node.children {
            for child in children {
                queryNode(child, sphere: sphere, results: &results)
            }
        }
    }

    private func queryNode(
        _ node: OctreeNode,
        rayOrigin: simd_float3,
        rayDirection: simd_float3,
        maxDistance: Float,
        results: inout [(EntityID, Float)]
    ) {
        // Early out if ray doesn't intersect this node's AABB
        guard let _ = rayAABBIntersectionDistance(
            rayOrigin: rayOrigin,
            rayDirection: rayDirection,
            minBounds: node.bounds.min,
            maxBounds: node.bounds.max
        ) else {
            return
        }

        // Check entries stored at this node
        for entry in node.entries {
            if let distance = rayAABBIntersectionDistance(
                rayOrigin: rayOrigin,
                rayDirection: rayDirection,
                minBounds: entry.bounds.min,
                maxBounds: entry.bounds.max
            ), distance <= maxDistance {
                results.append((entry.entityId, distance))
            }
        }

        // Recurse into children
        if let children = node.children {
            for child in children {
                queryNode(child, rayOrigin: rayOrigin, rayDirection: rayDirection, maxDistance: maxDistance, results: &results)
            }
        }
    }

    private func queryNode(_ node: OctreeNode, frustum: [simd_float4], results: inout [EntityID]) {
        // Early out if node is outside frustum
        guard isAABBInFrustum(node.bounds, frustum: frustum) else {
            return
        }

        // Check entries at this node
        for entry in node.entries {
            if isAABBInFrustum(entry.bounds, frustum: frustum) {
                results.append(entry.entityId)
            }
        }

        // Recurse into children
        if let children = node.children {
            for child in children {
                queryNode(child, frustum: frustum, results: &results)
            }
        }
    }

    /// Frustum-AABB intersection test
    private func isAABBInFrustum(_ aabb: AABB, frustum: [simd_float4]) -> Bool {
        for plane in frustum {
            let normal = simd_float3(plane.x, plane.y, plane.z)
            let d = plane.w

            // Find the positive vertex (furthest along plane normal)
            let pVertex = simd_float3(
                normal.x >= 0 ? aabb.max.x : aabb.min.x,
                normal.y >= 0 ? aabb.max.y : aabb.min.y,
                normal.z >= 0 ? aabb.max.z : aabb.min.z
            )

            // If positive vertex is outside, the entire AABB is outside
            if simd_dot(normal, pVertex) + d < 0 {
                return false
            }
        }
        return true
    }
}

// MARK: - Debug Helpers

extension Octree {
    /// Snapshot leaf node bounds.
    /// - Parameter occupiedOnly: When true, returns only leaf nodes containing entries.
    public func leafNodeBounds(occupiedOnly: Bool = true) -> [AABB] {
        var bounds: [AABB] = []
        gatherLeafBounds(node: root, occupiedOnly: occupiedOnly, bounds: &bounds)
        return bounds
    }

    /// Snapshot leaf node bounds with contained entity IDs.
    /// - Parameter occupiedOnly: When true, returns only leaf nodes containing entries.
    public func leafNodeSnapshots(occupiedOnly: Bool = true) -> [OctreeLeafSnapshot] {
        var snapshots: [OctreeLeafSnapshot] = []
        gatherLeafSnapshots(node: root, occupiedOnly: occupiedOnly, snapshots: &snapshots)
        return snapshots
    }

    private func gatherLeafBounds(node: OctreeNode, occupiedOnly: Bool, bounds: inout [AABB]) {
        if node.isLeaf {
            if occupiedOnly == false || node.entries.isEmpty == false {
                bounds.append(node.bounds)
            }
            return
        }

        for child in node.children ?? [] {
            gatherLeafBounds(node: child, occupiedOnly: occupiedOnly, bounds: &bounds)
        }
    }

    private func gatherLeafSnapshots(node: OctreeNode, occupiedOnly: Bool, snapshots: inout [OctreeLeafSnapshot]) {
        if node.isLeaf {
            let entityIds = node.entries.map(\.entityId)
            if occupiedOnly == false || entityIds.isEmpty == false {
                snapshots.append(OctreeLeafSnapshot(bounds: node.bounds, entityIds: entityIds))
            }
            return
        }

        for child in node.children ?? [] {
            gatherLeafSnapshots(node: child, occupiedOnly: occupiedOnly, snapshots: &snapshots)
        }
    }

    /// Get statistics about the tree
    public var stats: OctreeStats {
        var stats = OctreeStats()
        gatherStats(node: root, stats: &stats)
        return stats
    }

    private func gatherStats(node: OctreeNode, stats: inout OctreeStats) {
        stats.nodeCount += 1
        stats.maxDepth = max(stats.maxDepth, node.depth)

        if node.isLeaf {
            stats.leafCount += 1
            stats.entriesInLeaves += node.entries.count
            stats.maxEntriesInLeaf = max(stats.maxEntriesInLeaf, node.entries.count)
        } else {
            stats.entriesInBranches += node.entries.count
            for child in node.children ?? [] {
                gatherStats(node: child, stats: &stats)
            }
        }
    }
}

public struct OctreeLeafSnapshot {
    public var bounds: AABB
    public var entityIds: [EntityID]

    public init(bounds: AABB, entityIds: [EntityID]) {
        self.bounds = bounds
        self.entityIds = entityIds
    }
}

public struct OctreeStats {
    public var nodeCount: Int = 0
    public var leafCount: Int = 0
    public var maxDepth: Int = 0
    public var entriesInLeaves: Int = 0
    public var entriesInBranches: Int = 0
    public var maxEntriesInLeaf: Int = 0

    public var totalEntries: Int {
        entriesInLeaves + entriesInBranches
    }

    public var averageEntriesPerLeaf: Float {
        leafCount > 0 ? Float(entriesInLeaves) / Float(leafCount) : 0
    }
}

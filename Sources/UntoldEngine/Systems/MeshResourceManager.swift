
//
//  MeshResourceManager.swift
//  Untold Engine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// Cached mesh resource for a USDZ file with all its meshes
public struct MeshResource {
    /// All meshes from this file, keyed by asset name
    /// e.g., "wall_01" -> [Mesh], "pillar_01" -> [Mesh]
    public var meshesByName: [String: [Mesh]]

    /// Reference count per mesh name (how many entities use each)
    public var refCountByName: [String: Int]

    /// Total GPU memory size in bytes for all meshes
    public var totalMemorySize: Int

    /// Original source URL
    public var sourceURL: URL

    /// Frame number when this resource was last accessed
    public var lastAccessFrame: Int

    /// Total reference count (sum of all mesh refs)
    public var totalRefCount: Int {
        refCountByName.values.reduce(0, +)
    }

    /// Check if any mesh is still in use
    public var isInUse: Bool {
        totalRefCount > 0
    }
}

/// Manages mesh resources with reference counting for efficient memory usage
public class MeshResourceManager: @unchecked Sendable {
    public static let shared = MeshResourceManager()

    /// URL -> MeshResource mapping (caches entire USDZ files)
    private var resources: [URL: MeshResource] = [:]

    /// EntityID -> (URL, meshName) mapping (tracks which entity uses which specific mesh)
    private var entityToMesh: [EntityID: (url: URL, meshName: String)] = [:]

    /// Tracks in-flight file loads so concurrent callers for the same URL share a single parse/load.
    private var inFlightLoadWaiters: [URL: [CheckedContinuation<Bool, Never>]] = [:]

    /// Thread-safe access queue
    private let accessQueue = DispatchQueue(label: "com.untoldengine.meshresource", attributes: .concurrent)

    /// Current frame number (updated by streaming system)
    public var currentFrame: Int = 0

    private init() {}
}

// MARK: - Loading

public extension MeshResourceManager {
    /// Load a specific mesh by name from a USDZ file
    /// If file not cached, loads entire file and caches all meshes
    /// - Parameters:
    ///   - url: The USDZ file URL
    ///   - meshName: The specific mesh name to retrieve (e.g., "wall_01")
    /// - Returns: The mesh array for the requested mesh name, or nil if not found
    func loadMesh(url: URL, meshName: String) async -> [Mesh]? {
        // Check cache first
        if let cached = getCachedMesh(url: url, meshName: meshName) {
            updateAccessTime(url: url)
            return cached
        }

        // Not cached - load entire USDZ and cache all meshes
        await loadAndCacheFile(url: url)

        // Now retrieve the specific mesh
        return getCachedMesh(url: url, meshName: meshName)
    }

    /// Load entire USDZ file and cache all meshes by name
    private func loadAndCacheFile(url: URL) async {
        // Single-flight gate: one loader per URL; all other callers await completion.
        let shouldLoad = await waitForExistingLoadOrBecomeLoader(url: url)
        guard shouldLoad else {
            return
        }
        defer { finishInFlightLoad(url: url) }

        // Load all meshes from file
        let meshArrays = await Mesh.loadSceneMeshesAsync(
            url: url,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            coordinateConversion: .autoDetect
        )

        guard !meshArrays.isEmpty else { return }

        // Build mesh dictionary keyed by asset name
        var meshesByName: [String: [Mesh]] = [:]
        var totalMemory = 0

        for meshArray in meshArrays {
            guard let firstMesh = meshArray.first else { continue }
            let name = firstMesh.assetName
            meshesByName[name] = meshArray
            totalMemory += meshArray.reduce(0) { $0 + calculateMeshMemory($1) }
        }

        guard !meshesByName.isEmpty else { return }

        // Cache the resource (preserve any existing refCounts from retain calls)
        accessQueue.sync(flags: .barrier) {
            let existingRefCounts = self.resources[url]?.refCountByName ?? [:]
            self.resources[url] = MeshResource(
                meshesByName: meshesByName,
                refCountByName: existingRefCounts,
                totalMemorySize: totalMemory,
                sourceURL: url,
                lastAccessFrame: self.currentFrame
            )
        }
    }

    /// Get cached mesh (thread-safe)
    private func getCachedMesh(url: URL, meshName: String) -> [Mesh]? {
        accessQueue.sync {
            resources[url]?.meshesByName[meshName]
        }
    }

    /// Update last access time (thread-safe)
    private func updateAccessTime(url: URL) {
        accessQueue.async(flags: .barrier) {
            self.resources[url]?.lastAccessFrame = self.currentFrame
        }
    }

    /// Get cached mesh for an entity
    func getMesh(for entityId: EntityID) -> [Mesh]? {
        accessQueue.sync {
            guard let mapping = entityToMesh[entityId],
                  let resource = resources[mapping.url]
            else {
                return nil
            }
            return resource.meshesByName[mapping.meshName]
        }
    }

    /// Check if a file is already cached
    func isCached(url: URL) -> Bool {
        accessQueue.sync { resources[url] != nil }
    }

    /// Get all mesh names in a cached file
    func getMeshNames(url: URL) -> [String] {
        accessQueue.sync {
            resources[url].map { Array($0.meshesByName.keys) } ?? []
        }
    }

    /// Cache pre-loaded meshes (call this from setEntityMeshAsync to populate cache)
    /// This allows streaming to use cached data instead of reloading from disk
    func cacheLoadedMeshes(url: URL, meshArrays: [[Mesh]]) {
        // Build mesh dictionary keyed by asset name
        var meshesByName: [String: [Mesh]] = [:]
        var totalMemory = 0

        for meshArray in meshArrays {
            guard let firstMesh = meshArray.first else { continue }
            let name = firstMesh.assetName
            meshesByName[name] = meshArray
            totalMemory += meshArray.reduce(0) { $0 + calculateMeshMemory($1) }
        }

        guard !meshesByName.isEmpty else { return }

        // Cache the resource (preserve any existing refCounts) and wake any waiters.
        let waiters: [CheckedContinuation<Bool, Never>] = accessQueue.sync(flags: .barrier) {
            if self.resources[url]?.meshesByName.isEmpty == false {
                return []
            }

            let existingRefCounts = self.resources[url]?.refCountByName ?? [:]
            self.resources[url] = MeshResource(
                meshesByName: meshesByName,
                refCountByName: existingRefCounts,
                totalMemorySize: totalMemory,
                sourceURL: url,
                lastAccessFrame: self.currentFrame
            )
            return self.inFlightLoadWaiters.removeValue(forKey: url) ?? []
        }

        for waiter in waiters {
            waiter.resume(returning: false)
        }
    }
}

// MARK: - In-Flight Coordination

private extension MeshResourceManager {
    /// Returns true if the caller should perform the file load; false if it should wait/return.
    func waitForExistingLoadOrBecomeLoader(url: URL) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            accessQueue.sync(flags: .barrier) {
                if self.resources[url]?.meshesByName.isEmpty == false {
                    continuation.resume(returning: false)
                    return
                }

                if self.inFlightLoadWaiters[url] != nil {
                    self.inFlightLoadWaiters[url]!.append(continuation)
                    return
                }

                // First caller becomes loader.
                self.inFlightLoadWaiters[url] = []
                continuation.resume(returning: true)
            }
        }
    }

    func finishInFlightLoad(url: URL) {
        let waiters: [CheckedContinuation<Bool, Never>] = accessQueue.sync(flags: .barrier) {
            self.inFlightLoadWaiters.removeValue(forKey: url) ?? []
        }
        for waiter in waiters {
            waiter.resume(returning: false)
        }
    }
}

// MARK: - Reference Counting

public extension MeshResourceManager {
    /// Retain a specific mesh for an entity
    /// Call this when an entity starts using a mesh
    func retain(url: URL, meshName: String, for entityId: EntityID) {
        accessQueue.async(flags: .barrier) {
            // Release any existing mesh first
            if self.entityToMesh[entityId] != nil {
                self.releaseInternal(entityId: entityId)
            }

            // Map entity to mesh
            self.entityToMesh[entityId] = (url: url, meshName: meshName)

            // Create resource entry if it doesn't exist (for ref counting before load completes)
            if self.resources[url] == nil {
                self.resources[url] = MeshResource(
                    meshesByName: [:],
                    refCountByName: [:],
                    totalMemorySize: 0,
                    sourceURL: url,
                    lastAccessFrame: self.currentFrame
                )
            }

            // Increment ref count for this specific mesh
            let currentCount = self.resources[url]!.refCountByName[meshName] ?? 0
            self.resources[url]!.refCountByName[meshName] = currentCount + 1
            self.resources[url]!.lastAccessFrame = self.currentFrame
        }
    }

    /// Release a mesh from an entity
    func release(entityId: EntityID) {
        accessQueue.async(flags: .barrier) {
            self.releaseInternal(entityId: entityId)
        }
    }

    /// Internal release (must be called within barrier)
    private func releaseInternal(entityId: EntityID) {
        guard let mapping = entityToMesh[entityId] else { return }

        entityToMesh.removeValue(forKey: entityId)

        if resources[mapping.url] != nil {
            let currentCount = resources[mapping.url]!.refCountByName[mapping.meshName] ?? 0
            if currentCount > 0 {
                resources[mapping.url]!.refCountByName[mapping.meshName] = currentCount - 1
            }
        }
    }

    /// Check if entity has a retained mesh
    func hasRetainedMesh(entityId: EntityID) -> Bool {
        accessQueue.sync {
            entityToMesh[entityId] != nil
        }
    }

    /// Get total reference count for a file
    func getTotalRefCount(url: URL) -> Int {
        accessQueue.sync {
            resources[url]?.totalRefCount ?? 0
        }
    }
}

// MARK: - Eviction

public extension MeshResourceManager {
    /// Check if a file's meshes can be safely evicted (no references)
    func canEvict(url: URL) -> Bool {
        accessQueue.sync {
            guard let resource = resources[url] else { return false }
            return !resource.isInUse
        }
    }

    /// Evict a file's meshes (only if no references)
    @discardableResult
    func evict(url: URL) -> Bool {
        var evicted = false

        accessQueue.sync(flags: .barrier) {
            guard let resource = resources[url], !resource.isInUse else {
                return
            }

            // Clean up GPU resources
            for (_, meshArray) in resource.meshesByName {
                for var mesh in meshArray {
                    mesh.cleanUp()
                }
            }

            resources.removeValue(forKey: url)
            evicted = true
        }

        return evicted
    }

    /// Evict all unused cached files
    @discardableResult
    func evictUnused() -> Int {
        var evictedCount = 0

        accessQueue.sync(flags: .barrier) {
            let toEvict = resources.filter { !$0.value.isInUse }.map(\.key)

            for url in toEvict {
                if let resource = resources[url] {
                    // Clean up GPU resources
                    for (_, meshArray) in resource.meshesByName {
                        for var mesh in meshArray {
                            mesh.cleanUp()
                        }
                    }
                    resources.removeValue(forKey: url)
                    evictedCount += 1
                }
            }
        }

        return evictedCount
    }

    /// Evict files until target memory is freed (LRU order)
    @discardableResult
    func evictToFreeMemory(targetBytes: Int) -> Int {
        var freedBytes = 0

        accessQueue.sync(flags: .barrier) {
            let candidates = resources
                .filter { !$0.value.isInUse }
                .sorted { $0.value.lastAccessFrame < $1.value.lastAccessFrame }

            for (url, resource) in candidates {
                guard freedBytes < targetBytes else { break }

                for (_, meshArray) in resource.meshesByName {
                    for var mesh in meshArray {
                        mesh.cleanUp()
                    }
                }
                resources.removeValue(forKey: url)
                freedBytes += resource.totalMemorySize
            }
        }

        return freedBytes
    }
}

// MARK: - Queries

public extension MeshResourceManager {
    /// Get total memory used by all cached meshes
    func getMemoryUsage() -> Int {
        accessQueue.sync {
            resources.values.reduce(0) { $0 + $1.totalMemorySize }
        }
    }

    /// Get number of cached mesh resources
    func getResourceCount() -> Int {
        accessQueue.sync {
            resources.count
        }
    }

    /// Get number of active references (entities using meshes)
    func getActiveReferenceCount() -> Int {
        accessQueue.sync {
            entityToMesh.count
        }
    }

    /// Get detailed stats
    func getStats() -> MeshResourceStats {
        accessQueue.sync {
            let totalMemory = resources.values.reduce(0) { $0 + $1.totalMemorySize }
            let totalRefs = resources.values.reduce(0) { $0 + $1.totalRefCount }
            let evictable = resources.values.filter { $0.totalRefCount == 0 }.count

            return MeshResourceStats(
                cachedMeshCount: resources.count,
                totalMemoryBytes: totalMemory,
                totalReferences: totalRefs,
                evictableCount: evictable,
                activeEntities: entityToMesh.count
            )
        }
    }

    /// Clear all resources (use with caution!)
    func clearAll() {
        accessQueue.async(flags: .barrier) {
            self.resources.removeAll()
            self.entityToMesh.removeAll()
        }
    }
}

/// Statistics for mesh resource manager
public struct MeshResourceStats {
    public var cachedMeshCount: Int
    public var totalMemoryBytes: Int
    public var totalReferences: Int
    public var evictableCount: Int
    public var activeEntities: Int
}

/// Calculate GPU memory size for a mesh
private func calculateMeshMemory(_ mesh: Mesh) -> Int {
    var size = 0

    // Vertex buffer
    if let vertexBuffer = mesh.metalKitMesh.vertexBuffers.first {
        size += vertexBuffer.buffer.length
    }

    // Index buffers (submeshes)
    for submesh in mesh.metalKitMesh.submeshes {
        size += submesh.indexBuffer.buffer.length
    }

    return size
}

//
//  MemoryBudgetManager.swift
//  UntoldEngine
//
//  Created for Geometry Streaming
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal
import simd

/// Current memory usage statistics
public struct MemoryStats {
    /// Mesh geometry memory in bytes
    public var meshMemoryUsed: Int

    /// Texture memory in bytes (tracked separately)
    public var textureMemoryUsed: Int

    /// Total tracked GPU memory
    public var totalTrackedMemory: Int {
        meshMemoryUsed + textureMemoryUsed
    }

    /// Configured budget limit in bytes
    public var budgetLimit: Int

    /// Current utilization as percentage (0.0 - 1.0+)
    public var utilizationPercent: Float {
        guard budgetLimit > 0 else { return 0 }
        return Float(totalTrackedMemory) / Float(budgetLimit)
    }

    /// Number of entities currently tracked
    public var trackedEntityCount: Int

    /// Memory available before hitting budget
    public var availableMemory: Int {
        max(0, budgetLimit - totalTrackedMemory)
    }

    /// Whether memory pressure is high
    public var isUnderPressure: Bool {
        utilizationPercent >= 0.85
    }

    public init(
        meshMemoryUsed: Int = 0,
        textureMemoryUsed: Int = 0,
        budgetLimit: Int = 0,
        trackedEntityCount: Int = 0
    ) {
        self.meshMemoryUsed = meshMemoryUsed
        self.textureMemoryUsed = textureMemoryUsed
        self.budgetLimit = budgetLimit
        self.trackedEntityCount = trackedEntityCount
    }
}

// MARK: - Memory Entry

/// Tracks memory usage for a single entity
struct MemoryEntry {
    let entityId: EntityID
    var meshSizeBytes: Int
    var textureSizeBytes: Int
    var lastUsedFrame: UInt64
    var registrationFrame: UInt64

    var totalSize: Int {
        meshSizeBytes + textureSizeBytes
    }
}

// MARK: - Memory Budget Manager

/// Manages GPU memory budget for geometry streaming
public class MemoryBudgetManager: @unchecked Sendable {
    public static let shared = MemoryBudgetManager()

    // MARK: - Configuration

    /// Maximum mesh memory budget in bytes (default: 512 MB)
    public var meshBudget: Int = 512 * 1024 * 1024 {
        didSet {
            Logger.log(message: "MemoryBudgetManager: Budget set to \(meshBudget.formattedAsMemory)")
        }
    }

    /// Start evicting when utilization reaches this threshold (default: 85%)
    public var highWaterMark: Float = 0.85

    /// Evict down to this utilization level (default: 70%)
    public var lowWaterMark: Float = 0.70

    /// Whether the manager is enabled
    public var enabled: Bool = true

    // MARK: - State

    /// Memory entries indexed by entity ID
    private var memoryEntries: [EntityID: MemoryEntry] = [:]

    /// Current frame counter for LRU tracking
    private var currentFrame: UInt64 = 0

    /// Total mesh memory currently tracked
    private var totalMeshMemory: Int = 0

    /// Total texture memory currently tracked
    private var totalTextureMemory: Int = 0

    /// In-flight texture upgrade reservations.
    ///
    /// When `TextureStreamingSystem` accepts a budget check for an upgrade batch, it
    /// atomically reserves the estimated bytes here before spawning the async Task.
    /// Subsequent concurrent `canAcceptTexture` / `reserveTexture` checks include this
    /// value so they see the already-committed headroom and cannot collectively overshoot
    /// the budget. The reservation is released (and replaced by actual bytes via
    /// `updateTextureSizeBytes`) once the async work completes or fails.
    private var inFlightTextureReservation: Int = 0

    /// Thread safety lock
    private let lock = NSLock()

    // MARK: - Initialization

    private init() {
        // Attempt to set budget based on device capabilities
        configureDefaultBudget()
    }

    /// Configure budget based on device GPU memory
    private func configureDefaultBudget() {
        // Metal doesn't expose total GPU memory directly
        // Use conservative defaults based on typical device classes
        #if os(macOS)
            // macOS typically has more GPU memory
            meshBudget = 1024 * 1024 * 1024 // 1 GB
        #elseif os(iOS)
            // iOS devices vary widely, use conservative default
            if ProcessInfo.processInfo.physicalMemory > 4 * 1024 * 1024 * 1024 {
                meshBudget = 512 * 1024 * 1024 // 512 MB for high-end
            } else {
                meshBudget = 256 * 1024 * 1024 // 256 MB for lower-end
            }
        #else
            meshBudget = 512 * 1024 * 1024 // 512 MB default
        #endif
    }

    // MARK: - Frame Management

    /// Call at the start of each frame to update internal counters
    public func beginFrame() {
        currentFrame += 1
    }

    // MARK: - Registration

    /// Register a mesh's memory usage for an entity
    /// - Parameters:
    ///   - entityId: The entity owning the mesh
    ///   - meshSizeBytes: Size of mesh geometry in bytes
    ///   - textureSizeBytes: Size of textures in bytes (optional)
    public func registerMesh(entityId: EntityID, meshSizeBytes: Int, textureSizeBytes: Int = 0) {
        guard enabled else { return }

        lock.lock()
        defer { lock.unlock() }

        // Remove existing entry if present (handles updates)
        if let existing = memoryEntries[entityId] {
            totalMeshMemory -= existing.meshSizeBytes
            totalTextureMemory -= existing.textureSizeBytes
        }

        let entry = MemoryEntry(
            entityId: entityId,
            meshSizeBytes: meshSizeBytes,
            textureSizeBytes: textureSizeBytes,
            lastUsedFrame: currentFrame,
            registrationFrame: currentFrame
        )

        memoryEntries[entityId] = entry
        totalMeshMemory += meshSizeBytes
        totalTextureMemory += textureSizeBytes
    }

    /// Register mesh memory by calculating size from mesh array
    /// - Parameters:
    ///   - entityId: The entity owning the meshes
    ///   - meshes: Array of meshes to calculate size from
    public func registerMesh(entityId: EntityID, meshes: [Mesh]) {
        let meshSize = calculateMeshArrayMemory(meshes)
        let textureSize = meshes.reduce(0) { $0 + $1.textureMemorySize }
        registerMesh(entityId: entityId, meshSizeBytes: meshSize, textureSizeBytes: textureSize)
    }

    /// Unregister an entity's memory
    public func unregisterMesh(entityId: EntityID) {
        lock.lock()
        defer { lock.unlock() }

        guard let entry = memoryEntries.removeValue(forKey: entityId) else { return }

        totalMeshMemory -= entry.meshSizeBytes
        totalTextureMemory -= entry.textureSizeBytes
    }

    // MARK: - Usage Tracking

    /// Mark an entity as used this frame (for LRU tracking)
    /// Call this when an entity is rendered or otherwise accessed
    public func markUsed(entityId: EntityID) {
        guard enabled else { return }

        lock.lock()
        defer { lock.unlock() }

        memoryEntries[entityId]?.lastUsedFrame = currentFrame
    }

    /// Mark multiple entities as used
    public func markUsed(entityIds: [EntityID]) {
        guard enabled else { return }

        lock.lock()
        defer { lock.unlock() }

        for entityId in entityIds {
            memoryEntries[entityId]?.lastUsedFrame = currentFrame
        }
    }

    /// Mark multiple entities as used (Set version)
    public func markUsed(entityIds: Set<EntityID>) {
        guard enabled else { return }

        lock.lock()
        defer { lock.unlock() }

        for entityId in entityIds {
            memoryEntries[entityId]?.lastUsedFrame = currentFrame
        }
    }

    // MARK: - Queries

    /// Get current memory statistics
    public func getStats() -> MemoryStats {
        lock.lock()
        defer { lock.unlock() }

        return MemoryStats(
            meshMemoryUsed: totalMeshMemory,
            textureMemoryUsed: totalTextureMemory,
            budgetLimit: meshBudget,
            trackedEntityCount: memoryEntries.count
        )
    }

    /// Check if we should start evicting entities (combined geometry + texture budget).
    public func shouldEvict() -> Bool {
        guard enabled else { return false }

        lock.lock()
        defer { lock.unlock() }

        let utilization = Float(totalMeshMemory + totalTextureMemory) / Float(meshBudget)
        return utilization >= highWaterMark
    }

    /// Check if geometry memory alone has hit the high-water mark.
    ///
    /// Used by `GeometryStreamingSystem` so that texture upgrades on already-loaded
    /// entities cannot block new mesh loads. Texture memory is intentionally excluded
    /// from this check — texture pressure is managed independently by `TextureStreamingSystem`.
    public func shouldEvictGeometry() -> Bool {
        guard enabled else { return false }

        lock.lock()
        defer { lock.unlock() }

        let utilization = Float(totalMeshMemory) / Float(meshBudget)
        return utilization >= highWaterMark
    }

    /// Check if we can accept a new mesh of the given size.
    ///
    /// Accounts for both geometry and texture memory already tracked so the
    /// combined GPU footprint stays within the budget after the new allocation.
    public func canAccept(sizeBytes: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return (totalMeshMemory + totalTextureMemory + sizeBytes) <= meshBudget
    }

    /// Check if a new mesh of the given size fits within the geometry portion of the budget.
    ///
    /// Only counts geometry (vertex/index) memory — texture memory is excluded so that
    /// texture upgrades cannot prevent mesh loads. Used by `GeometryStreamingSystem`
    /// for its per-candidate pre-emptive budget reservation.
    public func canAcceptMesh(sizeBytes: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return (totalMeshMemory + sizeBytes) <= meshBudget
    }

    /// Check if we can accept a new texture allocation of the given size.
    ///
    /// Includes in-flight reservations (`inFlightTextureReservation`) so callers see
    /// headroom already committed to in-progress upgrade Tasks. Use `reserveTexture`
    /// instead of this method when you intend to actually start an upgrade — `reserveTexture`
    /// atomically checks and reserves in one lock acquisition, eliminating the TOCTOU race
    /// between checking and acting.
    public func canAcceptTexture(sizeBytes: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return (totalMeshMemory + totalTextureMemory + inFlightTextureReservation + sizeBytes) <= meshBudget
    }

    /// Atomically check whether a texture upgrade fits within the budget and, if so,
    /// reserve the estimated bytes.
    ///
    /// Unlike `canAcceptTexture` + a separate action, this method eliminates the
    /// check-then-act race: two concurrent callers cannot both see "budget available"
    /// and both proceed, because the first reservation reduces the apparent headroom
    /// for the second caller before it acquires the lock.
    ///
    /// - Parameter sizeBytes: Estimated GPU bytes for the upgrade batch (from
    ///   `TextureStreamingSystem.estimatedUpgradeBytes`).
    /// - Returns: `true` if the reservation was accepted; `false` if the budget would
    ///   be exceeded. If `false`, the caller should proceed with downgrades only and
    ///   must NOT call `releaseTextureReservation`.
    public func reserveTexture(sizeBytes: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard (totalMeshMemory + totalTextureMemory + inFlightTextureReservation + sizeBytes) <= meshBudget else {
            return false
        }
        inFlightTextureReservation += sizeBytes
        return true
    }

    /// Release a previously accepted texture upgrade reservation.
    ///
    /// Call this after the async upgrade Task completes (success, failure, or cancellation),
    /// before or concurrently with `updateTextureSizeBytes`. Releasing the reservation
    /// restores the apparent headroom for subsequent `canAcceptTexture` / `reserveTexture`
    /// calls. Only call this if `reserveTexture` returned `true`.
    public func releaseTextureReservation(sizeBytes: Int) {
        lock.lock()
        inFlightTextureReservation = max(0, inFlightTextureReservation - sizeBytes)
        lock.unlock()
    }

    /// Update texture size tracking for an entity after texture streaming completes.
    ///
    /// Called by `TextureStreamingSystem` whenever a texture upgrade or downgrade
    /// finishes so `totalTextureMemory` reflects the actual current GPU allocation.
    /// No-op if the entity is not currently tracked (e.g. entity was evicted while
    /// the streaming Task was in-flight).
    public func updateTextureSizeBytes(entityId: EntityID, newSizeBytes: Int) {
        lock.lock()
        defer { lock.unlock() }

        guard var entry = memoryEntries[entityId] else { return }
        totalTextureMemory -= entry.textureSizeBytes
        entry.textureSizeBytes = newSizeBytes
        entry.lastUsedFrame = currentFrame
        totalTextureMemory += newSizeBytes
        memoryEntries[entityId] = entry
    }

    /// Get memory size for an entity (if tracked)
    public func getMemorySize(for entityId: EntityID) -> Int? {
        lock.lock()
        defer { lock.unlock() }

        return memoryEntries[entityId]?.totalSize
    }

    /// Get last used frame for an entity
    public func getLastUsedFrame(for entityId: EntityID) -> UInt64? {
        lock.lock()
        defer { lock.unlock() }

        return memoryEntries[entityId]?.lastUsedFrame
    }

    /// Check if an entity is tracked
    public func isTracked(entityId: EntityID) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return memoryEntries[entityId] != nil
    }

    // MARK: - Eviction

    /// Get eviction candidates sorted by LRU (least recently used first)
    /// - Parameter count: Maximum number of candidates to return
    /// - Returns: Array of entity IDs sorted by staleness (oldest first)
    public func getEvictionCandidates(count: Int) -> [EntityID] {
        lock.lock()
        defer { lock.unlock() }

        // Sort by last used frame (ascending = oldest first)
        let sorted = memoryEntries.values
            .sorted { $0.lastUsedFrame < $1.lastUsedFrame }
            .prefix(count)
            .map(\.entityId)

        return Array(sorted)
    }

    /// Get eviction candidates with their memory sizes
    /// - Parameter count: Maximum number of candidates to return
    /// - Returns: Array of (EntityID, sizeBytes) tuples sorted by staleness
    public func getEvictionCandidatesWithSizes(count: Int) -> [(entityId: EntityID, sizeBytes: Int)] {
        lock.lock()
        defer { lock.unlock() }

        let sorted = memoryEntries.values
            .sorted { $0.lastUsedFrame < $1.lastUsedFrame }
            .prefix(count)
            .map { (entityId: $0.entityId, sizeBytes: $0.totalSize) }

        return Array(sorted)
    }

    /// Get candidates to evict to reach the low water mark.
    ///
    /// Uses combined geometry + texture memory to compute how much needs to be
    /// freed, and counts each candidate's total size (mesh + texture) toward the
    /// target. This ensures eviction correctly accounts for texture-heavy entities.
    public func getEvictionCandidatesToTarget() -> [EntityID] {
        lock.lock()
        defer { lock.unlock() }

        let targetMemory = Int(Float(meshBudget) * lowWaterMark)
        var memoryToFree = (totalMeshMemory + totalTextureMemory) - targetMemory

        guard memoryToFree > 0 else { return [] }

        // Sort by last used frame (oldest first)
        let sorted = memoryEntries.values.sorted { $0.lastUsedFrame < $1.lastUsedFrame }

        var candidates: [EntityID] = []
        for entry in sorted {
            if memoryToFree <= 0 { break }
            candidates.append(entry.entityId)
            memoryToFree -= entry.totalSize
        }

        return candidates
    }

    /// Get entities that haven't been used for N frames
    /// - Parameter frameThreshold: Number of frames of staleness
    /// - Returns: Array of entity IDs that are stale
    public func getStaleEntities(frameThreshold: UInt64) -> [EntityID] {
        lock.lock()
        defer { lock.unlock() }

        let threshold = currentFrame > frameThreshold ? currentFrame - frameThreshold : 0

        return memoryEntries.values
            .filter { $0.lastUsedFrame < threshold }
            .map(\.entityId)
    }

    // MARK: - Utilities

    /// Clear all tracked memory (call when scene is unloaded)
    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        memoryEntries.removeAll()
        totalMeshMemory = 0
        totalTextureMemory = 0
        inFlightTextureReservation = 0
    }

    /// Get number of tracked entities
    public var entityCount: Int {
        lock.lock()
        defer { lock.unlock() }

        return memoryEntries.count
    }

    /// Get total tracked mesh memory
    public var totalMeshMemoryUsed: Int {
        lock.lock()
        defer { lock.unlock() }

        return totalMeshMemory
    }

    /// Log current memory status
    public func logStatus() {
        let stats = getStats()
        Logger.log(message: """
        MemoryBudgetManager Status:
        - Mesh Memory: \(stats.meshMemoryUsed.formattedAsMemory)
        - Texture Memory: \(stats.textureMemoryUsed.formattedAsMemory)
        - Total GPU Memory: \(stats.totalTrackedMemory.formattedAsMemory) / \(stats.budgetLimit.formattedAsMemory)
        - Utilization: \(String(format: "%.1f%%", stats.utilizationPercent * 100))
        - Tracked Entities: \(stats.trackedEntityCount)
        - Under Pressure: \(stats.isUnderPressure)
        """)
    }
}

/// Memory budget presets
public extension MemoryBudgetManager {
    /// Apply low-memory preset (mobile/older devices)
    func applyLowMemoryPreset() {
        meshBudget = 256 * 1024 * 1024 // 256 MB
        highWaterMark = 0.80
        lowWaterMark = 0.60
    }

    /// Apply standard preset (most devices)
    func applyStandardPreset() {
        meshBudget = 512 * 1024 * 1024 // 512 MB
        highWaterMark = 0.85
        lowWaterMark = 0.70
    }

    /// Apply high-memory preset (desktop/high-end)
    func applyHighMemoryPreset() {
        meshBudget = 1024 * 1024 * 1024 // 1 GB
        highWaterMark = 0.90
        lowWaterMark = 0.75
    }

    /// Apply unlimited preset (no eviction)
    func applyUnlimitedPreset() {
        meshBudget = Int.max / 2 // Effectively unlimited
        highWaterMark = 1.0
        lowWaterMark = 1.0
    }
}

// MARK: - Debug Extensions

#if DEBUG
    public extension MemoryBudgetManager {
        /// Get all tracked entity IDs (debug only)
        var debugTrackedEntities: [EntityID] {
            lock.lock()
            defer { lock.unlock() }

            return Array(memoryEntries.keys)
        }

        /// Get detailed entry info (debug only)
        func debugGetEntry(for entityId: EntityID) -> (meshSize: Int, textureSize: Int, lastUsed: UInt64, registered: UInt64)? {
            lock.lock()
            defer { lock.unlock() }

            guard let entry = memoryEntries[entityId] else { return nil }
            return (entry.meshSizeBytes, entry.textureSizeBytes, entry.lastUsedFrame, entry.registrationFrame)
        }
    }
#endif

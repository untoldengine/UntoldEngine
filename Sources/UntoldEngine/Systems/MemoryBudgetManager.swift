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
#if canImport(Darwin)
    import Darwin
#endif

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

    /// Geometry-only budget (vertex + index buffers)
    public var geometryBudget: Int

    /// Texture-only budget
    public var textureBudget: Int

    /// Combined budget limit in bytes
    public var budgetLimit: Int {
        geometryBudget + textureBudget
    }

    /// Geometry pool utilization (0.0 – 1.0+)
    public var geometryUtilization: Float {
        guard geometryBudget > 0 else { return 0 }
        return Float(meshMemoryUsed) / Float(geometryBudget)
    }

    /// Texture pool utilization (0.0 – 1.0+)
    public var textureUtilization: Float {
        guard textureBudget > 0 else { return 0 }
        return Float(textureMemoryUsed) / Float(textureBudget)
    }

    /// Combined utilization as percentage (0.0 - 1.0+)
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

    /// Whether either pool is under pressure (geometry or texture pool at ≥ 85 %)
    public var isUnderPressure: Bool {
        geometryUtilization >= 0.85 || textureUtilization >= 0.85
    }

    public init(
        meshMemoryUsed: Int = 0,
        textureMemoryUsed: Int = 0,
        geometryBudget: Int = 0,
        textureBudget: Int = 0,
        trackedEntityCount: Int = 0
    ) {
        self.meshMemoryUsed = meshMemoryUsed
        self.textureMemoryUsed = textureMemoryUsed
        self.geometryBudget = geometryBudget
        self.textureBudget = textureBudget
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

    /// Geometry (vertex + index) memory budget in bytes.
    ///
    /// Managed independently from texture memory so texture upgrades cannot block
    /// mesh loads and vice versa. Set automatically at init from device capabilities.
    public var geometryBudget: Int = 300 * 1024 * 1024 {
        didSet {
            Logger.log(message: "MemoryBudgetManager: Geometry budget → \(geometryBudget.formattedAsMemory)")
        }
    }

    /// Texture memory budget in bytes.
    ///
    /// Managed independently from geometry memory.
    public var textureBudget: Int = 200 * 1024 * 1024 {
        didSet {
            Logger.log(message: "MemoryBudgetManager: Texture budget → \(textureBudget.formattedAsMemory)")
        }
    }

    /// Combined geometry + texture budget — read/write alias for backward compatibility.
    ///
    /// Getting returns `geometryBudget + textureBudget`.
    /// Setting splits the value 60 % geometry / 40 % texture, which preserves the
    /// existing semantics for test code and external callers that set a single number.
    public var meshBudget: Int {
        get { geometryBudget + textureBudget }
        set {
            geometryBudget = Int(Double(newValue) * 0.60)
            textureBudget = Int(Double(newValue) * 0.40)
        }
    }

    /// Start evicting when utilization reaches this threshold (default: 85%)
    public var highWaterMark: Float = 0.85

    /// Evict down to this utilization level (default: 70%)
    public var lowWaterMark: Float = 0.70

    /// Whether the manager is enabled
    public var enabled: Bool = true

    // MARK: - OS Memory Pressure

    /// Called when the OS signals warning-level memory pressure.
    ///
    /// Register a handler from `GeometryStreamingSystem` to proactively shed textures
    /// and evict geometry before the OS escalates to critical. The handler is invoked
    /// on a background queue — use a flag to defer actual eviction to the next update tick.
    public var onMemoryPressureWarning: (() -> Void)?

    /// Called when the OS signals critical memory pressure.
    ///
    /// Should trigger aggressive eviction. Invoked on a background queue.
    public var onMemoryPressureCritical: (() -> Void)?

    /// Retained for the lifetime of the singleton. Never cancelled — `MemoryBudgetManager`
    /// is app-lifetime, so there is no dealloc path that would require cleanup.
    private var pressureSource: DispatchSourceMemoryPressure?

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

    /// Last combined-utilization bucket that was logged (0, 50, 75, 85, or 95).
    /// Prevents log spam by only emitting a line when crossing a threshold.
    private var lastLoggedThresholdBucket: Int = 0

    /// Thread safety lock
    private let lock = NSLock()

    // MARK: - Initialization

    private init() {
        configureDefaultBudget()
        startMemoryPressureMonitoring()
    }

    /// Configure geometry and texture budgets based on device capabilities.
    ///
    /// On macOS, anchors to `MTLDevice.recommendedMaxWorkingSetSize` (the GPU's safe
    /// working-set size for the unified memory architecture).
    /// On visionOS / iOS, probes `os_proc_available_memory()` — the remaining process
    /// footprint before the OS kills the app — and takes 40 % as a conservative GPU
    /// sub-budget.  The total is split 60 % geometry / 40 % texture so each pool has
    /// an independent ceiling.
    private func configureDefaultBudget() {
        // Log device profile first so crash logs always carry hardware context.
        if let device = MTLCreateSystemDefaultDevice() {
            let maxWorkingSetMB = Int(device.recommendedMaxWorkingSetSize) / (1024 * 1024)
            Logger.log(message: "[DeviceProfile] Metal device: '\(device.name)' | hasUnifiedMemory=\(device.hasUnifiedMemory) | recommendedMaxWorkingSetSize=\(maxWorkingSetMB) MB")
        }
        #if canImport(Darwin) && !os(macOS)
            let procAvailableMB = Int(os_proc_available_memory()) / (1024 * 1024)
            Logger.log(message: "[DeviceProfile] OS process available memory: \(procAvailableMB) MB (app kill threshold)")
        #endif

        let totalBudget: Int

        #if os(macOS)
            if let device = MTLCreateSystemDefaultDevice() {
                let gpuWorking = Int(device.recommendedMaxWorkingSetSize)
                // 40 % of the GPU working set is a safe OOC sub-budget on unified memory.
                totalBudget = max(512 * 1024 * 1024, Int(Double(gpuWorking) * 0.40))
            } else {
                totalBudget = 1024 * 1024 * 1024 // 1 GB fallback
            }
        #elseif canImport(Darwin)
            // os_proc_available_memory() returns remaining app footprint before kill.
            // 40 % of that is a safe GPU sub-budget; clamp to [512 MB, 3 GB].
            let available = Int(os_proc_available_memory())
            let probed = Int(Double(available) * 0.40)
            totalBudget = max(512 * 1024 * 1024, min(probed, 3 * 1024 * 1024 * 1024))
        #else
            totalBudget = 512 * 1024 * 1024
        #endif

        // Independent pools: 60 % geometry, 40 % texture.
        geometryBudget = Int(Double(totalBudget) * 0.60)
        textureBudget = Int(Double(totalBudget) * 0.40)
        Logger.log(message: "MemoryBudgetManager: probed budgets — geometry=\(geometryBudget.formattedAsMemory) texture=\(textureBudget.formattedAsMemory) total=\(meshBudget.formattedAsMemory)")
    }

    /// Subscribe to OS memory pressure events and fire the registered callbacks.
    ///
    /// On `.warning`: calls `onMemoryPressureWarning` — expected to shed textures and
    /// evict geometry proactively before the OS escalates.
    /// On `.critical`: calls `onMemoryPressureCritical` — expected to aggressively free
    /// memory to avoid process termination.
    /// Both callbacks are invoked on a background queue; handlers must be thread-safe.
    private func startMemoryPressureMonitoring() {
        #if os(macOS) || os(iOS) || os(visionOS)
            let source = DispatchSource.makeMemoryPressureSource(
                eventMask: [.warning, .critical],
                queue: .global(qos: .userInitiated)
            )
            source.setEventHandler { [weak self] in
                guard let self else { return }
                let event = source.data
                if event.contains(.critical) {
                    Logger.log(message: "[MemoryBudgetManager] OS critical memory pressure — triggering aggressive eviction")
                    onMemoryPressureCritical?()
                } else if event.contains(.warning) {
                    Logger.log(message: "[MemoryBudgetManager] OS warning memory pressure — triggering proactive eviction")
                    onMemoryPressureWarning?()
                }
            }
            source.resume()
            pressureSource = source
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
        lock.unlock()

        checkThresholdLogging()
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
            geometryBudget: geometryBudget,
            textureBudget: textureBudget,
            trackedEntityCount: memoryEntries.count
        )
    }

    /// Check if we should start evicting entities.
    ///
    /// Returns `true` when either the geometry pool or the texture pool has reached
    /// its individual high-water mark. This fires texture relief (downgrade distant
    /// textures) before considering geometry eviction, so the two pools are managed
    /// independently rather than competing for the same ceiling.
    public func shouldEvict() -> Bool {
        guard enabled else { return false }

        lock.lock()
        defer { lock.unlock() }

        let geomUtil = Float(totalMeshMemory) / Float(max(1, geometryBudget))
        let texUtil = Float(totalTextureMemory) / Float(max(1, textureBudget))
        return geomUtil >= highWaterMark || texUtil >= highWaterMark
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

        let utilization = Float(totalMeshMemory) / Float(max(1, geometryBudget))
        return utilization >= highWaterMark
    }

    /// Check if we can accept a new mesh of the given size.
    ///
    /// Legacy combined check: passes if the new bytes fit within the sum of both pools.
    /// Prefer `canAcceptMesh` or `canAcceptTexture` for pool-specific gates.
    public func canAccept(sizeBytes: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return (totalMeshMemory + totalTextureMemory + sizeBytes) <= (geometryBudget + textureBudget)
    }

    /// Check if a new mesh of the given size fits within the geometry pool.
    ///
    /// Only counts geometry (vertex/index) memory against `geometryBudget` — texture
    /// memory is excluded so texture upgrades cannot prevent mesh loads.
    /// Used by `GeometryStreamingSystem` for per-candidate pre-emptive budget reservation.
    public func canAcceptMesh(sizeBytes: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return (totalMeshMemory + sizeBytes) <= geometryBudget
    }

    /// Check if we can accept a new texture allocation of the given size.
    ///
    /// Checks against `textureBudget` (independent of geometry pool) and includes
    /// in-flight reservations so callers see already-committed headroom.
    /// Use `reserveTexture` when you intend to actually start an upgrade — it
    /// atomically checks and reserves, eliminating the TOCTOU race.
    public func canAcceptTexture(sizeBytes: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return (totalTextureMemory + inFlightTextureReservation + sizeBytes) <= textureBudget
    }

    /// Atomically check whether a texture upgrade fits within `textureBudget` and,
    /// if so, reserve the estimated bytes.
    ///
    /// Unlike `canAcceptTexture` + a separate action, this method eliminates the
    /// check-then-act race: two concurrent callers cannot both see "budget available"
    /// and both proceed, because the first reservation reduces the apparent headroom
    /// for the second caller before it acquires the lock.
    ///
    /// - Parameter sizeBytes: Estimated GPU bytes for the upgrade batch.
    /// - Returns: `true` if the reservation was accepted; `false` if the texture budget
    ///   would be exceeded. If `false`, do NOT call `releaseTextureReservation`.
    public func reserveTexture(sizeBytes: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard (totalTextureMemory + inFlightTextureReservation + sizeBytes) <= textureBudget else {
            return false
        }
        inFlightTextureReservation += sizeBytes
        return true
    }

    /// Release a previously accepted texture upgrade reservation.
    ///
    /// Call this after the async upgrade Task completes (success, failure, or cancellation),
    /// before or concurrently with `updateTextureSizeBytes`. Only call if `reserveTexture`
    /// returned `true`.
    public func releaseTextureReservation(sizeBytes: Int) {
        lock.lock()
        inFlightTextureReservation = max(0, inFlightTextureReservation - sizeBytes)
        lock.unlock()
    }

    /// Update texture size tracking for an entity after texture streaming completes.
    ///
    /// Called by `TextureStreamingSystem` whenever a texture upgrade or downgrade
    /// finishes so `totalTextureMemory` reflects the actual current GPU allocation.
    /// No-op if the entity is not currently tracked.
    public func updateTextureSizeBytes(entityId: EntityID, newSizeBytes: Int) {
        lock.lock()
        guard var entry = memoryEntries[entityId] else {
            lock.unlock()
            return
        }
        totalTextureMemory -= entry.textureSizeBytes
        entry.textureSizeBytes = newSizeBytes
        entry.lastUsedFrame = currentFrame
        totalTextureMemory += newSizeBytes
        memoryEntries[entityId] = entry
        lock.unlock()

        checkThresholdLogging()
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
    /// Intentionally uses the combined geometry + texture budget and combined entity
    /// sizes. Evicting an entity releases both its geometry and texture bytes at once,
    /// so accounting against a single combined target is correct and avoids the
    /// complexity of running two separate per-pool passes. Per-pool targets would risk
    /// double-evicting entities that contribute to both pools simultaneously.
    public func getEvictionCandidatesToTarget() -> [EntityID] {
        lock.lock()
        defer { lock.unlock() }

        let totalBudget = geometryBudget + textureBudget
        let targetMemory = Int(Float(totalBudget) * lowWaterMark)
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

    // MARK: - Threshold Logging

    /// Log a single line when combined utilization crosses 75 %, 85 %, or 95 %.
    ///
    /// Called without the lock after `registerMesh` and `updateTextureSizeBytes` so
    /// the lock is never held during logging. There is a benign race window between
    /// the two lock acquisitions, which is acceptable since this path is for diagnostics
    /// only — it never drives a budget decision.
    private func checkThresholdLogging() {
        lock.lock()
        let meshMem = totalMeshMemory
        let texMem = totalTextureMemory
        let geomBudget = geometryBudget
        let texBudget = textureBudget
        let lastBucket = lastLoggedThresholdBucket
        lock.unlock()

        let combined = geomBudget + texBudget
        let combinedPct = combined > 0 ? Int(Float(meshMem + texMem) * 100 / Float(combined)) : 0
        let newBucket: Int = combinedPct >= 95 ? 95
            : combinedPct >= 85 ? 85
            : combinedPct >= 75 ? 75 : 0

        guard newBucket != lastBucket else { return }

        lock.lock()
        lastLoggedThresholdBucket = newBucket
        lock.unlock()

        let geomPct = geomBudget > 0 ? Int(Float(meshMem) * 100 / Float(geomBudget)) : 0
        let texPct = texBudget > 0 ? Int(Float(texMem) * 100 / Float(texBudget)) : 0
        Logger.log(message: "[MemoryBudgetManager] \(combinedPct)% combined — geom \(geomPct)%/\(geomBudget.formattedAsMemory), tex \(texPct)%/\(texBudget.formattedAsMemory)")
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
        lastLoggedThresholdBucket = 0
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
        - Mesh Memory:    \(stats.meshMemoryUsed.formattedAsMemory) / \(stats.geometryBudget.formattedAsMemory) (\(String(format: "%.1f%%", stats.geometryUtilization * 100)))
        - Texture Memory: \(stats.textureMemoryUsed.formattedAsMemory) / \(stats.textureBudget.formattedAsMemory) (\(String(format: "%.1f%%", stats.textureUtilization * 100)))
        - Total GPU Memory: \(stats.totalTrackedMemory.formattedAsMemory) / \(stats.budgetLimit.formattedAsMemory) (\(String(format: "%.1f%%", stats.utilizationPercent * 100)))
        - Tracked Entities: \(stats.trackedEntityCount)
        - Under Pressure: \(stats.isUnderPressure)
        """)
    }
}

/// Memory budget presets
public extension MemoryBudgetManager {
    /// Apply low-memory preset (mobile/older devices)
    func applyLowMemoryPreset() {
        geometryBudget = Int(Double(256 * 1024 * 1024) * 0.60)
        textureBudget = Int(Double(256 * 1024 * 1024) * 0.40)
        highWaterMark = 0.80
        lowWaterMark = 0.60
    }

    /// Apply standard preset (most devices)
    func applyStandardPreset() {
        geometryBudget = Int(Double(512 * 1024 * 1024) * 0.60)
        textureBudget = Int(Double(512 * 1024 * 1024) * 0.40)
        highWaterMark = 0.85
        lowWaterMark = 0.70
    }

    /// Apply high-memory preset (desktop/high-end)
    func applyHighMemoryPreset() {
        geometryBudget = Int(Double(1024 * 1024 * 1024) * 0.60)
        textureBudget = Int(Double(1024 * 1024 * 1024) * 0.40)
        highWaterMark = 0.90
        lowWaterMark = 0.75
    }

    /// Apply unlimited preset (no eviction)
    func applyUnlimitedPreset() {
        geometryBudget = Int.max / 4
        textureBudget = Int.max / 4
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

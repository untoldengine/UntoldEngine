//
//  AssetLoadingState.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import QuartzCore

/// Synchronous loading gate for render threads that can't `await`.
/// Mirrors `AssetLoadingState` activity count and is safe to query from any thread.
public final class AssetLoadingGate: @unchecked Sendable {
    public static let shared = AssetLoadingGate()

    private let lock = NSLock()
    private var activeLoads: Int = 0
    #if ENGINE_STATS_ENABLED
        private var activeSinceSeconds: Double?
        private var accumulatedActiveSeconds: Double = 0.0
    #endif

    private init() {}

    public func beginLoading() {
        lock.lock()
        activeLoads += 1
        #if ENGINE_STATS_ENABLED
            if activeLoads == 1 {
                activeSinceSeconds = CACurrentMediaTime()
            }
        #endif
        lock.unlock()
    }

    public func finishLoading() {
        lock.lock()
        activeLoads = max(0, activeLoads - 1)
        #if ENGINE_STATS_ENABLED
            if activeLoads == 0, let start = activeSinceSeconds {
                accumulatedActiveSeconds += max(0.0, CACurrentMediaTime() - start)
                activeSinceSeconds = nil
            }
        #endif
        lock.unlock()
    }

    public var isLoadingAny: Bool {
        lock.lock()
        let value = activeLoads > 0
        lock.unlock()
        return value
    }

    public var activeLoadCount: Int {
        #if ENGINE_STATS_ENABLED
            lock.lock()
            let value = activeLoads
            lock.unlock()
            return value
        #else
            return 0
        #endif
    }

    /// Returns milliseconds that the loading gate has been active since the last sample.
    public func consumeBlockedMsSinceLastSample() -> Double {
        #if ENGINE_STATS_ENABLED
            lock.lock()
            let now = CACurrentMediaTime()
            if let start = activeSinceSeconds {
                accumulatedActiveSeconds += max(0.0, now - start)
                activeSinceSeconds = now
            }
            let blockedMs = accumulatedActiveSeconds * 1000.0
            accumulatedActiveSeconds = 0.0
            lock.unlock()
            return blockedMs
        #else
            return 0.0
        #endif
    }
}

private final class WorldAccessGate: @unchecked Sendable {
    static let shared = WorldAccessGate()

    private let lock = NSRecursiveLock()

    private init() {}

    func sync<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    func lockAccess() {
        lock.lock()
    }

    func unlockAccess() {
        lock.unlock()
    }
}

/// Execute a world/ECS access critical section without changing render loading state.
@inline(__always)
public func withWorldAccessGate<T>(_ body: () throws -> T) rethrows -> T {
    try WorldAccessGate.shared.sync(body)
}

@inline(__always)
public func lockWorldAccessGate() {
    WorldAccessGate.shared.lockAccess()
}

@inline(__always)
public func unlockWorldAccessGate() {
    WorldAccessGate.shared.unlockAccess()
}

/// Execute a world-mutation critical section while pausing XR scene traversal.
@inline(__always)
public func withWorldMutationGate<T>(_ body: () throws -> T) rethrows -> T {
    AssetLoadingGate.shared.beginLoading()
    defer { AssetLoadingGate.shared.finishLoading() }
    return try WorldAccessGate.shared.sync(body)
}

/// Loading phase enum
public enum LoadingPhase {
    case loading // Loading meshes from disk
    case registering // Registering components to ECS
}

/// Progress information for a loading entity
public struct LoadingProgress {
    public let entityId: EntityID
    public let filename: String
    public let currentMesh: Int
    public let totalMeshes: Int
    public var phase: LoadingPhase

    public var percentage: Float {
        guard totalMeshes > 0 else { return 0 }
        return Float(currentMesh) / Float(totalMeshes)
    }

    public var phaseDescription: String {
        switch phase {
        case .loading: return "Loading"
        case .registering: return "Registering"
        }
    }
}

/// Thread-safe manager for tracking asset loading state
public actor AssetLoadingState {
    public static let shared = AssetLoadingState()

    private var loadingEntities: [EntityID: LoadingProgress] = [:]

    private init() {}

    /// Start tracking loading for an entity
    public func startLoading(entityId: EntityID, filename: String, totalMeshes: Int = 0) {
        if loadingEntities[entityId] == nil {
            AssetLoadingGate.shared.beginLoading()
        }

        loadingEntities[entityId] = LoadingProgress(
            entityId: entityId,
            filename: filename,
            currentMesh: 0,
            totalMeshes: totalMeshes,
            phase: .loading
        )
    }

    /// Update progress for a loading entity
    public func updateProgress(entityId: EntityID, currentMesh: Int, totalMeshes: Int, phase: LoadingPhase? = nil) {
        guard let existing = loadingEntities[entityId] else { return }
        loadingEntities[entityId] = LoadingProgress(
            entityId: entityId,
            filename: existing.filename,
            currentMesh: currentMesh,
            totalMeshes: totalMeshes,
            phase: phase ?? existing.phase
        )
    }

    /// Mark entity as finished loading
    public func finishLoading(entityId: EntityID) {
        if loadingEntities.removeValue(forKey: entityId) != nil {
            AssetLoadingGate.shared.finishLoading()
        }
    }

    /// Check if a specific entity is loading
    public func isLoading(entityId: EntityID) -> Bool {
        loadingEntities[entityId] != nil
    }

    /// Check if any assets are currently loading
    public func isLoadingAny() -> Bool {
        !loadingEntities.isEmpty
    }

    /// Get the number of entities currently loading
    public func loadingCount() -> Int {
        loadingEntities.count
    }

    /// Get progress for a specific entity
    public func getProgress(for entityId: EntityID) -> LoadingProgress? {
        loadingEntities[entityId]
    }

    /// Get all loading entities and their progress
    public func getAllProgress() -> [LoadingProgress] {
        Array(loadingEntities.values)
    }

    /// Get total progress across all loading entities
    public func totalProgress() -> (current: Int, total: Int) {
        let current = loadingEntities.values.reduce(0) { $0 + $1.currentMesh }
        let total = loadingEntities.values.reduce(0) { $0 + $1.totalMeshes }
        return (current, total)
    }

    /// Get a summary string of current loading state
    public func loadingSummary() -> String {
        guard !loadingEntities.isEmpty else { return "No assets loading" }

        let (current, total) = totalProgress()
        let entityCount = loadingEntities.count

        if entityCount == 1, let progress = loadingEntities.values.first {
            return "\(progress.phaseDescription) \(progress.filename): \(current)/\(total) entities"
        } else {
            return "\(entityCount) assets loading: \(current)/\(total) entities"
        }
    }
}

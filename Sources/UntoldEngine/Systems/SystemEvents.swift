//
//  SystemEvents.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import QuartzCore

// MARK: - Event Types

/// Emitted by GeometryStreamingSystem when mesh residency changes
public struct AssetResidencyChangedEvent {
    public let entityId: EntityID
    public let assetURL: URL
    public let meshName: String
    public let isResident: Bool // true = became resident, false = evicted

    public init(entityId: EntityID, assetURL: URL, meshName: String, isResident: Bool) {
        self.entityId = entityId
        self.assetURL = assetURL
        self.meshName = meshName
        self.isResident = isResident
    }
}

/// Emitted by LODSystem when an entity's active LOD selection changes
public struct EntityLODChangedEvent {
    public let entityId: EntityID
    public let previousLODIndex: Int
    public let newLODIndex: Int
    public let meshAssetID: String // Identifier for the mesh (URL + name)

    public init(entityId: EntityID, previousLODIndex: Int, newLODIndex: Int, meshAssetID: String) {
        self.entityId = entityId
        self.previousLODIndex = previousLODIndex
        self.newLODIndex = newLODIndex
        self.meshAssetID = meshAssetID
    }
}

/// Emitted when an entity's static batching eligibility changes
public struct EntityBatchingChangedEvent {
    public let entityId: EntityID
    public let isEligible: Bool // true = now eligible, false = no longer eligible

    public init(entityId: EntityID, isEligible: Bool) {
        self.entityId = entityId
        self.isEligible = isEligible
    }
}

/// Emitted by StreamingRegionManager when a region finishes loading or unloading
public struct RegionStreamingEvent {
    public let regionId: UUID
    public let isLoaded: Bool // true = region loaded, false = region unloaded
    public let entityCount: Int // Number of entities in the region

    public init(regionId: UUID, isLoaded: Bool, entityCount: Int) {
        self.regionId = regionId
        self.isLoaded = isLoaded
        self.entityCount = entityCount
    }
}

// MARK: - Event Bus

/// Simple event bus for decoupled system communication
/// Used from both render/update and async loading paths.
public final class SystemEventBus: @unchecked Sendable {
    public static let shared = SystemEventBus()

    private let lock = NSLock()

    // Subscriber storage
    private var residencySubscribers: [(AssetResidencyChangedEvent) -> Void] = []
    private var lodChangeSubscribers: [(EntityLODChangedEvent) -> Void] = []
    private var batchingSubscribers: [(EntityBatchingChangedEvent) -> Void] = []

    // Event queues for deferred processing
    private var pendingResidencyEvents: [AssetResidencyChangedEvent] = []
    private var pendingLODEvents: [EntityLODChangedEvent] = []

    private init() {}

    // MARK: - Subscriptions

    public func subscribeToResidencyChanges(_ handler: @escaping (AssetResidencyChangedEvent) -> Void) {
        lock.lock()
        residencySubscribers.append(handler)
        lock.unlock()
    }

    public func subscribeToLODChanges(_ handler: @escaping (EntityLODChangedEvent) -> Void) {
        lock.lock()
        lodChangeSubscribers.append(handler)
        lock.unlock()
    }

    public func subscribeToBatchingChanges(_ handler: @escaping (EntityBatchingChangedEvent) -> Void) {
        lock.lock()
        batchingSubscribers.append(handler)
        lock.unlock()
    }

    // MARK: - Queue Events (deferred until flush)

    public func queueResidencyChange(_ event: AssetResidencyChangedEvent) {
        lock.lock()
        pendingResidencyEvents.append(event)
        lock.unlock()
    }

    public func queueLODChange(_ event: EntityLODChangedEvent) {
        lock.lock()
        pendingLODEvents.append(event)
        lock.unlock()
    }

    // MARK: - Flush (process all queued events)

    public func flushEvents() {
        let residencyEvents: [AssetResidencyChangedEvent]
        let lodEvents: [EntityLODChangedEvent]
        let residencyHandlers: [(AssetResidencyChangedEvent) -> Void]
        let lodHandlers: [(EntityLODChangedEvent) -> Void]

        lock.lock()
        residencyEvents = pendingResidencyEvents
        lodEvents = pendingLODEvents
        pendingResidencyEvents.removeAll(keepingCapacity: true)
        pendingLODEvents.removeAll(keepingCapacity: true)
        residencyHandlers = residencySubscribers
        lodHandlers = lodChangeSubscribers
        lock.unlock()

        // Process residency events first (streaming -> LOD/batching)
        for event in residencyEvents {
            for subscriber in residencyHandlers {
                subscriber(event)
            }
        }

        // Then LOD events (LOD -> batching)
        for event in lodEvents {
            for subscriber in lodHandlers {
                subscriber(event)
            }
        }
    }

    /// Clear queued events while preserving active subscribers.
    public func clearPendingEvents() {
        lock.lock()
        pendingResidencyEvents.removeAll(keepingCapacity: true)
        pendingLODEvents.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    /// Clear all subscribers and pending events (for testing/reset)
    public func reset() {
        lock.lock()
        residencySubscribers.removeAll()
        lodChangeSubscribers.removeAll()
        batchingSubscribers.removeAll()
        pendingResidencyEvents.removeAll()
        pendingLODEvents.removeAll()
        lock.unlock()
    }
}

// MARK: - Integration Stats

/// Statistics for monitoring system interactions (logged once per second)
public struct SystemIntegrationStats {
    public var streamingLoadsThisSecond: Int = 0
    public var streamingUnloadsThisSecond: Int = 0
    public var lodSwitchesThisSecond: Int = 0
    public var lodFallbacksThisSecond: Int = 0
    public var batchRebuildsThisSecond: Int = 0
    public var residentMeshCount: Int = 0

    // Region streaming stats
    public var regionLoadsThisSecond: Int = 0
    public var regionUnloadsThisSecond: Int = 0
    public var loadedRegionCount: Int = 0

    public mutating func reset() {
        streamingLoadsThisSecond = 0
        streamingUnloadsThisSecond = 0
        lodSwitchesThisSecond = 0
        lodFallbacksThisSecond = 0
        batchRebuildsThisSecond = 0
        regionLoadsThisSecond = 0
        regionUnloadsThisSecond = 0
    }
}

/// Tracks per-second stats for debugging system integration
public final class SystemIntegrationMonitor: @unchecked Sendable {
    public static let shared = SystemIntegrationMonitor()

    private let lock = NSLock()
    private var _stats = SystemIntegrationStats()
    private var lastResetTime: Double = 0
    private var _enableLogging = false

    public var stats: SystemIntegrationStats {
        lock.lock()
        let value = _stats
        lock.unlock()
        return value
    }

    public var enableLogging: Bool {
        get {
            lock.lock()
            let value = _enableLogging
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            _enableLogging = newValue
            lock.unlock()
        }
    }

    private init() {
        lastResetTime = CACurrentMediaTime()
    }

    /// Call once per frame
    public func tick() {
        var shouldLog = false
        var snapshot = SystemIntegrationStats()

        lock.lock()
        let now = CACurrentMediaTime()
        if now - lastResetTime >= 1.0 {
            snapshot = _stats
            shouldLog = _enableLogging && hasActivity(stats: snapshot)
            _stats.reset()
            lastResetTime = now
        }
        lock.unlock()

        if shouldLog {
            Logger.log(
                message: "[Integration] Loads: \(snapshot.streamingLoadsThisSecond), Unloads: \(snapshot.streamingUnloadsThisSecond), LOD switches: \(snapshot.lodSwitchesThisSecond), Fallbacks: \(snapshot.lodFallbacksThisSecond), Batch rebuilds: \(snapshot.batchRebuildsThisSecond)",
                category: LogCategory.integration.rawValue
            )
        }
    }

    private func hasActivity(stats: SystemIntegrationStats) -> Bool {
        stats.streamingLoadsThisSecond > 0 ||
            stats.streamingUnloadsThisSecond > 0 ||
            stats.lodSwitchesThisSecond > 0 ||
            stats.batchRebuildsThisSecond > 0 ||
            stats.regionLoadsThisSecond > 0 ||
            stats.regionUnloadsThisSecond > 0
    }

    public func recordStreamingLoad() {
        lock.lock()
        _stats.streamingLoadsThisSecond += 1
        lock.unlock()
    }

    public func recordStreamingUnload() {
        lock.lock()
        _stats.streamingUnloadsThisSecond += 1
        lock.unlock()
    }

    public func recordLODSwitch() {
        lock.lock()
        _stats.lodSwitchesThisSecond += 1
        lock.unlock()
    }

    public func recordLODFallback() {
        lock.lock()
        _stats.lodFallbacksThisSecond += 1
        lock.unlock()
    }

    public func recordBatchRebuild() {
        lock.lock()
        _stats.batchRebuildsThisSecond += 1
        lock.unlock()
    }

    public func setResidentMeshCount(_ count: Int) {
        lock.lock()
        _stats.residentMeshCount = count
        lock.unlock()
    }

    /// Region streaming
    public func recordRegionLoad() {
        lock.lock()
        _stats.regionLoadsThisSecond += 1
        lock.unlock()
    }

    public func recordRegionUnload() {
        lock.lock()
        _stats.regionUnloadsThisSecond += 1
        lock.unlock()
    }

    public func setLoadedRegionCount(_ count: Int) {
        lock.lock()
        _stats.loadedRegionCount = count
        lock.unlock()
    }
}

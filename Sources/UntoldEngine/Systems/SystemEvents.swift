//
//  SystemEvents.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

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
/// All systems run on main thread, so no synchronization needed
public final class SystemEventBus {
    public static let shared = SystemEventBus()

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
        residencySubscribers.append(handler)
    }

    public func subscribeToLODChanges(_ handler: @escaping (EntityLODChangedEvent) -> Void) {
        lodChangeSubscribers.append(handler)
    }

    public func subscribeToBatchingChanges(_ handler: @escaping (EntityBatchingChangedEvent) -> Void) {
        batchingSubscribers.append(handler)
    }

    // MARK: - Queue Events (deferred until flush)

    public func queueResidencyChange(_ event: AssetResidencyChangedEvent) {
        pendingResidencyEvents.append(event)
    }

    public func queueLODChange(_ event: EntityLODChangedEvent) {
        pendingLODEvents.append(event)
    }

    // MARK: - Flush (process all queued events)

    public func flushEvents() {
        // Process residency events first (streaming -> LOD/batching)
        for event in pendingResidencyEvents {
            for subscriber in residencySubscribers {
                subscriber(event)
            }
        }
        pendingResidencyEvents.removeAll(keepingCapacity: true)

        // Then LOD events (LOD -> batching)
        for event in pendingLODEvents {
            for subscriber in lodChangeSubscribers {
                subscriber(event)
            }
        }
        pendingLODEvents.removeAll(keepingCapacity: true)
    }

    /// Clear all subscribers and pending events (for testing/reset)
    public func reset() {
        residencySubscribers.removeAll()
        lodChangeSubscribers.removeAll()
        batchingSubscribers.removeAll()
        pendingResidencyEvents.removeAll()
        pendingLODEvents.removeAll()
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
public final class SystemIntegrationMonitor {
    public static let shared = SystemIntegrationMonitor()

    public private(set) var stats = SystemIntegrationStats()
    private var lastResetTime: Double = 0
    public var enableLogging: Bool = false

    private init() {
        lastResetTime = CACurrentMediaTime()
    }

    /// Call once per frame
    public func tick() {
        let now = CACurrentMediaTime()
        if now - lastResetTime >= 1.0 {
            if enableLogging, hasActivity() {
                Logger.log(message: "[Integration] Loads: \(stats.streamingLoadsThisSecond), Unloads: \(stats.streamingUnloadsThisSecond), LOD switches: \(stats.lodSwitchesThisSecond), Fallbacks: \(stats.lodFallbacksThisSecond), Batch rebuilds: \(stats.batchRebuildsThisSecond)")
            }
            stats.reset()
            lastResetTime = now
        }
    }

    private func hasActivity() -> Bool {
        stats.streamingLoadsThisSecond > 0 ||
            stats.streamingUnloadsThisSecond > 0 ||
            stats.lodSwitchesThisSecond > 0 ||
            stats.batchRebuildsThisSecond > 0 ||
            stats.regionLoadsThisSecond > 0 ||
            stats.regionUnloadsThisSecond > 0
    }

    public func recordStreamingLoad() { stats.streamingLoadsThisSecond += 1 }
    public func recordStreamingUnload() { stats.streamingUnloadsThisSecond += 1 }
    public func recordLODSwitch() { stats.lodSwitchesThisSecond += 1 }
    public func recordLODFallback() { stats.lodFallbacksThisSecond += 1 }
    public func recordBatchRebuild() { stats.batchRebuildsThisSecond += 1 }
    public func setResidentMeshCount(_ count: Int) { stats.residentMeshCount = count }

    // Region streaming
    public func recordRegionLoad() { stats.regionLoadsThisSecond += 1 }
    public func recordRegionUnload() { stats.regionUnloadsThisSecond += 1 }
    public func setLoadedRegionCount(_ count: Int) { stats.loadedRegionCount = count }
}

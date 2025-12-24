//
//  AssetLoadingState.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation

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
        loadingEntities.removeValue(forKey: entityId)
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

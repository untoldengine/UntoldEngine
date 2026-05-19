//
//  ProgressiveAssetLoader.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

// MARK: - Loader

/// Manages the out-of-core streaming CPU registry for .untold assets.
///
/// Large .untold tiles are registered as zero-GPU stub entities. CPU-side RuntimeAssetNode data
/// is stored in `cpuRuntimeRegistry` keyed by child entity ID so `GeometryStreamingSystem` can
/// upload each stub on demand — no disk re-read required on normal eviction/reload cycles.
///
/// ## Integration
/// - `setEntityMeshAsync()` registers stubs and stores CPURuntimeEntry for OCC-routed tiles.
/// - `GeometryStreamingSystem.loadMeshAsync()` retrieves entries via `retrieveCPURuntimeEntry(for:)`.
/// - Call `removeOutOfCoreAsset(rootEntityId:)` when destroying a root entity.
/// - Call `cancelAll()` during scene resets or test teardown.
public final class ProgressiveAssetLoader: @unchecked Sendable {
    public static let shared = ProgressiveAssetLoader()

    // MARK: State

    private let lock = NSLock()

    // MARK: - .untold OCC Registry

    /// All context needed to upload one .untold mesh node to Metal without re-reading the file.
    ///
    /// RuntimeAssetNode is a value type whose vertexData/indexData are self-contained Data blobs
    /// — no parent asset reference is needed to keep the buffers alive. Stored in
    /// cpuRuntimeRegistry keyed by child entity ID.
    struct CPURuntimeEntry {
        let node: RuntimeAssetNode
        let url: URL
        let uniqueAssetName: String
        let estimatedGPUBytes: Int
        let residencyPolicy: AssetLoadingPolicy
    }

    /// CPU-resident .untold runtime node data keyed by child entity ID.
    private var cpuRuntimeRegistry: [EntityID: CPURuntimeEntry] = [:]

    /// Child entity IDs grouped by root entity ID — used to bulk-remove CPU entries
    /// when the root entity is destroyed.
    private var rootEntityChildren: [EntityID: [EntityID]] = [:]

    // MARK: - Registry API

    func storeCPURuntimeEntry(_ entry: CPURuntimeEntry, for entityId: EntityID) {
        lock.lock()
        cpuRuntimeRegistry[entityId] = entry
        lock.unlock()
    }

    func retrieveCPURuntimeEntry(for entityId: EntityID) -> CPURuntimeEntry? {
        lock.lock()
        defer { lock.unlock() }
        return cpuRuntimeRegistry[entityId]
    }

    func hasCPURuntimeData(for entityId: EntityID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cpuRuntimeRegistry[entityId] != nil
    }

    func removeCPURuntimeEntry(for entityId: EntityID) {
        lock.lock()
        cpuRuntimeRegistry.removeValue(forKey: entityId)
        lock.unlock()
    }

    func registerChildren(_ childIds: [EntityID], for rootEntityId: EntityID) {
        lock.lock()
        rootEntityChildren[rootEntityId] = childIds
        lock.unlock()
    }

    func getChildren(for rootEntityId: EntityID) -> [EntityID] {
        lock.lock()
        defer { lock.unlock() }
        return rootEntityChildren[rootEntityId] ?? []
    }

    // MARK: - Lifecycle

    /// Release all CPU entries for a root entity.
    /// Call this when the root entity is destroyed to free CPU-heap geometry data.
    public func removeOutOfCoreAsset(rootEntityId: EntityID) {
        lock.lock()
        let children = rootEntityChildren.removeValue(forKey: rootEntityId) ?? []
        for childId in children {
            cpuRuntimeRegistry.removeValue(forKey: childId)
        }
        lock.unlock()
        if !children.isEmpty {
            Logger.log(
                message: "[OutOfCore] Released CPU data for \(children.count) entities (root \(rootEntityId))",
                category: LogCategory.oocStatus.rawValue
            )
        }
    }

    private init() {}

    // MARK: Per-Frame Tick

    /// No-op stub retained for call-site compatibility.
    public func tick() {}

    // MARK: Cancellation

    /// Release all CPU entries. Call this during scene resets or test teardown.
    public func cancelAll() {
        lock.lock()
        cpuRuntimeRegistry.removeAll()
        rootEntityChildren.removeAll()
        lock.unlock()
        Logger.log(
            message: "[OutOfCore] Released all CPU data (cancelAll)",
            category: LogCategory.oocStatus.rawValue
        )
    }
}

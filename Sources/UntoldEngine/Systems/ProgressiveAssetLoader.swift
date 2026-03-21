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
import MetalKit
import ModelIO

// MARK: - Loader

/// Manages the out-of-core streaming CPU registry for large USD/USDZ assets.
///
/// Large assets (exceeding `fileSizeThresholdBytes` or `outOfCoreObjectCountThreshold`)
/// are registered as zero-GPU stub entities immediately. CPU-side MDLMesh data is stored
/// in `cpuMeshRegistry` keyed by child entity ID so `GeometryStreamingSystem` can upload
/// each mesh on demand — no disk re-read required on eviction/reload cycles.
///
/// ## Integration
/// - `setEntityMeshAsync()` registers stubs and stores CPU entries for large assets.
/// - `GeometryStreamingSystem.loadMeshAsync()` retrieves CPU entries via `retrieveCPUMesh(for:)`.
/// - `UntoldEngine.swift` calls `tick()` each frame (no-op; retained for API compatibility).
/// - Call `removeOutOfCoreAsset(rootEntityId:)` when destroying a root entity.
public final class ProgressiveAssetLoader: @unchecked Sendable {
    public static let shared = ProgressiveAssetLoader()

    // MARK: Configuration

    /// File-size threshold (bytes) that routes assets to the out-of-core stub path.
    ///
    /// Assets whose on-disk size exceeds this value are registered as stub entities with
    /// no GPU allocation. GeometryStreamingSystem uploads each stub from CPU RAM on demand.
    /// Assets at or below use the immediate fast path (all meshes registered in one pass).
    ///
    /// Default: 50 MB. Adjust based on the target device's GPU memory budget.
    public var fileSizeThresholdBytes: Int = 50 * 1024 * 1024 // 50 MB

    /// Minimum leaf-mesh count that triggers the out-of-core stub path regardless of file size.
    ///
    /// A small USDZ (e.g. 18 MB) with 200+ objects would bypass the file-size threshold
    /// and never get out-of-core treatment. This count-based trigger catches those cases.
    /// Default: 50 meshes. Set to `Int.max` to disable count-based triggering.
    public var outOfCoreObjectCountThreshold: Int = 50

    /// Set to `false` to skip all texture loading during mesh upload.
    /// Useful for testing geometry-only throughput without the texture decompression overhead.
    public var textureLoadingEnabled: Bool = true

    // MARK: State

    private let lock = NSLock()

    // MARK: Out-of-Core CPU Registry

    /// All context needed to upload one MDLMesh leaf to Metal without re-reading the USDZ.
    ///
    /// Stored in `cpuMeshRegistry` keyed by child entity ID. The registry entry persists
    /// across eviction/reload cycles so GeometryStreamingSystem can re-upload the mesh from
    /// CPU RAM whenever the entity re-enters streaming range — no disk I/O required.
    struct CPUMeshEntry: @unchecked Sendable {
        let object: MDLObject
        let vertexDescriptor: MDLVertexDescriptor
        let textureLoader: TextureLoader
        let device: MTLDevice
        let url: URL
        let filename: String
        let withExtension: String
        /// Pre-computed unique name for this entity: "\(parentName)#\(index)".
        let uniqueAssetName: String
        /// Estimated GPU memory (bytes) for pre-emptive budget reservation.
        /// Computed from MDLMesh vertex/index counts at stub registration time — no disk I/O.
        let estimatedGPUBytes: Int
    }

    /// CPU-resident mesh data keyed by child entity ID.
    private var cpuMeshRegistry: [EntityID: CPUMeshEntry] = [:]

    /// MDLAsset references kept alive per root entity so the MDLMeshBufferDataAllocator
    /// that backs all child MDLMesh CPU buffers is not prematurely released.
    private var rootAssetRefs: [EntityID: MDLAsset] = [:]

    /// Child entity IDs grouped by root entity ID — used to bulk-remove CPU entries
    /// when the root entity is destroyed.
    private var rootEntityChildren: [EntityID: [EntityID]] = [:]

    /// Per-asset NSLocks that serialize texture hydration across concurrent streaming uploads.
    ///
    /// MDLAsset is not thread-safe. Two Tasks uploading different meshes from the same asset
    /// simultaneously can race during `loadTextures()` or `texelDataWithTopLeftOrigin`. One lock
    /// per root entity ensures only one mesh from a given asset loads textures at a time.
    private var assetTextureLocks: [EntityID: NSLock] = [:]

    /// Tracks which root assets have already had `loadTextures()` called on their MDLAsset.
    /// After the first upload from an asset triggers deferred texture loading, subsequent
    /// uploads from the same asset skip the call.
    private var assetTexturesLoaded: Set<EntityID> = []

    func storeCPUMesh(_ entry: CPUMeshEntry, for entityId: EntityID) {
        lock.lock()
        cpuMeshRegistry[entityId] = entry
        lock.unlock()
    }

    func retrieveCPUMesh(for entityId: EntityID) -> CPUMeshEntry? {
        lock.lock()
        defer { lock.unlock() }
        return cpuMeshRegistry[entityId]
    }

    func removeCPUMesh(for entityId: EntityID) {
        lock.lock()
        cpuMeshRegistry.removeValue(forKey: entityId)
        lock.unlock()
    }

    func storeAsset(_ asset: MDLAsset, for rootEntityId: EntityID) {
        lock.lock()
        rootAssetRefs[rootEntityId] = asset
        assetTextureLocks[rootEntityId] = NSLock()
        lock.unlock()
    }

    /// Acquire the per-asset texture-load lock before calling makeMeshesFromCPUBuffers.
    /// Returns immediately if no asset is registered for this root (e.g. non-out-of-core entity).
    func acquireAssetTextureLock(for rootEntityId: EntityID) {
        lock.lock()
        let assetLock = assetTextureLocks[rootEntityId]
        lock.unlock()
        assetLock?.lock()
    }

    /// Release the per-asset texture-load lock after makeMeshesFromCPUBuffers returns.
    func releaseAssetTextureLock(for rootEntityId: EntityID) {
        lock.lock()
        let assetLock = assetTextureLocks[rootEntityId]
        lock.unlock()
        assetLock?.unlock()
    }

    /// Call `loadTextures()` on the MDLAsset for `rootEntityId` if it has not been called yet.
    ///
    /// **Must be called while the per-asset texture lock is held** (i.e. between
    /// `acquireAssetTextureLock` and `releaseAssetTextureLock`) to prevent two concurrent
    /// uploads from both seeing `texturesLoaded == false` and both calling `loadTextures()`.
    ///
    /// This defers the texture decompression from parse time (where it could OOM-kill the
    /// process) to first-upload time, where the app is already interactive and the RAM budget
    /// is more predictable. Subsequent uploads from the same asset skip the call entirely.
    func ensureTexturesLoaded(for rootEntityId: EntityID) {
        lock.lock()
        let alreadyLoaded = assetTexturesLoaded.contains(rootEntityId)
        let asset = rootAssetRefs[rootEntityId]
        lock.unlock()

        guard !alreadyLoaded, let asset else { return }
        guard textureLoadingEnabled else { return }

        Logger.log(message: "[OutOfCore] Deferred loadTextures() for root entity \(rootEntityId) — loading textures at first upload")
        asset.loadTextures()

        lock.lock()
        assetTexturesLoaded.insert(rootEntityId)
        lock.unlock()
    }

    func registerChildren(_ childIds: [EntityID], for rootEntityId: EntityID) {
        lock.lock()
        rootEntityChildren[rootEntityId] = childIds
        lock.unlock()
    }

    /// Release all CPU mesh entries and the MDLAsset for a root entity.
    /// Call this when the root entity is destroyed to free CPU-heap geometry data.
    public func removeOutOfCoreAsset(rootEntityId: EntityID) {
        lock.lock()
        let children = rootEntityChildren.removeValue(forKey: rootEntityId) ?? []
        rootAssetRefs.removeValue(forKey: rootEntityId)
        assetTextureLocks.removeValue(forKey: rootEntityId)
        assetTexturesLoaded.remove(rootEntityId)
        for childId in children {
            cpuMeshRegistry.removeValue(forKey: childId)
        }
        lock.unlock()
        if !children.isEmpty {
            Logger.log(message: "[OutOfCore] Released CPU mesh data for \(children.count) entities (root \(rootEntityId))")
        }
    }

    private init() {}

    // MARK: Per-Frame Tick

    /// No-op stub retained for call-site compatibility (UntoldEngine.swift, UntoldEngineXR.swift).
    /// The out-of-core path registers all stubs synchronously in setEntityMeshAsync and drives
    /// GPU uploads via GeometryStreamingSystem — no per-frame job processing is needed here.
    public func tick() {}

    // MARK: Cancellation

    /// Release all out-of-core CPU mesh entries and the MDLAsset for every root entity.
    /// Call this during scene resets or test teardown.
    public func cancelAll() {
        lock.lock()
        cpuMeshRegistry.removeAll()
        rootAssetRefs.removeAll()
        rootEntityChildren.removeAll()
        assetTextureLocks.removeAll()
        assetTexturesLoaded.removeAll()
        lock.unlock()
        Logger.log(message: "[OutOfCore] Released all CPU mesh data (cancelAll)")
    }
}

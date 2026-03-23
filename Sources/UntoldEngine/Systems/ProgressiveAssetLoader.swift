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
/// Large assets are registered as zero-GPU stub entities immediately. CPU-side MDLMesh data is
/// stored in `cpuMeshRegistry` keyed by child entity ID so `GeometryStreamingSystem` can upload
/// each mesh on demand — no disk re-read required on normal eviction/reload cycles.
///
/// ## Warm / Cold Residency Lifecycle
///
/// Each root asset starts **CPU-warm**: its `MDLAsset` and all child `MDLObject` buffers are
/// alive in `rootAssetRefs` / `cpuMeshRegistry`. Uploads read directly from RAM.
///
/// Call `releaseWarmAsset(rootEntityId:)` to transition an asset to **CPU-cold**: the
/// `MDLAsset` and all child CPU buffers are released, freeing heap memory. The
/// `RootRehydrationContext` (URL + loading policy) stored at registration time is retained so
/// `GeometryStreamingSystem` can re-parse from disk transparently when a cold entity
/// re-enters streaming range.
///
/// Cold re-hydration is serialized per root entity via `getOrCreateRehydrationTask`: exactly one
/// re-parse `Task` runs per root regardless of how many child entities concurrently detect the
/// cold state. Once re-parsing completes, `markAsWarm` restores the warm state.
///
/// ## Integration
/// - `setEntityMeshAsync()` registers stubs, stores CPU entries, and calls
///   `storeRootRehydrationContext` for large assets.
/// - `GeometryStreamingSystem.loadMeshAsync()` retrieves CPU entries via `retrieveCPUMesh(for:)`;
///   if the asset is cold it calls `rehydrateColdAsset` to re-parse from disk.
/// - `UntoldEngine.swift` calls `tick()` each frame (no-op; retained for API compatibility).
/// - Call `removeOutOfCoreAsset(rootEntityId:)` when destroying a root entity.
/// - Call `releaseWarmAsset(rootEntityId:)` to free CPU-heap memory while keeping the
///   entity registered so it can be re-hydrated on demand.
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
    ///
    /// - Note: Deprecated. Asset classification is now handled by the two-stage admission gate
    ///   in `RegistrationSystem.setEntityMeshAsync` (Stage 1: 20× file-size expansion vs 50%
    ///   physical RAM; Stage 2: `AssetProfiler.profile` geometry bytes vs 75% physical RAM)
    ///   and by `AssetProfiler.classifyPolicy` for the `.auto` streaming policy. This property
    ///   is retained only for call-site compatibility and has no effect on admission decisions.
    @available(*, deprecated, message: "No longer used for admission decisions. The two-stage gate in setEntityMeshAsync and AssetProfiler.classifyPolicy replace this threshold. Safe to remove from call sites.")
    public var fileSizeThresholdBytes: Int = 50 * 1024 * 1024 // 50 MB

    /// Minimum leaf-mesh count that triggers the out-of-core stub path regardless of file size.
    ///
    /// A small USDZ (e.g. 18 MB) with 200+ objects would bypass the file-size threshold
    /// and never get out-of-core treatment. This count-based trigger catches those cases.
    /// Default: 50 meshes. Set to `Int.max` to disable count-based triggering.
    ///
    /// - Note: Deprecated. Asset classification is now handled by the two-stage admission gate
    ///   in `RegistrationSystem.setEntityMeshAsync` and by `AssetProfiler.classifyPolicy`.
    ///   This property is retained only for call-site compatibility and has no effect on
    ///   classification decisions.
    @available(*, deprecated, message: "No longer used for classification. AssetProfiler.classifyPolicy and the two-stage admission gate replace this threshold. Safe to remove from call sites.")
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
        /// The loading policy selected at classification time (computed by AssetProfiler
        /// for .auto, or derived from the caller's MeshStreamingPolicy for .outOfCore /
        /// .immediate). This is immutable classification-time intent, not mutable runtime
        /// state. uploadFromCPUEntry reads this to decide geometry and texture upload behaviour.
        let residencyPolicy: AssetLoadingPolicy
    }

    /// Immutable context needed to re-parse a cold root asset from disk.
    ///
    /// Stored at stub-registration time in `rootRehydrationContexts`. Survives `releaseWarmAsset`
    /// so `GeometryStreamingSystem` can re-parse the USDZ and rebuild CPU entries without
    /// any information from the caller.
    struct RootRehydrationContext: @unchecked Sendable {
        let url: URL
        let loadingPolicy: AssetLoadingPolicy
    }

    /// CPU-resident mesh data keyed by child entity ID.
    private var cpuMeshRegistry: [EntityID: CPUMeshEntry] = [:]

    /// CPU-resident LOD mesh data keyed by LOD group entity ID → LOD index.
    ///
    /// Used exclusively by the LOD+OOC path where a single entity holds a `LODComponent`
    /// whose levels are each backed by a separate `CPUMeshEntry`. Unlike `cpuMeshRegistry`
    /// (one entry per stub entity), this stores N entries per entity — one per LOD level.
    private var cpuLODRegistry: [EntityID: [Int: CPUMeshEntry]] = [:]

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

    /// Root entity IDs whose background prewarm task is currently executing `loadTextures()`.
    /// Entities belonging to a root in this set are deferred by the scheduler: dispatching
    /// them while the prewarm holds the per-asset texture lock would block the entire first
    /// batch for the full remaining prewarm duration (~1-2 s). Slots stay free until the
    /// prewarm releases the lock, then the burst fires with lockWait ≈ 0.
    private var activePrewarmRoots: Set<EntityID> = []

    // MARK: Warm / Cold Residency State

    /// Root entity IDs whose CPU data (MDLAsset + cpuMeshRegistry entries) has been released.
    /// Warm roots are absent from this set. Cold roots are re-hydratable from `rootRehydrationContexts`.
    private var coldRoots: Set<EntityID> = []

    /// Rehydration context (URL + policy) keyed by root entity ID.
    /// Populated at stub-registration time; survives `releaseWarmAsset`.
    private var rootRehydrationContexts: [EntityID: RootRehydrationContext] = [:]

    /// In-flight re-parse tasks keyed by root entity ID.
    /// `getOrCreateRehydrationTask` ensures at most one task runs per root concurrently.
    private var coldRehydrationTasks: [EntityID: Task<Bool, Never>] = [:]

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

    // MARK: LOD CPU Registry

    /// Store the CPU mesh entry for one LOD level of a LOD group entity.
    func storeCPULODMesh(_ entry: CPUMeshEntry, for entityId: EntityID, lodIndex: Int) {
        lock.lock()
        if cpuLODRegistry[entityId] == nil {
            cpuLODRegistry[entityId] = [:]
        }
        cpuLODRegistry[entityId]![lodIndex] = entry
        lock.unlock()
    }

    /// Retrieve the CPU mesh entry for one LOD level of a LOD group entity.
    func retrieveCPULODMesh(for entityId: EntityID, lodIndex: Int) -> CPUMeshEntry? {
        lock.lock()
        defer { lock.unlock() }
        return cpuLODRegistry[entityId]?[lodIndex]
    }

    /// Retrieve all LOD-level CPU entries for a LOD group entity (keyed by LOD index).
    func retrieveAllCPULODMeshes(for entityId: EntityID) -> [Int: CPUMeshEntry]? {
        lock.lock()
        defer { lock.unlock() }
        return cpuLODRegistry[entityId]
    }

    /// Returns `true` if the entity has at least one CPU LOD entry (i.e. was registered via the LOD+OOC path).
    func hasCPULODData(for entityId: EntityID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !(cpuLODRegistry[entityId]?.isEmpty ?? true)
    }

    /// Remove all CPU LOD entries for a LOD group entity (called on entity destruction or cold-release).
    func removeCPULODEntry(for entityId: EntityID) {
        lock.lock()
        cpuLODRegistry.removeValue(forKey: entityId)
        lock.unlock()
    }

    func storeAsset(_ asset: MDLAsset, for rootEntityId: EntityID) {
        lock.lock()
        rootAssetRefs[rootEntityId] = asset
        assetTextureLocks[rootEntityId] = NSLock()
        lock.unlock()
        // Kick off a background pre-warm so loadTextures() completes before any mesh
        // enters streaming range. This moves the first-texture penalty off the critical
        // upload path — the per-asset lock ensures at-most-once execution.
        prewarmTexturesAsync(for: rootEntityId)
    }

    /// Returns `true` while the background prewarm task for `rootEntityId` is running.
    ///
    /// The scheduler uses this to defer dispatching entities for this root until the prewarm
    /// releases the per-asset texture lock. Once it returns `false`, the next burst tick
    /// dispatches the full first batch with lockWait ≈ 0.
    func isPrewarmActive(for rootEntityId: EntityID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activePrewarmRoots.contains(rootEntityId)
    }

    /// Fire a background task to call `loadTextures()` on this root asset's MDLAsset.
    ///
    /// Runs at user-initiated priority so it completes quickly before meshes enter range.
    /// `ensureTexturesLoaded` is idempotent — if the upload path races and calls it first,
    /// the pre-warm becomes a no-op, and vice versa. The per-asset texture lock prevents
    /// both from running `loadTextures()` simultaneously.
    /// Marks `activePrewarmRoots` while running so the scheduler can defer dispatch.
    private func clearPrewarmActive(for rootEntityId: EntityID) {
        lock.lock()
        activePrewarmRoots.remove(rootEntityId)
        lock.unlock()
    }

    private func prewarmTexturesAsync(for rootEntityId: EntityID) {
        guard textureLoadingEnabled else { return }
        lock.lock()
        activePrewarmRoots.insert(rootEntityId)
        lock.unlock()
        Task.detached(priority: .userInitiated) {
            ProgressiveAssetLoader.shared.acquireAssetTextureLock(for: rootEntityId)
            ProgressiveAssetLoader.shared.ensureTexturesLoaded(for: rootEntityId)
            ProgressiveAssetLoader.shared.releaseAssetTextureLock(for: rootEntityId)
            ProgressiveAssetLoader.shared.clearPrewarmActive(for: rootEntityId)
        }
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
        // [Instrumentation] Time the first-texture penalty: loadTextures() is only called
        // once per asset, but it decodes all embedded textures synchronously. If this is
        // large it confirms the first-texture setup cost as a dominant bottleneck.
        let loadTexturesStart = CFAbsoluteTimeGetCurrent()
        asset.loadTextures()
        let loadTexturesMs = (CFAbsoluteTimeGetCurrent() - loadTexturesStart) * 1000.0
        Logger.log(message: "[OOC-Timing] Root \(rootEntityId): loadTextures() first-texture penalty=\(String(format: "%.1f", loadTexturesMs))ms")

        lock.lock()
        assetTexturesLoaded.insert(rootEntityId)
        lock.unlock()
    }

    func registerChildren(_ childIds: [EntityID], for rootEntityId: EntityID) {
        lock.lock()
        rootEntityChildren[rootEntityId] = childIds
        lock.unlock()
    }

    /// Store the rehydration context for a root entity.
    /// Call this once at stub-registration time (after `storeAsset` and `registerChildren`).
    func storeRootRehydrationContext(url: URL, policy: AssetLoadingPolicy, for rootEntityId: EntityID) {
        lock.lock()
        rootRehydrationContexts[rootEntityId] = RootRehydrationContext(url: url, loadingPolicy: policy)
        lock.unlock()
    }

    // MARK: Warm / Cold Lifecycle

    /// Transition a root entity from CPU-warm to CPU-cold.
    ///
    /// Releases the `MDLAsset` and all child `CPUMeshEntry` objects, freeing CPU-heap memory.
    /// The `RootRehydrationContext` is retained so `GeometryStreamingSystem` can re-parse
    /// the asset from disk when the entity next enters streaming range.
    ///
    /// - Note: This does NOT destroy ECS entities or GPU resources. It only frees the CPU-side
    ///   MDLAsset and CPU buffers. GPU-resident meshes (if any) remain until eviction.
    public func releaseWarmAsset(rootEntityId: EntityID) {
        lock.lock()
        let children = rootEntityChildren[rootEntityId] ?? []
        rootAssetRefs.removeValue(forKey: rootEntityId)
        assetTextureLocks.removeValue(forKey: rootEntityId)
        assetTexturesLoaded.remove(rootEntityId)
        for childId in children {
            cpuMeshRegistry.removeValue(forKey: childId)
            cpuLODRegistry.removeValue(forKey: childId)
        }
        coldRoots.insert(rootEntityId)
        lock.unlock()
        Logger.log(message: "[OutOfCore] Released warm CPU data for root \(rootEntityId) (\(children.count) children) — asset is now cold")
    }

    /// Returns `true` if the root entity is CPU-cold (warm assets were released via `releaseWarmAsset`).
    func isColdRoot(_ rootEntityId: EntityID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return coldRoots.contains(rootEntityId)
    }

    /// Returns the rehydration context for a root entity, or `nil` if none is registered.
    func rehydrationContext(for rootEntityId: EntityID) -> RootRehydrationContext? {
        lock.lock()
        defer { lock.unlock() }
        return rootRehydrationContexts[rootEntityId]
    }

    /// Returns the child entity IDs for a root entity (in registration order).
    func getChildren(for rootEntityId: EntityID) -> [EntityID] {
        lock.lock()
        defer { lock.unlock() }
        return rootEntityChildren[rootEntityId] ?? []
    }

    /// Return the existing in-flight rehydration task for `rootEntityId`, or create and
    /// store a new one using `factory`. Exactly one task runs per root at a time.
    func getOrCreateRehydrationTask(
        for rootEntityId: EntityID,
        factory: () -> Task<Bool, Never>
    ) -> Task<Bool, Never> {
        lock.lock()
        defer { lock.unlock() }
        if let existing = coldRehydrationTasks[rootEntityId] {
            return existing
        }
        let task = factory()
        coldRehydrationTasks[rootEntityId] = task
        return task
    }

    /// Restore a root entity to warm state after successful re-hydration.
    /// Removes it from `coldRoots` and clears the completed rehydration task.
    func markAsWarm(rootEntityId: EntityID) {
        lock.lock()
        coldRoots.remove(rootEntityId)
        coldRehydrationTasks.removeValue(forKey: rootEntityId)
        lock.unlock()
    }

    /// Remove the in-flight rehydration task for `rootEntityId` (e.g. after failure).
    func clearRehydrationTask(for rootEntityId: EntityID) {
        lock.lock()
        coldRehydrationTasks.removeValue(forKey: rootEntityId)
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
            cpuLODRegistry.removeValue(forKey: childId)
        }
        // Clear warm/cold lifecycle state and prewarm tracking.
        coldRoots.remove(rootEntityId)
        rootRehydrationContexts.removeValue(forKey: rootEntityId)
        activePrewarmRoots.remove(rootEntityId)
        let task = coldRehydrationTasks.removeValue(forKey: rootEntityId)
        lock.unlock()
        task?.cancel()
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
        cpuLODRegistry.removeAll()
        rootAssetRefs.removeAll()
        rootEntityChildren.removeAll()
        assetTextureLocks.removeAll()
        assetTexturesLoaded.removeAll()
        coldRoots.removeAll()
        rootRehydrationContexts.removeAll()
        activePrewarmRoots.removeAll()
        let tasks = Array(coldRehydrationTasks.values)
        coldRehydrationTasks.removeAll()
        lock.unlock()
        tasks.forEach { $0.cancel() }
        Logger.log(message: "[OutOfCore] Released all CPU mesh data (cancelAll)")
    }
}

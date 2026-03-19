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
import QuartzCore

// MARK: - Load State

/// Tracks the stage of a progressively loading asset.
///
/// Designed to extend into a full residency-management state machine in Phase 2:
///   `.resident` → `.pending eviction` → `.evicted` → `.reloading`
public enum ProgressiveLoadState: Sendable {
    case parsingAsset
    case progressiveLoading(completed: Int, total: Int)
    case fullyLoaded
}

// MARK: - Pending Work Item

/// One top-level MDLObject pending MTKMesh creation and ECS registration.
///
/// Carries all context needed to create Metal resources and register the child
/// entity independently of the caller. Keeping `textureLoader` here (shared per
/// job) avoids recreating it per item.
struct PendingObjectItem: @unchecked Sendable {
    let index: Int
    let object: MDLObject
    let rootEntityId: EntityID
    let url: URL
    let filename: String
    let withExtension: String
    let vertexDescriptor: MDLVertexDescriptor
    let textureLoader: TextureLoader
    let device: MTLDevice
}

// MARK: - Load Job

/// Manages the lifecycle of one active progressive load for a root entity.
///
/// All mutable state (`nextPendingIndex`, `completedCount`, `failedCount`,
/// `state`, `assetRef`, `isCancelled`) is only mutated from `tick()`, which is
/// enforced to run on the main thread. The immutable `pending` array replaces
/// the old removeFirst() queue, giving O(1) dequeue via an index cursor.
final class ProgressiveLoadJob: @unchecked Sendable {
    let rootEntityId: EntityID
    let filename: String
    let withExtension: String
    let url: URL
    let startTime: Double
    let totalCount: Int

    /// Immutable work queue. Use `nextPendingIndex` as a cursor — O(1) dequeue,
    /// no array shifting. Replacing with removeFirst() would be O(n) per item.
    let pending: [PendingObjectItem]
    var nextPendingIndex: Int = 0

    var completedCount: Int = 0
    var failedCount: Int = 0
    var state: ProgressiveLoadState

    /// Set by `cancel(entityId:)` to stop processing at the next tick boundary.
    var isCancelled: Bool = false

    /// Retained so CPU-side MDLMesh objects (referenced by `Mesh.modelMDLMesh`)
    /// remain valid while batch processing is in flight. Released when the job finishes.
    var assetRef: MDLAsset?

    /// Called on the main actor when all mesh groups have been registered.
    let completion: ((Bool) -> Void)?

    var hasPendingWork: Bool {
        nextPendingIndex < pending.count
    }

    var isFullyLoaded: Bool {
        completedCount >= totalCount
    }

    init(
        rootEntityId: EntityID,
        filename: String,
        withExtension: String,
        url: URL,
        pending: [PendingObjectItem],
        totalCount: Int,
        assetRef: MDLAsset?,
        completion: ((Bool) -> Void)?
    ) {
        self.rootEntityId = rootEntityId
        self.filename = filename
        self.withExtension = withExtension
        self.url = url
        self.pending = pending
        self.totalCount = totalCount
        self.assetRef = assetRef
        startTime = CACurrentMediaTime()
        state = .progressiveLoading(completed: 0, total: totalCount)
        self.completion = completion
    }
}

// MARK: - Loader

/// Processes large USD/USDZ assets incrementally over multiple engine ticks.
///
/// Each tick, up to `maxMeshesPerTick` pending mesh groups are converted from
/// CPU-side MDLMesh data to Metal GPU buffers (`MTKMesh`) and registered as
/// renderable child entities. Already-registered meshes render immediately while
/// the remaining queue continues loading.
///
/// ## Scheduling
/// - Jobs are served in round-robin order so simultaneous loads share the per-tick
///   budget fairly rather than one job starving another.
/// - Processing also stops early if the tick wall-clock time exceeds
///   `maxTickMilliseconds`, adapting automatically to mesh complexity.
///
/// ## Integration
/// - `setEntityMeshAsync()` enqueues a `ProgressiveLoadJob` when an asset exceeds
///   `progressiveLoadingThreshold` top-level mesh groups.
/// - `UntoldEngine.swift` calls `ProgressiveAssetLoader.shared.tick()` each frame.
/// - Call `cancel(entityId:)` before destroying a root entity to stop orphaned
///   child-entity creation.
///
/// ## Phase 2 extensibility
/// - `PendingObjectItem` can carry distance/priority metadata for priority-based scheduling.
/// - `ProgressiveLoadJob.state` can extend to `.evicted` / `.reloading` for out-of-core support.
/// - Replace the count budget with a byte budget (`maxUploadBytesPerTick`) for finer control.
public final class ProgressiveAssetLoader: @unchecked Sendable {
    public static let shared = ProgressiveAssetLoader()

    // MARK: Configuration

    /// Maximum number of mesh groups to process per engine tick.
    /// Each group = one CPU→Metal buffer copy + one `MTKMesh` creation + one child entity registration.
    /// Lower = smoother frames; higher = faster total load time.
    /// The actual count processed may be lower if `maxTickMilliseconds` is reached first.
    public var maxMeshesPerTick: Int = 4

    /// Wall-clock budget per tick in milliseconds. Processing stops early when this
    /// is exceeded, regardless of how many items remain in the current batch.
    /// Adapts automatically to mesh complexity — a mesh with 50k triangles costs
    /// far more than one with 500, so a time budget is more reliable than a count budget alone.
    public var maxTickMilliseconds: Double = 2.0

    /// File-size threshold (bytes) that determines which loading path is used.
    ///
    /// Assets whose on-disk size exceeds this value use progressive loading —
    /// GPU memory is allocated one batch at a time to avoid a spike that could
    /// cause the OS to terminate the app. Assets at or below use the immediate
    /// fast path (all meshes registered in a single pass, no per-frame batching).
    ///
    /// Default: 50 MB. Adjust based on the target device's GPU memory budget.
    /// - A 1.5 MB file with 2 000 simple meshes is fast to upload all at once.
    /// - A 530 MB file must be streamed to avoid exhausting GPU memory.
    public var fileSizeThresholdBytes: Int = 50 * 1024 * 1024 // 50 MB

    /// Set to `false` to globally disable progressive loading (falls back to legacy path).
    public var enabled: Bool = true

    // MARK: State

    private var jobs: [EntityID: ProgressiveLoadJob] = [:]
    private let lock = NSLock()

    /// Rotates which job is served first each tick for round-robin fairness.
    private var roundRobinOffset: Int = 0

    /// `true` when at least one progressive load is in flight.
    public var hasActiveJobs: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !jobs.isEmpty
    }

    private init() {}

    // MARK: Enqueue

    /// Register a new progressive load job. Called from `setEntityMeshAsync()`.
    func enqueue(_ job: ProgressiveLoadJob) {
        lock.lock()
        jobs[job.rootEntityId] = job
        lock.unlock()
        Logger.log(message: "[ProgressiveLoader] Started progressive load for '\(job.filename)' — \(job.totalCount) mesh groups, \(maxMeshesPerTick)/tick max (root: \(job.rootEntityId))")
    }

    // MARK: Cancellation

    /// Stop processing for a root entity and remove its job immediately.
    ///
    /// Any batch already in flight during the current tick will finish, but no
    /// further child entities will be registered after this returns.
    /// Wire this into your entity destruction path to avoid orphaned children.
    public func cancel(entityId: EntityID) {
        lock.lock()
        let removed = jobs.removeValue(forKey: entityId)
        lock.unlock()
        removed?.isCancelled = true
        if removed != nil {
            Logger.log(message: "[ProgressiveLoader] Cancelled progressive load for entity \(entityId)")
        }
    }

    /// Cancel all active progressive load jobs immediately.
    ///
    /// Use this during scene resets or test teardown to prevent in-flight jobs
    /// from registering entities into a stale or already-destroyed scene.
    public func cancelAll() {
        lock.lock()
        let count = jobs.count
        jobs.removeAll()
        lock.unlock()
        if count > 0 {
            Logger.log(message: "[ProgressiveLoader] Cancelled all \(count) active progressive load jobs")
        }
    }

    // MARK: Per-Frame Tick

    /// Process pending mesh groups within the per-tick count and time budgets.
    ///
    /// Must be called from the main thread — mutations to `ProgressiveLoadJob`
    /// state are not lock-protected (the lock only guards the `jobs` dictionary).
    /// A `dispatchPrecondition` enforces this in debug builds.
    ///
    /// Jobs are served in round-robin order so concurrent loads share the budget
    /// fairly. Processing stops early when `maxTickMilliseconds` is exceeded.
    public func tick() {
        dispatchPrecondition(condition: .onQueue(.main))

        let snapshot: [ProgressiveLoadJob]
        lock.lock()
        snapshot = Array(jobs.values)
        lock.unlock()

        guard !snapshot.isEmpty else { return }

        // Rotate starting job each tick for round-robin fairness across simultaneous loads.
        roundRobinOffset = (roundRobinOffset + 1) % snapshot.count
        let orderedJobs: [ProgressiveLoadJob] = snapshot.count > 1
            ? Array(snapshot[roundRobinOffset...] + snapshot[..<roundRobinOffset])
            : snapshot

        var processedThisTick = 0
        var toRemove: [EntityID] = []
        let tickStart = CACurrentMediaTime()

        for job in orderedJobs {
            guard !job.isCancelled else {
                toRemove.append(job.rootEntityId)
                continue
            }

            let completedBefore = job.completedCount

            while processedThisTick < maxMeshesPerTick, job.hasPendingWork {
                // Frame-time budget: bail early if this tick is already over budget.
                let elapsedMs = (CACurrentMediaTime() - tickStart) * 1000
                if elapsedMs >= maxTickMilliseconds { break }

                // O(1) dequeue via index cursor — no array shifting.
                let item = job.pending[job.nextPendingIndex]
                job.nextPendingIndex += 1

                // CPU→Metal buffer copy + MTKMesh creation for this mesh only.
                // makeMeshesFromCPUBuffers copies MDLMeshBufferData (CPU heap) into fresh
                // MTKMeshBufferAllocator buffers before calling MTKMesh(mesh:device:),
                // which requires MTKMeshBuffer-backed data (MTKModelErrorNoMTLBuffer otherwise).
                let meshes = Mesh.makeMeshesFromCPUBuffers(
                    object: item.object,
                    vertexDescriptor: item.vertexDescriptor,
                    textureLoader: item.textureLoader,
                    device: item.device,
                    flip: true
                )

                processedThisTick += 1
                job.completedCount += 1
                job.state = .progressiveLoading(completed: job.completedCount, total: job.totalCount)

                if meshes.isEmpty {
                    // Mesh creation failed — count it so completion log reflects reality.
                    job.failedCount += 1
                    continue
                }

                // Register child entity — immediately renderable.
                // withWorldMutationGate inside briefly pauses XR traversal during ECS mutation.
                registerProgressiveChildEntity(
                    meshes: meshes,
                    index: item.index,
                    rootEntityId: item.rootEntityId,
                    url: item.url,
                    filename: item.filename,
                    withExtension: item.withExtension
                )
            }

            // Log at 50% and 100% milestones without spamming every tick.
            let pct = job.totalCount > 0
                ? Int((Float(job.completedCount) / Float(job.totalCount)) * 100)
                : 100
            let prevPct = job.totalCount > 0
                ? Int((Float(completedBefore) / Float(job.totalCount)) * 100)
                : 0
            let remaining = job.pending.count - job.nextPendingIndex
            if (prevPct < 50 && pct >= 50) || job.isFullyLoaded {
                Logger.log(message: "[ProgressiveLoader] '\(job.filename)': \(pct)% — \(job.completedCount)/\(job.totalCount) renderable (\(remaining) queued)")
            }

            if job.isFullyLoaded {
                toRemove.append(job.rootEntityId)
                job.state = .fullyLoaded
                let elapsed = CACurrentMediaTime() - job.startTime
                var summary = "[ProgressiveLoader] '\(job.filename)': progressive load complete ✅ \(job.totalCount) groups in \(String(format: "%.2f", elapsed))s"
                if job.failedCount > 0 {
                    summary += " (\(job.failedCount) mesh groups failed)"
                }
                Logger.log(message: summary)

                // Release the MDLAsset container. Individual MDLMesh instances survive
                // inside Mesh.modelMDLMesh references — the container itself is no longer needed.
                job.assetRef = nil

                let completionCallback = job.completion
                Task { @MainActor in
                    completionCallback?(true)
                }
            }
        }

        if !toRemove.isEmpty {
            lock.lock()
            for id in toRemove {
                jobs.removeValue(forKey: id)
            }
            lock.unlock()
        }

        if processedThisTick > 0 {
            let tickMs = (CACurrentMediaTime() - tickStart) * 1000.0
            let totalRemaining = snapshot.reduce(0) { $0 + ($1.pending.count - $1.nextPendingIndex) }
            Logger.log(message: "[ProgressiveLoader] Tick: \(processedThisTick) processed, \(totalRemaining) remaining (\(String(format: "%.1f", tickMs))ms)")
        }
    }

    // MARK: Queries

    /// Current load state for a given root entity, or `nil` if not progressively loading.
    public func loadState(for entityId: EntityID) -> ProgressiveLoadState? {
        lock.lock()
        defer { lock.unlock() }
        return jobs[entityId]?.state
    }

    /// Diagnostics snapshot: active job count, total items still queued, total completed.
    public func diagnostics() -> (activeJobs: Int, totalQueued: Int, totalCompleted: Int) {
        lock.lock()
        defer { lock.unlock() }
        let queued = jobs.values.reduce(0) { $0 + ($1.pending.count - $1.nextPendingIndex) }
        let completed = jobs.values.reduce(0) { $0 + $1.completedCount }
        return (jobs.count, queued, completed)
    }
}

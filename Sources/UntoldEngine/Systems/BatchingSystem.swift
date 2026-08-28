//
//  BatchingSystem.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import Metal
import simd

public struct BatchCellID: Hashable, Sendable {
    public var x: Int
    public var y: Int
    public var z: Int

    public init(x: Int, y: Int, z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = BatchCellID(x: 0, y: 0, z: 0)
}

public enum StaticBatchCellRenderState: String, Sendable {
    case unloaded
    case streaming
    case renderableUnbatched
    case batchPending
    case renderableBatched
    case retiring
}

private struct BatchBuildKey: Hashable {
    let cellId: BatchCellID
    let materialHash: String
    let lodIndex: Int
    let sceneChannelsRawValue: UInt64

    var materialLODHash: String {
        "\(materialHash)_LOD\(lodIndex)"
    }
}

private typealias BatchMeshItem = (
    entityId: EntityID,
    mesh: Mesh,
    meshIndex: Int,
    transform: simd_float4x4,
    material: Material
)

private struct BatchCandidate {
    let entityId: EntityID
    let renderComponent: RenderComponent
    let worldTransform: WorldTransformComponent
    let lodIndex: Int
    let cellId: BatchCellID
    let sceneChannels: SceneChannel
}

private struct BatchCellLifecycleRecord {
    var state: StaticBatchCellRenderState = .unloaded
    var nextBatchBuildFrame: Int = 0
    var dirtySinceFrame: Int = 0
}

private struct RetiringBatchArtifact {
    let cellId: BatchCellID
    let groups: [BatchGroup]
    let retireAfterFrame: Int
}

public struct BatchingTickDiagnostics: Sendable {
    public var tickFrame: Int = 0
    public var pendingEntityRemovals: Int = 0
    public var pendingEntityAdditions: Int = 0
    public var promotedCells: Int = 0
    public var consideredBatchPendingCells: Int = 0
    public var dirtyCellsBeforePrune: Int = 0
    public var dirtyCellsAfterPrune: Int = 0
    public var pendingBatchCells: Int = 0
    public var deferredByQuiescence: Int = 0
    public var deferredByVisibility: Int = 0
    public var deferredByWorkBudget: Int = 0
    public var skippedByComplexityGuard: Int = 0
    public var dispatchedBuilds: Int = 0
    public var appliedArtifacts: Int = 0
    public var inFlightBuildCells: Int = 0
    public var readyArtifactsQueued: Int = 0
    public var rebuiltCells: Int = 0
    public var rebuiltBatchGroups: Int = 0
    public var rebuiltVertices: Int = 0
    public var rebuiltIndices: Int = 0
    public var rebuiltBufferBytes: Int = 0
    public var rebuildWorkMs: Double = 0.0
    public var maxCellRebuildMs: Double = 0.0
    public var maxCell: BatchCellID?
    public var retiringArtifactsQueued: Int = 0

    public init() {}
}

/// Runtime tuning controls for streamed static batching behavior.
///
/// Use this to set how aggressively the engine upgrades cells from
/// `renderableUnbatched` to `renderableBatched`.
///
/// High values converge to batched rendering faster but risk CPU spikes.
/// Low values prioritize frame stability and smooth traversal.
public struct RuntimeBatchingTuning: Sendable {
    /// Maximum dirty cells considered for rebuild scheduling per tick.
    /// Lower values reduce worst-case tick work but can delay convergence.
    public var maxDirtyCellsPerTick: Int

    /// Maximum cells dispatched for background artifact build per tick.
    /// Lower values reduce background CPU pressure and contention.
    public var maxBuildDispatchesPerTick: Int

    /// Maximum completed artifacts applied (swapped to batched) per tick.
    /// Lower values smooth swap bursts when many builds finish together.
    public var maxArtifactAppliesPerTick: Int

    /// Per-tick work budget guard (estimated vertices).
    /// Helps cap rebuild cost even if few cells are selected.
    public var maxRebuildVerticesPerTick: Int

    /// Per-tick work budget guard (estimated indices).
    /// Pair this with vertex and byte budgets to prevent spikes.
    public var maxRebuildIndicesPerTick: Int

    /// Per-tick work budget guard (estimated combined buffer bytes).
    /// Useful when cell meshes are dense or have many attributes.
    public var maxRebuildBufferBytesPerTick: Int

    /// Per-cell runtime eligibility guard (vertices).
    /// Cells above this stay unbatched at runtime to avoid pathological stalls.
    public var maxRuntimeCellVertices: Int

    /// Per-cell runtime eligibility guard (indices).
    /// Use this with vertex/bytes guards for heavy architecture cells.
    public var maxRuntimeCellIndices: Int

    /// Per-cell runtime eligibility guard (estimated bytes).
    /// If exceeded, cell remains unbatched during traversal.
    public var maxRuntimeCellBufferBytes: Int

    /// Minimum stable frames before a dirty cell may enter rebuild work.
    /// Higher values avoid churn during frequent residency/LOD changes.
    public var quiescenceFramesBeforeBatchBuild: Int

    /// Frames a cell remains "recently visible" for scheduling priority.
    /// Larger windows keep near-past visible cells eligible longer.
    public var recentVisibilityWindowFrames: Int

    /// If true, only visible/recently-visible cells are promoted/rebuilt.
    /// Strongly recommended for large streamed scenes.
    public var visibilityGatedBatchBuildEnabled: Bool

    /// Deferred retirement artifacts processed per tick.
    /// Lower values smooth teardown cost; higher values reclaim memory faster.
    public var maxRetirementsPerTick: Int

    /// Safety delay (frames) before retired batch GPU resources are released.
    /// Increase when testing for GPU in-flight safety issues.
    public var batchRetireDelayFrames: Int

    /// World-space side length of each batch cell (in all three axes).
    /// Smaller values produce more cells with fewer entities each, reducing the
    /// chance that a cell exceeds the runtime complexity guard.  Larger values
    /// reduce cell count and bookkeeping overhead but increase per-cell density.
    /// Changing this at runtime invalidates all existing batches and triggers a
    /// full rebuild.
    public var cellSize: Float

    public init(
        maxDirtyCellsPerTick: Int = 8,
        maxBuildDispatchesPerTick: Int = 4,
        maxArtifactAppliesPerTick: Int = 4,
        maxRebuildVerticesPerTick: Int = 120_000,
        maxRebuildIndicesPerTick: Int = 220_000,
        maxRebuildBufferBytesPerTick: Int = 6 * 1024 * 1024,
        maxRuntimeCellVertices: Int = 160_000,
        maxRuntimeCellIndices: Int = 300_000,
        maxRuntimeCellBufferBytes: Int = 8 * 1024 * 1024,
        quiescenceFramesBeforeBatchBuild: Int = 1,
        recentVisibilityWindowFrames: Int = 120,
        visibilityGatedBatchBuildEnabled: Bool = true,
        maxRetirementsPerTick: Int = 8,
        batchRetireDelayFrames: Int = 3,
        cellSize: Float = 32.0
    ) {
        self.maxDirtyCellsPerTick = maxDirtyCellsPerTick
        self.maxBuildDispatchesPerTick = maxBuildDispatchesPerTick
        self.maxArtifactAppliesPerTick = maxArtifactAppliesPerTick
        self.maxRebuildVerticesPerTick = maxRebuildVerticesPerTick
        self.maxRebuildIndicesPerTick = maxRebuildIndicesPerTick
        self.maxRebuildBufferBytesPerTick = maxRebuildBufferBytesPerTick
        self.maxRuntimeCellVertices = maxRuntimeCellVertices
        self.maxRuntimeCellIndices = maxRuntimeCellIndices
        self.maxRuntimeCellBufferBytes = maxRuntimeCellBufferBytes
        self.quiescenceFramesBeforeBatchBuild = quiescenceFramesBeforeBatchBuild
        self.recentVisibilityWindowFrames = recentVisibilityWindowFrames
        self.visibilityGatedBatchBuildEnabled = visibilityGatedBatchBuildEnabled
        self.maxRetirementsPerTick = maxRetirementsPerTick
        self.batchRetireDelayFrames = batchRetireDelayFrames
        self.cellSize = cellSize
    }

    /// Balanced defaults for desktop-class hardware.
    public static var macOSBalanced: RuntimeBatchingTuning {
        RuntimeBatchingTuning(
            maxDirtyCellsPerTick: 8,
            maxBuildDispatchesPerTick: 4,
            maxArtifactAppliesPerTick: 4,
            maxRebuildVerticesPerTick: 120_000,
            maxRebuildIndicesPerTick: 220_000,
            maxRebuildBufferBytesPerTick: 6 * 1024 * 1024,
            maxRuntimeCellVertices: 160_000,
            maxRuntimeCellIndices: 300_000,
            maxRuntimeCellBufferBytes: 8 * 1024 * 1024,
            quiescenceFramesBeforeBatchBuild: 1,
            recentVisibilityWindowFrames: 120,
            visibilityGatedBatchBuildEnabled: true,
            maxRetirementsPerTick: 8,
            batchRetireDelayFrames: 3,
            cellSize: 32.0
        )
    }

    /// Defaults tuned for Vision Pro: smaller cells and higher dispatch rate for
    /// fast convergence. The runtime complexity guard is set high because background
    /// artifact builds are async — large cells (dense architecture) add ~50–100 ms
    /// to the background queue, never stalling the render thread.
    public static var visionOSBalanced: RuntimeBatchingTuning {
        RuntimeBatchingTuning(
            maxDirtyCellsPerTick: 8,
            maxBuildDispatchesPerTick: 4,
            maxArtifactAppliesPerTick: 2,
            maxRebuildVerticesPerTick: 100_000,
            maxRebuildIndicesPerTick: 180_000,
            maxRebuildBufferBytesPerTick: 6 * 1024 * 1024,
            maxRuntimeCellVertices: 1_200_000,
            maxRuntimeCellIndices: 2_200_000,
            maxRuntimeCellBufferBytes: 70 * 1024 * 1024,
            quiescenceFramesBeforeBatchBuild: 2,
            recentVisibilityWindowFrames: 90,
            visibilityGatedBatchBuildEnabled: true,
            maxRetirementsPerTick: 4,
            batchRetireDelayFrames: 3,
            cellSize: 16.0
        )
    }
}

private struct DirtyRebuildMetrics {
    var dirtyCellsBeforePrune: Int = 0
    var dirtyCellsAfterPrune: Int = 0
    var consideredBatchPendingCells: Int = 0
    var pendingBatchCells: Int = 0
    var deferredByQuiescence: Int = 0
    var deferredByVisibility: Int = 0
    var deferredByWorkBudget: Int = 0
    var skippedByComplexityGuard: Int = 0
    var dispatchedBuilds: Int = 0
    var appliedArtifacts: Int = 0
    var inFlightBuildCells: Int = 0
    var readyArtifactsQueued: Int = 0
    var rebuiltCells: Int = 0
    var rebuiltBatchGroups: Int = 0
    var rebuiltVertices: Int = 0
    var rebuiltIndices: Int = 0
    var rebuiltBufferBytes: Int = 0
    var rebuildWorkMs: Double = 0.0
    var maxCellRebuildMs: Double = 0.0
    var maxCell: BatchCellID?
}

private struct PromotionMetrics {
    var promotedCells: Int = 0
    var deferredByQuiescence: Int = 0
    var deferredByVisibility: Int = 0
}

private struct CellWorkEstimate {
    var vertices: Int = 0
    var indices: Int = 0
    var bytes: Int = 0
    var opaqueSubmeshCount: Int = 0

    static let zero = CellWorkEstimate()
}

private struct CellRebuildCandidate {
    var cellId: BatchCellID
    var estimate: CellWorkEstimate
    var isVisibleNow: Bool
    var isRecentlyVisible: Bool
    var lastVisibleFrame: Int
    var dirtySinceFrame: Int
}

private struct CellBuildInput {
    var cellId: BatchCellID
    var generation: Int
    var epoch: Int
    var materialGroups: [BatchBuildKey: [BatchMeshItem]]
}

private struct PreparedCellArtifact {
    var cellId: BatchCellID
    var generation: Int
    var epoch: Int
    var builtGroups: [BatchGroup]
    var entityBatchMap: [EntityID: EntityBatchInfo]
    var groupCount: Int
    var vertexCount: Int
    var indexCount: Int
    var bufferBytes: Int
    var buildMs: Double
}

extension CellBuildInput: @unchecked Sendable {}
extension PreparedCellArtifact: @unchecked Sendable {}

private struct BatchCellRuntimeStats {
    var cellId: BatchCellID
    var lastEstimatedVertices: Int = 0
    var lastEstimatedIndices: Int = 0
    var lastEstimatedBytes: Int = 0
    var rebuildCount: Int = 0
    var lastRebuildMs: Double = 0.0
    var maxRebuildMs: Double = 0.0
    var skipByWorkBudgetCount: Int = 0
    var skipByQuiescenceCount: Int = 0
    var skipByComplexityCount: Int = 0
    var lastRebuiltGroupCount: Int = 0
}

public struct BatchCellRuntimeDiagnostic: Sendable {
    public var cellId: BatchCellID
    public var lastEstimatedVertices: Int
    public var lastEstimatedIndices: Int
    public var lastEstimatedBytes: Int
    public var rebuildCount: Int
    public var lastRebuildMs: Double
    public var maxRebuildMs: Double
    public var skipByWorkBudgetCount: Int
    public var skipByQuiescenceCount: Int
    public var skipByComplexityCount: Int
    public var lastRebuiltGroupCount: Int

    public init(
        cellId: BatchCellID,
        lastEstimatedVertices: Int,
        lastEstimatedIndices: Int,
        lastEstimatedBytes: Int,
        rebuildCount: Int,
        lastRebuildMs: Double,
        maxRebuildMs: Double,
        skipByWorkBudgetCount: Int,
        skipByQuiescenceCount: Int,
        skipByComplexityCount: Int,
        lastRebuiltGroupCount: Int
    ) {
        self.cellId = cellId
        self.lastEstimatedVertices = lastEstimatedVertices
        self.lastEstimatedIndices = lastEstimatedIndices
        self.lastEstimatedBytes = lastEstimatedBytes
        self.rebuildCount = rebuildCount
        self.lastRebuildMs = lastRebuildMs
        self.maxRebuildMs = maxRebuildMs
        self.skipByWorkBudgetCount = skipByWorkBudgetCount
        self.skipByQuiescenceCount = skipByQuiescenceCount
        self.skipByComplexityCount = skipByComplexityCount
        self.lastRebuiltGroupCount = lastRebuiltGroupCount
    }
}

public struct RuntimeBatchingSummaryDiagnostic: Sendable {
    public var trackedCells: Int
    public var runtimeIneligibleCells: Int
    public var averageEstimatedVerticesPerCell: Double
    public var maxEstimatedVerticesInCell: Int
    public var averageEstimatedBytesPerCell: Double
    public var maxEstimatedBytesInCell: Int
    public var worstRebuildMs: Double
    public var totalComplexitySkips: Int
    public var totalBudgetSkips: Int
    public var totalQuiescenceDeferrals: Int

    public init(
        trackedCells: Int = 0,
        runtimeIneligibleCells: Int = 0,
        averageEstimatedVerticesPerCell: Double = 0.0,
        maxEstimatedVerticesInCell: Int = 0,
        averageEstimatedBytesPerCell: Double = 0.0,
        maxEstimatedBytesInCell: Int = 0,
        worstRebuildMs: Double = 0.0,
        totalComplexitySkips: Int = 0,
        totalBudgetSkips: Int = 0,
        totalQuiescenceDeferrals: Int = 0
    ) {
        self.trackedCells = trackedCells
        self.runtimeIneligibleCells = runtimeIneligibleCells
        self.averageEstimatedVerticesPerCell = averageEstimatedVerticesPerCell
        self.maxEstimatedVerticesInCell = maxEstimatedVerticesInCell
        self.averageEstimatedBytesPerCell = averageEstimatedBytesPerCell
        self.maxEstimatedBytesInCell = maxEstimatedBytesInCell
        self.worstRebuildMs = worstRebuildMs
        self.totalComplexitySkips = totalComplexitySkips
        self.totalBudgetSkips = totalBudgetSkips
        self.totalQuiescenceDeferrals = totalQuiescenceDeferrals
    }
}

/// Per-cell breakdown of material key diversity. Used to diagnose why batch coverage is low.
public struct BatchCellMaterialBreakdown: Sendable {
    /// Cell coordinates.
    public var cellId: BatchCellID
    /// Entities currently registered in this cell.
    public var registeredEntities: Int
    /// Distinct (materialHash × LOD) combinations across all entities in this cell.
    public var uniqueMaterialLODKeys: Int
    /// Keys held by exactly one entity — these cannot form a batch group.
    public var singletonKeys: Int
    /// Keys shared by two or more entities — these will produce a batch group.
    public var groupableKeys: Int
    /// Batch groups currently built for this cell.
    public var builtBatchGroups: Int
    /// singletonKeys / uniqueMaterialLODKeys. 1.0 = nothing batches; 0.0 = everything batches.
    public var singletonRatio: Float

    public init(
        cellId: BatchCellID = .zero, registeredEntities: Int = 0,
        uniqueMaterialLODKeys: Int = 0, singletonKeys: Int = 0,
        groupableKeys: Int = 0, builtBatchGroups: Int = 0, singletonRatio: Float = 0
    ) {
        self.cellId = cellId; self.registeredEntities = registeredEntities
        self.uniqueMaterialLODKeys = uniqueMaterialLODKeys; self.singletonKeys = singletonKeys
        self.groupableKeys = groupableKeys; self.builtBatchGroups = builtBatchGroups
        self.singletonRatio = singletonRatio
    }
}

/// Scene-wide material diversity diagnostics. Expensive to collect — use
/// logMaterialDiagnosticsIfDue for rate-limited periodic logging.
public struct BatchMaterialDiagnostics: Sendable {
    /// Entities in the scene that carry StaticBatchComponent (resident or not).
    public var staticBatchComponentCount: Int = 0
    /// Entities currently registered in the batching system (resident + passed eligibility).
    public var registeredCandidates: Int = 0
    /// Registered entities that resolved cleanly through resolveBatchCandidate.
    public var resolvedCandidates: Int = 0
    /// Resolved entities that are the only entity for their material key in their cell.
    /// These cannot batch regardless of other settings.
    public var entitiesAsSingletons: Int = 0
    /// Resolved entities that share a material key with at least one peer in their cell.
    public var entitiesGroupable: Int = 0
    /// Cells permanently excluded by the runtime complexity guard.
    public var cellsBlockedByComplexity: Int = 0
    /// Distinct (materialHash × LOD) keys across all registered cells.
    public var uniqueMaterialLODKeys: Int = 0
    /// Material keys held by exactly one entity — will never produce a batch group.
    public var singletonMaterialKeys: Int = 0
    /// Material keys shared by two or more entities — will produce a batch group.
    public var groupableMaterialKeys: Int = 0
    /// Top cells ranked by unique material key count (highest diversity first).
    public var topCellsByMaterialDiversity: [BatchCellMaterialBreakdown] = []

    public init() {}
}

/// Represents a group of meshes batched together
public struct BatchGroup {
    var id: UUID
    var cellId: BatchCellID
    var lodIndex: Int
    var batchKey: String // Composite key: material hash + LOD
    var material: Material // Representative material for this batch

    // Separate buffers for each vertex attribute (simpler than interleaved)
    var positionBuffer: MTLBuffer?
    var normalBuffer: MTLBuffer?
    var uvBuffer: MTLBuffer?
    var tangentBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var featureEdgeIndexBuffer: MTLBuffer?

    var indexCount: Int
    var featureEdgeIndexCount: Int
    var vertexCount: Int
    var entityIds: [EntityID] // Original entities in this batch
    var meshIndices: [(entityId: EntityID, meshIndex: Int)] // Track source meshes
    var boundingBox: (min: simd_float3, max: simd_float3)
    var sceneChannels: SceneChannel

    /// Incremented each time `updateBatchMaterialInPlace` patches this group's textures.
    /// Used to detect whether a batch artifact is stale relative to the live streaming state.
    var textureGeneration: Int = 0

    /// True when at least one entity in this batch has a LODComponent.
    /// Used by the LOD debug visualizer to distinguish LOD batches from non-LOD batches
    /// so that non-LOD entities are not incorrectly colored with an LOD0 tint.
    var isLODBatch: Bool = false

    /// Backward-compatible alias; prefer batchKey for clarity.
    var materialHash: String {
        batchKey
    }
}

/// Tracks an entity's batch membership
public struct EntityBatchInfo {
    public var batchId: UUID
    public var lodIndex: Int
    public var materialHash: String
    public var cellId: BatchCellID = .zero
}

/// Manages all batching operations.
/// Access is expected from the engine's serialized update/render pipeline.
public class BatchingSystem: @unchecked Sendable {
    public static let shared = BatchingSystem()

    public private(set) var batchGroups: [BatchGroup] = []
    private var entityToBatch: [EntityID: EntityBatchInfo] = [:] // Track which batch an entity belongs to
    private var batchIdToIndex: [UUID: Int] = [:] // Fast batch lookup by id
    private var batchedCells: Set<BatchCellID> = [] // Fast check for cells that currently have active batches
    private var entityToCellMembership: [EntityID: BatchCellID] = [:] // Track candidate cell membership
    private var cellToEntities: [BatchCellID: Set<EntityID>] = [:] // Candidate entities by cell
    private var batchingEnabled: Bool = false

    // Dirty tracking for incremental updates
    private var dirtyCells: Set<BatchCellID> = []
    private var pendingEntityRemovals: Set<EntityID> = []
    private var pendingEntityAdditions: Set<EntityID> = []
    private var newlyResidentEntities: Set<EntityID> = []
    /// Entities registered via notifyTileParsedEntities (legacy direct path).
    /// notifyTileEntitiesResident no longer pre-populates this set — drain-queue
    /// entities go through the normal quiescence path so that multiple drain slices
    /// for the same cell coalesce into a single rebuild rather than rebuilding once
    /// per slice.
    private var tileParsedEntityIds: Set<EntityID> = []
    /// FIFO queue of tile-resident entities waiting for per-entity cell registration.
    /// Populated by notifyTileEntitiesResident; drained at maxTileResidentDrainPerTick
    /// entities per batch tick.  Spreading this work across frames prevents the
    /// withWorldMutationGate stall that occurred when all N entities of a large
    /// fullLoad tile were registered in one shot at parse-completion time.
    private var pendingTileResidentQueue: [EntityID] = []
    /// Logical start of pendingTileResidentQueue.  Advancing this instead of calling
    /// removeFirst(k) avoids O(remaining) element-shift cost on every drain.
    /// The array is compacted (old head entries freed) once the head passes the midpoint.
    private var pendingTileResidentQueueHead: Int = 0
    /// Maximum entities drained from pendingTileResidentQueue per batch tick.
    /// Higher values register tile geometry faster but may spike batch-tick cost.
    /// Default 16: a 32-entity tile registers over 2 ticks (~33 ms at 60 fps).
    /// Values < 1 are clamped to 1 at the drain site — 0 or negative would either
    /// silently stall the queue or crash on Array.removeFirst with a negative count.
    public var maxTileResidentDrainPerTick: Int = 16
    private var isSubscribed: Bool = false
    private var batchCellSize: Float = 32.0
    /// Maps each cell to the UUIDs of its current batch groups.
    /// Kept in sync with batchGroups so removeBatchesForCell can locate
    /// groups in O(groups-in-cell) instead of scanning the entire array.
    private var cellToGroupIds: [BatchCellID: [UUID]] = [:]
    private var cellLifecycle: [BatchCellID: BatchCellLifecycleRecord] = [:]
    private var retiringBatchArtifacts: [RetiringBatchArtifact] = []
    private var retiringCellRefCounts: [BatchCellID: Int] = [:] // O(1) pending-retirement checks
    private var batchRetireDelayFrames: Int = 3
    private var maxRetirementsPerTick: Int = 8
    private var maxDirtyCellsPerTick: Int = 8
    private var maxRebuildVerticesPerTick: Int = 120_000
    private var maxRebuildIndicesPerTick: Int = 220_000
    private var maxRebuildBufferBytesPerTick: Int = 6 * 1024 * 1024
    private var maxRuntimeCellVertices: Int = 160_000
    private var maxRuntimeCellIndices: Int = 300_000
    private var maxRuntimeCellBufferBytes: Int = 8 * 1024 * 1024
    private var quiescenceFramesBeforeBatchBuild: Int = 1
    private var recentVisibilityWindowFrames: Int = 120
    private var visibilityGatedBatchBuildEnabled: Bool = true
    private var backgroundArtifactBuildEnabled: Bool = true
    private var maxBuildDispatchesPerTick: Int = 4
    private var maxArtifactAppliesPerTick: Int = 4
    private(set) var lastTickDiagnostics: BatchingTickDiagnostics = .init()
    private var batchIndexNeedsRebuild: Bool = false
    private var tickCounter: Int = 0
    private var cellLastVisibleFrame: [BatchCellID: Int] = [:]
    private var runtimeBatchIneligibleCells: Set<BatchCellID> = []
    private var runtimeCellStats: [BatchCellID: BatchCellRuntimeStats] = [:]
    private var cellBuildGeneration: [BatchCellID: Int] = [:]
    private var lastMaterialDiagLogTime: Double = 0

    private let artifactBuildQueue = DispatchQueue(
        label: "UntoldEngine.BatchingSystem.ArtifactBuild",
        qos: .utility
    )
    private let artifactStateLock = NSLock()
    private var inFlightBuildCells: Set<BatchCellID> = []
    private var readyArtifacts: [PreparedCellArtifact] = []
    private var buildArtifactEpoch: Int = 0

    private init() {
        subscribeToEvents()
    }

    // MARK: - Event Subscription

    private func subscribeToEvents() {
        guard !isSubscribed else { return }
        isSubscribed = true

        // Subscribe to LOD changes
        SystemEventBus.shared.subscribeToLODChanges { [weak self] event in
            self?.handleLODChange(event)
        }

        // Subscribe to residency changes (for eviction handling)
        SystemEventBus.shared.subscribeToResidencyChanges { [weak self] event in
            self?.handleResidencyChange(event)
        }
    }

    /// Called by GeometryStreamingSystem when a fullLoad tile finishes parsing.
    /// Marks the given entities so that when their residency events arrive in the
    /// same or next tick, their cells are promoted to batchPending immediately
    /// without waiting for the quiescence delay.
    public func notifyTileParsedEntities(_ entityIds: Set<EntityID>) {
        tileParsedEntityIds.formUnion(entityIds)
    }

    /// Batch-notifies the batching system that all entities in `entityIds` are now
    /// resident.  Per-entity cell registration is deferred to the batch tick drain
    /// (pendingTileResidentQueue) so the withWorldMutationGate hold at tile
    /// parse-completion time is reduced to a cheap Set union + Array append, removing
    /// the O(N) cell-resolution spike that caused visible frame stalls on large tiles.
    public func notifyTileEntitiesResident(_ entityIds: Set<EntityID>) {
        guard batchingEnabled else { return }
        guard !entityIds.isEmpty else { return }

        // Enqueue for deferred per-entity registration — O(N) appends, no ECS work.
        // Entities are intentionally NOT pre-marked in tileParsedEntityIds here.
        // Doing so caused drain slices to bypass quiescence and promote their cell
        // to batchPending immediately, triggering a batch rebuild per slice.  For a
        // 30-entity tile drained at 16/tick, that was 2 rebuilds instead of 1.
        // Without the pre-mark, drained entities enter via deferBatchBuild = true →
        // normal quiescence path.  Subsequent slices for the same cell arrive within
        // the 1-frame quiescence window and reset the timer, so the cell rebuilds
        // once after the last slice — regardless of how many slices the tile produced.
        pendingTileResidentQueue.append(contentsOf: entityIds)
    }

    /// Removes the given entities from all pending batching queues immediately.
    /// Call this before destroying LOD/HLOD child entities so their queued additions
    /// are never processed after the entity is gone, eliminating "entity is missing"
    /// errors and wasted batch rebuilds on the next tick.
    ///
    /// Only cancels *pending* state — entities already committed to `entityToCellMembership`
    /// by a previous batch tick are not removed.  Use `notifyTileEntitiesUnloading` when
    /// destroying tile geometry to also clean committed state.
    public func cancelPendingEntities(_ entityIds: Set<EntityID>) {
        guard !entityIds.isEmpty else { return }
        pendingEntityAdditions.subtract(entityIds)
        pendingEntityRemovals.subtract(entityIds)
        newlyResidentEntities.subtract(entityIds)
        tileParsedEntityIds.subtract(entityIds)
        // Rebuild from the unprocessed tail only; already-drained entries (before
        // head) don't need to be scanned and the rebuild resets the head to 0.
        if pendingTileResidentQueueHead < pendingTileResidentQueue.count {
            let tail = pendingTileResidentQueue[pendingTileResidentQueueHead...]
            pendingTileResidentQueue = tail.filter { !entityIds.contains($0) }
        } else {
            pendingTileResidentQueue.removeAll(keepingCapacity: true)
        }
        pendingTileResidentQueueHead = 0
    }

    /// Full batching cleanup for tile entities that are about to be destroyed.
    ///
    /// Handles both cases:
    /// - Entities still in the *pending* queue (batch tick hasn't run yet): removes
    ///   them so the addition is never processed on a destroyed entity.
    /// - Entities already *committed* to `entityToCellMembership` (a previous batch tick
    ///   ran): queues them for removal so stale map entries are cleared before entity IDs
    ///   are recycled by the ECS.  Without this, a new tile whose mesh entity gets a
    ///   recycled ID lands in the wrong batch cell, corrupting batch state and causing
    ///   "entity is missing" errors when the next batch tick processes the stale entry.
    public func notifyTileEntitiesUnloading(_ entityIds: Set<EntityID>) {
        guard !entityIds.isEmpty else { return }
        // Cancel any pending additions — prevents processing additions on dead entities.
        pendingEntityAdditions.subtract(entityIds)
        newlyResidentEntities.subtract(entityIds)
        tileParsedEntityIds.subtract(entityIds)
        // Flush unprocessed entries from the drain queue so destroyed entity IDs
        // are never drained.  Rebuild from the unprocessed tail and reset the head.
        if pendingTileResidentQueueHead < pendingTileResidentQueue.count {
            let tail = pendingTileResidentQueue[pendingTileResidentQueueHead...]
            pendingTileResidentQueue = tail.filter { !entityIds.contains($0) }
        } else {
            pendingTileResidentQueue.removeAll(keepingCapacity: true)
        }
        pendingTileResidentQueueHead = 0
        // Queue removal from committed state.  removeEntityFromBatchingTracking is called
        // by the batch tick; it only manipulates BatchingSystem-internal dictionaries and
        // does not access ECS data, so it is safe to call after destroyEntity.
        pendingEntityRemovals.formUnion(entityIds)
    }

    /// Removes fading tile representation entities from active/pending batches so
    /// the renderer can draw them with per-entity dither uniforms.
    public func notifyTileEntitiesFading(_ entityIds: Set<EntityID>) {
        guard !entityIds.isEmpty else { return }

        pendingEntityAdditions.subtract(entityIds)
        newlyResidentEntities.subtract(entityIds)
        tileParsedEntityIds.subtract(entityIds)
        if pendingTileResidentQueueHead < pendingTileResidentQueue.count {
            let tail = pendingTileResidentQueue[pendingTileResidentQueueHead...]
            pendingTileResidentQueue = tail.filter { !entityIds.contains($0) }
        } else {
            pendingTileResidentQueue.removeAll(keepingCapacity: true)
        }
        pendingTileResidentQueueHead = 0

        var affectedCells: Set<BatchCellID> = []
        for entityId in entityIds {
            if let cellId = entityToCellMembership[entityId] ?? resolveCellIdForEntity(entityId: entityId) {
                affectedCells.insert(cellId)
            }
            pendingEntityRemovals.insert(entityId)
        }

        for cellId in affectedCells {
            _ = removeBatchesForCell(cellId, queueForRetirement: false)
            dirtyCells.insert(cellId)
            setCellState(cellId, .renderableUnbatched)
        }
    }

    /// Compact one-line summary for periodic heartbeat logging.
    /// Reports the fields most likely to reveal accumulation bugs:
    /// registered entity count, dirty cells, and last rebuild cost.
    public func diagnosticSummary() -> String {
        let d = lastTickDiagnostics
        let q = pendingTileResidentQueue.count - pendingTileResidentQueueHead
        let qStr = q > 0 ? " residentQueue=\(q)" : ""
        return "batch: registered=\(entityToCellMembership.count) dirty=\(d.dirtyCellsBeforePrune) rebuildMs=\(String(format: "%.1f", d.rebuildWorkMs)) groups=\(batchGroups.count)\(qStr)"
    }

    private func handleLODChange(_ event: EntityLODChangedEvent) {
        guard batchingEnabled else { return }
        guard scene.exists(event.entityId) else { return }

        // Only queue removal when the entity is already committed to a batch cell.
        // For unbatched entities, removeEntityFromBatchingTracking is a no-op (it exits
        // immediately on a nil entityToCellMembership lookup) but still costs an
        // iteration in the removal loop each tick.
        // The premature dirtyCells.insert is also omitted: removeEntityFromBatchingTracking
        // calls markCellDirtyForFallback during the tick which inserts the same cell —
        // the early insert only caused a redundant estimateCellWork() call on the same tick.
        let isActiveLODFade = scene.get(component: LODComponent.self, for: event.entityId)?.previousLOD != nil
        if let cellId = entityToCellMembership[event.entityId] {
            if isActiveLODFade {
                _ = removeBatchesForCell(cellId, queueForRetirement: false)
            }
            pendingEntityRemovals.insert(event.entityId)
        }

        // Active entity LOD fades need per-entity uniforms. LODSystem emits a
        // same-LOD completion event after the fade clears, which requeues batching.
        if !isActiveLODFade {
            pendingEntityAdditions.insert(event.entityId)
        }
    }

    private func handleResidencyChange(_ event: AssetResidencyChangedEvent) {
        Logger.log(message: "[Batching] handleResidencyChange called isResident=\(event.isResident) batchingEnabled=\(batchingEnabled)")
        guard batchingEnabled else { return }
        guard scene.exists(event.entityId) else { return }

        if !event.isResident {
            // Mesh evicted - remove entity from batching membership
            pendingEntityRemovals.insert(event.entityId)
            newlyResidentEntities.remove(event.entityId)
            if let cellId = entityToCellMembership[event.entityId] {
                dirtyCells.insert(cellId)
            }
        } else {
            // Mesh became resident - entity might be eligible for batching
            let hasStaticBatch = scene.get(component: StaticBatchComponent.self, for: event.entityId) != nil
            Logger.log(message: "[Batching] residencyChange entity=\(event.entityId) hasStaticBatch=\(hasStaticBatch)")
            if hasStaticBatch {
                pendingEntityAdditions.insert(event.entityId)
                newlyResidentEntities.insert(event.entityId)
                if let cellId = resolveCellIdForEntity(entityId: event.entityId) {
                    markCellStreaming(cellId)
                }
            }
        }
    }

    private func currentBuildGeneration(for cellId: BatchCellID) -> Int {
        cellBuildGeneration[cellId] ?? 0
    }

    private func bumpCellBuildGeneration(_ cellId: BatchCellID) {
        let next = (cellBuildGeneration[cellId] ?? 0) &+ 1
        cellBuildGeneration[cellId] = next
    }

    private func reserveInFlightBuild(cellId: BatchCellID) -> Bool {
        artifactStateLock.lock()
        defer { artifactStateLock.unlock() }
        if inFlightBuildCells.contains(cellId) {
            return false
        }
        inFlightBuildCells.insert(cellId)
        return true
    }

    private func finishInFlightBuild(cellId: BatchCellID, artifact: PreparedCellArtifact?) {
        artifactStateLock.lock()
        inFlightBuildCells.remove(cellId)
        if let artifact, artifact.epoch == buildArtifactEpoch {
            readyArtifacts.append(artifact)
        }
        artifactStateLock.unlock()
    }

    private func isBuildInFlight(cellId: BatchCellID) -> Bool {
        artifactStateLock.lock()
        let inFlight = inFlightBuildCells.contains(cellId)
        artifactStateLock.unlock()
        return inFlight
    }

    private func dequeueReadyArtifacts(limit: Int) -> [PreparedCellArtifact] {
        let cap = max(0, limit)
        guard cap > 0 else { return [] }
        artifactStateLock.lock()
        defer { artifactStateLock.unlock() }
        guard !readyArtifacts.isEmpty else { return [] }
        let count = min(cap, readyArtifacts.count)
        let dequeued = Array(readyArtifacts.prefix(count))
        readyArtifacts.removeFirst(count)
        return dequeued
    }

    private func inFlightBuildCountSnapshot() -> Int {
        artifactStateLock.lock()
        let count = inFlightBuildCells.count
        artifactStateLock.unlock()
        return count
    }

    private func readyArtifactCountSnapshot() -> Int {
        artifactStateLock.lock()
        let count = readyArtifacts.count
        artifactStateLock.unlock()
        return count
    }

    private func currentBuildArtifactEpoch() -> Int {
        artifactStateLock.lock()
        let epoch = buildArtifactEpoch
        artifactStateLock.unlock()
        return epoch
    }

    private func clearPendingBuildArtifacts() {
        artifactStateLock.lock()
        buildArtifactEpoch &+= 1
        inFlightBuildCells.removeAll()
        readyArtifacts.removeAll()
        artifactStateLock.unlock()
    }

    // MARK: - Per-Frame Tick (Incremental Updates)

    /// Called each frame to process pending batch updates
    public func tick() {
        tickCounter &+= 1
        var diagnostics = BatchingTickDiagnostics()
        diagnostics.tickFrame = tickCounter
        diagnostics.pendingEntityRemovals = pendingEntityRemovals.count
        diagnostics.pendingEntityAdditions = pendingEntityAdditions.count
        diagnostics.dirtyCellsBeforePrune = dirtyCells.count
        diagnostics.retiringArtifactsQueued = retiringBatchArtifacts.count
        diagnostics.inFlightBuildCells = inFlightBuildCountSnapshot()
        diagnostics.readyArtifactsQueued = readyArtifactCountSnapshot()

        processRetiringBatchArtifacts()
        diagnostics.retiringArtifactsQueued = retiringBatchArtifacts.count
        guard batchingEnabled else {
            diagnostics.dirtyCellsAfterPrune = dirtyCells.count
            lastTickDiagnostics = diagnostics
            return
        }

        // Drain deferred tile-resident entities at a controlled rate.
        // notifyTileEntitiesResident enqueues entity IDs here instead of processing
        // them immediately inside withWorldMutationGate.  Each tick we take at most
        // maxTileResidentDrainPerTick entries, do the per-entity ECS and cell work,
        // and insert them into pendingEntityAdditions for the normal processing below.
        if pendingTileResidentQueueHead < pendingTileResidentQueue.count {
            // Clamp to >= 1: 0 stalls the queue; negatives crash removeFirst.
            let safeDrain = max(1, maxTileResidentDrainPerTick)
            let available = pendingTileResidentQueue.count - pendingTileResidentQueueHead
            let drainEnd = pendingTileResidentQueueHead + min(safeDrain, available)

            for i in pendingTileResidentQueueHead ..< drainEnd {
                let entityId = pendingTileResidentQueue[i]
                guard scene.exists(entityId) else { continue }
                guard scene.get(component: StaticBatchComponent.self, for: entityId) != nil else { continue }
                pendingEntityAdditions.insert(entityId)
                newlyResidentEntities.insert(entityId)
                if let cellId = resolveCellIdForEntity(entityId: entityId) {
                    markCellStreaming(cellId)
                }
            }

            pendingTileResidentQueueHead = drainEnd

            // Compact: free dead-head entries when fully drained or head is past
            // the midpoint.  Both paths are at most O(remaining), but the midpoint
            // trigger means each element causes at most one copy — amortised O(1).
            if pendingTileResidentQueueHead >= pendingTileResidentQueue.count {
                pendingTileResidentQueue.removeAll(keepingCapacity: true)
                pendingTileResidentQueueHead = 0
            } else if pendingTileResidentQueueHead > pendingTileResidentQueue.count / 2 {
                pendingTileResidentQueue = Array(pendingTileResidentQueue[pendingTileResidentQueueHead...])
                pendingTileResidentQueueHead = 0
            }
        }

        guard !pendingEntityRemovals.isEmpty ||
            !pendingEntityAdditions.isEmpty ||
            !dirtyCells.isEmpty ||
            !retiringBatchArtifacts.isEmpty
        else {
            diagnostics.dirtyCellsAfterPrune = dirtyCells.count
            lastTickDiagnostics = diagnostics
            return
        }

        // Process removals
        for entityId in pendingEntityRemovals {
            removeEntityFromBatchingTracking(entityId: entityId)
        }
        pendingEntityRemovals.removeAll(keepingCapacity: true)

        // Process additions / cell updates based on latest entity state.
        // Drain-queue entities arrive with deferBatchBuild = true (they are in
        // newlyResidentEntities but NOT in tileParsedEntityIds) so they go through
        // the normal quiescence path.  The tileParsedEntityIds fast path is kept for
        // any future caller of notifyTileParsedEntities but is not triggered by
        // notifyTileEntitiesResident, which deliberately omits the pre-mark.
        var tileEntitiesAdded: Set<EntityID> = []
        for entityId in pendingEntityAdditions {
            let isTileParsed = tileParsedEntityIds.contains(entityId)
            if isTileParsed { newlyResidentEntities.remove(entityId) }
            let deferBatchBuild = !isTileParsed && (newlyResidentEntities.remove(entityId) != nil)
            registerEntityForBatching(entityId: entityId, deferBatchBuild: deferBatchBuild)
            if isTileParsed { tileEntitiesAdded.insert(entityId) }
        }
        pendingEntityAdditions.removeAll(keepingCapacity: true)

        // Immediately promote cells that belong to the just-loaded tile to
        // batchPending, bypassing the quiescence window entirely.  These cells
        // were registered above (renderableUnbatched) with no extra deferral.
        if !tileEntitiesAdded.isEmpty {
            var tileCells: Set<BatchCellID> = []
            for entityId in tileEntitiesAdded {
                if let cellId = entityToCellMembership[entityId] {
                    tileCells.insert(cellId)
                }
            }
            for cellId in tileCells {
                guard let record = cellLifecycle[cellId],
                      record.state == .renderableUnbatched || record.state == .streaming,
                      cellToEntities[cellId]?.isEmpty == false else { continue }
                dirtyCells.insert(cellId)
                bumpCellBuildGeneration(cellId)
                setCellState(cellId, .batchPending)
            }
            tileParsedEntityIds.subtract(tileEntitiesAdded)
        }

        let visibleCells = updateCellVisibilityHistory()
        let promotionMetrics = promoteRenderableCellsToBatchPending(visibleCells: visibleCells)

        // Rebuild dirty cells only
        let rebuildMetrics = rebuildDirtyCells(visibleCells: visibleCells)
        diagnostics.promotedCells = promotionMetrics.promotedCells
        diagnostics.consideredBatchPendingCells = rebuildMetrics.consideredBatchPendingCells
        diagnostics.deferredByQuiescence = promotionMetrics.deferredByQuiescence + rebuildMetrics.deferredByQuiescence
        diagnostics.deferredByVisibility = promotionMetrics.deferredByVisibility + rebuildMetrics.deferredByVisibility
        diagnostics.deferredByWorkBudget = rebuildMetrics.deferredByWorkBudget
        diagnostics.skippedByComplexityGuard = rebuildMetrics.skippedByComplexityGuard
        diagnostics.dispatchedBuilds = rebuildMetrics.dispatchedBuilds
        diagnostics.appliedArtifacts = rebuildMetrics.appliedArtifacts
        diagnostics.inFlightBuildCells = rebuildMetrics.inFlightBuildCells
        diagnostics.readyArtifactsQueued = rebuildMetrics.readyArtifactsQueued
        diagnostics.dirtyCellsBeforePrune = rebuildMetrics.dirtyCellsBeforePrune
        diagnostics.dirtyCellsAfterPrune = rebuildMetrics.dirtyCellsAfterPrune
        diagnostics.pendingBatchCells = rebuildMetrics.pendingBatchCells
        diagnostics.rebuiltCells = rebuildMetrics.rebuiltCells
        diagnostics.rebuiltBatchGroups = rebuildMetrics.rebuiltBatchGroups
        diagnostics.rebuiltVertices = rebuildMetrics.rebuiltVertices
        diagnostics.rebuiltIndices = rebuildMetrics.rebuiltIndices
        diagnostics.rebuiltBufferBytes = rebuildMetrics.rebuiltBufferBytes
        diagnostics.rebuildWorkMs = rebuildMetrics.rebuildWorkMs
        diagnostics.maxCellRebuildMs = rebuildMetrics.maxCellRebuildMs
        diagnostics.maxCell = rebuildMetrics.maxCell

        if batchIndexNeedsRebuild {
            rebuildBatchIndex()
            batchIndexNeedsRebuild = false
        }

        diagnostics.retiringArtifactsQueued = retiringBatchArtifacts.count
        diagnostics.inFlightBuildCells = inFlightBuildCountSnapshot()
        diagnostics.readyArtifactsQueued = readyArtifactCountSnapshot()
        lastTickDiagnostics = diagnostics
    }

    private func removeEntityFromBatchingTracking(entityId: EntityID) {
        entityToBatch.removeValue(forKey: entityId)

        guard let oldCell = entityToCellMembership.removeValue(forKey: entityId) else { return }
        if var members = cellToEntities[oldCell] {
            members.remove(entityId)
            if members.isEmpty {
                cellToEntities.removeValue(forKey: oldCell)
            } else {
                cellToEntities[oldCell] = members
            }
        }

        dirtyCells.insert(oldCell)
        markCellDirtyForFallback(cellId: oldCell, deferBatchBuild: false)
        if cellToEntities[oldCell]?.isEmpty ?? true {
            transitionCellToRetiringOrUnloaded(cellId: oldCell)
        }
    }

    private func registerEntityForBatching(entityId: EntityID, deferBatchBuild: Bool) {
        guard let candidate = resolveBatchCandidate(entityId: entityId) else {
            guard scene.exists(entityId) else {
                removeEntityFromBatchingTracking(entityId: entityId)
                return
            }
            let hasStatic = scene.get(component: StaticBatchComponent.self, for: entityId) != nil
            let hasRender = scene.get(component: RenderComponent.self, for: entityId) != nil
            let meshEmpty = (scene.get(component: RenderComponent.self, for: entityId)?.mesh.isEmpty ?? true)
            let hasWorld = scene.get(component: WorldTransformComponent.self, for: entityId) != nil
            let hasLocal = scene.get(component: LocalTransformComponent.self, for: entityId) != nil
            Logger.log(message: "[Batching] resolveBatchCandidate FAILED entity=\(entityId) staticBatch=\(hasStatic) render=\(hasRender) meshEmpty=\(meshEmpty) world=\(hasWorld) local=\(hasLocal)")
            removeEntityFromBatchingTracking(entityId: entityId)
            return
        }

        let newCell = candidate.cellId
        if let oldCell = entityToCellMembership[entityId], oldCell != newCell {
            if var members = cellToEntities[oldCell] {
                members.remove(entityId)
                if members.isEmpty {
                    cellToEntities.removeValue(forKey: oldCell)
                } else {
                    cellToEntities[oldCell] = members
                }
            }
            dirtyCells.insert(oldCell)
            markCellDirtyForFallback(cellId: oldCell, deferBatchBuild: false)
            if cellToEntities[oldCell]?.isEmpty ?? true {
                transitionCellToRetiringOrUnloaded(cellId: oldCell)
            }
        }

        entityToCellMembership[entityId] = newCell
        cellToEntities[newCell, default: []].insert(entityId)
        dirtyCells.insert(newCell)
        markCellDirtyForFallback(cellId: newCell, deferBatchBuild: deferBatchBuild)
    }

    private func updateCellVisibilityHistory() -> Set<BatchCellID> {
        guard !entityToCellMembership.isEmpty else { return [] }
        var visibleCells: Set<BatchCellID> = []
        visibleCells.reserveCapacity(visibleEntityIds.count)
        for entityId in visibleEntityIds {
            guard let cellId = entityToCellMembership[entityId] else { continue }
            visibleCells.insert(cellId)
            cellLastVisibleFrame[cellId] = tickCounter
        }
        return visibleCells
    }

    private func promoteRenderableCellsToBatchPending(visibleCells: Set<BatchCellID>) -> PromotionMetrics {
        var metrics = PromotionMetrics()
        guard !dirtyCells.isEmpty else { return metrics }
        let currentFrame = tickCounter
        let recentWindow = max(0, recentVisibilityWindowFrames)
        for cellId in dirtyCells {
            guard var record = cellLifecycle[cellId] else { continue }
            guard record.state == .renderableUnbatched || record.state == .streaming else { continue }
            guard cellToEntities[cellId]?.isEmpty == false else { continue }
            guard !runtimeBatchIneligibleCells.contains(cellId) else { continue }
            if visibilityGatedBatchBuildEnabled {
                let lastVisibleFrame = cellLastVisibleFrame[cellId] ?? Int.min
                let isVisibleNow = visibleCells.contains(cellId)
                let isRecentlyVisible = isVisibleNow || (lastVisibleFrame != Int.min && (tickCounter - lastVisibleFrame) <= recentWindow)
                if !isRecentlyVisible {
                    metrics.deferredByVisibility += 1
                    continue
                }
            }
            if currentFrame >= record.nextBatchBuildFrame {
                record.state = .batchPending
                cellLifecycle[cellId] = record
                metrics.promotedCells += 1
            } else {
                metrics.deferredByQuiescence += 1
                recordRuntimeCellQuiescenceSkip(cellId: cellId)
            }
        }
        return metrics
    }

    private func rebuildDirtyCells(visibleCells: Set<BatchCellID>) -> DirtyRebuildMetrics {
        var metrics = DirtyRebuildMetrics()
        metrics.dirtyCellsBeforePrune = dirtyCells.count
        pruneDirtyCells()
        metrics.dirtyCellsAfterPrune = dirtyCells.count

        // Apply completed artifacts first. This stage is intentionally short and gated.
        let artifactsToApply = dequeueReadyArtifacts(limit: max(1, maxArtifactAppliesPerTick))
        if !artifactsToApply.isEmpty {
            let applyStart = CFAbsoluteTimeGetCurrent()
            withWorldMutationGate {
                for artifact in artifactsToApply {
                    applyPreparedArtifact(artifact, into: &metrics)
                }
            }
            metrics.rebuildWorkMs += (CFAbsoluteTimeGetCurrent() - applyStart) * 1000.0
        }

        let pendingCells = dirtyCells.filter { cellId in
            guard let record = cellLifecycle[cellId] else { return false }
            return record.state == .batchPending
        }
        metrics.consideredBatchPendingCells = pendingCells.count
        metrics.pendingBatchCells = pendingCells.count
        guard !pendingCells.isEmpty else {
            metrics.inFlightBuildCells = inFlightBuildCountSnapshot()
            metrics.readyArtifactsQueued = readyArtifactCountSnapshot()
            return metrics
        }

        var candidates: [CellRebuildCandidate] = []
        candidates.reserveCapacity(pendingCells.count)
        let recentWindow = max(0, recentVisibilityWindowFrames)
        for cellId in pendingCells {
            if isBuildInFlight(cellId: cellId) {
                metrics.deferredByWorkBudget += 1
                continue
            }

            let estimate = estimateCellWork(for: cellId)
            updateRuntimeCellEstimate(cellId: cellId, estimate: estimate)
            if exceedsRuntimeComplexityGuard(estimate) {
                metrics.skippedByComplexityGuard += 1
                runtimeBatchIneligibleCells.insert(cellId)
                recordRuntimeCellComplexitySkip(cellId: cellId)
                dirtyCells.remove(cellId)
                setCellState(
                    cellId,
                    .renderableUnbatched,
                    nextBatchBuildFrame: tickCounter + max(1, quiescenceFramesBeforeBatchBuild)
                )
                continue
            }

            let lastVisibleFrame = cellLastVisibleFrame[cellId] ?? Int.min
            let isVisibleNow = visibleCells.contains(cellId)
            let isRecentlyVisible = isVisibleNow || (lastVisibleFrame != Int.min && (tickCounter - lastVisibleFrame) <= recentWindow)
            if visibilityGatedBatchBuildEnabled, !isRecentlyVisible {
                metrics.deferredByVisibility += 1
                continue
            }
            let dirtySinceFrame = cellLifecycle[cellId]?.dirtySinceFrame ?? tickCounter
            candidates.append(
                CellRebuildCandidate(
                    cellId: cellId,
                    estimate: estimate,
                    isVisibleNow: isVisibleNow,
                    isRecentlyVisible: isRecentlyVisible,
                    lastVisibleFrame: lastVisibleFrame,
                    dirtySinceFrame: dirtySinceFrame
                )
            )
        }

        guard !candidates.isEmpty else {
            metrics.inFlightBuildCells = inFlightBuildCountSnapshot()
            metrics.readyArtifactsQueued = readyArtifactCountSnapshot()
            return metrics
        }

        candidates.sort { lhs, rhs in
            if lhs.isVisibleNow != rhs.isVisibleNow { return lhs.isVisibleNow && !rhs.isVisibleNow }
            if lhs.isRecentlyVisible != rhs.isRecentlyVisible { return lhs.isRecentlyVisible && !rhs.isRecentlyVisible }
            if lhs.lastVisibleFrame != rhs.lastVisibleFrame { return lhs.lastVisibleFrame > rhs.lastVisibleFrame }
            if lhs.estimate.bytes != rhs.estimate.bytes { return lhs.estimate.bytes < rhs.estimate.bytes }
            if lhs.dirtySinceFrame != rhs.dirtySinceFrame { return lhs.dirtySinceFrame < rhs.dirtySinceFrame }
            if lhs.cellId.x != rhs.cellId.x { return lhs.cellId.x < rhs.cellId.x }
            if lhs.cellId.y != rhs.cellId.y { return lhs.cellId.y < rhs.cellId.y }
            return lhs.cellId.z < rhs.cellId.z
        }

        let cellBudget = max(1, maxDirtyCellsPerTick)
        let dispatchBudget = max(1, maxBuildDispatchesPerTick)
        var selectedCells: [BatchCellID] = []
        selectedCells.reserveCapacity(min(cellBudget, candidates.count))
        var consumedWork = CellWorkEstimate.zero
        for candidate in candidates {
            let cellBudgetReached = selectedCells.count >= cellBudget
            let dispatchBudgetReached = selectedCells.count >= dispatchBudget
            let workBudgetReached = exceedsTickWorkBudget(current: consumedWork, adding: candidate.estimate)
            if cellBudgetReached || dispatchBudgetReached || (workBudgetReached && !selectedCells.isEmpty) {
                metrics.deferredByWorkBudget += 1
                recordRuntimeCellBudgetSkip(cellId: candidate.cellId)
                continue
            }

            selectedCells.append(candidate.cellId)
            consumedWork.vertices += candidate.estimate.vertices
            consumedWork.indices += candidate.estimate.indices
            consumedWork.bytes += candidate.estimate.bytes
            consumedWork.opaqueSubmeshCount += candidate.estimate.opaqueSubmeshCount
        }

        guard !selectedCells.isEmpty else {
            metrics.inFlightBuildCells = inFlightBuildCountSnapshot()
            metrics.readyArtifactsQueued = readyArtifactCountSnapshot()
            return metrics
        }

        // Snapshot minimal build inputs under gate. Heavy artifact construction happens off-gate.
        var buildInputs: [CellBuildInput] = []
        let snapshotStart = CFAbsoluteTimeGetCurrent()
        withWorldMutationGate {
            traverseSceneGraph()
            for cellId in selectedCells {
                dirtyCells.remove(cellId)
                guard let input = snapshotBuildInput(for: cellId) else { continue }
                buildInputs.append(input)
            }
        }
        metrics.rebuildWorkMs += (CFAbsoluteTimeGetCurrent() - snapshotStart) * 1000.0

        if buildInputs.isEmpty {
            metrics.inFlightBuildCells = inFlightBuildCountSnapshot()
            metrics.readyArtifactsQueued = readyArtifactCountSnapshot()
            return metrics
        }

        var immediateArtifacts: [PreparedCellArtifact] = []
        for input in buildInputs {
            if !backgroundArtifactBuildEnabled {
                immediateArtifacts.append(buildPreparedArtifact(from: input))
                continue
            }

            guard reserveInFlightBuild(cellId: input.cellId) else {
                metrics.deferredByWorkBudget += 1
                continue
            }
            metrics.dispatchedBuilds += 1

            artifactBuildQueue.async { [weak self] in
                guard let self else { return }
                let artifact = buildPreparedArtifact(from: input)
                finishInFlightBuild(cellId: input.cellId, artifact: artifact)
            }
        }

        if !immediateArtifacts.isEmpty {
            let applyStart = CFAbsoluteTimeGetCurrent()
            withWorldMutationGate {
                for artifact in immediateArtifacts {
                    applyPreparedArtifact(artifact, into: &metrics)
                }
            }
            metrics.rebuildWorkMs += (CFAbsoluteTimeGetCurrent() - applyStart) * 1000.0
        }

        metrics.inFlightBuildCells = inFlightBuildCountSnapshot()
        metrics.readyArtifactsQueued = readyArtifactCountSnapshot()
        return metrics
    }

    private func snapshotBuildInput(for cellId: BatchCellID) -> CellBuildInput? {
        guard let members = cellToEntities[cellId], !members.isEmpty else {
            transitionCellToRetiringOrUnloaded(cellId: cellId)
            return nil
        }

        var validMembers: Set<EntityID> = []
        var materialGroups: [BatchBuildKey: [BatchMeshItem]] = [:]

        for entityId in members {
            guard let candidate = resolveBatchCandidate(entityId: entityId) else {
                entityToCellMembership.removeValue(forKey: entityId)
                continue
            }

            if candidate.cellId != cellId {
                entityToCellMembership[entityId] = candidate.cellId
                cellToEntities[candidate.cellId, default: []].insert(entityId)
                dirtyCells.insert(candidate.cellId)
                markCellDirtyForFallback(cellId: candidate.cellId, deferBatchBuild: false)
                continue
            }

            validMembers.insert(entityId)
            addCandidateMeshes(candidate, to: &materialGroups)
        }

        if validMembers.isEmpty {
            cellToEntities.removeValue(forKey: cellId)
            transitionCellToRetiringOrUnloaded(cellId: cellId)
            return nil
        }

        cellToEntities[cellId] = validMembers
        return CellBuildInput(
            cellId: cellId,
            generation: currentBuildGeneration(for: cellId),
            epoch: currentBuildArtifactEpoch(),
            materialGroups: materialGroups
        )
    }

    private func buildPreparedArtifact(from input: CellBuildInput) -> PreparedCellArtifact {
        let buildStart = CFAbsoluteTimeGetCurrent()
        var builtGroups: [BatchGroup] = []
        var entityBatchMap: [EntityID: EntityBatchInfo] = [:]
        var totalVertices = 0
        var totalIndices = 0
        var totalBytes = 0

        for (batchKey, meshGroup) in input.materialGroups {
            if meshGroup.count < 2 { continue }
            let convertedGroup = meshGroup.map { item in
                (entityId: item.entityId, mesh: item.mesh, meshIndex: item.meshIndex, transform: item.transform)
            }
            guard let batchMaterial = meshGroup.first?.material else { continue }
            guard let group = createBatchGroup(
                from: convertedGroup,
                batchKey: batchKey.materialLODHash,
                material: batchMaterial,
                cellId: batchKey.cellId,
                lodIndex: batchKey.lodIndex
            ) else { continue }

            builtGroups.append(group)
            totalVertices += group.vertexCount
            totalIndices += group.indexCount
            totalBytes += group.positionBuffer?.length ?? 0
            totalBytes += group.normalBuffer?.length ?? 0
            totalBytes += group.uvBuffer?.length ?? 0
            totalBytes += group.tangentBuffer?.length ?? 0
            totalBytes += group.indexBuffer?.length ?? 0

            for item in meshGroup {
                entityBatchMap[item.entityId] = EntityBatchInfo(
                    batchId: group.id,
                    lodIndex: batchKey.lodIndex,
                    materialHash: batchKey.materialHash,
                    cellId: batchKey.cellId
                )
            }
        }

        let buildMs = (CFAbsoluteTimeGetCurrent() - buildStart) * 1000.0
        return PreparedCellArtifact(
            cellId: input.cellId,
            generation: input.generation,
            epoch: input.epoch,
            builtGroups: builtGroups,
            entityBatchMap: entityBatchMap,
            groupCount: builtGroups.count,
            vertexCount: totalVertices,
            indexCount: totalIndices,
            bufferBytes: totalBytes,
            buildMs: buildMs
        )
    }

    private func applyPreparedArtifact(_ artifact: PreparedCellArtifact, into metrics: inout DirtyRebuildMetrics) {
        let cellId = artifact.cellId
        guard artifact.epoch == currentBuildArtifactEpoch() else { return }
        guard artifact.generation == currentBuildGeneration(for: cellId) else { return }
        guard cellLifecycle[cellId]?.state != .retiring else { return }
        guard cellLifecycle[cellId]?.state != .unloaded else { return }
        guard cellToEntities[cellId]?.isEmpty == false else {
            transitionCellToRetiringOrUnloaded(cellId: cellId)
            return
        }

        let removedExisting = removeBatchesForCell(cellId, queueForRetirement: true)
        if artifact.builtGroups.isEmpty {
            setCellState(
                cellId,
                .renderableUnbatched,
                nextBatchBuildFrame: tickCounter + max(1, quiescenceFramesBeforeBatchBuild)
            )
            if removedExisting {
                runtimeBatchIneligibleCells.remove(cellId)
            }
            return
        }

        let insertedStart = batchGroups.count
        batchGroups.append(contentsOf: artifact.builtGroups)
        batchedCells.insert(cellId)
        for (entityId, info) in artifact.entityBatchMap {
            entityToBatch[entityId] = info
        }

        // Maintain batchIdToIndex and cellToGroupIds for the newly inserted groups so
        // removeBatchesForCell can find them in O(groups-in-cell) on the next rebuild.
        for i in insertedStart ..< batchGroups.count {
            let group = batchGroups[i]
            batchIdToIndex[group.id] = i
            cellToGroupIds[group.cellId, default: []].append(group.id)
        }

        // The artifact was built from a material snapshot that may predate one or more
        // texture streaming patches. Re-apply the live streaming state from each group's
        // representative entity so the freshly-installed batch reflects current resolution.
        reconcileStreamingTexturesAfterArtifact(insertedStart: insertedStart)
        setCellState(cellId, .renderableBatched)

        metrics.appliedArtifacts += 1
        metrics.rebuiltCells += 1
        metrics.rebuiltBatchGroups += artifact.groupCount
        metrics.rebuiltVertices += artifact.vertexCount
        metrics.rebuiltIndices += artifact.indexCount
        metrics.rebuiltBufferBytes += artifact.bufferBytes
        if artifact.buildMs > metrics.maxCellRebuildMs {
            metrics.maxCellRebuildMs = artifact.buildMs
            metrics.maxCell = cellId
        }

        recordRuntimeCellRebuild(cellId: cellId, rebuildMs: artifact.buildMs, rebuiltGroups: artifact.groupCount)
        runtimeBatchIneligibleCells.remove(cellId)
        SystemIntegrationMonitor.shared.recordBatchRebuild()
    }

    /// After a fresh artifact is appended to `batchGroups`, copy the live texture state
    /// from each group's representative entity into the group's material.
    ///
    /// This prevents a background build (snapshotted before a streaming patch) from
    /// silently reverting an entity to a lower-resolution tier.
    private func reconcileStreamingTexturesAfterArtifact(insertedStart: Int) {
        guard insertedStart < batchGroups.count else { return }

        for i in insertedStart ..< batchGroups.count {
            // All entities in a group share the same material, so the first live entity
            // is a valid representative for the current streaming state.
            var liveTexture: (
                baseTex: MTLTexture?, baseLevel: TextureStreamingLevel,
                roughTex: MTLTexture?, roughLevel: TextureStreamingLevel,
                metalTex: MTLTexture?, metalLevel: TextureStreamingLevel,
                normalTex: MTLTexture?, normalLevel: TextureStreamingLevel
            )?

            for entityId in batchGroups[i].entityIds {
                guard let render = scene.get(component: RenderComponent.self, for: entityId),
                      let mesh = render.mesh.first,
                      let submesh = mesh.submeshes.first,
                      let material = submesh.material
                else { continue }

                liveTexture = (
                    baseTex: material.baseColor.texture,
                    baseLevel: material.baseColorStreamingLevel,
                    roughTex: material.roughness.texture,
                    roughLevel: material.roughnessStreamingLevel,
                    metalTex: material.metallic.texture,
                    metalLevel: material.metallicStreamingLevel,
                    normalTex: material.normal.texture,
                    normalLevel: material.normalStreamingLevel
                )
                break
            }

            guard let live = liveTexture else { continue }

            // Only reconcile if the entity's streaming level differs from the artifact's
            // snapshot — i.e., a streaming patch actually occurred after the snapshot.
            let artifactLevel = batchGroups[i].material.baseColorStreamingLevel
            guard live.baseLevel != artifactLevel
                || live.roughLevel != batchGroups[i].material.roughnessStreamingLevel
                || live.metalLevel != batchGroups[i].material.metallicStreamingLevel
                || live.normalLevel != batchGroups[i].material.normalStreamingLevel
            else { continue }

            batchGroups[i].material.baseColor.texture = live.baseTex
            batchGroups[i].material.baseColorStreamingLevel = live.baseLevel
            batchGroups[i].material.roughness.texture = live.roughTex
            batchGroups[i].material.roughnessStreamingLevel = live.roughLevel
            batchGroups[i].material.metallic.texture = live.metalTex
            batchGroups[i].material.metallicStreamingLevel = live.metalLevel
            batchGroups[i].material.normal.texture = live.normalTex
            batchGroups[i].material.normalStreamingLevel = live.normalLevel
        }
    }

    private func estimateCellWork(for cellId: BatchCellID) -> CellWorkEstimate {
        guard let members = cellToEntities[cellId], !members.isEmpty else { return .zero }
        var estimate = CellWorkEstimate.zero
        var groupCounts: [BatchBuildKey: Int] = [:]
        var groupVertices: [BatchBuildKey: Int] = [:]
        var groupIndices: [BatchBuildKey: Int] = [:]

        for entityId in members {
            guard let candidate = resolveBatchCandidate(entityId: entityId) else { continue }
            if candidate.cellId != cellId { continue }
            let assetURL = candidate.renderComponent.assetURL
            for mesh in candidate.renderComponent.mesh {
                let vertexCount = mesh.metalKitMesh.vertexCount
                for submesh in mesh.submeshes {
                    guard let material = submesh.material else { continue }
                    if material.hasTransparency { continue }
                    let matHash = getMaterialHash(material: material, assetURL: assetURL)
                    let key = BatchBuildKey(
                        cellId: candidate.cellId,
                        materialHash: matHash,
                        lodIndex: candidate.lodIndex,
                        sceneChannelsRawValue: candidate.sceneChannels.rawValue
                    )
                    groupCounts[key, default: 0] += 1
                    groupVertices[key, default: 0] += vertexCount
                    groupIndices[key, default: 0] += submesh.metalKitSubmesh.indexCount
                }
            }
        }

        for (key, count) in groupCounts where count >= 2 {
            let vertices = groupVertices[key] ?? 0
            let indices = groupIndices[key] ?? 0
            estimate.vertices += vertices
            estimate.indices += indices
            estimate.bytes += estimatedBufferBytes(vertexCount: vertices, indexCount: indices)
            estimate.opaqueSubmeshCount += count
        }
        return estimate
    }

    private func estimatedBufferBytes(vertexCount: Int, indexCount: Int) -> Int {
        // Match createBatchGroup layout: position(float4) + normal(float4) + tangent(float4) + uv(float2) + indices(uint32)
        let vertexBytes = vertexCount * (MemoryLayout<simd_float4>.stride * 3 + MemoryLayout<simd_float2>.stride)
        let indexBytes = indexCount * MemoryLayout<UInt32>.stride
        return vertexBytes + indexBytes
    }

    private func exceedsRuntimeComplexityGuard(_ estimate: CellWorkEstimate) -> Bool {
        estimate.vertices > maxRuntimeCellVertices ||
            estimate.indices > maxRuntimeCellIndices ||
            estimate.bytes > maxRuntimeCellBufferBytes
    }

    private func exceedsTickWorkBudget(current: CellWorkEstimate, adding candidate: CellWorkEstimate) -> Bool {
        let nextVertices = current.vertices + candidate.vertices
        let nextIndices = current.indices + candidate.indices
        let nextBytes = current.bytes + candidate.bytes
        return nextVertices > maxRebuildVerticesPerTick ||
            nextIndices > maxRebuildIndicesPerTick ||
            nextBytes > maxRebuildBufferBytesPerTick
    }

    private func updateRuntimeCellEstimate(cellId: BatchCellID, estimate: CellWorkEstimate) {
        var stats = runtimeCellStats[cellId] ?? BatchCellRuntimeStats(cellId: cellId)
        stats.lastEstimatedVertices = estimate.vertices
        stats.lastEstimatedIndices = estimate.indices
        stats.lastEstimatedBytes = estimate.bytes
        runtimeCellStats[cellId] = stats
    }

    private func recordRuntimeCellBudgetSkip(cellId: BatchCellID) {
        var stats = runtimeCellStats[cellId] ?? BatchCellRuntimeStats(cellId: cellId)
        stats.skipByWorkBudgetCount += 1
        runtimeCellStats[cellId] = stats
    }

    private func recordRuntimeCellComplexitySkip(cellId: BatchCellID) {
        var stats = runtimeCellStats[cellId] ?? BatchCellRuntimeStats(cellId: cellId)
        stats.skipByComplexityCount += 1
        runtimeCellStats[cellId] = stats
    }

    private func recordRuntimeCellQuiescenceSkip(cellId: BatchCellID) {
        var stats = runtimeCellStats[cellId] ?? BatchCellRuntimeStats(cellId: cellId)
        stats.skipByQuiescenceCount += 1
        runtimeCellStats[cellId] = stats
    }

    private func recordRuntimeCellRebuild(cellId: BatchCellID, rebuildMs: Double, rebuiltGroups: Int) {
        var stats = runtimeCellStats[cellId] ?? BatchCellRuntimeStats(cellId: cellId)
        stats.rebuildCount += 1
        stats.lastRebuildMs = rebuildMs
        stats.maxRebuildMs = max(stats.maxRebuildMs, rebuildMs)
        stats.lastRebuiltGroupCount = rebuiltGroups
        runtimeCellStats[cellId] = stats
    }

    private func resolveBatchCandidate(entityId: EntityID) -> BatchCandidate? {
        guard scene.exists(entityId) else { return nil }
        guard let staticBatch = scene.get(component: StaticBatchComponent.self, for: entityId),
              staticBatch.canBatch,
              let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
              let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId),
              let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId)
        else {
            return nil
        }

        // Skip entities with empty meshes (not yet loaded by streaming)
        if renderComponent.mesh.isEmpty { return nil }

        if scene.get(component: LODComponent.self, for: entityId)?.previousLOD != nil {
            return nil
        }

        if scene.get(component: TileRepresentationFadeComponent.self, for: entityId) != nil {
            return nil
        }

        // Identity-preserved streamed objects must stay individually renderable/selectable.
        if shouldPreserveSceneEntityIdentity(entityId: entityId) { return nil }

        // Skip entities with animations
        if scene.get(component: SkeletonComponent.self, for: entityId) != nil { return nil }
        if scene.get(component: AnimationComponent.self, for: entityId) != nil { return nil }

        // Skip gizmos and special entities
        if scene.get(component: GizmoComponent.self, for: entityId) != nil { return nil }
        if scene.get(component: LightComponent.self, for: entityId) != nil { return nil }

        let hasTransparentSubmesh = renderComponent.mesh.contains { mesh in
            mesh.submeshes.contains { submesh in
                submesh.material?.hasTransparency ?? false
            }
        }
        if hasTransparentSubmesh { return nil }

        // Get current LOD index — prefer LODComponent (entity-level LOD), then
        // TileLODTagComponent (per-tile LOD/HLOD children), default 0.
        let lodIndex = scene.get(component: LODComponent.self, for: entityId)?.currentLOD
            ?? scene.get(component: TileLODTagComponent.self, for: entityId)?.levelIndex
            ?? 0
        let cellId = resolveCellId(localTransform: localTransform, worldTransform: worldTransform)

        return BatchCandidate(
            entityId: entityId,
            renderComponent: renderComponent,
            worldTransform: worldTransform,
            lodIndex: lodIndex,
            cellId: cellId,
            sceneChannels: getEntitySceneChannels(entityId: entityId)
        )
    }

    private func addCandidateMeshes(
        _ candidate: BatchCandidate,
        to materialGroups: inout [BatchBuildKey: [BatchMeshItem]]
    ) {
        let assetURL = candidate.renderComponent.assetURL

        for mesh in candidate.renderComponent.mesh {
            for (submeshIndex, submesh) in mesh.submeshes.enumerated() {
                guard let material = submesh.material else { continue }
                if material.hasTransparency { continue }

                let matHash = getMaterialHash(material: material, assetURL: assetURL)
                let batchKey = BatchBuildKey(
                    cellId: candidate.cellId,
                    materialHash: matHash,
                    lodIndex: candidate.lodIndex,
                    sceneChannelsRawValue: candidate.sceneChannels.rawValue
                )
                let finalTransform = simd_mul(candidate.worldTransform.space, mesh.localSpace)

                materialGroups[batchKey, default: []].append((
                    entityId: candidate.entityId,
                    mesh: mesh,
                    meshIndex: submeshIndex,
                    transform: finalTransform,
                    material: material
                ))
            }
        }
    }

    @discardableResult
    private func appendBatchGroups(
        from materialGroups: [BatchBuildKey: [BatchMeshItem]]
    ) -> (createdGroups: Int, batchedMeshes: Int) {
        var createdGroups = 0
        var batchedMeshes = 0

        for (batchKey, meshGroup) in materialGroups {
            // Only batch if we have multiple meshes with same material+LOD
            if meshGroup.count < 2 {
                continue
            }

            let convertedGroup = meshGroup.map { item in
                (entityId: item.entityId, mesh: item.mesh, meshIndex: item.meshIndex, transform: item.transform)
            }

            guard let batchMaterial = meshGroup.first?.material else { continue }

            if let batchGroup = createBatchGroup(
                from: convertedGroup,
                batchKey: batchKey.materialLODHash,
                material: batchMaterial,
                cellId: batchKey.cellId,
                lodIndex: batchKey.lodIndex
            ) {
                batchGroups.append(batchGroup)
                let newIndex = batchGroups.count - 1
                batchIdToIndex[batchGroup.id] = newIndex
                cellToGroupIds[batchGroup.cellId, default: []].append(batchGroup.id)
                batchedCells.insert(batchGroup.cellId)
                createdGroups += 1
                batchedMeshes += batchGroup.entityIds.count

                // Track entity to batch mapping with LOD info
                for item in meshGroup {
                    entityToBatch[item.entityId] = EntityBatchInfo(
                        batchId: batchGroup.id,
                        lodIndex: batchKey.lodIndex,
                        materialHash: batchKey.materialHash,
                        cellId: batchKey.cellId
                    )
                }
            }
        }

        return (createdGroups, batchedMeshes)
    }

    @discardableResult
    private func removeBatchesForCell(_ cellId: BatchCellID, queueForRetirement: Bool) -> Bool {
        guard batchedCells.contains(cellId) else { return false }
        guard let groupIds = cellToGroupIds[cellId], !groupIds.isEmpty else {
            batchedCells.remove(cellId)
            return false
        }

        // Collect the groups and their positions from the cell index — O(groups-in-cell).
        var removedGroups: [BatchGroup] = []
        removedGroups.reserveCapacity(groupIds.count)
        var removedEntityIds: Set<EntityID> = []
        var indicesToRemove: [Int] = []
        indicesToRemove.reserveCapacity(groupIds.count)

        for uuid in groupIds {
            guard let index = batchIdToIndex[uuid] else { continue }
            indicesToRemove.append(index)
            removedGroups.append(batchGroups[index])
            for entityId in batchGroups[index].entityIds {
                removedEntityIds.insert(entityId)
            }
        }

        guard !removedGroups.isEmpty else {
            cellToGroupIds.removeValue(forKey: cellId)
            batchedCells.remove(cellId)
            return false
        }

        // Swap-remove: process indices high-to-low so earlier positions stay valid.
        indicesToRemove.sort(by: >)
        for index in indicesToRemove {
            let lastIndex = batchGroups.count - 1
            if index < lastIndex {
                batchGroups.swapAt(index, lastIndex)
                batchIdToIndex[batchGroups[index].id] = index
            }
            batchGroups.removeLast()
        }

        for uuid in groupIds {
            batchIdToIndex.removeValue(forKey: uuid)
        }
        for entityId in removedEntityIds {
            entityToBatch.removeValue(forKey: entityId)
        }

        cellToGroupIds.removeValue(forKey: cellId)
        batchedCells.remove(cellId)

        if queueForRetirement {
            enqueueRetiringBatchGroups(cellId: cellId, groups: removedGroups)
        }
        return true
    }

    private func rebuildBatchIndex() {
        batchIdToIndex.removeAll(keepingCapacity: true)
        batchIdToIndex.reserveCapacity(batchGroups.count)
        cellToGroupIds.removeAll(keepingCapacity: true)
        for (index, group) in batchGroups.enumerated() {
            batchIdToIndex[group.id] = index
            cellToGroupIds[group.cellId, default: []].append(group.id)
        }
    }

    private func resolveCellIdForEntity(entityId: EntityID) -> BatchCellID? {
        if let known = entityToCellMembership[entityId] {
            return known
        }
        guard let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId),
              let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId)
        else {
            return nil
        }
        return resolveCellId(localTransform: localTransform, worldTransform: worldTransform)
    }

    private func setCellState(_ cellId: BatchCellID, _ state: StaticBatchCellRenderState, nextBatchBuildFrame: Int? = nil) {
        var record = cellLifecycle[cellId] ?? BatchCellLifecycleRecord()
        record.state = state
        if let nextBatchBuildFrame {
            record.nextBatchBuildFrame = max(nextBatchBuildFrame, tickCounter)
        } else if state == .batchPending {
            record.nextBatchBuildFrame = max(record.nextBatchBuildFrame, tickCounter)
        }
        cellLifecycle[cellId] = record
    }

    private func markCellStreaming(_ cellId: BatchCellID) {
        let current = cellLifecycle[cellId]?.state ?? .unloaded
        if current == .unloaded {
            setCellState(cellId, .streaming)
        }
    }

    private func markCellDirtyForFallback(cellId: BatchCellID, deferBatchBuild: Bool) {
        guard cellToEntities[cellId]?.isEmpty == false else { return }
        let delay = (deferBatchBuild ? 1 : 0) + max(0, quiescenceFramesBeforeBatchBuild)
        let warmupFrame = tickCounter + delay

        bumpCellBuildGeneration(cellId)
        runtimeBatchIneligibleCells.remove(cellId)
        _ = removeBatchesForCell(cellId, queueForRetirement: true)
        setCellState(cellId, .renderableUnbatched, nextBatchBuildFrame: warmupFrame)
        if var record = cellLifecycle[cellId] {
            record.dirtySinceFrame = tickCounter
            cellLifecycle[cellId] = record
        }
    }

    private func transitionCellToRetiringOrUnloaded(cellId: BatchCellID) {
        dirtyCells.remove(cellId)
        bumpCellBuildGeneration(cellId)
        runtimeBatchIneligibleCells.remove(cellId)
        let removed = removeBatchesForCell(cellId, queueForRetirement: true)
        if removed || hasPendingRetirement(for: cellId) {
            setCellState(cellId, .retiring)
        } else {
            setCellState(cellId, .unloaded)
        }

        guard cellToEntities[cellId]?.isEmpty ?? true else { return }
        if cellLifecycle[cellId]?.state == .unloaded {
            cellLifecycle.removeValue(forKey: cellId)
            cellLastVisibleFrame.removeValue(forKey: cellId)
        }
    }

    private func enqueueRetiringBatchGroups(cellId: BatchCellID, groups: [BatchGroup]) {
        guard !groups.isEmpty else { return }
        let safeDelayFrames = max(1, batchRetireDelayFrames)
        let artifact = RetiringBatchArtifact(
            cellId: cellId,
            groups: groups,
            retireAfterFrame: tickCounter + safeDelayFrames
        )
        retiringBatchArtifacts.append(artifact)
        retiringCellRefCounts[cellId, default: 0] += 1
    }

    private func hasPendingRetirement(for cellId: BatchCellID) -> Bool {
        (retiringCellRefCounts[cellId] ?? 0) > 0
    }

    private func processRetiringBatchArtifacts() {
        guard !retiringBatchArtifacts.isEmpty else { return }
        let currentFrame = tickCounter
        var processed = 0
        let maxRetires = max(1, maxRetirementsPerTick)
        var index = 0

        while index < retiringBatchArtifacts.count, processed < maxRetires {
            let artifact = retiringBatchArtifacts[index]
            guard artifact.retireAfterFrame <= currentFrame else {
                index += 1
                continue
            }

            // Drop retained groups after a frame-safety delay.
            let lastIndex = retiringBatchArtifacts.count - 1
            retiringBatchArtifacts.swapAt(index, lastIndex)
            let retiredArtifact = retiringBatchArtifacts.removeLast()
            let cellId = retiredArtifact.cellId
            if let count = retiringCellRefCounts[cellId] {
                if count <= 1 {
                    retiringCellRefCounts.removeValue(forKey: cellId)
                } else {
                    retiringCellRefCounts[cellId] = count - 1
                }
            }
            processed += 1

            if cellToEntities[cellId]?.isEmpty ?? true,
               !hasPendingRetirement(for: cellId),
               cellLifecycle[cellId]?.state == .retiring
            {
                setCellState(cellId, .unloaded)
                cellLifecycle.removeValue(forKey: cellId)
            }
        }
    }

    private func pruneDirtyCells() {
        var cellsToRemove: [BatchCellID] = []
        cellsToRemove.reserveCapacity(dirtyCells.count)

        for cellId in dirtyCells {
            guard let record = cellLifecycle[cellId] else {
                cellsToRemove.append(cellId)
                continue
            }
            if record.state == .unloaded {
                cellsToRemove.append(cellId)
                continue
            }
            if cellToEntities[cellId]?.isEmpty == false { continue }
            if !hasPendingRetirement(for: cellId) {
                cellsToRemove.append(cellId)
            }
        }

        for cellId in cellsToRemove {
            dirtyCells.remove(cellId)
        }
    }

    private func summarizeBatches(for cellId: BatchCellID) -> (groupCount: Int, vertexCount: Int, indexCount: Int, bufferBytes: Int) {
        var groupCount = 0
        var vertexCount = 0
        var indexCount = 0
        var bufferBytes = 0
        for group in batchGroups where group.cellId == cellId {
            groupCount += 1
            vertexCount += group.vertexCount
            indexCount += group.indexCount
            bufferBytes += group.positionBuffer?.length ?? 0
            bufferBytes += group.normalBuffer?.length ?? 0
            bufferBytes += group.uvBuffer?.length ?? 0
            bufferBytes += group.tangentBuffer?.length ?? 0
            bufferBytes += group.indexBuffer?.length ?? 0
        }
        return (groupCount, vertexCount, indexCount, bufferBytes)
    }

    /// Generate batches for all static entities in the scene
    public func generateBatches() {
        #if ENGINE_STATS_ENABLED
            let rebuildStart = CFAbsoluteTimeGetCurrent()
            var inputMeshCount = 0
            var outputBatchCount = 0
            var outputBatchedMeshCount = 0
        #endif

        EngineProfiler.shared.beginScope(.batchingRebuild)
        withWorldMutationGate {
            Logger.log(message: "🔨 Starting static batch generation...")

            // Update all world transforms before batching
            // (batching needs accurate world positions)
            traverseSceneGraph()

            // Clear existing batches
            clearBatches()

            let transformId = getComponentId(for: WorldTransformComponent.self)
            let renderId = getComponentId(for: RenderComponent.self)
            let staticBatchId = getComponentId(for: StaticBatchComponent.self)
            let entities = queryEntitiesWithComponentIds([transformId, renderId, staticBatchId], in: scene)

            Logger.log(message: "📋 Found \(entities.count) entities with StaticBatchComponent")

            // Group meshes by cell + material + LOD
            var materialGroups: [BatchBuildKey: [BatchMeshItem]] = [:]

            // Build fresh cell membership and mesh groups from current scene state.
            for entityId in entities {
                guard let candidate = resolveBatchCandidate(entityId: entityId) else { continue }
                entityToCellMembership[entityId] = candidate.cellId
                cellToEntities[candidate.cellId, default: []].insert(entityId)
                addCandidateMeshes(candidate, to: &materialGroups)
            }

            for cellId in cellToEntities.keys {
                setCellState(cellId, .renderableUnbatched)
            }

            Logger.log(message: "📦 Found \(materialGroups.count) material groups")
            #if ENGINE_STATS_ENABLED
                inputMeshCount = materialGroups.values.reduce(0) { partialResult, meshGroup in
                    partialResult + meshGroup.count
                }
            #endif

            _ = appendBatchGroups(from: materialGroups)

            for batchGroup in batchGroups {
                setCellState(batchGroup.cellId, .renderableBatched)
            }

            Logger.log(message: "✅ Created \(batchGroups.count) batch groups")
            let totalBatchedMeshes = batchGroups.reduce(0) { $0 + $1.entityIds.count }
            Logger.log(message: "📊 Batching Stats: \(totalBatchedMeshes) meshes → \(batchGroups.count) draw calls")
            #if ENGINE_STATS_ENABLED
                outputBatchCount = batchGroups.count
                outputBatchedMeshCount = totalBatchedMeshes
            #endif
        }

        EngineProfiler.shared.endScope(.batchingRebuild)
        #if ENGINE_STATS_ENABLED
            let rebuildMs = (CFAbsoluteTimeGetCurrent() - rebuildStart) * 1000.0
            EngineStatsMonitor.shared.update { snapshot in
                snapshot.timing.batchingRebuildMs += rebuildMs
                snapshot.batching.lastRebuildCostMs = rebuildMs
                snapshot.batching.lastRebuildInputMeshCount = inputMeshCount
                snapshot.batching.lastRebuildOutputBatchCount = outputBatchCount
                snapshot.batching.batchGroupCount = outputBatchCount
                snapshot.batching.batchedMeshCount = outputBatchedMeshCount
            }
        #endif
    }

    private func createBatchGroup(
        from meshGroup: [(entityId: EntityID, mesh: Mesh, meshIndex: Int, transform: simd_float4x4)],
        batchKey: String,
        material: Material,
        cellId: BatchCellID,
        lodIndex: Int
    ) -> BatchGroup? {
        var allPositions: [simd_float4] = [] // Changed to float4 to match vertex descriptor
        var allNormals: [simd_float4] = [] // Changed to float4 to match vertex descriptor
        var allUVs: [simd_float2] = []
        var allTangents: [simd_float4] = [] // Changed to float4 to match vertex descriptor
        var allIndices: [UInt32] = []
        var allFeatureEdgeIndices: [UInt32] = []
        var entityIds: [EntityID] = []
        var meshIndices: [(EntityID, Int)] = []
        var sceneChannels: SceneChannel = []

        var minBounds = simd_float3(Float.infinity, Float.infinity, Float.infinity)
        var maxBounds = simd_float3(-Float.infinity, -Float.infinity, -Float.infinity)

        // Combine all meshes
        for item in meshGroup {
            let currentVertexOffset = UInt32(allPositions.count)

            // Extract and transform vertices (returns separate arrays)
            let vertexData = extractVertices(from: item.mesh, worldTransform: item.transform)

            allPositions.append(contentsOf: vertexData.positions)
            allNormals.append(contentsOf: vertexData.normals)
            allUVs.append(contentsOf: vertexData.uvs)
            allTangents.append(contentsOf: vertexData.tangents)

            // Update bounding box (extract xyz from float4 positions)
            for position in vertexData.positions {
                let pos3 = simd_float3(position.x, position.y, position.z)
                minBounds = simd_min(minBounds, pos3)
                maxBounds = simd_max(maxBounds, pos3)
            }

            // Extract indices with offset
            let indices = extractIndices(from: item.mesh, submeshIndex: item.meshIndex, indexOffset: currentVertexOffset)
            allIndices.append(contentsOf: indices)
            let edgeIndices = extractFeatureEdgeIndices(from: item.mesh, indexOffset: currentVertexOffset)
            allFeatureEdgeIndices.append(contentsOf: edgeIndices)

            entityIds.append(item.entityId)
            meshIndices.append((item.entityId, item.meshIndex))
            sceneChannels.formUnion(getEntitySceneChannels(entityId: item.entityId))
        }

        guard !allPositions.isEmpty, !allIndices.isEmpty else {
            Logger.logWarning(message: "Failed to create batch: no vertices or indices")
            return nil
        }

        // Create separate Metal buffers for each attribute (using float4 for positions, normals, tangents)
        let positionBufferSize = allPositions.count * MemoryLayout<simd_float4>.stride
        let normalBufferSize = allNormals.count * MemoryLayout<simd_float4>.stride
        let uvBufferSize = allUVs.count * MemoryLayout<simd_float2>.stride
        let tangentBufferSize = allTangents.count * MemoryLayout<simd_float4>.stride
        let indexBufferSize = allIndices.count * MemoryLayout<UInt32>.stride
        let featureEdgeIndexBufferSize = allFeatureEdgeIndices.count * MemoryLayout<UInt32>.stride

        guard let positionBuffer = renderInfo.device.makeBuffer(
            bytes: allPositions,
            length: positionBufferSize,
            options: .storageModeShared
        ) else {
            handleError(.bufferAllocationFailed, "batch position buffer")
            return nil
        }

        guard let normalBuffer = renderInfo.device.makeBuffer(
            bytes: allNormals,
            length: normalBufferSize,
            options: .storageModeShared
        ) else {
            handleError(.bufferAllocationFailed, "batch normal buffer")
            return nil
        }

        guard let uvBuffer = renderInfo.device.makeBuffer(
            bytes: allUVs,
            length: uvBufferSize,
            options: .storageModeShared
        ) else {
            handleError(.bufferAllocationFailed, "batch UV buffer")
            return nil
        }

        guard let tangentBuffer = renderInfo.device.makeBuffer(
            bytes: allTangents,
            length: tangentBufferSize,
            options: .storageModeShared
        ) else {
            handleError(.bufferAllocationFailed, "batch tangent buffer")
            return nil
        }

        guard let indexBuffer = renderInfo.device.makeBuffer(
            bytes: allIndices,
            length: indexBufferSize,
            options: .storageModeShared
        ) else {
            handleError(.bufferAllocationFailed, "batch index buffer")
            return nil
        }

        positionBuffer.label = "Batch Position Buffer"
        normalBuffer.label = "Batch Normal Buffer"
        uvBuffer.label = "Batch UV Buffer"
        tangentBuffer.label = "Batch Tangent Buffer"
        indexBuffer.label = "Batch Index Buffer"
        let featureEdgeIndexBuffer = allFeatureEdgeIndices.isEmpty ? nil : renderInfo.device.makeBuffer(
            bytes: allFeatureEdgeIndices,
            length: featureEdgeIndexBufferSize,
            options: .storageModeShared
        )
        featureEdgeIndexBuffer?.label = "Batch Feature Edge Index Buffer"

        let isLODBatch = meshGroup.contains {
            scene.get(component: LODComponent.self, for: $0.entityId) != nil
                || scene.get(component: TileLODTagComponent.self, for: $0.entityId) != nil
        }

        return BatchGroup(
            id: UUID(),
            cellId: cellId,
            lodIndex: lodIndex,
            batchKey: batchKey,
            material: material,
            positionBuffer: positionBuffer,
            normalBuffer: normalBuffer,
            uvBuffer: uvBuffer,
            tangentBuffer: tangentBuffer,
            indexBuffer: indexBuffer,
            featureEdgeIndexBuffer: featureEdgeIndexBuffer,
            indexCount: allIndices.count,
            featureEdgeIndexCount: allFeatureEdgeIndices.count,
            vertexCount: allPositions.count,
            entityIds: entityIds,
            meshIndices: meshIndices,
            boundingBox: (min: minBounds, max: maxBounds),
            sceneChannels: sceneChannels,
            isLODBatch: isLODBatch
        )
    }

    /// Clear all existing batches
    public func clearBatches() {
        batchGroups.removeAll()
        entityToBatch.removeAll()
        batchIdToIndex.removeAll()
        cellToGroupIds.removeAll()
        batchedCells.removeAll()
        entityToCellMembership.removeAll()
        cellToEntities.removeAll()
        cellLifecycle.removeAll()
        retiringBatchArtifacts.removeAll()
        retiringCellRefCounts.removeAll()
        dirtyCells.removeAll()
        pendingEntityRemovals.removeAll()
        pendingEntityAdditions.removeAll()
        newlyResidentEntities.removeAll()
        tileParsedEntityIds.removeAll()
        pendingTileResidentQueue.removeAll()
        pendingTileResidentQueueHead = 0
        cellLastVisibleFrame.removeAll()
        cellBuildGeneration.removeAll()
        runtimeBatchIneligibleCells.removeAll()
        runtimeCellStats.removeAll()
        clearPendingBuildArtifacts()
        lastTickDiagnostics = .init()
        batchIndexNeedsRebuild = false
        tickCounter = 0
    }

    /// Check if an entity is part of a batch
    public func isBatched(entityId: EntityID) -> Bool {
        entityToBatch[entityId] != nil
    }

    /// Get batch group for an entity
    public func getBatchGroup(for entityId: EntityID) -> BatchGroup? {
        guard let batchInfo = entityToBatch[entityId] else { return nil }
        guard let index = batchIdToIndex[batchInfo.batchId], batchGroups.indices.contains(index) else { return nil }
        return batchGroups[index]
    }

    /// Get batch info for an entity
    public func getBatchInfo(for entityId: EntityID) -> EntityBatchInfo? {
        entityToBatch[entityId]
    }

    /// Update the representative material of the batch group that contains `entityId` in-place.
    ///
    /// This lets texture streaming swap a new `MTLTexture` into the batch group's material
    /// without tearing down or rebuilding the batch. The render pass reads `group.material`
    /// fresh every frame, so the change takes effect on the very next draw call.
    ///
    /// - Returns: `true` if the entity was found in an active batch and the update was applied.
    @discardableResult
    public func updateBatchMaterialInPlace(for entityId: EntityID, update: (inout Material) -> Void) -> Bool {
        guard let batchInfo = entityToBatch[entityId],
              let index = batchIdToIndex[batchInfo.batchId],
              batchGroups.indices.contains(index)
        else { return false }
        update(&batchGroups[index].material)
        batchGroups[index].textureGeneration += 1
        return true
    }

    public func setEnabled(_ enabled: Bool) {
        batchingEnabled = enabled
        if !enabled {
            for cellId in Set(batchGroups.map(\.cellId)) {
                _ = removeBatchesForCell(cellId, queueForRetirement: true)
            }
            rebuildBatchIndex()
            batchIndexNeedsRebuild = false
            dirtyCells.removeAll()
            pendingEntityRemovals.removeAll()
            pendingEntityAdditions.removeAll()
            newlyResidentEntities.removeAll()
            tileParsedEntityIds.removeAll()
            pendingTileResidentQueue.removeAll()
            pendingTileResidentQueueHead = 0
            runtimeBatchIneligibleCells.removeAll()
            clearPendingBuildArtifacts()
            for cellId in cellToEntities.keys {
                setCellState(cellId, .renderableUnbatched)
            }
        }
    }

    public func isEnabled() -> Bool {
        batchingEnabled
    }

    public func setBatchCellSize(_ size: Float) {
        let clamped = max(size, 0.01)
        guard abs(clamped - batchCellSize) > .ulpOfOne else { return }
        batchCellSize = clamped

        // Cell assignment depends on size. Existing batches/memberships are invalid if the size changes.
        if !batchGroups.isEmpty || !entityToCellMembership.isEmpty {
            if batchingEnabled {
                generateBatches()
            } else {
                clearBatches()
            }
        }
    }

    public func getBatchCellSize() -> Float {
        batchCellSize
    }

    /// Number of frames to retain old batch buffers after swap/unload before releasing them.
    public func setBatchRetireDelayFrames(_ value: Int) {
        batchRetireDelayFrames = max(1, value)
    }

    public func getBatchRetireDelayFrames() -> Int {
        batchRetireDelayFrames
    }

    /// Maximum retiring batch artifacts released per tick.
    public func setMaxRetirementsPerTick(_ value: Int) {
        maxRetirementsPerTick = max(1, value)
    }

    public func getMaxRetirementsPerTick() -> Int {
        maxRetirementsPerTick
    }

    /// Max dirty cells rebuilt per tick; lower values smooth frame spikes at the cost of convergence latency.
    public func setMaxDirtyCellsPerTick(_ value: Int) {
        maxDirtyCellsPerTick = max(1, value)
    }

    public func getMaxDirtyCellsPerTick() -> Int {
        maxDirtyCellsPerTick
    }

    /// Enables asynchronous artifact preparation. Keep enabled in production for smoother traversal.
    public func setBackgroundArtifactBuildEnabled(_ enabled: Bool) {
        backgroundArtifactBuildEnabled = enabled
        if !enabled {
            clearPendingBuildArtifacts()
        }
    }

    public func isBackgroundArtifactBuildEnabled() -> Bool {
        backgroundArtifactBuildEnabled
    }

    /// Max number of cells dispatched for artifact build per tick.
    public func setMaxBuildDispatchesPerTick(_ value: Int) {
        maxBuildDispatchesPerTick = max(1, value)
    }

    public func getMaxBuildDispatchesPerTick() -> Int {
        maxBuildDispatchesPerTick
    }

    /// Max number of completed artifacts applied per tick.
    public func setMaxArtifactAppliesPerTick(_ value: Int) {
        maxArtifactAppliesPerTick = max(1, value)
    }

    public func getMaxArtifactAppliesPerTick() -> Int {
        maxArtifactAppliesPerTick
    }

    /// Max estimated vertices rebuilt per tick.
    public func setMaxRebuildVerticesPerTick(_ value: Int) {
        maxRebuildVerticesPerTick = max(1, value)
    }

    public func getMaxRebuildVerticesPerTick() -> Int {
        maxRebuildVerticesPerTick
    }

    /// Max estimated indices rebuilt per tick.
    public func setMaxRebuildIndicesPerTick(_ value: Int) {
        maxRebuildIndicesPerTick = max(1, value)
    }

    public func getMaxRebuildIndicesPerTick() -> Int {
        maxRebuildIndicesPerTick
    }

    /// Max estimated combined vertex/index bytes rebuilt per tick.
    public func setMaxRebuildBufferBytesPerTick(_ value: Int) {
        maxRebuildBufferBytesPerTick = max(1, value)
    }

    public func getMaxRebuildBufferBytesPerTick() -> Int {
        maxRebuildBufferBytesPerTick
    }

    /// Runtime complexity guard (per-cell) for vertices.
    public func setMaxRuntimeCellVertices(_ value: Int) {
        maxRuntimeCellVertices = max(1, value)
    }

    public func getMaxRuntimeCellVertices() -> Int {
        maxRuntimeCellVertices
    }

    /// Runtime complexity guard (per-cell) for indices.
    public func setMaxRuntimeCellIndices(_ value: Int) {
        maxRuntimeCellIndices = max(1, value)
    }

    public func getMaxRuntimeCellIndices() -> Int {
        maxRuntimeCellIndices
    }

    /// Runtime complexity guard (per-cell) for estimated bytes.
    public func setMaxRuntimeCellBufferBytes(_ value: Int) {
        maxRuntimeCellBufferBytes = max(1, value)
    }

    public func getMaxRuntimeCellBufferBytes() -> Int {
        maxRuntimeCellBufferBytes
    }

    /// Minimum stable frames before a dirty cell can be promoted to batch rebuild.
    public func setQuiescenceFramesBeforeBatchBuild(_ value: Int) {
        quiescenceFramesBeforeBatchBuild = max(0, value)
    }

    public func getQuiescenceFramesBeforeBatchBuild() -> Int {
        quiescenceFramesBeforeBatchBuild
    }

    /// How long a cell stays "recently visible" for rebuild prioritization.
    public func setRecentVisibilityWindowFrames(_ value: Int) {
        recentVisibilityWindowFrames = max(0, value)
    }

    public func getRecentVisibilityWindowFrames() -> Int {
        recentVisibilityWindowFrames
    }

    /// Whether off-screen cells are deferred from runtime batch rebuild work.
    public func setVisibilityGatedBatchBuildEnabled(_ enabled: Bool) {
        visibilityGatedBatchBuildEnabled = enabled
    }

    public func isVisibilityGatedBatchBuildEnabled() -> Bool {
        visibilityGatedBatchBuildEnabled
    }

    /// Runtime per-cell diagnostics sorted by worst rebuild time first.
    public func getRuntimeBatchCellDiagnostics(limit: Int = 32) -> [BatchCellRuntimeDiagnostic] {
        guard !runtimeCellStats.isEmpty else { return [] }
        let sorted = runtimeCellStats.values.sorted { lhs, rhs in
            if lhs.maxRebuildMs != rhs.maxRebuildMs { return lhs.maxRebuildMs > rhs.maxRebuildMs }
            if lhs.lastEstimatedBytes != rhs.lastEstimatedBytes { return lhs.lastEstimatedBytes > rhs.lastEstimatedBytes }
            if lhs.rebuildCount != rhs.rebuildCount { return lhs.rebuildCount > rhs.rebuildCount }
            if lhs.cellId.x != rhs.cellId.x { return lhs.cellId.x < rhs.cellId.x }
            if lhs.cellId.y != rhs.cellId.y { return lhs.cellId.y < rhs.cellId.y }
            return lhs.cellId.z < rhs.cellId.z
        }
        let cap = max(0, limit)
        return sorted.prefix(cap).map { stats in
            BatchCellRuntimeDiagnostic(
                cellId: stats.cellId,
                lastEstimatedVertices: stats.lastEstimatedVertices,
                lastEstimatedIndices: stats.lastEstimatedIndices,
                lastEstimatedBytes: stats.lastEstimatedBytes,
                rebuildCount: stats.rebuildCount,
                lastRebuildMs: stats.lastRebuildMs,
                maxRebuildMs: stats.maxRebuildMs,
                skipByWorkBudgetCount: stats.skipByWorkBudgetCount,
                skipByQuiescenceCount: stats.skipByQuiescenceCount,
                skipByComplexityCount: stats.skipByComplexityCount,
                lastRebuiltGroupCount: stats.lastRebuiltGroupCount
            )
        }
    }

    /// Runtime aggregate diagnostics for tuning streamed-cell batching.
    public func getRuntimeBatchingSummaryDiagnostic() -> RuntimeBatchingSummaryDiagnostic {
        guard !runtimeCellStats.isEmpty else {
            return RuntimeBatchingSummaryDiagnostic(trackedCells: 0, runtimeIneligibleCells: runtimeBatchIneligibleCells.count)
        }

        let values = Array(runtimeCellStats.values)
        let count = Double(values.count)
        let totalEstimatedVertices = values.reduce(0) { $0 + $1.lastEstimatedVertices }
        let totalEstimatedBytes = values.reduce(0) { $0 + $1.lastEstimatedBytes }
        let maxEstimatedVertices = values.map(\.lastEstimatedVertices).max() ?? 0
        let maxEstimatedBytes = values.map(\.lastEstimatedBytes).max() ?? 0
        let worstRebuildMs = values.map(\.maxRebuildMs).max() ?? 0.0
        let totalComplexitySkips = values.reduce(0) { $0 + $1.skipByComplexityCount }
        let totalBudgetSkips = values.reduce(0) { $0 + $1.skipByWorkBudgetCount }
        let totalQuiescenceDeferrals = values.reduce(0) { $0 + $1.skipByQuiescenceCount }

        return RuntimeBatchingSummaryDiagnostic(
            trackedCells: values.count,
            runtimeIneligibleCells: runtimeBatchIneligibleCells.count,
            averageEstimatedVerticesPerCell: Double(totalEstimatedVertices) / count,
            maxEstimatedVerticesInCell: maxEstimatedVertices,
            averageEstimatedBytesPerCell: Double(totalEstimatedBytes) / count,
            maxEstimatedBytesInCell: maxEstimatedBytes,
            worstRebuildMs: worstRebuildMs,
            totalComplexitySkips: totalComplexitySkips,
            totalBudgetSkips: totalBudgetSkips,
            totalQuiescenceDeferrals: totalQuiescenceDeferrals
        )
    }

    // MARK: - Material diversity diagnostics

    /// Scans all registered cells and returns a scene-wide breakdown of material key diversity.
    ///
    /// This is O(registered entities × submeshes per entity) and should not be called every frame.
    /// Use logMaterialDiagnosticsIfDue for rate-limited periodic emission.
    ///
    /// - Parameter topCellCount: How many cells to include in the per-cell breakdown, ranked by
    ///   unique material key count (highest diversity — worst for batching — first).
    public func collectMaterialDiagnostics(topCellCount: Int = 10) -> BatchMaterialDiagnostics {
        var diag = BatchMaterialDiagnostics()

        // Count scene entities that carry StaticBatchComponent regardless of residency.
        let sbcId = getComponentId(for: StaticBatchComponent.self)
        diag.staticBatchComponentCount = queryEntitiesWithComponentIds([sbcId], in: scene).count

        diag.registeredCandidates = entityToCellMembership.count
        diag.cellsBlockedByComplexity = runtimeBatchIneligibleCells.count

        var cellReports: [BatchCellMaterialBreakdown] = []
        cellReports.reserveCapacity(cellToEntities.count)
        var globalKeys: Set<String> = []

        for (cellId, members) in cellToEntities {
            var keyCounts: [String: Int] = [:]

            for entityId in members {
                guard let candidate = resolveBatchCandidate(entityId: entityId) else { continue }
                diag.resolvedCandidates += 1
                let assetURL = candidate.renderComponent.assetURL
                for mesh in candidate.renderComponent.mesh {
                    for submesh in mesh.submeshes {
                        guard let material = submesh.material, !material.hasTransparency else { continue }
                        let key = getMaterialHash(material: material, assetURL: assetURL)
                            + "_LOD\(candidate.lodIndex)"
                        keyCounts[key, default: 0] += 1
                        globalKeys.insert(key)
                    }
                }
            }

            var singletonKeys = 0
            var groupableKeys = 0
            var singletonEntities = 0
            var groupableEntities = 0
            for (_, count) in keyCounts {
                if count == 1 {
                    singletonKeys += 1
                    singletonEntities += 1
                } else {
                    groupableKeys += 1
                    groupableEntities += count
                }
            }

            diag.singletonMaterialKeys += singletonKeys
            diag.groupableMaterialKeys += groupableKeys
            diag.entitiesAsSingletons += singletonEntities
            diag.entitiesGroupable += groupableEntities

            let totalKeys = keyCounts.count
            let ratio: Float = totalKeys > 0 ? Float(singletonKeys) / Float(totalKeys) : 0
            let builtGroups = batchGroups.filter { $0.cellId == cellId }.count
            cellReports.append(BatchCellMaterialBreakdown(
                cellId: cellId,
                registeredEntities: members.count,
                uniqueMaterialLODKeys: totalKeys,
                singletonKeys: singletonKeys,
                groupableKeys: groupableKeys,
                builtBatchGroups: builtGroups,
                singletonRatio: ratio
            ))
        }

        diag.uniqueMaterialLODKeys = globalKeys.count
        diag.topCellsByMaterialDiversity = Array(
            cellReports
                .sorted { $0.uniqueMaterialLODKeys > $1.uniqueMaterialLODKeys }
                .prefix(max(1, topCellCount))
        )
        return diag
    }

    /// Logs material diversity diagnostics at most once per `interval` seconds.
    ///
    /// No-op when the Batching log category is disabled — the scan is never run.
    /// Enable with `Logger.enable(category: .batching)` before calling.
    public func logMaterialDiagnosticsIfDue(interval: Double = 30.0) {
        guard Logger.isEnabled(category: .batching) else { return }
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastMaterialDiagLogTime >= interval else { return }
        lastMaterialDiagLogTime = now
        emitMaterialDiagnostics(collectMaterialDiagnostics())
    }

    /// Emits material diversity diagnostics immediately, bypassing the rate-limit timer.
    ///
    /// Use this for a one-shot snapshot after enabling the category:
    /// ```swift
    /// Logger.enable(category: .batching)
    /// BatchingSystem.shared.logMaterialDiagnosticsNow()
    /// ```
    /// No-op when the Batching log category is disabled.
    public func logMaterialDiagnosticsNow() {
        guard Logger.isEnabled(category: .batching) else { return }
        lastMaterialDiagLogTime = CFAbsoluteTimeGetCurrent()
        emitMaterialDiagnostics(collectMaterialDiagnostics())
    }

    private func emitMaterialDiagnostics(_ diag: BatchMaterialDiagnostics) {
        let batchRatio = diag.resolvedCandidates > 0
            ? Int(100.0 * Double(diag.entitiesGroupable) / Double(diag.resolvedCandidates))
            : 0
        Logger.log(
            message: "[BatchMaterial] staticBatch=\(diag.staticBatchComponentCount) registered=\(diag.registeredCandidates) resolved=\(diag.resolvedCandidates) batchable=\(batchRatio)%"
                + " | singletons=\(diag.entitiesAsSingletons) groupable=\(diag.entitiesGroupable)"
                + " | cellsBlocked=\(diag.cellsBlockedByComplexity)"
                + " | uniqueMatLOD=\(diag.uniqueMaterialLODKeys) singletonKeys=\(diag.singletonMaterialKeys) groupableKeys=\(diag.groupableMaterialKeys)",
            category: LogCategory.batching.rawValue
        )
        for cell in diag.topCellsByMaterialDiversity.prefix(5) {
            Logger.log(
                message: "[BatchMaterial] cell(\(cell.cellId.x),\(cell.cellId.y),\(cell.cellId.z))"
                    + " ents=\(cell.registeredEntities) uniqueKeys=\(cell.uniqueMaterialLODKeys)"
                    + " singletons=\(cell.singletonKeys) groupable=\(cell.groupableKeys)"
                    + " groups=\(cell.builtBatchGroups) ratio=\(String(format: "%.2f", cell.singletonRatio))",
                category: LogCategory.batching.rawValue
            )
        }
    }

    /// Snapshot of the most recent tick's internal rebuild work.
    public func getTickDiagnosticsSnapshot() -> BatchingTickDiagnostics {
        lastTickDiagnostics
    }

    public func getCellRenderState(cellId: BatchCellID) -> StaticBatchCellRenderState {
        if let state = cellLifecycle[cellId]?.state {
            return state
        }
        return .unloaded
    }

    public func getCellRenderStatesSnapshot() -> [BatchCellID: StaticBatchCellRenderState] {
        var snapshot: [BatchCellID: StaticBatchCellRenderState] = [:]
        snapshot.reserveCapacity(cellLifecycle.count)
        for (cellId, record) in cellLifecycle {
            snapshot[cellId] = record.state
        }
        return snapshot
    }

    /// Called by GeometryStreamingSystem when an entity starts streaming in.
    public func notifyEntityStreamingStarted(entityId: EntityID) {
        guard batchingEnabled else { return }
        guard scene.get(component: StaticBatchComponent.self, for: entityId) != nil else { return }
        guard let cellId = resolveCellIdForEntity(entityId: entityId) else { return }
        markCellStreaming(cellId)
    }

    /// Called by GeometryStreamingSystem when an entity starts unloading.
    public func notifyEntityRetiring(entityId: EntityID) {
        guard batchingEnabled else { return }
        guard scene.get(component: StaticBatchComponent.self, for: entityId) != nil else { return }
        guard let cellId = resolveCellIdForEntity(entityId: entityId) else { return }
        setCellState(cellId, .retiring)
    }

    /// Called when an entity's material/texture changes.
    /// Queues an incremental rebatch via the normal per-frame tick path.
    public func notifyEntityMaterialChanged(entityId: EntityID) {
        notifyEntityBatchKeyChanged(entityId: entityId)
    }

    /// Called when an entity's scene-channel mask changes.
    /// Queues an incremental rebatch because channel masks are part of the batch key.
    public func notifyEntitySceneChannelsChanged(entityId: EntityID) {
        notifyEntityBatchKeyChanged(entityId: entityId)
    }

    private func notifyEntityBatchKeyChanged(entityId: EntityID) {
        guard batchingEnabled else { return }
        guard scene.get(component: StaticBatchComponent.self, for: entityId) != nil else { return }

        pendingEntityRemovals.insert(entityId)
        pendingEntityAdditions.insert(entityId)

        if let cellId = entityToCellMembership[entityId] {
            dirtyCells.insert(cellId)
            markCellDirtyForFallback(cellId: cellId, deferBatchBuild: false)
        }
    }

    /// Apply a complete runtime batching tuning profile.
    ///
    /// Recommended usage:
    /// - `RuntimeBatchingTuning.visionOSBalanced` for Vision Pro defaults
    /// - `RuntimeBatchingTuning.macOSBalanced` for desktop defaults
    /// - then override specific fields for scene-specific behavior.
    public func applyRuntimeBatchingTuning(_ tuning: RuntimeBatchingTuning) {
        // Cell size first: changing it invalidates existing batches, so all other
        // tuning changes land on the already-invalidated state.
        setBatchCellSize(tuning.cellSize)
        setMaxDirtyCellsPerTick(tuning.maxDirtyCellsPerTick)
        setMaxBuildDispatchesPerTick(tuning.maxBuildDispatchesPerTick)
        setMaxArtifactAppliesPerTick(tuning.maxArtifactAppliesPerTick)
        setMaxRebuildVerticesPerTick(tuning.maxRebuildVerticesPerTick)
        setMaxRebuildIndicesPerTick(tuning.maxRebuildIndicesPerTick)
        setMaxRebuildBufferBytesPerTick(tuning.maxRebuildBufferBytesPerTick)
        setMaxRuntimeCellVertices(tuning.maxRuntimeCellVertices)
        setMaxRuntimeCellIndices(tuning.maxRuntimeCellIndices)
        setMaxRuntimeCellBufferBytes(tuning.maxRuntimeCellBufferBytes)
        setQuiescenceFramesBeforeBatchBuild(tuning.quiescenceFramesBeforeBatchBuild)
        setRecentVisibilityWindowFrames(tuning.recentVisibilityWindowFrames)
        setVisibilityGatedBatchBuildEnabled(tuning.visibilityGatedBatchBuildEnabled)
        setMaxRetirementsPerTick(tuning.maxRetirementsPerTick)
        setBatchRetireDelayFrames(tuning.batchRetireDelayFrames)
    }

    /// Returns the currently active runtime batching tuning values.
    public func getRuntimeBatchingTuning() -> RuntimeBatchingTuning {
        RuntimeBatchingTuning(
            maxDirtyCellsPerTick: maxDirtyCellsPerTick,
            maxBuildDispatchesPerTick: maxBuildDispatchesPerTick,
            maxArtifactAppliesPerTick: maxArtifactAppliesPerTick,
            maxRebuildVerticesPerTick: maxRebuildVerticesPerTick,
            maxRebuildIndicesPerTick: maxRebuildIndicesPerTick,
            maxRebuildBufferBytesPerTick: maxRebuildBufferBytesPerTick,
            maxRuntimeCellVertices: maxRuntimeCellVertices,
            maxRuntimeCellIndices: maxRuntimeCellIndices,
            maxRuntimeCellBufferBytes: maxRuntimeCellBufferBytes,
            quiescenceFramesBeforeBatchBuild: quiescenceFramesBeforeBatchBuild,
            recentVisibilityWindowFrames: recentVisibilityWindowFrames,
            visibilityGatedBatchBuildEnabled: visibilityGatedBatchBuildEnabled,
            maxRetirementsPerTick: maxRetirementsPerTick,
            batchRetireDelayFrames: batchRetireDelayFrames,
            cellSize: batchCellSize
        )
    }

    /// Generate a hash representing material properties for batching compatibility.
    ///
    /// For USDZ assets (packed archives), assetURL is included in the hash to prevent
    /// embedded textures with identical names but different pixel data from incorrectly
    /// batching together (e.g. "embedded_Basecolor_map" from dungeon.usdz vs chair.usdz).
    ///
    /// For USDC/USD assets, textures are separate files on disk referenced by absolute
    /// path.  The texture URL entries below already provide stable, unique identity —
    /// appending the tile file path would prevent identical materials in adjacent tiles
    /// from batching together, which is the primary case for tiled outdoor scenes.
    private func getMaterialHash(material: Material, assetURL: URL? = nil) -> String {
        var components: [String] = []

        // USDZ-only scope guard: embedded texture name collisions across packed archives.
        let isUSDZ = assetURL?.pathExtension.lowercased() == "usdz"
        if isUSDZ {
            components.append(assetURL?.absoluteString ?? "unknown_asset")
        }

        // Texture identity:
        // - Use canonical URL identity when available (stable across asset instances).
        // - Preserve full embedded pseudo-URL to avoid filename-only collisions.
        // - If URL metadata is missing, fall back to texture label/presence.
        components.append(textureIdentity(material.baseColor.texture, material.baseColorURL))
        components.append(textureIdentity(material.roughness.texture, material.roughnessURL))
        components.append(textureIdentity(material.metallic.texture, material.metallicURL))
        components.append(textureIdentity(material.normal.texture, material.normalURL))
        components.append(textureIdentity(material.height.texture, material.heightURL))

        // Base color value (important for meshes without textures)
        components.append(String(format: "%.2f,%.2f,%.2f,%.2f",
                                 material.baseColorValue.x,
                                 material.baseColorValue.y,
                                 material.baseColorValue.z,
                                 material.baseColorValue.w))

        // Material values (rounded to avoid tiny differences)
        components.append(String(format: "%.2f", material.roughnessValue))
        components.append(String(format: "%.2f", material.metallicValue))
        components.append("\(material.roughnessChannel.rawValue)")
        components.append("\(material.metallicChannel.rawValue)")
        components.append(String(format: "%.2f", material.specular))
        components.append(String(format: "%.2f", material.ior))
        components.append(String(format: "%.2f", material.stScale))
        components.append("\(material.alphaMode.rawValue)")
        components.append(String(format: "%.2f", material.alphaCutoff))

        // Height / Parallax Occlusion Mapping parameters. Without these, two materials
        // differing only in height texture or POM tuning hash identically and can be
        // merged into the same batch group, silently applying one material's POM state
        // (or lack of it) to geometry that should render differently.
        components.append("\(material.heightEnabled)")
        components.append(String(format: "%.3f", material.heightScale))
        components.append(String(format: "%.3f", material.heightMidlevel))
        components.append(String(format: "%.3f", material.heightRemapMin))
        components.append(String(format: "%.3f", material.heightRemapMax))

        // Texture flags are included to prevent grouping materials that differ only by map presence.
        components.append("\(material.hasBaseMap)")
        components.append("\(material.hasRoughMap)")
        components.append("\(material.hasMetalMap)")
        components.append("\(material.hasNormalMap)")
        components.append("\(material.hasHeightMap)")

        // Flags
        components.append("\(material.interactWithLight)")

        return components.joined(separator: "|")
    }

    /// Returns a stable texture identity string.
    private func textureIdentity(_ texture: MTLTexture?, _ url: URL?) -> String {
        if let url {
            return normalizeTextureURL(url)
        }
        if let texture {
            return "present:\(texture.label ?? "no_label")"
        }
        return "none"
    }

    /// Normalize texture URL for batching compatibility.
    private func normalizeTextureURL(_ url: URL?) -> String {
        guard let url else { return "none" }

        // Legacy embedded pseudo-URLs were generated as:
        // usdz-embedded://<meshName>/embedded_<MapType>
        // The meshName host differs per mesh even when the embedded texture is shared.
        // Collapse this pattern to the texture token so shared embedded textures batch together.
        if url.scheme == "usdz-embedded" {
            let host = url.host ?? ""
            let trimmedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            if !trimmedPath.isEmpty {
                if trimmedPath.hasPrefix("embedded_"), !host.isEmpty {
                    return "usdz-embedded://\(trimmedPath)"
                }
                if !host.isEmpty {
                    return "usdz-embedded://\(host)/\(trimmedPath)"
                }
                return "usdz-embedded://\(trimmedPath)"
            }

            if !host.isEmpty {
                return "usdz-embedded://\(host)"
            }
        }

        return url.standardized.absoluteString
    }

    /// Check if two materials are compatible for batching
    private func areMaterialsCompatible(_ mat1: Material, _ mat2: Material) -> Bool {
        getMaterialHash(material: mat1) == getMaterialHash(material: mat2)
    }

    private func resolveCellId(localTransform: LocalTransformComponent, worldTransform: WorldTransformComponent) -> BatchCellID {
        let (worldMin, worldMax) = worldAABB_MinMax(
            localMin: localTransform.boundingBox.min,
            localMax: localTransform.boundingBox.max,
            worldMatrix: worldTransform.space
        )
        let worldCenter = (worldMin + worldMax) * 0.5
        return cellId(for: worldCenter)
    }

    private func cellId(for worldCenter: simd_float3) -> BatchCellID {
        let size = batchCellSize
        return BatchCellID(
            x: Int(floor(worldCenter.x / size)),
            y: Int(floor(worldCenter.y / size)),
            z: Int(floor(worldCenter.z / size))
        )
    }

    /// Extract vertex data from a mesh and transform to world space
    /// Returns separate arrays for each attribute (using float4 to match shader expectations)
    private func extractVertices(from mesh: Mesh, worldTransform: simd_float4x4) -> (
        positions: [simd_float4],
        normals: [simd_float4],
        uvs: [simd_float2],
        tangents: [simd_float4]
    ) {
        var positions: [simd_float4] = []
        var normals: [simd_float4] = []
        var uvs: [simd_float2] = []
        var tangents: [simd_float4] = []

        let metalMesh = mesh.metalKitMesh

        // Get vertex buffers
        guard metalMesh.vertexBuffers.count > Int(modelPassVerticesIndex.rawValue) else {
            return (positions, normals, uvs, tangents)
        }

        let positionBuffer = metalMesh.vertexBuffers[Int(modelPassVerticesIndex.rawValue)].buffer
        let normalBuffer = metalMesh.vertexBuffers[Int(modelPassNormalIndex.rawValue)].buffer
        let uvBuffer = metalMesh.vertexBuffers[Int(modelPassUVIndex.rawValue)].buffer
        let tangentBuffer = metalMesh.vertexBuffers[Int(modelPassTangentIndex.rawValue)].buffer

        // Get vertex count
        guard mesh.submeshes.first != nil else { return (positions, normals, uvs, tangents) }
        let vertexCount = metalMesh.vertexCount

        // Extract raw data (Metal vertex buffers use float4 for positions, normals, tangents)
        let posData = positionBuffer.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)
        let normData = normalBuffer.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)
        let uvData = uvBuffer.contents().bindMemory(to: simd_float2.self, capacity: vertexCount)
        let tanData = tangentBuffer.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)

        // Calculate normal transformation matrix (inverse transpose of upper 3x3)
        let upperModelMatrix = matrix_float3x3(columns: (
            simd_float3(worldTransform.columns.0.x, worldTransform.columns.0.y, worldTransform.columns.0.z),
            simd_float3(worldTransform.columns.1.x, worldTransform.columns.1.y, worldTransform.columns.1.z),
            simd_float3(worldTransform.columns.2.x, worldTransform.columns.2.y, worldTransform.columns.2.z)
        ))
        let normalMatrix = upperModelMatrix.inverse.transpose

        // Reserve capacity
        positions.reserveCapacity(vertexCount)
        normals.reserveCapacity(vertexCount)
        uvs.reserveCapacity(vertexCount)
        tangents.reserveCapacity(vertexCount)

        // Transform and append
        for i in 0 ..< vertexCount {
            // Transform position to world space (keep as float4)
            let localPos = posData[i] // Already float4 with w component
            let worldPos = worldTransform * localPos
            positions.append(worldPos)

            // Transform normal to world space (extract xyz, transform, then pack as float4 with w=0)
            let localNorm = simd_float3(normData[i].x, normData[i].y, normData[i].z)
            let worldNormal = simd_normalize(normalMatrix * localNorm)
            normals.append(simd_float4(worldNormal.x, worldNormal.y, worldNormal.z, 0.0))

            // UVs don't need transformation
            uvs.append(uvData[i])

            // Transform tangent to world space (extract xyz, transform, preserve w)
            let localTan = simd_float3(tanData[i].x, tanData[i].y, tanData[i].z)
            let worldTangent = simd_normalize(normalMatrix * localTan)
            tangents.append(simd_float4(worldTangent.x, worldTangent.y, worldTangent.z, tanData[i].w))
        }

        return (positions, normals, uvs, tangents)
    }

    /// Extract indices from a mesh with offset applied
    private func extractIndices(from mesh: Mesh, submeshIndex: Int, indexOffset: UInt32) -> [UInt32] {
        var indices: [UInt32] = []

        guard submeshIndex < mesh.submeshes.count else { return indices }
        let submesh = mesh.submeshes[submeshIndex]

        let indexBuffer = submesh.metalKitSubmesh.indexBuffer.buffer
        let indexBufferOffset = submesh.metalKitSubmesh.indexBuffer.offset
        let indexCount = submesh.metalKitSubmesh.indexCount
        let indexType = submesh.metalKitSubmesh.indexType

        if indexType == .uint16 {
            let rawIndices = indexBuffer.contents()
                .advanced(by: indexBufferOffset)
                .bindMemory(to: UInt16.self, capacity: indexCount)
            for i in 0 ..< indexCount {
                indices.append(UInt32(rawIndices[i]) + indexOffset)
            }
        } else if indexType == .uint32 {
            let rawIndices = indexBuffer.contents()
                .advanced(by: indexBufferOffset)
                .bindMemory(to: UInt32.self, capacity: indexCount)
            for i in 0 ..< indexCount {
                indices.append(rawIndices[i] + indexOffset)
            }
        }

        return indices
    }

    private func extractFeatureEdgeIndices(from mesh: Mesh, indexOffset: UInt32) -> [UInt32] {
        guard let indexBuffer = mesh.featureEdgeIndexBuffer,
              mesh.featureEdgeIndexCount > 0
        else { return [] }

        var indices: [UInt32] = []
        indices.reserveCapacity(mesh.featureEdgeIndexCount)

        if mesh.featureEdgeIndexType == .uint16 {
            let rawIndices = indexBuffer.contents().bindMemory(to: UInt16.self, capacity: mesh.featureEdgeIndexCount)
            for i in 0 ..< mesh.featureEdgeIndexCount {
                indices.append(UInt32(rawIndices[i]) + indexOffset)
            }
        } else {
            let rawIndices = indexBuffer.contents().bindMemory(to: UInt32.self, capacity: mesh.featureEdgeIndexCount)
            for i in 0 ..< mesh.featureEdgeIndexCount {
                indices.append(rawIndices[i] + indexOffset)
            }
        }

        return indices
    }
}

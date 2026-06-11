//
//  EngineStatsSnapshot.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

public struct EngineTimingStats {
    public var frameTotalMs: Double = 0.0
    /// CPU frame time averaged over the last 30 frames — use this for smooth FPS display.
    public var smoothedFrameMs: Double = 0.0
    /// True GPU execution time for this frame (gpuEndTime - gpuStartTime from MTLCommandBuffer).
    public var gpuExecutionMs: Double = 0.0
    /// Wall-clock interval between successive GPU frame completions — use this for true GPU FPS.
    public var gpuFrameCadenceMs: Double = 0.0
    public var updateMs: Double = 0.0
    public var renderTotalMs: Double = 0.0
    public var renderPrepMs: Double = 0.0
    public var encodeMs: Double = 0.0
    public var submitMs: Double = 0.0
    public var cullingMs: Double = 0.0
    public var streamingRegionMs: Double = 0.0
    public var geometryStreamingMs: Double = 0.0
    public var batchingTickMs: Double = 0.0
    public var batchingRebuildMs: Double = 0.0

    public init(
        frameTotalMs: Double = 0.0,
        smoothedFrameMs: Double = 0.0,
        gpuExecutionMs: Double = 0.0,
        gpuFrameCadenceMs: Double = 0.0,
        updateMs: Double = 0.0,
        renderTotalMs: Double = 0.0,
        renderPrepMs: Double = 0.0,
        encodeMs: Double = 0.0,
        submitMs: Double = 0.0,
        cullingMs: Double = 0.0,
        streamingRegionMs: Double = 0.0,
        geometryStreamingMs: Double = 0.0,
        batchingTickMs: Double = 0.0,
        batchingRebuildMs: Double = 0.0
    ) {
        self.frameTotalMs = frameTotalMs
        self.smoothedFrameMs = smoothedFrameMs
        self.gpuExecutionMs = gpuExecutionMs
        self.gpuFrameCadenceMs = gpuFrameCadenceMs
        self.updateMs = updateMs
        self.renderTotalMs = renderTotalMs
        self.renderPrepMs = renderPrepMs
        self.encodeMs = encodeMs
        self.submitMs = submitMs
        self.cullingMs = cullingMs
        self.streamingRegionMs = streamingRegionMs
        self.geometryStreamingMs = geometryStreamingMs
        self.batchingTickMs = batchingTickMs
        self.batchingRebuildMs = batchingRebuildMs
    }
}

public struct EngineRenderStats {
    public var drawCallsTotal: Int = 0
    public var drawCallsOpaque: Int = 0
    public var drawCallsTransparent: Int = 0
    public var drawCallsShadow: Int = 0
    public var drawCallsBatched: Int = 0
    public var trianglesTotal: Int = 0
    public var visibleInstances: Int = 0

    public init(
        drawCallsTotal: Int = 0,
        drawCallsOpaque: Int = 0,
        drawCallsTransparent: Int = 0,
        drawCallsShadow: Int = 0,
        drawCallsBatched: Int = 0,
        trianglesTotal: Int = 0,
        visibleInstances: Int = 0
    ) {
        self.drawCallsTotal = drawCallsTotal
        self.drawCallsOpaque = drawCallsOpaque
        self.drawCallsTransparent = drawCallsTransparent
        self.drawCallsShadow = drawCallsShadow
        self.drawCallsBatched = drawCallsBatched
        self.trianglesTotal = trianglesTotal
        self.visibleInstances = visibleInstances
    }
}

public struct EngineCullingStats {
    public var frustumTested: Int = 0
    public var frustumPassed: Int = 0
    public var frustumFailed: Int = 0
    public var occlusionTested: Int = 0
    public var occlusionPassed: Int = 0
    public var occlusionFailed: Int = 0
    public var usedHZB: Bool = false
    public var optimizedFrustumPath: Bool = false
    public var hzbIsValid: Bool = false
    public var hzbMipCount: Int = 0
    public var selectedHZBMipLevel: Int = 0
    public var selectedHZBMipSize: simd_int2 = .zero

    public init(
        frustumTested: Int = 0,
        frustumPassed: Int = 0,
        frustumFailed: Int = 0,
        occlusionTested: Int = 0,
        occlusionPassed: Int = 0,
        occlusionFailed: Int = 0,
        usedHZB: Bool = false,
        optimizedFrustumPath: Bool = false,
        hzbIsValid: Bool = false,
        hzbMipCount: Int = 0,
        selectedHZBMipLevel: Int = 0,
        selectedHZBMipSize: simd_int2 = .zero
    ) {
        self.frustumTested = frustumTested
        self.frustumPassed = frustumPassed
        self.frustumFailed = frustumFailed
        self.occlusionTested = occlusionTested
        self.occlusionPassed = occlusionPassed
        self.occlusionFailed = occlusionFailed
        self.usedHZB = usedHZB
        self.optimizedFrustumPath = optimizedFrustumPath
        self.hzbIsValid = hzbIsValid
        self.hzbMipCount = hzbMipCount
        self.selectedHZBMipLevel = selectedHZBMipLevel
        self.selectedHZBMipSize = selectedHZBMipSize
    }
}

public struct EngineStreamingStats {
    public var activeLoads: Int = 0
    public var loadCandidates: Int = 0
    public var pendingLoadBacklog: Int = 0
    public var residentMeshEntities: Int = 0
    public var cachedMeshResources: Int = 0
    public var pendingUploadCount: Int = 0
    public var blockedByGateMs: Double = 0.0
    public var loadedStreamingEntities: Int = 0
    public var loadingStreamingEntities: Int = 0
    public var unloadedStreamingEntities: Int = 0
    // per-tick operational detail (from GeometryStreamingDiagnosticsSnapshot)
    public var updateTriggered: Bool = false
    public var updateWorkMs: Double = 0.0
    public var nearbyEntitiesQueried: Int = 0
    public var availableLoadSlots: Int = 0
    public var evictionsPerformed: Int = 0
    public var averageAsyncLoadMs: Double = 0.0
    public var lastApplyLoadedMeshMs: Double = 0.0
    public var tileSwapWarnings: Int = 0
    public var tilesSkippedByHierarchyGate: Int = 0
    public var tileRepresentationGapWarnings: Int = 0
    public var lod0VisibilityWarnings: Int = 0
    public var lod0VisibilityWarningsWithFallback: Int = 0
    public var lod0VisibilityWarningsNoFallback: Int = 0

    public init(
        activeLoads: Int = 0,
        loadCandidates: Int = 0,
        pendingLoadBacklog: Int = 0,
        residentMeshEntities: Int = 0,
        cachedMeshResources: Int = 0,
        pendingUploadCount: Int = 0,
        blockedByGateMs: Double = 0.0,
        loadedStreamingEntities: Int = 0,
        loadingStreamingEntities: Int = 0,
        unloadedStreamingEntities: Int = 0,
        updateTriggered: Bool = false,
        updateWorkMs: Double = 0.0,
        nearbyEntitiesQueried: Int = 0,
        availableLoadSlots: Int = 0,
        evictionsPerformed: Int = 0,
        averageAsyncLoadMs: Double = 0.0,
        lastApplyLoadedMeshMs: Double = 0.0,
        tileSwapWarnings: Int = 0,
        tilesSkippedByHierarchyGate: Int = 0,
        tileRepresentationGapWarnings: Int = 0,
        lod0VisibilityWarnings: Int = 0,
        lod0VisibilityWarningsWithFallback: Int = 0,
        lod0VisibilityWarningsNoFallback: Int = 0
    ) {
        self.activeLoads = activeLoads
        self.loadCandidates = loadCandidates
        self.pendingLoadBacklog = pendingLoadBacklog
        self.residentMeshEntities = residentMeshEntities
        self.cachedMeshResources = cachedMeshResources
        self.pendingUploadCount = pendingUploadCount
        self.blockedByGateMs = blockedByGateMs
        self.loadedStreamingEntities = loadedStreamingEntities
        self.loadingStreamingEntities = loadingStreamingEntities
        self.unloadedStreamingEntities = unloadedStreamingEntities
        self.updateTriggered = updateTriggered
        self.updateWorkMs = updateWorkMs
        self.nearbyEntitiesQueried = nearbyEntitiesQueried
        self.availableLoadSlots = availableLoadSlots
        self.evictionsPerformed = evictionsPerformed
        self.averageAsyncLoadMs = averageAsyncLoadMs
        self.lastApplyLoadedMeshMs = lastApplyLoadedMeshMs
        self.tileSwapWarnings = tileSwapWarnings
        self.tilesSkippedByHierarchyGate = tilesSkippedByHierarchyGate
        self.tileRepresentationGapWarnings = tileRepresentationGapWarnings
        self.lod0VisibilityWarnings = lod0VisibilityWarnings
        self.lod0VisibilityWarningsWithFallback = lod0VisibilityWarningsWithFallback
        self.lod0VisibilityWarningsNoFallback = lod0VisibilityWarningsNoFallback
    }
}

public struct EngineBatchingStats {
    public var batchGroupCount: Int = 0
    public var batchedMeshCount: Int = 0
    public var rebuildsThisSecond: Int = 0
    public var lastRebuildCostMs: Double = 0.0
    public var lastRebuildInputMeshCount: Int = 0
    public var lastRebuildOutputBatchCount: Int = 0
    // per-tick scheduler detail (from BatchingTickDiagnostics)
    public var dirtyCellsBeforePrune: Int = 0
    public var dirtyCellsAfterPrune: Int = 0
    public var deferredByWorkBudget: Int = 0
    public var skippedByComplexityGuard: Int = 0
    public var dispatchedBuilds: Int = 0

    public init(
        batchGroupCount: Int = 0,
        batchedMeshCount: Int = 0,
        rebuildsThisSecond: Int = 0,
        lastRebuildCostMs: Double = 0.0,
        lastRebuildInputMeshCount: Int = 0,
        lastRebuildOutputBatchCount: Int = 0,
        dirtyCellsBeforePrune: Int = 0,
        dirtyCellsAfterPrune: Int = 0,
        deferredByWorkBudget: Int = 0,
        skippedByComplexityGuard: Int = 0,
        dispatchedBuilds: Int = 0
    ) {
        self.batchGroupCount = batchGroupCount
        self.batchedMeshCount = batchedMeshCount
        self.rebuildsThisSecond = rebuildsThisSecond
        self.lastRebuildCostMs = lastRebuildCostMs
        self.lastRebuildInputMeshCount = lastRebuildInputMeshCount
        self.lastRebuildOutputBatchCount = lastRebuildOutputBatchCount
        self.dirtyCellsBeforePrune = dirtyCellsBeforePrune
        self.dirtyCellsAfterPrune = dirtyCellsAfterPrune
        self.deferredByWorkBudget = deferredByWorkBudget
        self.skippedByComplexityGuard = skippedByComplexityGuard
        self.dispatchedBuilds = dispatchedBuilds
    }
}

public struct EngineMemoryStats {
    public var meshMemoryBytes: Int = 0
    public var textureMemoryBytes: Int = 0
    public var geometryBudgetBytes: Int = 0
    public var textureBudgetBytes: Int = 0
    public var utilizationPercent: Double = 0.0
    public var isUnderPressure: Bool = false
    public var trackedEntityCount: Int = 0

    public init(
        meshMemoryBytes: Int = 0,
        textureMemoryBytes: Int = 0,
        geometryBudgetBytes: Int = 0,
        textureBudgetBytes: Int = 0,
        utilizationPercent: Double = 0.0,
        isUnderPressure: Bool = false,
        trackedEntityCount: Int = 0
    ) {
        self.meshMemoryBytes = meshMemoryBytes
        self.textureMemoryBytes = textureMemoryBytes
        self.geometryBudgetBytes = geometryBudgetBytes
        self.textureBudgetBytes = textureBudgetBytes
        self.utilizationPercent = utilizationPercent
        self.isUnderPressure = isUnderPressure
        self.trackedEntityCount = trackedEntityCount
    }
}

public struct EngineStatsSnapshot {
    public var frameIndex: UInt64 = 0
    public var timestampSeconds: Double = 0.0
    public var timing: EngineTimingStats = .init()
    public var render: EngineRenderStats = .init()
    public var culling: EngineCullingStats = .init()
    public var streaming: EngineStreamingStats = .init()
    public var batching: EngineBatchingStats = .init()
    public var memory: EngineMemoryStats = .init()

    public init(
        frameIndex: UInt64 = 0,
        timestampSeconds: Double = 0.0,
        timing: EngineTimingStats = .init(),
        render: EngineRenderStats = .init(),
        culling: EngineCullingStats = .init(),
        streaming: EngineStreamingStats = .init(),
        batching: EngineBatchingStats = .init(),
        memory: EngineMemoryStats = .init()
    ) {
        self.frameIndex = frameIndex
        self.timestampSeconds = timestampSeconds
        self.timing = timing
        self.render = render
        self.culling = culling
        self.streaming = streaming
        self.batching = batching
        self.memory = memory
    }
}

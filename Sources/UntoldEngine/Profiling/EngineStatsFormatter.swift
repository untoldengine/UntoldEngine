//
//  EngineStatsFormatter.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public enum EngineStatsFormatStyle {
    case compact
    case expanded
}

public func formatEngineStats(_ snapshot: EngineStatsSnapshot, style: EngineStatsFormatStyle = .expanded) -> String {
    switch style {
    case .compact:
        return compactEngineStatsString(snapshot)
    case .expanded:
        return expandedEngineStatsString(snapshot)
    }
}

public func formatEngineStatsCompact(_ snapshot: EngineStatsSnapshot) -> String {
    formatEngineStats(snapshot, style: .compact)
}

public func formatEngineStatsOverlay(_ snapshot: EngineStatsSnapshot) -> String {
    formatEngineStats(snapshot, style: .expanded)
}

private func compactEngineStatsString(_ snapshot: EngineStatsSnapshot) -> String {
    "frame=\(snapshot.frameIndex) " +
        "cpuFPS=\(formatFPS(frameMs: snapshot.timing.smoothedFrameMs)) " +
        "gpuFPS=\(formatFPS(frameMs: snapshot.timing.gpuFrameCadenceMs)) " +
        "cpuMs=\(formatMs(snapshot.timing.smoothedFrameMs)) " +
        "gpuExecMs=\(formatMs(snapshot.timing.gpuExecutionMs)) " +
        "updateMs=\(formatMs(snapshot.timing.updateMs)) " +
        "renderMs=\(formatMs(snapshot.timing.renderTotalMs)) " +
        "cullMs=\(formatMs(snapshot.timing.cullingMs)) " +
        "drawCalls=\(snapshot.render.drawCallsTotal) " +
        "triangles=\(snapshot.render.trianglesTotal) " +
        "visible=\(snapshot.render.visibleInstances)"
}

private func expandedEngineStatsString(_ snapshot: EngineStatsSnapshot) -> String {
    let cpuBound = snapshot.timing.gpuFrameCadenceMs <= 0
        || snapshot.timing.smoothedFrameMs >= snapshot.timing.gpuFrameCadenceMs * 0.9
    let bottleneck = cpuBound ? "CPU-bound" : "GPU-bound"
    let meshMB = formatMB(snapshot.memory.meshMemoryBytes)
    let meshBudgetMB = formatMB(snapshot.memory.geometryBudgetBytes)
    let texMB = formatMB(snapshot.memory.textureMemoryBytes)
    let texBudgetMB = formatMB(snapshot.memory.textureBudgetBytes)
    let memPct = String(format: "%.0f%%", snapshot.memory.utilizationPercent * 100)
    let pressure = snapshot.memory.isUnderPressure ? " PRESSURE" : ""
    return """
    Frame \(snapshot.frameIndex) | CPU \(formatMs(snapshot.timing.smoothedFrameMs))ms (\(formatFPS(frameMs: snapshot.timing.smoothedFrameMs)) fps, smoothed)  GPU \(formatMs(snapshot.timing.gpuExecutionMs))ms exec / \(formatFPS(frameMs: snapshot.timing.gpuFrameCadenceMs)) fps cadence  [\(bottleneck)]
    Timing: frame \(formatMs(snapshot.timing.frameTotalMs))ms (raw CPU) | update \(formatMs(snapshot.timing.updateMs))ms | render \(formatMs(snapshot.timing.renderTotalMs))ms | cull \(formatMs(snapshot.timing.cullingMs))ms | stream \(formatMs(snapshot.timing.streamingRegionMs + snapshot.timing.geometryStreamingMs))ms | batchTick \(formatMs(snapshot.timing.batchingTickMs))ms | batchRebuild \(formatMs(snapshot.timing.batchingRebuildMs))ms
    Render: draws \(snapshot.render.drawCallsTotal) (opaque \(snapshot.render.drawCallsOpaque), transparent \(snapshot.render.drawCallsTransparent), shadow \(snapshot.render.drawCallsShadow), batched \(snapshot.render.drawCallsBatched)) | triangles \(snapshot.render.trianglesTotal) | visible \(snapshot.render.visibleInstances)
    Culling: frustum \(snapshot.culling.frustumPassed)/\(snapshot.culling.frustumTested) failed \(snapshot.culling.frustumFailed) | occlusion \(snapshot.culling.occlusionPassed)/\(snapshot.culling.occlusionTested) failed \(snapshot.culling.occlusionFailed) | usedHZB \(snapshot.culling.usedHZB) validHZB \(snapshot.culling.hzbIsValid)
    Streaming: loaded \(snapshot.streaming.loadedStreamingEntities) loading \(snapshot.streaming.loadingStreamingEntities) unloaded \(snapshot.streaming.unloadedStreamingEntities) | active \(snapshot.streaming.activeLoads) | nearby \(snapshot.streaming.nearbyEntitiesQueried) candidates \(snapshot.streaming.loadCandidates) slots \(snapshot.streaming.availableLoadSlots) | backlog \(snapshot.streaming.pendingLoadBacklog) | pendingUploads \(snapshot.streaming.pendingUploadCount) | gateMs \(formatMs(snapshot.streaming.blockedByGateMs))
    Streaming: tick=\(snapshot.streaming.updateTriggered) workMs \(formatMs(snapshot.streaming.updateWorkMs)) | evictions \(snapshot.streaming.evictionsPerformed) | avgLoadMs \(formatMs(snapshot.streaming.averageAsyncLoadMs)) | applyMs \(formatMs(snapshot.streaming.lastApplyLoadedMeshMs)) | tileSwapWarn \(snapshot.streaming.tileSwapWarnings) | hierGateSkip \(snapshot.streaming.tilesSkippedByHierarchyGate)
    Batching: groups \(snapshot.batching.batchGroupCount) | batchedMeshes \(snapshot.batching.batchedMeshCount) | dirty \(snapshot.batching.dirtyCellsBeforePrune)→\(snapshot.batching.dirtyCellsAfterPrune) | defWork \(snapshot.batching.deferredByWorkBudget) skipComplex \(snapshot.batching.skippedByComplexityGuard) | dispatched \(snapshot.batching.dispatchedBuilds)→\(snapshot.batching.lastRebuildOutputBatchCount) groups | rebuilds/s \(snapshot.batching.rebuildsThisSecond) | rebuildMs \(formatMs(snapshot.batching.lastRebuildCostMs))
    Memory: mesh \(meshMB)/\(meshBudgetMB)mb | tex \(texMB)/\(texBudgetMB)mb | total \(memPct) | entities \(snapshot.memory.trackedEntityCount)\(pressure)
    """
}

private func formatMB(_ bytes: Int) -> String {
    String(format: "%.0f", Double(bytes) / (1024 * 1024))
}

private func formatMs(_ value: Double) -> String {
    String(format: "%.2f", value)
}

private func formatFPS(frameMs: Double) -> String {
    guard frameMs > 0 else { return "0.0" }
    return String(format: "%.1f", 1000.0 / frameMs)
}

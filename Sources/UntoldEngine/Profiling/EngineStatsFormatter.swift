//
//  EngineStatsFormatter.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

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
    return """
    Frame \(snapshot.frameIndex) | CPU \(formatMs(snapshot.timing.smoothedFrameMs))ms (\(formatFPS(frameMs: snapshot.timing.smoothedFrameMs)) fps, smoothed)  GPU \(formatMs(snapshot.timing.gpuExecutionMs))ms exec / \(formatFPS(frameMs: snapshot.timing.gpuFrameCadenceMs)) fps cadence  [\(bottleneck)]
    Timing: frame \(formatMs(snapshot.timing.frameTotalMs))ms (raw CPU) | update \(formatMs(snapshot.timing.updateMs))ms | render \(formatMs(snapshot.timing.renderTotalMs))ms | cull \(formatMs(snapshot.timing.cullingMs))ms | stream \(formatMs(snapshot.timing.streamingRegionMs + snapshot.timing.geometryStreamingMs))ms | batchTick \(formatMs(snapshot.timing.batchingTickMs))ms | batchRebuild \(formatMs(snapshot.timing.batchingRebuildMs))ms
    Render: draws \(snapshot.render.drawCallsTotal) (opaque \(snapshot.render.drawCallsOpaque), transparent \(snapshot.render.drawCallsTransparent), shadow \(snapshot.render.drawCallsShadow), batched \(snapshot.render.drawCallsBatched)) | triangles \(snapshot.render.trianglesTotal) | visible \(snapshot.render.visibleInstances)
    Culling: frustum \(snapshot.culling.frustumPassed)/\(snapshot.culling.frustumTested) failed \(snapshot.culling.frustumFailed) | occlusion \(snapshot.culling.occlusionPassed)/\(snapshot.culling.occlusionTested) failed \(snapshot.culling.occlusionFailed) | usedHZB \(snapshot.culling.usedHZB) validHZB \(snapshot.culling.hzbIsValid)
    Streaming: activeLoads \(snapshot.streaming.activeLoads) | candidates \(snapshot.streaming.loadCandidates) | backlog \(snapshot.streaming.pendingLoadBacklog) | residentMeshes \(snapshot.streaming.residentMeshEntities) | cachedResources \(snapshot.streaming.cachedMeshResources) | pendingUploads \(snapshot.streaming.pendingUploadCount) | blockedByGate \(formatMs(snapshot.streaming.blockedByGateMs))ms
    Batching: groups \(snapshot.batching.batchGroupCount) | batchedMeshes \(snapshot.batching.batchedMeshCount) | rebuilds/s \(snapshot.batching.rebuildsThisSecond) | lastRebuild \(formatMs(snapshot.batching.lastRebuildCostMs))ms (\(snapshot.batching.lastRebuildInputMeshCount)->\(snapshot.batching.lastRebuildOutputBatchCount))
    """
}

private func formatMs(_ value: Double) -> String {
    String(format: "%.2f", value)
}

private func formatFPS(frameMs: Double) -> String {
    guard frameMs > 0 else { return "0.0" }
    return String(format: "%.1f", 1000.0 / frameMs)
}

//
//  GaussianChunkCullBenchmark.swift
//  UntoldEngine
//
//  Informational timing of the per-chunk path on synthetic one- and two-million-splat slabs: the
//  whole frame's command-buffer GPU time (renderInfo.lastCommandBuffer gpuStartTime/gpuEndTime)
//  and the resident bytes with the per-splat cull over the whole buffer (legacy: 48-byte records,
//  index buffers, the set sized to the asset), through the chunk path with every chunk forced
//  visible (disableChunkCull), through the chunk path proper with the budget unlimited, and
//  through the chunk path with the budget at a quarter of the visible count, at a camera that
//  sees about 30 % of the asset. Skipped unless UNTOLD_PERF_GAUSSIAN_CHUNK_CULL=1: the bakes take
//  tens of seconds and the numbers are machine-specific, so this is a tool, not a gate.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Metal
import simd
@testable import UntoldEngine
import XCTest

@MainActor
final class GaussianChunkCullBenchmark: BaseRenderSetup {
    private var savedDisableChunkCull = false
    private var savedDisableHZBOcclusionCull = false
    private var savedWorkingSetOverride: Int?

    override func setUp() async throws {
        try await super.setUp()
        savedDisableChunkCull = GaussianDebugOptions.shared.disableChunkCull
        savedDisableHZBOcclusionCull = GaussianDebugOptions.shared.disableHZBOcclusionCull
        savedWorkingSetOverride = GaussianRuntimeLimits.workingSetSplatsOverride
    }

    override func tearDown() async throws {
        GaussianDebugOptions.shared.disableChunkCull = savedDisableChunkCull
        GaussianDebugOptions.shared.disableHZBOcclusionCull = savedDisableHZBOcclusionCull
        GaussianRuntimeLimits.workingSetSplatsOverride = savedWorkingSetOverride
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    private func intEnv(_ name: String, default defaultValue: Int) -> Int {
        guard let raw = ProcessInfo.processInfo.environment[name], let value = Int(raw), value > 0 else { return defaultValue }
        return value
    }

    // MARK: - Synthetic asset

    private func syntheticAssetURL(splatCount: Int) throws -> URL {
        try GaussianSyntheticAsset.url(splatCount: splatCount)
    }

    // MARK: - Scene

    private func addEntity(_ result: GaussianLoadResult) -> GaussianComponent? {
        let entity = createEntity()
        registerComponent(entityId: entity, componentType: GaussianComponent.self)
        registerComponent(entityId: entity, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entity, componentType: LocalTransformComponent.self)
        scene.get(component: WorldTransformComponent.self, for: entity)?.space = matrix_identity_float4x4
        guard let component = scene.get(component: GaussianComponent.self, for: entity) else { return nil }
        copyGaussianLoadResult(result, to: component)
        return component
    }

    /// Fraction of the asset's splats whose chunk's *unpadded* centre box is in view — with the
    /// uniform synthetic density a stand-in for the fraction of splats the per-splat cull keeps.
    /// (The padded boxes the chunk cull tests keep more: see the visible-chunk counts reported.)
    private func visibleFraction(index: UntoldGSIndex, viewProjection: simd_float4x4) -> Double {
        let visible = index.chunks.filter {
            GaussianChunkCullMath.boxPassesClipPlanes(boxMin: $0.aabbMin, boxMax: $0.aabbMax, viewProjection: viewProjection)
        }
        let splats = visible.reduce(0) { $0 + Int($1.splatCount) }
        return Double(splats) / Double(max(1, Int(index.header.splatCount)))
    }

    /// An oblique view down onto the slab's centre, raised until the chunk mirror keeps about
    /// `target` of the splats: the higher the camera, the more of the slab its frustum covers.
    private func placeCameraSeeing(target: Double, index: UntoldGSIndex) -> (fraction: Double, eye: simd_float3) {
        let camera = placeGaussianTestCamera(eye: simd_float3(0, 5, 3), target: .zero)
        var low: Float = 0.3
        var high: Float = 20
        var best: (Double, simd_float3) = (0, .zero)
        for _ in 0 ..< 24 {
            let height = 0.5 * (low + high)
            let eye = simd_float3(0, height, 0.6 * height)
            cameraLookAt(entityId: camera, eye: eye, target: .zero, up: simd_float3(0, 1, 0))
            let view = scene.get(component: CameraComponent.self, for: camera)?.viewSpace ?? matrix_identity_float4x4
            let fraction = visibleFraction(index: index, viewProjection: simd_mul(renderInfo.perspectiveSpace, view))
            best = (fraction, eye)
            if abs(fraction - target) < 0.01 { break }
            if fraction > target { high = height } else { low = height }
        }
        return best
    }

    private struct FrameSample {
        var gpuMs: Double
        var visibleSplats: Int
        var visibleChunks: Int
    }

    private func measure(frames: Int, component: GaussianComponent) -> [FrameSample] {
        var samples: [FrameSample] = []
        for _ in 0 ..< frames {
            renderer.draw(in: renderer.metalView)
            guard let commandBuffer = renderInfo.lastCommandBuffer else { continue }
            commandBuffer.waitUntilCompleted()
            let slot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
            let visible = sharedGaussianVisibleCount()
            let chunks = component.chunkTable.map { Int($0.visibleChunkSets[min(slot, $0.visibleChunkSets.count - 1)].contents().load(as: GaussianVisibleSet.self).threadgroupCount) } ?? -1
            samples.append(FrameSample(gpuMs: (commandBuffer.gpuEndTime - commandBuffer.gpuStartTime) * 1000, visibleSplats: visible, visibleChunks: chunks))
        }
        return samples
    }

    /// GPU time of a command buffer holding only the Gaussian cull encoder (chunk stage, when
    /// any, plus the per-splat pass): isolates the pass this branch changes from the rest of the
    /// frame, which the whole-frame numbers above cannot resolve.
    private func measureCullOnly(frames: Int) -> [Double] {
        var times: [Double] = []
        for _ in 0 ..< frames {
            guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else { continue }
            executeGaussianFrustumCulling(commandBuffer)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            times.append((commandBuffer.gpuEndTime - commandBuffer.gpuStartTime) * 1000)
        }
        return times
    }

    private func summary(_ times: [Double]) -> String {
        let sorted = times.sorted()
        guard !sorted.isEmpty else { return "no samples" }
        let mean = sorted.reduce(0, +) / Double(sorted.count)
        return String(format: "mean %.3f ms, median %.3f ms, min %.3f ms, max %.3f ms over %d", mean, sorted[sorted.count / 2], sorted.first!, sorted.last!, sorted.count)
    }

    private func report(_ label: String, _ samples: [FrameSample], cullOnly: [Double], warmup: Int, component: GaussianComponent) -> String {
        let measured = Array(samples.dropFirst(warmup))
        guard let last = measured.last else { return "\(label): no samples" }
        let workingSet = GaussianSharedWorkingSet.shared
        let state = workingSet.lastBudgetState
        let line = "\(label): frame gpu \(summary(measured.map(\.gpuMs))) frames; cull-only gpu \(summary(Array(cullOnly.dropFirst(warmup)))) buffers; visible splats \(last.visibleSplats), visible chunks \(last.visibleChunks); entity \(gaussianFormatBytes(component.estimatedGPUBytes)), shared set \(gaussianFormatBytes(workingSet.residentBytes)) (capacity \(workingSet.capacity)), total \(gaussianFormatBytes(component.estimatedGPUBytes + workingSet.residentBytes)); budget \(state.budget) requested \(state.requestedSplats) quota \(state.quotaSplats) scale \(String(format: "%.3f", state.scale))"
        print("[GaussianChunkCullBenchmark] \(line)")
        return line
    }

    /// One configuration on one asset: add the entity, converge the budget scale, measure.
    private func bench(_ label: String, result: GaussianLoadResult, index: UntoldGSIndex, frames: Int, warmup: Int) -> (line: String, visibleSplats: Int)? {
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        _ = placeCameraSeeing(target: 0.30, index: index)
        guard let component = addEntity(result) else { return nil }
        defer { destroyAllEntities() }
        let samples = measure(frames: frames + warmup, component: component)
        let cullOnly = measureCullOnly(frames: frames + warmup)
        return (report(label, samples, cullOnly: cullOnly, warmup: warmup, component: component), samples.last?.visibleSplats ?? 0)
    }

    // MARK: - Bench

    func testChunkCullFrameTime() throws {
        guard ProcessInfo.processInfo.environment["UNTOLD_PERF_GAUSSIAN_CHUNK_CULL"] == "1" else {
            throw XCTSkip("Set UNTOLD_PERF_GAUSSIAN_CHUNK_CULL=1 to run the chunk-cull benchmark")
        }
        guard renderer != nil else { throw XCTSkip("Renderer not initialized") }
        let splatCounts = ProcessInfo.processInfo.environment["UNTOLD_PERF_SPLAT_COUNT"].flatMap { Int($0) }.map { [$0] } ?? [1_000_000, 2_000_000]
        let frames = intEnv("UNTOLD_PERF_GAUSSIAN_FRAMES", default: 30)
        let warmup = intEnv("UNTOLD_PERF_WARMUP_FRAMES", default: 5)
        GaussianDebugOptions.shared.disableHZBOcclusionCull = false

        var lines: [String] = []
        for splatCount in splatCounts {
            let url = try syntheticAssetURL(splatCount: splatCount)
            let loaded = try GaussianChunkLoader.load(url: url)
            let chunked = try XCTUnwrap(buildGaussianLoadResult(
                packedSplatBuffer: loaded.packedSplatBuffer,
                splatCount: UInt(loaded.splatCount),
                sphericalHarmonicsBuffer: loaded.sphericalHarmonicsBuffer,
                sphericalHarmonicsMetadata: loaded.sphericalHarmonicsMetadata,
                boundingBox: loaded.boundingBox,
                chunkTable: loaded.chunkTable
            ))
            // The same records decoded once into the whole-buffer path: the legacy per-splat cull.
            let legacy = try GaussianLegacyTwin(loaded: loaded).result

            let view = placeCameraSeeing(target: 0.30, index: loaded.index)
            print(String(format: "[GaussianChunkCullBenchmark] %d splats in %d chunks; camera at (%.2f, %.2f, %.2f) sees %.1f %% of the splats by unpadded chunk box",
                         loaded.splatCount, loaded.chunkTable.chunkCount, view.eye.x, view.eye.y, view.eye.z, view.fraction * 100))
            destroyAllEntities()
            let prefix = "\(splatCount / 1_000_000) M"

            // Legacy, the set sized to the resident total (the debug switch restores that sizing).
            GaussianDebugOptions.shared.disableChunkCull = false
            GaussianDebugOptions.shared.disableWorkingSetBudget = true
            GaussianRuntimeLimits.workingSetSplatsOverride = nil
            if let legacyRun = bench("\(prefix) legacy per-splat cull (48 B records, set sized to the asset)", result: legacy, index: loaded.index, frames: frames, warmup: warmup) {
                lines.append(legacyRun.line)
            }
            GaussianDebugOptions.shared.disableWorkingSetBudget = false

            // Chunked and fused, budget unlimited (the set still never exceeds the resident total).
            GaussianRuntimeLimits.workingSetSplatsOverride = splatCount
            GaussianDebugOptions.shared.disableChunkCull = true
            if let forced = bench("\(prefix) chunk path, every chunk forced visible, budget unlimited", result: chunked, index: loaded.index, frames: frames, warmup: warmup) {
                lines.append(forced.line)
            }
            GaussianDebugOptions.shared.disableChunkCull = false
            var visibleUnlimited = 0
            if let unlimited = bench("\(prefix) chunk cull + fused pass, budget unlimited", result: chunked, index: loaded.index, frames: frames, warmup: warmup) {
                lines.append(unlimited.line)
                visibleUnlimited = unlimited.visibleSplats
            }

            // Budget at a quarter of what the camera sees.
            let quarter = max(1, visibleUnlimited / 4)
            GaussianRuntimeLimits.workingSetSplatsOverride = quarter
            if let budgeted = bench("\(prefix) chunk cull + fused pass, budget \(quarter) (25 %% of the visible count)", result: chunked, index: loaded.index, frames: frames, warmup: warmup) {
                lines.append(budgeted.line)
            }
            GaussianRuntimeLimits.workingSetSplatsOverride = nil
        }

        XCTAssertEqual(lines.count, splatCounts.count * 4)
    }
}

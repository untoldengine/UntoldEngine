//
//  GaussianChunkCullBenchmark.swift
//  UntoldEngine
//
//  Informational timing of the per-chunk path on synthetic one- and two-million-splat slabs: the
//  whole frame's command-buffer GPU time (renderInfo.lastCommandBuffer gpuStartTime/gpuEndTime)
//  and the resident bytes with the per-splat cull over the whole buffer (legacy: 48-byte records,
//  index buffers, the set sized to the asset), through the chunk path with every chunk forced
//  visible (disableChunkCull), through the chunk path proper with the budget unlimited, and
//  through the chunk path with the budget at a quarter of the visible count — once with the
//  screen-weighted quotas and once with the uniform rule (disableScreenWeightedQuotas), with
//  the PSNR of each against the unlimited frame over the near (bottom) and far (top) halves of
//  the image — and paged from the file into a pool a quarter of the asset's size with the
//  budget unlimited (frames to warm, pages, reads and evictions per frame, the pager's worst
//  tick), plus a pool that holds the whole asset whose near half must match the unlimited
//  frame — at a camera that sees about 30 % of the asset; and, with the slab's per-chunk coarse
//  levels baked, the quarter budget with the levels on and off (the far half of the image is
//  where the levels replace the fine prefix) and the quarter pool in both modes (the fine bytes
//  the pager reads to warm). Skipped unless
//  UNTOLD_PERF_GAUSSIAN_CHUNK_CULL=1: the bakes take tens of seconds and the numbers are
//  machine-specific, so this is a tool, not a gate.
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
    private var savedDisableScreenWeightedQuotas = false
    private var savedWorkingSetOverride: Int?
    private var savedLevelMode = GaussianLevelMode.auto

    override func setUp() async throws {
        try await super.setUp()
        savedDisableChunkCull = GaussianDebugOptions.shared.disableChunkCull
        savedDisableHZBOcclusionCull = GaussianDebugOptions.shared.disableHZBOcclusionCull
        savedDisableScreenWeightedQuotas = GaussianDebugOptions.shared.disableScreenWeightedQuotas
        savedWorkingSetOverride = GaussianRuntimeLimits.workingSetSplatsOverride
        savedLevelMode = GaussianDebugOptions.shared.gaussianLevelMode
        GaussianDebugOptions.shared.gaussianLevelMode = .auto
        // Count-bounded commits, so framesToWarm and committed/frame compare across machines.
        GaussianPagingPolicy.commitBudget = .infinity
    }

    override func tearDown() async throws {
        GaussianPagingPolicy.resetKnobs()
        GaussianDebugOptions.shared.disableChunkCull = savedDisableChunkCull
        GaussianDebugOptions.shared.disableHZBOcclusionCull = savedDisableHZBOcclusionCull
        GaussianDebugOptions.shared.disableScreenWeightedQuotas = savedDisableScreenWeightedQuotas
        GaussianDebugOptions.shared.gaussianLevelMode = savedLevelMode
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

    private func syntheticAssetURL(splatCount: Int, coarseLevels: UntoldGSCoarseLevelOptions? = nil) throws -> URL {
        try GaussianSyntheticAsset.url(splatCount: splatCount, coarseLevels: coarseLevels)
    }

    // MARK: - Scene

    private func addEntity(_ result: GaussianLoadResult) -> (entity: EntityID, component: GaussianComponent)? {
        let entity = createEntity()
        registerComponent(entityId: entity, componentType: GaussianComponent.self)
        registerComponent(entityId: entity, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entity, componentType: LocalTransformComponent.self)
        scene.get(component: WorldTransformComponent.self, for: entity)?.space = matrix_identity_float4x4
        guard let component = scene.get(component: GaussianComponent.self, for: entity) else { return nil }
        copyGaussianLoadResult(result, to: component)
        return (entity, component)
    }

    /// Removes the entity's splat data at once — `destroyAllEntities` alone leaves a paged
    /// entity's pool in the registry until a frame finalizes, and the next paged load would be
    /// sized against what that pool left of the budget.
    private func removeEntity(_ entity: EntityID) {
        removeEntityGaussian(entityId: entity)
        destroyAllEntities()
    }

    /// The oblique view the budget test's partial-view case uses too (GaussianRenderTestSupport).
    private func placeCameraSeeing(target: Double, index: UntoldGSIndex) -> (fraction: Double, eye: simd_float3) {
        placeGaussianCameraSeeing(target: target, index: index)
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
        let density = workingSet.lastDensityHistogram
        let fill = density.grant == 0 ? 1 : Double(state.quotaSplats) / Double(density.grant)
        let line = "\(label): frame gpu \(summary(measured.map(\.gpuMs))) frames; cull-only gpu \(summary(Array(cullOnly.dropFirst(warmup)))) buffers; visible splats \(last.visibleSplats), visible chunks \(last.visibleChunks); entity \(gaussianFormatBytes(component.estimatedGPUBytes)), shared set \(gaussianFormatBytes(workingSet.residentBytes)) (capacity \(workingSet.capacity)), total \(gaussianFormatBytes(component.estimatedGPUBytes + workingSet.residentBytes)); budget \(state.budget) requested \(state.requestedSplats) quota \(state.quotaSplats) scale \(String(format: "%.3f", state.scale)) density \(String(format: "%.4g", Double(state.densityCap))) fill \(String(format: "%.3f", fill)) visibleChunks \(density.visibleChunks)"
        print("[GaussianChunkCullBenchmark] \(line)")
        return line
    }

    /// One configuration on one asset: add the entity, converge the budget scale, measure, and
    /// keep one rendered splat layer for the quality comparison.
    private func bench(_ label: String, result: GaussianLoadResult, index: UntoldGSIndex, frames: Int, warmup: Int) -> (line: String, visibleSplats: Int, image: [Float16], gpuMs: Double)? {
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        _ = placeCameraSeeing(target: 0.30, index: index)
        guard let (entity, component) = addEntity(result) else { return nil }
        defer { removeEntity(entity) }
        let samples = measure(frames: frames + warmup, component: component)
        let cullOnly = measureCullOnly(frames: frames + warmup)
        let image = renderGaussianSplatLayer()
        let measured = samples.dropFirst(warmup).map(\.gpuMs).sorted()
        return (report(label, samples, cullOnly: cullOnly, warmup: warmup, component: component), samples.last?.visibleSplats ?? 0, image, measured.isEmpty ? 0 : measured[measured.count / 2])
    }

    /// The paged configuration: the asset loaded from the file into a pool of `poolBytes`,
    /// warmed until no read is pending for five frames (at most 300), then measured like the
    /// others; the line carries the pool, the pages, the reads and evictions per frame and the
    /// pager's worst tick.
    private func benchPaged(_ label: String, url: URL, index: UntoldGSIndex, poolBytes: Int, frames: Int, warmup: Int) throws -> (line: String, visibleSplats: Int, image: [Float16], fineBytes: Int)? {
        GaussianPagingPolicy.pagingThresholdBytesOverride = 0
        GaussianPagingPolicy.residencyBudgetBytesOverride = poolBytes
        defer {
            GaussianPagingPolicy.pagingThresholdBytesOverride = nil
            GaussianPagingPolicy.residencyBudgetBytesOverride = nil
        }
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        _ = placeCameraSeeing(target: 0.30, index: index)
        let loaded = try GaussianChunkLoader.load(url: url, allowPaging: true)
        let pager = try XCTUnwrap(loaded.pager, "the asset pages into its pool")
        let result = try XCTUnwrap(buildGaussianLoadResult(
            packedSplatBuffer: loaded.packedSplatBuffer,
            splatCount: UInt(loaded.splatCount),
            sphericalHarmonicsBuffer: loaded.sphericalHarmonicsBuffer,
            sphericalHarmonicsMetadata: loaded.sphericalHarmonicsMetadata,
            boundingBox: loaded.boundingBox,
            chunkTable: loaded.chunkTable,
            pager: pager
        ))
        guard let (entity, component) = addEntity(result) else { return nil }
        defer { removeEntity(entity) }

        var framesToWarm = 0
        var quietFrames = 0
        var worstTickMs: Double = 0
        var issued = 0
        var committed = 0
        var evicted = 0
        var deferredMax = 0
        let slotBytes = pager.ranksPerPage * (UntoldGSFormat.coreRecordSize + index.header.shBytesPerSplat)
        while quietFrames < 5, framesToWarm < 300 {
            let start = CACurrentMediaTime()
            renderer.draw(in: renderer.metalView)
            worstTickMs = max(worstTickMs, (CACurrentMediaTime() - start) * 1000)
            renderInfo.lastCommandBuffer?.waitUntilCompleted()
            framesToWarm += 1
            let stats = pager.stats
            issued += stats.issuedThisTick
            committed += stats.committedThisTick
            evicted += stats.evictedThisTick
            deferredMax = max(deferredMax, stats.deferredTiers)
            // Quiet: nothing pending, nothing issued, and no landed tier left for the next tick.
            quietFrames = stats.pendingReads == 0 && stats.issuedThisTick == 0 && stats.deferredTiers == 0 ? quietFrames + 1 : 0
        }
        let samples = measure(frames: frames + warmup, component: component)
        let cullOnly = measureCullOnly(frames: frames + warmup)
        let image = renderGaussianSplatLayer()
        let stats = pager.stats
        let perFrame = Double(max(1, framesToWarm))
        let coarse = stats.coarseLevels == 0 ? "" : String(format: " coarseLevels=%d coarseBytes=%@ coarsePieces=%d", stats.coarseLevels, gaussianFormatBytes(stats.coarseBytesLanded), stats.coarseReadsIssued)
        let line = report(label, samples, cullOnly: cullOnly, warmup: warmup, component: component)
            + String(format: " pool=%@ pages=%d/%d framesToWarm=%d issued/frame=%.1f committed/frame=%.1f evicted/frame=%.1f commitCap=%d commitBudget=%@ deferred(max)=%d tickMs(max)=%.2f saturated=%d faults=%d%@",
                     gaussianFormatBytes(stats.poolBytes), stats.residentSlots, stats.slotCount, framesToWarm,
                     Double(issued) / perFrame, Double(committed) / perFrame, Double(evicted) / perFrame,
                     GaussianPagingPolicy.maxCommitsPerTick, GaussianPagingPolicy.commitBudget.isFinite ? String(format: "%.2fms", GaussianPagingPolicy.commitBudget * 1000) : "inf", deferredMax,
                     worstTickMs, stats.saturatedCandidates, stats.faultedChunks, coarse)
        print("[GaussianChunkCullBenchmark] \(line)")
        return (line, samples.last?.visibleSplats ?? 0, image, issued * slotBytes)
    }

    /// The two halves of a splat layer: the bottom half (the near content of the oblique view,
    /// the camera looking down at the slab) and the top half (the far content).
    private func halves(_ image: [Float16]) -> (near: [Float16], far: [Float16]) {
        let texture = renderInfo.gaussianRenderPassDescriptor.colorAttachments[0].texture!
        let rowStride = texture.width * 4
        let split = (texture.height / 2) * rowStride
        return (Array(image[split...]), Array(image[..<split]))
    }

    /// PSNR of `image` against `reference` over the near and far halves.
    private func psnrByHalf(_ image: [Float16], reference: [Float16]) -> (near: Float, far: Float) {
        let a = halves(image)
        let b = halves(reference)
        return (compareGaussianSplatLayers(a.near, b.near).psnr, compareGaussianSplatLayers(a.far, b.far).psnr)
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
            var reference: [Float16] = []
            if let unlimited = bench("\(prefix) chunk cull + fused pass, budget unlimited", result: chunked, index: loaded.index, frames: frames, warmup: warmup) {
                lines.append(unlimited.line)
                visibleUnlimited = unlimited.visibleSplats
                reference = unlimited.image
            }

            // Budget at a quarter of what the camera sees: the screen-weighted quotas, then the
            // uniform rule, each compared with the unlimited frame over the near and far halves.
            let quarter = max(1, visibleUnlimited / 4)
            GaussianRuntimeLimits.workingSetSplatsOverride = quarter
            GaussianDebugOptions.shared.disableScreenWeightedQuotas = false
            var weightedQuality: (near: Float, far: Float)?
            if let weighted = bench("\(prefix) chunk cull + fused pass, budget \(quarter) (25 %% of the visible count), screen-weighted quotas", result: chunked, index: loaded.index, frames: frames, warmup: warmup) {
                lines.append(weighted.line)
                weightedQuality = psnrByHalf(weighted.image, reference: reference)
            }
            GaussianDebugOptions.shared.disableScreenWeightedQuotas = true
            var uniformQuality: (near: Float, far: Float)?
            if let uniform = bench("\(prefix) chunk cull + fused pass, budget \(quarter) (25 %% of the visible count), uniform quotas", result: chunked, index: loaded.index, frames: frames, warmup: warmup) {
                lines.append(uniform.line)
                uniformQuality = psnrByHalf(uniform.image, reference: reference)
            }
            GaussianDebugOptions.shared.disableScreenWeightedQuotas = false

            // Paged from the file into a quarter of the asset, budget unlimited; then into a pool
            // that holds every tier, whose near half must be the unlimited frame's.
            GaussianRuntimeLimits.workingSetSplatsOverride = splatCount
            let assetBytes = GaussianPagingPolicy.assetBytes(splatCount: loaded.splatCount, shBytesPerSplat: loaded.index.header.shBytesPerSplat)
            if let paged = try benchPaged("\(prefix) chunk cull + fused pass, paged (pool = 25 %% of the asset), budget unlimited", url: url, index: loaded.index, poolBytes: assetBytes / 4, frames: frames, warmup: warmup) {
                lines.append(paged.line)
                let quality = psnrByHalf(paged.image, reference: reference)
                print(String(format: "[GaussianChunkCullBenchmark] %@ PSNR vs unlimited, paged at a quarter pool — near half %.2f dB, far half %.2f dB", prefix, quality.near, quality.far))
            }
            if let whole = try benchPaged("\(prefix) chunk cull + fused pass, paged (pool = the asset), budget unlimited", url: url, index: loaded.index, poolBytes: assetBytes, frames: frames, warmup: warmup) {
                let quality = psnrByHalf(whole.image, reference: reference)
                print(String(format: "[GaussianChunkCullBenchmark] %@ PSNR vs unlimited, paged at a whole pool — near half %.2f dB, far half %.2f dB", prefix, quality.near, quality.far))
                XCTAssertGreaterThanOrEqual(quality.near, 45, "a pool that holds every wanted tier draws the unlimited frame's near half")
            }
            if let weightedQuality, let uniformQuality {
                print(String(format: "[GaussianChunkCullBenchmark] %@ PSNR vs unlimited at a quarter budget — near half: weighted %.2f dB, uniform %.2f dB; far half: weighted %.2f dB, uniform %.2f dB",
                             prefix, weightedQuality.near, uniformQuality.near, weightedQuality.far, uniformQuality.far))
                // The weighting spends the budget on the near content: its near half is never
                // worse than the uniform rule's beyond the sort's ties. The far half is where it
                // spends less; logged, not asserted.
                XCTAssertGreaterThanOrEqual(weightedQuality.near, uniformQuality.near - 0.25, "the weighted quotas keep the near half at least as well as the uniform rule")
            }

            // Per-chunk LOD (per-chunk-lod-tiers): the same slab with its coarse levels baked, at
            // the quarter budget with the levels on (.auto) and off (.fineOnly, the fine prefix),
            // each against the unlimited fine reference over the two halves — the far half is
            // where the levels replace the prefix — and their whole-frame GPU time; then paged
            // into a quarter of the asset in both modes with the pool's residency and the reads.
            let levelledURL = try syntheticAssetURL(splatCount: splatCount, coarseLevels: .default)
            let levelledLoaded = try GaussianChunkLoader.load(url: levelledURL)
            let levelledCoarse = try XCTUnwrap(levelledLoaded.chunkTable.coarse, "the levelled bake carries both levels beside a whole load")
            let levelledChunked = try XCTUnwrap(buildGaussianLoadResult(
                packedSplatBuffer: levelledLoaded.packedSplatBuffer,
                splatCount: UInt(levelledLoaded.splatCount),
                sphericalHarmonicsBuffer: levelledLoaded.sphericalHarmonicsBuffer,
                sphericalHarmonicsMetadata: levelledLoaded.sphericalHarmonicsMetadata,
                boundingBox: levelledLoaded.boundingBox,
                chunkTable: levelledLoaded.chunkTable
            ))
            print(String(format: "[GaussianChunkCullBenchmark] %@ coarse levels: %d resident (%@ of records), ratios %@",
                         prefix, levelledCoarse.levelCount, gaussianFormatBytes(levelledCoarse.recordBytes), levelledCoarse.ratioLog2.map(String.init).joined(separator: ",")))
            GaussianRuntimeLimits.workingSetSplatsOverride = quarter
            var levelsQuality: (near: Float, far: Float)?
            var levelsGPU: Double?
            GaussianDebugOptions.shared.gaussianLevelMode = .auto
            if let levels = bench("\(prefix) per-chunk LOD, budget \(quarter) (25 %% of the visible count), levels on", result: levelledChunked, index: levelledLoaded.index, frames: frames + 20, warmup: warmup + 20) {
                lines.append(levels.line)
                levelsQuality = psnrByHalf(levels.image, reference: reference)
                levelsGPU = levels.gpuMs
            }
            GaussianDebugOptions.shared.gaussianLevelMode = .fineOnly
            var prefixQuality: (near: Float, far: Float)?
            var prefixGPU: Double?
            if let fine = bench("\(prefix) per-chunk LOD, budget \(quarter) (25 %% of the visible count), fine only", result: levelledChunked, index: levelledLoaded.index, frames: frames, warmup: warmup) {
                lines.append(fine.line)
                prefixQuality = psnrByHalf(fine.image, reference: reference)
                prefixGPU = fine.gpuMs
            }
            if let levelsQuality, let prefixQuality, let levelsGPU, let prefixGPU {
                print(String(format: "[GaussianChunkCullBenchmark] %@ PSNR vs unlimited at a quarter budget — near half: levels %.2f dB, fine only %.2f dB; far half: levels %.2f dB, fine only %.2f dB; frame gpu median levels %.3f ms, fine only %.3f ms",
                             prefix, levelsQuality.near, prefixQuality.near, levelsQuality.far, prefixQuality.far, levelsGPU, prefixGPU))
                XCTAssertGreaterThanOrEqual(levelsQuality.far, prefixQuality.far - 0.25, "the levels draw the far half at least as well as the fine prefix")
            }
            GaussianRuntimeLimits.workingSetSplatsOverride = splatCount
            var pagedFineBytes: (levels: Int, fine: Int) = (0, 0)
            GaussianDebugOptions.shared.gaussianLevelMode = .auto
            if let paged = try benchPaged("\(prefix) per-chunk LOD, paged (pool = 25 %% of the asset), budget unlimited, levels on", url: levelledURL, index: levelledLoaded.index, poolBytes: assetBytes / 4, frames: frames, warmup: warmup) {
                lines.append(paged.line)
                pagedFineBytes.levels = paged.fineBytes
                let quality = psnrByHalf(paged.image, reference: reference)
                print(String(format: "[GaussianChunkCullBenchmark] %@ PSNR vs unlimited, paged at a quarter pool with levels — near half %.2f dB, far half %.2f dB", prefix, quality.near, quality.far))
            }
            GaussianDebugOptions.shared.gaussianLevelMode = .fineOnly
            if let paged = try benchPaged("\(prefix) per-chunk LOD, paged (pool = 25 %% of the asset), budget unlimited, fine only", url: levelledURL, index: levelledLoaded.index, poolBytes: assetBytes / 4, frames: frames, warmup: warmup) {
                lines.append(paged.line)
                pagedFineBytes.fine = paged.fineBytes
            }
            GaussianDebugOptions.shared.gaussianLevelMode = .auto
            print(String(format: "[GaussianChunkCullBenchmark] %@ paged fine bytes read to warm — levels %@, fine only %@", prefix, gaussianFormatBytes(pagedFineBytes.levels), gaussianFormatBytes(pagedFineBytes.fine)))
            XCTAssertLessThanOrEqual(pagedFineBytes.levels, pagedFineBytes.fine, "with the levels on the pager reads no more fine bytes than without")
            GaussianRuntimeLimits.workingSetSplatsOverride = nil
        }

        XCTAssertEqual(lines.count, splatCounts.count * 10)
    }
}

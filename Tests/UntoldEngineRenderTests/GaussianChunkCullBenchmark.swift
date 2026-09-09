//
//  GaussianChunkCullBenchmark.swift
//  UntoldEngine
//
//  Informational timing of the chunk-level cull on a synthetic million-splat asset: the whole
//  frame's command-buffer GPU time (renderInfo.lastCommandBuffer gpuStartTime/gpuEndTime) with
//  the per-splat cull over the whole buffer (legacy, no chunk table), through the chunk path
//  with every chunk forced visible (disableChunkCull), and through the chunk path proper, at a
//  camera that sees about 30 % of the asset. Skipped unless UNTOLD_PERF_GAUSSIAN_CHUNK_CULL=1:
//  the bake takes seconds and the numbers are machine-specific, so this is a tool, not a gate.
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

    override func setUp() async throws {
        try await super.setUp()
        savedDisableChunkCull = GaussianDebugOptions.shared.disableChunkCull
        savedDisableHZBOcclusionCull = GaussianDebugOptions.shared.disableHZBOcclusionCull
    }

    override func tearDown() async throws {
        GaussianDebugOptions.shared.disableChunkCull = savedDisableChunkCull
        GaussianDebugOptions.shared.disableHZBOcclusionCull = savedDisableHZBOcclusionCull
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    private func intEnv(_ name: String, default defaultValue: Int) -> Int {
        guard let raw = ProcessInfo.processInfo.environment[name], let value = Int(raw), value > 0 else { return defaultValue }
        return value
    }

    // MARK: - Synthetic asset

    /// Deterministic generator: splats spread over a 12 × 0.6 × 12 slab (a captured floor) so a
    /// camera near one corner sees a fraction of the chunks, scales exp(U[−4.5, −2.5]) and
    /// opacities U[0.2, 1].
    private struct SplitMix64 {
        private var state: UInt64
        init(seed: UInt64) {
            state = seed
        }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }

        mutating func unit() -> Float {
            Float(next() >> 40) / Float(1 << 24)
        }

        mutating func value(in range: ClosedRange<Float>) -> Float {
            range.lowerBound + unit() * (range.upperBound - range.lowerBound)
        }
    }

    private static let slabMin = simd_float3(-6, -0.3, -6)
    private static let slabMax = simd_float3(6, 0.3, 6)

    private func syntheticAssetURL(splatCount: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianChunkCullBenchmark-\(splatCount)-v1")
            .appendingPathExtension("untoldgs")
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        var generator = SplitMix64(seed: 0x5EED_CAFE)
        var splats: [UntoldGSSplat] = []
        splats.reserveCapacity(splatCount)
        for _ in 0 ..< splatCount {
            let t = simd_float3(generator.unit(), generator.unit(), generator.unit())
            let scale = simd_float3(exp(generator.value(in: -4.5 ... -2.5)), exp(generator.value(in: -4.5 ... -2.5)), exp(generator.value(in: -4.5 ... -2.5)))
            let q = simd_normalize(simd_float4(generator.value(in: -1 ... 1), generator.value(in: -1 ... 1), generator.value(in: -1 ... 1), generator.value(in: -1 ... 1)))
            splats.append(UntoldGSSplat(
                position: Self.slabMin + t * (Self.slabMax - Self.slabMin),
                scale: scale,
                rotation: simd_quatf(vector: q),
                color: simd_float3(generator.unit(), generator.unit(), generator.unit()),
                opacity: generator.value(in: 0.2 ... 1),
                sphericalHarmonics: []
            ))
        }
        var options = UntoldGSWriteOptions()
        options.log2ChunkSplats = 10
        let start = CFAbsoluteTimeGetCurrent()
        try UntoldGSFormat.write(splats: splats, options: options, to: url)
        print("[GaussianChunkCullBenchmark] baked \(splatCount) splats in \(String(format: "%.1f", CFAbsoluteTimeGetCurrent() - start)) s -> \(url.path)")
        return url
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

    private func report(_ label: String, _ samples: [FrameSample], cullOnly: [Double], warmup: Int) -> String {
        let measured = Array(samples.dropFirst(warmup))
        guard let last = measured.last else { return "\(label): no samples" }
        let line = "\(label): frame gpu \(summary(measured.map(\.gpuMs))) frames; cull-only gpu \(summary(Array(cullOnly.dropFirst(warmup)))) buffers; visible splats \(last.visibleSplats), visible chunks \(last.visibleChunks)"
        print("[GaussianChunkCullBenchmark] \(line)")
        return line
    }

    // MARK: - Bench

    func testChunkCullFrameTime() throws {
        guard ProcessInfo.processInfo.environment["UNTOLD_PERF_GAUSSIAN_CHUNK_CULL"] == "1" else {
            throw XCTSkip("Set UNTOLD_PERF_GAUSSIAN_CHUNK_CULL=1 to run the chunk-cull benchmark")
        }
        guard renderer != nil else { throw XCTSkip("Renderer not initialized") }
        let splatCount = intEnv("UNTOLD_PERF_SPLAT_COUNT", default: 1_000_000)
        let frames = intEnv("UNTOLD_PERF_GAUSSIAN_FRAMES", default: 30)
        let warmup = intEnv("UNTOLD_PERF_WARMUP_FRAMES", default: 5)
        GaussianDebugOptions.shared.disableHZBOcclusionCull = false

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

        var lines: [String] = []

        GaussianDebugOptions.shared.disableChunkCull = false
        if let component = addEntity(legacy) {
            lines.append(report("legacy per-splat cull (no chunk table)", measure(frames: frames + warmup, component: component), cullOnly: measureCullOnly(frames: frames + warmup), warmup: warmup))
        }
        destroyAllEntities()

        GaussianDebugOptions.shared.disableChunkCull = true
        _ = placeCameraSeeing(target: 0.30, index: loaded.index)
        if let component = addEntity(chunked) {
            lines.append(report("chunk path, every chunk forced visible", measure(frames: frames + warmup, component: component), cullOnly: measureCullOnly(frames: frames + warmup), warmup: warmup))
        }
        destroyAllEntities()

        GaussianDebugOptions.shared.disableChunkCull = false
        _ = placeCameraSeeing(target: 0.30, index: loaded.index)
        if let component = addEntity(chunked) {
            lines.append(report("chunk cull", measure(frames: frames + warmup, component: component), cullOnly: measureCullOnly(frames: frames + warmup), warmup: warmup))
        }

        XCTAssertEqual(lines.count, 3)
    }
}

//
//  GaussianRenderTestSupport.swift
//  UntoldEngine
//
//  Shared readback and comparison helpers for the Gaussian render tests: render one frame and
//  read the splat layer, compare two layers over the pixels they cover, read the shared
//  working set's count, the budget state, the density histogram and an entity's visible-chunk
//  list, assert that a frame fits its budget, drive the chunk cull by hand.
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

/// PSNR over the covered pixels and the number of pixels where any channel differs by more
/// than one 8-bit step.
struct GaussianLayerComparison {
    let psnr: Float
    let differingPixels: Int
    let covered: Int
}

extension BaseRenderSetup {
    /// Renders one frame, waits for its command buffer, and returns the splat layer
    /// (premultiplied colour and alpha, rgba16Float).
    func renderGaussianSplatLayer() -> [Float16] {
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()
        let texture = renderInfo.gaussianRenderPassDescriptor.colorAttachments[0].texture!
        var pixels = [Float16](repeating: 0, count: texture.width * texture.height * 4)
        texture.getBytes(&pixels, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        return pixels
    }

    /// Compares two splat layers over the pixels either of them covers. The old entity-order
    /// blending measured about 56 dB over the whole (mostly empty) frame on the test asset, so
    /// bounds on this measure have to be far tighter than that.
    func compareGaussianSplatLayers(_ a: [Float16], _ b: [Float16]) -> GaussianLayerComparison {
        var sum: Double = 0
        var covered = 0
        var differing = 0
        for i in stride(from: 0, to: min(a.count, b.count), by: 4) {
            guard Float(a[i + 3]) > 0.001 || Float(b[i + 3]) > 0.001 else { continue }
            covered += 1
            var maxDelta: Float = 0
            for c in 0 ..< 4 {
                let d = Float(a[i + c]) - Float(b[i + c])
                sum += Double(d * d)
                maxDelta = max(maxDelta, abs(d))
            }
            if maxDelta > 1.0 / 255.0 {
                differing += 1
            }
        }
        let mse = covered == 0 ? 0 : sum / Double(covered * 4)
        return GaussianLayerComparison(psnr: mse == 0 ? .infinity : Float(10 * log10(1 / mse)), differingPixels: differing, covered: covered)
    }

    /// The shared working set's visible count for the current in-flight slot.
    func sharedGaussianVisibleCount() -> Int {
        let slot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
        return Int(GaussianSharedWorkingSet.shared.visibleSet(slot: slot)!.contents().load(as: GaussianVisibleSet.self).visibleCount)
    }

    /// A camera entity looking from `eye` at `target`, made the active camera.
    @discardableResult
    func placeGaussianTestCamera(eye: simd_float3, target: simd_float3 = .zero, up: simd_float3 = simd_float3(0, 1, 0)) -> EntityID {
        let cameraEntity = createEntity()
        if let cameraComponent = scene.assign(to: cameraEntity, component: CameraComponent.self) {
            CameraSystem.shared.activeCamera = cameraEntity
            cameraComponent.viewSpace = matrix_identity_float4x4
            cameraComponent.localPosition = .zero
        }
        cameraLookAt(entityId: cameraEntity, eye: eye, target: target, up: up)
        return cameraEntity
    }
}

// MARK: - Working-set readback

extension BaseRenderSetup {
    /// The shared working set's records for the current in-flight slot, as many as its count.
    func sharedGaussianRecords() -> [GaussianWorkingSetSplat] {
        let slot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
        guard let set = GaussianSharedWorkingSet.shared.visibleSet(slot: slot),
              let records = GaussianSharedWorkingSet.shared.records(slot: slot)
        else { return [] }
        let count = min(Int(set.contents().load(as: GaussianVisibleSet.self).visibleCount), GaussianSharedWorkingSet.shared.capacity)
        return Array(UnsafeBufferPointer(start: records.contents().bindMemory(to: GaussianWorkingSetSplat.self, capacity: count), count: count))
    }

    /// The shared set's sorted keys for the current slot, as many as its count.
    func sharedGaussianSortedKeys() -> [UInt64] {
        let slot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
        guard let set = GaussianSharedWorkingSet.shared.visibleSet(slot: slot),
              let keys = GaussianSharedWorkingSet.shared.keys(slot: slot)
        else { return [] }
        let count = min(Int(set.contents().load(as: GaussianVisibleSet.self).visibleCount), GaussianSharedWorkingSet.shared.capacity)
        return Array(UnsafeBufferPointer(start: keys.contents().bindMemory(to: UInt64.self, capacity: count), count: count))
    }

    /// Runs the frame's cull and preprocess on one command buffer and waits for it.
    func runGaussianCullAndPreprocess() {
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Expected to allocate a command buffer")
            return
        }
        executeGaussianFrustumCulling(commandBuffer)
        executeGaussianPreprocess(commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        XCTAssertEqual(commandBuffer.status, .completed)
    }

    /// Fraction of an asset's splats whose chunk's *unpadded* centre box is in view — with a
    /// uniform density a stand-in for the fraction of splats the per-splat cull keeps. (The
    /// padded boxes the chunk cull tests keep more.)
    func gaussianVisibleFraction(index: UntoldGSIndex, viewProjection: simd_float4x4) -> Double {
        let visible = index.chunks.filter {
            GaussianChunkCullMath.boxPassesClipPlanes(boxMin: $0.aabbMin, boxMax: $0.aabbMax, viewProjection: viewProjection)
        }
        let splats = visible.reduce(0) { $0 + Int($1.splatCount) }
        return Double(splats) / Double(max(1, Int(index.header.splatCount)))
    }

    /// An oblique view down onto the origin, raised until the chunk mirror keeps about `target`
    /// of the asset's splats: the higher the camera, the more of a slab its frustum covers.
    @discardableResult
    func placeGaussianCameraSeeing(target: Double, index: UntoldGSIndex) -> (fraction: Double, eye: simd_float3) {
        let camera = placeGaussianTestCamera(eye: simd_float3(0, 5, 3), target: .zero)
        var low: Float = 0.3
        var high: Float = 20
        var best: (Double, simd_float3) = (0, .zero)
        for _ in 0 ..< 24 {
            let height = 0.5 * (low + high)
            let eye = simd_float3(0, height, 0.6 * height)
            cameraLookAt(entityId: camera, eye: eye, target: .zero, up: simd_float3(0, 1, 0))
            let view = scene.get(component: CameraComponent.self, for: camera)?.viewSpace ?? matrix_identity_float4x4
            let fraction = gaussianVisibleFraction(index: index, viewProjection: simd_mul(renderInfo.perspectiveSpace, view))
            best = (fraction, eye)
            if abs(fraction - target) < 0.01 { break }
            if fraction > target { high = height } else { low = height }
        }
        return best
    }
}

// MARK: - Budget readback

extension BaseRenderSetup {
    /// The in-flight slot the manual frames run in.
    var gaussianFrameSlot: Int {
        min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
    }

    /// The published budget state of the slot the manual frames run in.
    func budgetState() throws -> GaussianBudgetState {
        try XCTUnwrap(GaussianSharedWorkingSet.shared.budgetReadback(slot: gaussianFrameSlot)).contents().load(as: GaussianBudgetState.self)
    }

    /// The published density histogram of the slot the manual frames run in.
    func densityReadback() throws -> GaussianBudgetDensityHistogram {
        try XCTUnwrap(GaussianSharedWorkingSet.shared.densityReadback(slot: gaussianFrameSlot)).contents().load(as: GaussianBudgetDensityHistogram.self)
    }

    /// The shared working set's record for the current slot.
    func sharedVisibleSet() -> GaussianVisibleSet {
        GaussianSharedWorkingSet.shared.visibleSet(slot: gaussianFrameSlot)!.contents().load(as: GaussianVisibleSet.self)
    }

    /// The frame that just ran dropped nothing: no overflow, and the set holds no more than its
    /// capacity and no more than the quotas plus the whole-buffer reservation granted, which fit
    /// the capacity — and, on a truncated frame (the request above what the reservation leaves
    /// of the budget, so the target scale is below 1), leave the headroom.
    func assertFrameFits(file: StaticString = #filePath, line: UInt = #line) throws {
        let set = sharedVisibleSet()
        let state = try budgetState()
        XCTAssertEqual(set.overflowCount, 0, "no splat was dropped by arrival order", file: file, line: line)
        XCTAssertLessThanOrEqual(Int(set.visibleCount), GaussianSharedWorkingSet.shared.capacity, file: file, line: line)
        XCTAssertLessThanOrEqual(Int(set.visibleCount), Int(state.quotaSplats) + Int(state.reservedSplats), "the appends never exceed the grant", file: file, line: line)
        XCTAssertLessThanOrEqual(Int(state.quotaSplats) + Int(state.reservedSplats), Int(state.budget), "the grant fits the capacity", file: file, line: line)
        if state.targetScale < 1 {
            XCTAssertLessThanOrEqual(Int(state.quotaSplats) + Int(state.reservedSplats), max(Int(Float(state.budget) * gaussianBudgetHeadroom), Int(state.reservedSplats)), "a truncated frame leaves the headroom", file: file, line: line)
        }
    }

    /// The visible-chunk list and record of `table` for the current slot, as the GPU left them.
    func visibleChunkEntries(_ table: GaussianChunkTable) -> (record: GaussianVisibleSet, entries: [GaussianVisibleChunk]) {
        let readback = visibleChunkReadback(table, slot: min(renderInfo.currentInFlightFrameSlot, table.visibleChunkSets.count - 1))
        return (readback.record, readback.entries)
    }

    /// The visible-chunk list and record of `table` in `slot`, as the GPU left them.
    func visibleChunkReadback(_ table: GaussianChunkTable, slot: Int) -> (chunks: Set<UInt32>, record: GaussianVisibleSet, entries: [GaussianVisibleChunk]) {
        let record = table.visibleChunkSets[slot].contents().load(as: GaussianVisibleSet.self)
        let count = Int(record.threadgroupCount)
        let entries = Array(UnsafeBufferPointer(start: table.visibleChunks[slot].contents().bindMemory(to: GaussianVisibleChunk.self, capacity: count), count: count))
        return (Set(entries.map(\.chunkIndex)), record, entries)
    }

    /// Runs the frame's cull, preprocess and sort as the renderer does, and returns the sorted
    /// keys' depth words (the low word is the append slot, which no two frames need share).
    func sortedDepthWords() -> [UInt32] {
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Expected to allocate a command buffer")
            return []
        }
        executeGaussianFrustumCulling(commandBuffer)
        executeGaussianPreprocess(commandBuffer)
        executeRadixSort(commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return sharedGaussianSortedKeys().map { UInt32(truncatingIfNeeded: $0 >> 32) }
    }
}

// MARK: - The chunk cull by hand

extension BaseRenderSetup {
    func runSynchronously(_ encode: (MTLCommandBuffer) -> Void) {
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Expected to allocate a command buffer")
            return
        }
        encode(commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        XCTAssertEqual(commandBuffer.status, .completed)
    }

    /// The frame's persistent budget state, allocated with the shared set.
    func budgetStateBuffer() throws -> MTLBuffer {
        XCTAssertTrue(GaussianSharedWorkingSet.shared.ensureCapacity(1, device: renderInfo.device))
        return try XCTUnwrap(GaussianSharedWorkingSet.shared.budgetState)
    }

    /// The frame's persistent density histogram, allocated with the shared set.
    func densityHistogramBuffer() throws -> MTLBuffer {
        XCTAssertTrue(GaussianSharedWorkingSet.shared.ensureCapacity(1, device: renderInfo.device))
        return try XCTUnwrap(GaussianSharedWorkingSet.shared.densityHistogram)
    }

    /// Encodes one chunk cull of `table` into slot 0 with `constants` — after zeroing the
    /// persistent histogram, so it holds this cull alone — and returns the record.
    func cullChunks(_ table: GaussianChunkTable, constants: GaussianChunkCullConstants) throws -> (chunks: Set<UInt32>, record: GaussianVisibleSet, entries: [GaussianVisibleChunk]) {
        let pipelines = try XCTUnwrap(GaussianChunkCullPipelineStates.current())
        let budgetState = try budgetStateBuffer()
        let densityHistogram = try densityHistogramBuffer()
        densityHistogram.contents().storeBytes(of: GaussianBudgetDensityHistogram(), as: GaussianBudgetDensityHistogram.self)
        runSynchronously { commandBuffer in
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
            _ = encodeGaussianChunkCull(
                encoder,
                pipelines: pipelines,
                chunkTable: table,
                visibleChunks: table.visibleChunks[0],
                chunkSet: table.visibleChunkSets[0],
                budgetState: budgetState,
                densityHistogram: densityHistogram,
                constants: constants,
                hzbTexture: textureResources.hzbDepthPyramid ?? textureResources.depthMap
            )
            encoder.endEncoding()
        }
        return visibleChunkReadback(table, slot: 0)
    }

    /// The frame's cull constants for `entity` with the two eye matrices replaced.
    func stereoConstants(table: GaussianChunkTable, entity: EntityID, eye0: simd_float4x4, eye1: simd_float4x4, hzbValid: Bool = false) throws -> GaussianChunkCullConstants {
        let world = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: entity))
        var constants = gaussianChunkCullConstants(chunkTable: table, modelMatrix: world.space, viewMatrix: matrix_identity_float4x4, hzbValid: hzbValid, forceAllVisible: false, uniformQuotas: false)
        constants.viewProjection0 = eye0
        constants.viewProjection1 = eye1
        constants.viewCount = 2
        return constants
    }

    /// The view-projection of a camera at `eye` looking at `target` for `entity`, from a
    /// temporary camera entity so the active camera does not move.
    func viewProjection(entity: EntityID, eye: simd_float3, target: simd_float3) throws -> simd_float4x4 {
        let world = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: entity))
        let cameraEntity = createEntity()
        defer { destroyEntity(entityId: cameraEntity) }
        _ = scene.assign(to: cameraEntity, component: CameraComponent.self)
        cameraLookAt(entityId: cameraEntity, eye: eye, target: target, up: simd_float3(0, 1, 0))
        let view = try XCTUnwrap(scene.get(component: CameraComponent.self, for: cameraEntity)).viewSpace
        return simd_mul(renderInfo.perspectiveSpace, simd_mul(view, world.space))
    }

    /// A one-row depth texture whose texels span the screen from left to right, one mip level:
    /// with clamp_to_edge and nearest sampling every UV reads the texel of its horizontal band,
    /// so one texel stands in for a full-frame occluder and two for a half-covered frame.
    func makeHZBTestTexture(depths: [Float]) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: depths.count, height: 1, mipmapped: false)
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        let texture = try XCTUnwrap(renderInfo.device.makeTexture(descriptor: descriptor))
        depths.withUnsafeBytes { bytes in
            texture.replace(region: MTLRegionMake2D(0, 0, depths.count, 1), mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: depths.count * MemoryLayout<Float>.stride)
        }
        return texture
    }

    /// Runs `body` with `depths` installed as the frame's HZB pyramid (one mip, so the chunk
    /// test samples level 0 like the per-splat test) and `hzbIsValid` set to `valid`, then
    /// restores the real pyramid.
    func withInjectedHZB<T>(depths: [Float], valid: Bool, _ body: () throws -> T) throws -> T {
        let savedTexture = textureResources.hzbDepthPyramid
        let savedValid = renderInfo.hzbIsValid
        let savedMipCount = renderInfo.hzbMipCount
        defer {
            textureResources.hzbDepthPyramid = savedTexture
            renderInfo.hzbIsValid = savedValid
            renderInfo.hzbMipCount = savedMipCount
        }
        textureResources.hzbDepthPyramid = try makeHZBTestTexture(depths: depths)
        renderInfo.hzbIsValid = valid
        renderInfo.hzbMipCount = 1
        return try body()
    }
}

/// Recovers which splat of an asset each working-set record came from by its entity-local
/// centre: the fused pass and the whole-buffer path decode the same quantised position, so a
/// record's `position` lies within float round-off of exactly one CPU-decoded position (the
/// fixture has no coincident centres).
struct GaussianSplatIndexResolver {
    let positions: [simd_float3]
    private var cells: [SIMD3<Int32>: [Int]] = [:]
    private let cellSize: Float

    init(positions: [simd_float3]) {
        self.positions = positions
        var boundsMin = simd_float3(repeating: .infinity)
        var boundsMax = simd_float3(repeating: -.infinity)
        for position in positions {
            boundsMin = simd_min(boundsMin, position)
            boundsMax = simd_max(boundsMax, position)
        }
        let extent = positions.isEmpty ? 1 : max(simd_reduce_max(boundsMax - boundsMin), 1e-3)
        cellSize = extent / 64
        for (index, position) in positions.enumerated() {
            cells[cell(of: position), default: []].append(index)
        }
    }

    private func cell(of position: simd_float3) -> SIMD3<Int32> {
        SIMD3<Int32>(Int32((position.x / cellSize).rounded(.down)), Int32((position.y / cellSize).rounded(.down)), Int32((position.z / cellSize).rounded(.down)))
    }

    /// The nearest asset splat to `position`, or nil when none lies within `tolerance`.
    func index(of position: simd_float3, tolerance: Float = 1e-4) -> Int? {
        let center = cell(of: position)
        var best: (index: Int, distance: Float)?
        for dx in -1 ... 1 {
            for dy in -1 ... 1 {
                for dz in -1 ... 1 {
                    let key = center &+ SIMD3<Int32>(Int32(dx), Int32(dy), Int32(dz))
                    for candidate in cells[key] ?? [] {
                        let distance = simd_distance(positions[candidate], position)
                        if best == nil || distance < best!.distance {
                            best = (candidate, distance)
                        }
                    }
                }
            }
        }
        guard let best, best.distance <= tolerance else { return nil }
        return best.index
    }

    /// The asset indices of `records`, in record order; fails the test for any record that
    /// matches no splat.
    func indices(of records: [GaussianWorkingSetSplat], file: StaticString = #filePath, line: UInt = #line) -> [UInt32] {
        var result: [UInt32] = []
        result.reserveCapacity(records.count)
        var unmatched = 0
        for record in records {
            if let index = index(of: record.position) {
                result.append(UInt32(index))
            } else {
                unmatched += 1
            }
        }
        XCTAssertEqual(unmatched, 0, "\(unmatched) working-set records match no splat of the asset", file: file, line: line)
        return result
    }
}

/// A whole-buffer (legacy) twin of a chunked load: the same records expanded once into
/// `EncodedGaussianSplat` by `gaussianDecodeChunks`, with the per-slot index buffers a `.ply`
/// carries — the path every `.ply` runs, an oracle that never executes the per-chunk kernels.
struct GaussianLegacyTwin {
    let result: GaussianLoadResult

    init(loaded: GaussianChunkLoadResult) throws {
        let encoded = try GaussianChunkLoader.decodeEncodedSplats(loaded)
        result = try XCTUnwrap(buildGaussianLoadResult(
            encodedSplatBuffer: encoded,
            splatCount: UInt(loaded.splatCount),
            sphericalHarmonicsBuffer: loaded.sphericalHarmonicsBuffer,
            sphericalHarmonicsMetadata: loaded.sphericalHarmonicsMetadata,
            boundingBox: loaded.boundingBox
        ))
    }

    /// Runs `body` with `component` swapped onto the whole-buffer path over this twin's buffers,
    /// then puts its chunk table and packed records back.
    func withLegacyBuffers<T>(_ component: GaussianComponent, _ body: () throws -> T) rethrows -> T {
        let table = component.chunkTable
        let packed = component.packedSplatData
        component.chunkTable = nil
        component.packedSplatData = nil
        component.encodedSplatData = result.encodedSplatBuffer
        component.gaussianVisibleIndices = result.gaussianVisibleIndices.map { $0 as MTLBuffer? }
        component.gaussianVisibleCount = result.gaussianVisibleCount.map { $0 as MTLBuffer? }
        defer {
            component.encodedSplatData = nil
            component.gaussianVisibleIndices = []
            component.gaussianVisibleCount = []
            component.chunkTable = table
            component.packedSplatData = packed
        }
        return try body()
    }
}

// MARK: - Synthetic assets

/// Deterministic `.untoldgs` assets for the budget tests and the benchmark. The slabs: splats
/// spread over a 12 × 0.6 × 12 slab (a captured floor) so a camera near one corner sees a
/// fraction of the chunks, scales exp(U[−4.5, −2.5]) and opacities U[0.2, 1], 1024 splats per
/// chunk, baked once per process into the temporary directory and reused. The harmonics asset:
/// a small cloud over the 200-splat fixture's region with distinct per-splat degree-1
/// coefficients, for the spherical-harmonics-by-index oracle.
enum GaussianSyntheticAsset {
    struct SplitMix64 {
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

    static let slabMin = simd_float3(-6, -0.3, -6)
    static let slabMax = simd_float3(6, 0.3, 6)

    static func url(splatCount: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianSyntheticAsset-\(splatCount)-v1")
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
                position: slabMin + t * (slabMax - slabMin),
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
        print("[GaussianSyntheticAsset] baked \(splatCount) splats in \(String(format: "%.1f", CFAbsoluteTimeGetCurrent() - start)) s -> \(url.path)")
        return url
    }

    /// `splatCount` splats over x, y in ±1.4 and z in 0…0.5 (where GaussianChunkCullTest's three
    /// cameras look), `degree`-order harmonics whose coefficients differ splat by splat, chunks
    /// of 2^`log2ChunkSplats`. A fresh file at `url`; the caller removes it.
    static func writeHarmonicsAsset(splatCount: Int, degree: UInt8, log2ChunkSplats: UInt8, to url: URL) throws {
        var generator = SplitMix64(seed: 0x5EED_0005_4000)
        let coefficientCount = UntoldGSFormat.shCoefficientCount(degree: degree)
        var splats: [UntoldGSSplat] = []
        splats.reserveCapacity(splatCount)
        for index in 0 ..< splatCount {
            let q = simd_normalize(simd_float4(generator.value(in: -1 ... 1), generator.value(in: -1 ... 1), generator.value(in: -1 ... 1), generator.value(in: -1 ... 1)))
            // Distinct per splat and per coefficient, small enough that the colour stays in range.
            let harmonics = (0 ..< coefficientCount).map { k in
                0.15 * sin(Float(index) * 0.731 + Float(k) * 1.37) * (k % 2 == 0 ? 1 : -1)
            }
            splats.append(UntoldGSSplat(
                position: simd_float3(generator.value(in: -1.4 ... 1.4), generator.value(in: -1.4 ... 1.4), generator.value(in: 0 ... 0.5)),
                scale: simd_float3(exp(generator.value(in: -3 ... -1.5)), exp(generator.value(in: -3 ... -1.5)), exp(generator.value(in: -3 ... -1.5))),
                rotation: simd_quatf(vector: q),
                color: simd_float3(generator.value(in: 0.3 ... 0.7), generator.value(in: 0.3 ... 0.7), generator.value(in: 0.3 ... 0.7)),
                opacity: generator.value(in: 0.5 ... 1),
                sphericalHarmonics: harmonics
            ))
        }
        var options = UntoldGSWriteOptions()
        options.log2ChunkSplats = log2ChunkSplats
        options.shDegree = degree
        try UntoldGSFormat.write(splats: splats, options: options, to: url)
    }
}

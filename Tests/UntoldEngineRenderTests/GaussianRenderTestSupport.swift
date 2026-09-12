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

    /// The visible-chunk list and record of `table` in `slot`, as the GPU left them. `chunks` is
    /// the set of chunk indices with the level tag bits masked off (per-chunk-lod-tiers); an
    /// entity without coarse levels writes no tag bits, which is asserted here so a section-free
    /// frame is pinned to the entries of before.
    func visibleChunkReadback(_ table: GaussianChunkTable, slot: Int, file: StaticString = #filePath, line: UInt = #line) -> (chunks: Set<UInt32>, record: GaussianVisibleSet, entries: [GaussianVisibleChunk]) {
        let record = table.visibleChunkSets[slot].contents().load(as: GaussianVisibleSet.self)
        let count = Int(record.threadgroupCount)
        let entries = Array(UnsafeBufferPointer(start: table.visibleChunks[slot].contents().bindMemory(to: GaussianVisibleChunk.self, capacity: count), count: count))
        if !table.hasCoarse {
            for entry in entries where entry.chunkIndex & ~kGaussianVisibleChunkIndexMask != 0 {
                XCTFail("a section-free frame wrote tag bits into chunk index \(String(entry.chunkIndex, radix: 16))", file: file, line: line)
                break
            }
        }
        return (Set(entries.map { $0.chunkIndex & kGaussianVisibleChunkIndexMask }), record, entries)
    }

    /// One visible-chunk entry with its `chunkIndex` word decoded (per-chunk-lod-tiers): the chunk,
    /// the level the entry draws (0 fine, 1, 2) and whether it is the outgoing window of a fade.
    struct GaussianVisibleChunkLevelEntry {
        let chunkIndex: UInt32
        let level: Int
        let outgoing: Bool
        let entry: GaussianVisibleChunk

        var quota: UInt32 {
            entry.quota
        }

        var splatCount: UInt32 {
            entry.splatCount
        }

        var screenArea: Float {
            entry.screenArea
        }
    }

    /// The visible-chunk list of `table` for the current slot with every entry's tag decoded.
    func visibleChunkLevels(_ table: GaussianChunkTable) -> [GaussianVisibleChunkLevelEntry] {
        visibleChunkEntries(table).entries.map { entry in
            let tag = GaussianChunkCullMath.decodeVisibleChunkTag(entry.chunkIndex)
            return GaussianVisibleChunkLevelEntry(chunkIndex: tag.chunkIndex, level: tag.level, outgoing: tag.outgoing, entry: entry)
        }
    }

    /// The per-chunk level states of `coarse`, as the quota pass left them.
    func levelStates(_ coarse: GaussianCoarseTable, chunkCount: Int) -> [GaussianChunkLevelState] {
        Array(UnsafeBufferPointer(start: coarse.levelStateBuffer.contents().bindMemory(to: GaussianChunkLevelState.self, capacity: chunkCount), count: chunkCount))
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
    /// persistent histogram, so it holds this cull alone — and returns the record. An entity with
    /// coarse levels passes its `levels` and `levelConstants` (per-chunk-lod-tiers); with
    /// `quotas` the budget state is reset first and the scale and quota passes follow the cull on
    /// the same encoder with `budget`, so the entries carry their quotas and level tags.
    func cullChunks(
        _ table: GaussianChunkTable,
        constants: GaussianChunkCullConstants,
        levels: GaussianChunkLevelBuffers? = nil,
        levelConstants: GaussianChunkLevelConstants = GaussianChunkLevelConstants(),
        quotas: Bool = false,
        budget: Int = 1 << 24
    ) throws -> (chunks: Set<UInt32>, record: GaussianVisibleSet, entries: [GaussianVisibleChunk]) {
        let pipelines = try XCTUnwrap(GaussianChunkCullPipelineStates.current())
        let budgetState = try budgetStateBuffer()
        let densityHistogram = try densityHistogramBuffer()
        densityHistogram.contents().storeBytes(of: GaussianBudgetDensityHistogram(), as: GaussianBudgetDensityHistogram.self)
        runSynchronously { commandBuffer in
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
            if quotas {
                encodeGaussianBudgetReset(encoder, pipelines: pipelines, budgetState: budgetState, densityHistogram: densityHistogram)
            }
            _ = encodeGaussianChunkCull(
                encoder,
                pipelines: pipelines,
                chunkTable: table,
                visibleChunks: table.visibleChunks[0],
                chunkSet: table.visibleChunkSets[0],
                budgetState: budgetState,
                densityHistogram: densityHistogram,
                constants: constants,
                hzbTexture: textureResources.hzbDepthPyramid ?? textureResources.depthMap,
                levels: levels,
                levelConstants: levelConstants
            )
            if quotas {
                let scale = gaussianBudgetScaleConstants(
                    budget: budget,
                    resetHysteresis: true,
                    uniformQuotas: constants.uniformQuotas != 0,
                    densityFloor: levelConstants.densityFloor,
                    tierShifts: (levelConstants.tierShift1, levelConstants.tierShift2)
                )
                encodeGaussianBudgetScale(encoder, pipelines: pipelines, budgetState: budgetState, densityHistogram: densityHistogram, constants: scale)
                encodeGaussianChunkQuotas(
                    encoder,
                    pipelines: pipelines,
                    chunkTable: table,
                    visibleChunks: table.visibleChunks[0],
                    chunkSet: table.visibleChunkSets[0],
                    budgetState: budgetState,
                    levels: levels,
                    levelConstants: levelConstants
                )
            }
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

    init(result: GaussianLoadResult) {
        self.result = result
    }

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

    /// The slab of `splatCount` splats, section-free by default; with `coarseLevels` the same
    /// fine chunks byte for byte plus the per-chunk coarse section those options bake
    /// (per-chunk-lod-tiers), cached under its own name.
    static func url(splatCount: Int, coarseLevels: UntoldGSCoarseLevelOptions? = nil) throws -> URL {
        var name = "GaussianSyntheticAsset-\(splatCount)-v1"
        if let coarseLevels {
            name += "-coarse\(coarseLevels.levelCount)-" + coarseLevels.ratioLog2.prefix(coarseLevels.levelCount).map(String.init).joined(separator: "_")
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
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
        // Section-free unless asked: the slab is the fixture of the budget and paging suites,
        // whose frames are compared against whole-buffer twins; the per-chunk level tests take
        // the levelled variant (the writer's automatic policy would add a section to every slab
        // of at least 64 chunks).
        options.coarseLevels = coarseLevels
        options.coarseLevelsAutomatic = false
        let start = CFAbsoluteTimeGetCurrent()
        try UntoldGSFormat.write(splats: splats, options: options, to: url)
        print("[GaussianSyntheticAsset] baked \(splatCount) splats in \(String(format: "%.1f", CFAbsoluteTimeGetCurrent() - start)) s -> \(url.path)")
        return url
    }

    /// The analytic cluster fixture (per-chunk-lod-tiers): `chunkCount × 8` tight clusters of
    /// `clusterSplats` identical isotropic splats each, on a cubic grid whose cells are the
    /// Morton cells of the bake, so every chunk of 8 × `clusterSplats` splats holds exactly eight
    /// whole clusters and a level of ratio log2(`clusterSplats`) merges each cluster into one
    /// record whose moments are closed-form: centre = the cluster's mean, covariance ≈ r² I plus
    /// the members' spread, opacity 1 − exp(−N α r² / s_M). Baked with levels [log2 N, log2 8N]
    /// (one record per cluster, then one per chunk).
    struct CoarseClusters {
        let url: URL
        /// Cluster centres in bake order (chunk-major: chunk c holds clusters 8c … 8c + 7).
        let centres: [simd_float3]
        let radius: Float
        let splatRadius: Float
        let splatOpacity: Float
        let clusterSplats: Int
        let colours: [simd_float3]
        var chunkCount: Int {
            centres.count / 8
        }
    }

    static func coarseClusters(chunkCount: Int, clusterSplats: Int = 128, to url: URL) throws -> CoarseClusters {
        precondition(clusterSplats > 0 && clusterSplats & (clusterSplats - 1) == 0, "a power of two per cluster")
        // A cubic grid of 8 × chunkCount cells: side g with g³ ≥ 8 chunkCount, filled in Morton
        // order of the cell so consecutive clusters are consecutive in the bake.
        let clusterCount = 8 * chunkCount
        var side = 1
        while side * side * side < clusterCount {
            side *= 2
        }
        let spacing: Float = 1
        let radius: Float = 0.06 * spacing
        let splatRadius: Float = 0.02 * spacing
        let opacity: Float = 0.6
        var generator = SplitMix64(seed: 0x5EED_C1A5)
        /// Morton rank of every cell, sorted: the bake's order.
        func morton(_ x: Int, _ y: Int, _ z: Int) -> Int {
            var code = 0
            for bit in 0 ..< 10 {
                code |= ((x >> bit) & 1) << (3 * bit)
                code |= ((y >> bit) & 1) << (3 * bit + 1)
                code |= ((z >> bit) & 1) << (3 * bit + 2)
            }
            return code
        }
        var cells: [(code: Int, x: Int, y: Int, z: Int)] = []
        for z in 0 ..< side {
            for y in 0 ..< side {
                for x in 0 ..< side {
                    cells.append((morton(x, y, z), x, y, z))
                }
            }
        }
        cells.sort { $0.code < $1.code }
        var centres: [simd_float3] = []
        var colours: [simd_float3] = []
        var splats: [UntoldGSSplat] = []
        splats.reserveCapacity(clusterCount * clusterSplats)
        for cell in cells.prefix(clusterCount) {
            let centre = simd_float3(Float(cell.x), Float(cell.y), Float(cell.z)) * spacing
            let colour = simd_float3(generator.value(in: 0.2 ... 0.9), generator.value(in: 0.2 ... 0.9), generator.value(in: 0.2 ... 0.9))
            centres.append(centre)
            colours.append(colour)
            for _ in 0 ..< clusterSplats {
                // Uniform in the ball of `radius` around the centre.
                var offset: simd_float3
                repeat {
                    offset = simd_float3(generator.value(in: -1 ... 1), generator.value(in: -1 ... 1), generator.value(in: -1 ... 1))
                } while simd_length_squared(offset) > 1
                splats.append(UntoldGSSplat(
                    position: centre + offset * radius,
                    scale: simd_float3(repeating: splatRadius),
                    rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                    color: colour,
                    opacity: opacity,
                    sphericalHarmonics: []
                ))
            }
        }
        var options = UntoldGSWriteOptions()
        var log2 = 0
        while 1 << log2 < clusterSplats {
            log2 += 1
        }
        options.log2ChunkSplats = UInt8(log2 + 3)
        var levels = UntoldGSCoarseLevelOptions()
        levels.levelCount = 2
        levels.ratioLog2 = [UInt8(log2), UInt8(log2 + 3)]
        options.coarseLevels = levels
        options.coarseLevelsAutomatic = false
        try UntoldGSFormat.write(splats: splats, options: options, to: url)
        return CoarseClusters(url: url, centres: centres, radius: radius, splatRadius: splatRadius, splatOpacity: opacity, clusterSplats: clusterSplats, colours: colours)
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

// MARK: - Paging

/// A page source over the file's bytes in memory, for the paging tests: a read completes at
/// once, or blocks until the test advances the source's tick past its latency
/// (`latencyTicks`, `advance()`, `deliverAll()`); reads of `holdChunks` block until released;
/// `failChunks` throw; `corruptChunks` serve a flipped byte; after `identityChangesAfterRead`
/// successful reads every read throws `.fileChanged` and `reopen()` fails until
/// `restoreIdentity()`. Every read is logged by chunk, rank and bytes.
final class GaussianTestPageSource: GaussianPageSource, @unchecked Sendable {
    struct ReadRecord: Equatable {
        let chunk: Int
        let firstRank: Int
        let rankCount: Int
        let bytes: Int
        /// Whether the range is the chunk's core block (else its harmonics).
        let core: Bool
        /// A piece of the coarse section (per-chunk-lod-tiers): the file level whose records the
        /// range starts in, `chunk` −1 and no ranks; 0 for a tier read.
        var coarseLevel: Int = 0

        var isCoarse: Bool {
            coarseLevel != 0
        }

        /// A read of a chunk's core records (a fine tier).
        var isFine: Bool {
            core && chunk >= 0
        }
    }

    /// Every source the factory override created, newest last.
    static var created: [GaussianTestPageSource] {
        registryLock.lock()
        defer { registryLock.unlock() }
        return _created
    }

    static func resetCreated() {
        registryLock.lock()
        _created.removeAll()
        registryLock.unlock()
    }

    /// Installs the override; the sources it creates are listed in `created`.
    static func install() {
        GaussianPageSourceFactory.override = { url in
            let source = try GaussianTestPageSource(url: url)
            record(source)
            return source
        }
    }

    /// Lists a source a custom override created.
    static func record(_ source: GaussianTestPageSource) {
        registryLock.lock()
        _created.append(source)
        registryLock.unlock()
    }

    private static let registryLock = NSLock()
    private nonisolated(unsafe) static var _created: [GaussianTestPageSource] = []

    let url: URL
    let index: UntoldGSIndex
    private let data: Data
    private let lock = NSLock()
    private let condition = NSCondition()
    private var _identity: GaussianFileIdentity
    private let originalIdentity: GaussianFileIdentity
    private var identityChanged = false
    private var successfulReads = 0
    private var _tick = 0
    private var _blockedReads = 0
    private var released = false
    private var _closed = false
    private var _reopenCount = 0
    private var _log: [ReadRecord] = []
    private var _bytesRequested = 0

    var latencyTicks = 0
    /// Chunks whose reads never complete until released. Published under the condition's lock:
    /// a worker between its hold check and its wait holds that lock, so the change and its
    /// broadcast cannot slip into the gap and leave a released read asleep.
    var holdChunks: Set<Int> {
        get { lock.lock(); defer { lock.unlock() }; return _holdChunks }
        set {
            condition.lock()
            lock.lock()
            _holdChunks = newValue
            lock.unlock()
            condition.broadcast()
            condition.unlock()
        }
    }

    private var _holdChunks: Set<Int> = []
    var failChunks: [Int: GaussianPagingError] {
        get { lock.lock(); defer { lock.unlock() }; return _failChunks }
        set { lock.lock(); _failChunks = newValue; lock.unlock() }
    }

    private var _failChunks: [Int: GaussianPagingError] = [:]
    var corruptChunks: Set<Int> {
        get { lock.lock(); defer { lock.unlock() }; return _corruptChunks }
        set { lock.lock(); _corruptChunks = newValue; lock.unlock() }
    }

    private var _corruptChunks: Set<Int> = []
    /// Every read of the coarse section serves a flipped byte (per-chunk-lod-tiers): the first
    /// level payload the piece holds fails its CRC.
    var corruptCoarse: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _corruptCoarse }
        set { lock.lock(); _corruptCoarse = newValue; lock.unlock() }
    }

    private var _corruptCoarse = false
    /// Every piece of the coarse section fails its first this many reads with an I/O error
    /// (per piece, by file offset) and succeeds after (per-chunk-lod-tiers).
    var coarsePieceFailures: Int {
        get { lock.lock(); defer { lock.unlock() }; return _coarsePieceFailures }
        set { lock.lock(); _coarsePieceFailures = newValue; lock.unlock() }
    }

    private var _coarsePieceFailures = 0
    private var _coarsePieceAttempts: [UInt64: Int] = [:]
    var identityChangesAfterRead: Int? {
        get { lock.lock(); defer { lock.unlock() }; return _identityChangesAfterRead }
        set { lock.lock(); _identityChangesAfterRead = newValue; lock.unlock() }
    }

    private var _identityChangesAfterRead: Int?

    init(url: URL) throws {
        self.url = url
        data = try Data(contentsOf: url)
        index = try UntoldGSFormat.readIndex(from: data)
        let identity = GaussianFileIdentity(fileSize: UInt64(data.count), inode: 1, modificationSeconds: 1, modificationNanoseconds: 0)
        _identity = identity
        originalIdentity = identity
    }

    var identity: GaussianFileIdentity {
        lock.lock()
        defer { lock.unlock() }
        return _identity
    }

    var closed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _closed
    }

    var reopenCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _reopenCount
    }

    var requestLog: [ReadRecord] {
        lock.lock()
        defer { lock.unlock() }
        return _log
    }

    var bytesRequested: Int {
        lock.lock()
        defer { lock.unlock() }
        return _bytesRequested
    }

    /// Reads currently blocked on their latency or a hold.
    var blockedReads: Int {
        condition.lock()
        defer { condition.unlock() }
        return _blockedReads
    }

    /// One tick of latency passes: reads due at or before it complete.
    func advance() {
        condition.lock()
        _tick += 1
        condition.broadcast()
        condition.unlock()
    }

    /// Every blocked read completes (holds included).
    func deliverAll() {
        condition.lock()
        released = true
        condition.broadcast()
        condition.unlock()
    }

    func release(chunk: Int) {
        condition.lock()
        lock.lock()
        _holdChunks.remove(chunk)
        lock.unlock()
        condition.broadcast()
        condition.unlock()
    }

    /// The file "changes": reads and reopens fail until `restoreIdentity()`.
    func changeIdentity() {
        lock.lock()
        identityChanged = true
        _identity = GaussianFileIdentity(fileSize: originalIdentity.fileSize, inode: 2, modificationSeconds: 2, modificationNanoseconds: 0)
        lock.unlock()
    }

    func restoreIdentity() {
        lock.lock()
        identityChanged = false
        _identityChangesAfterRead = nil
        lock.unlock()
    }

    /// The chunk a file range belongs to, and its first rank and rank count within it.
    func locate(offset: UInt64, count: Int) -> ReadRecord? {
        for (chunkIndex, chunk) in index.chunks.enumerated() {
            guard offset >= chunk.payloadOffset, offset < chunk.payloadOffset + UInt64(chunk.payloadBytes) else { continue }
            let relative = Int(offset - chunk.payloadOffset)
            let shBytes = index.header.shBytesPerSplat
            if relative < Int(chunk.coreBytes) {
                return ReadRecord(chunk: chunkIndex, firstRank: relative / UntoldGSFormat.coreRecordSize, rankCount: count / UntoldGSFormat.coreRecordSize, bytes: count, core: true)
            }
            guard shBytes > 0 else { return nil }
            let shRelative = relative - Int(chunk.coreBytes)
            return ReadRecord(chunk: chunkIndex, firstRank: shRelative / shBytes, rankCount: count / shBytes, bytes: count, core: false)
        }
        // A piece of the coarse section: the level whose range holds the start of the piece.
        let header = index.header
        if header.hasCoarseLevels, offset >= header.coarsePayloadOffset, offset < header.fileSize {
            for level in 1 ... index.coarseLevelCount {
                guard let range = index.coarseLevelRange(level: level), range.contains(offset) else { continue }
                return ReadRecord(chunk: -1, firstRank: 0, rankCount: 0, bytes: count, core: false, coarseLevel: level)
            }
            return ReadRecord(chunk: -1, firstRank: 0, rankCount: 0, bytes: count, core: false, coarseLevel: index.coarseLevelCount)
        }
        return nil
    }

    func read(offset: UInt64, count: Int, into destination: UnsafeMutableRawPointer) throws {
        guard let record = locate(offset: offset, count: count) else {
            throw GaussianPagingError.truncated
        }
        lock.lock()
        _log.append(record)
        _bytesRequested += count
        let closedNow = _closed
        lock.unlock()
        if closedNow { throw GaussianPagingError.closed }

        // Latency and holds.
        condition.lock()
        let due = _tick + latencyTicks
        var blocked = false
        while !released {
            lock.lock()
            let held = _holdChunks.contains(record.chunk)
            lock.unlock()
            if !held, _tick >= due { break }
            if !blocked {
                blocked = true
                _blockedReads += 1
            }
            condition.wait()
        }
        if blocked { _blockedReads -= 1 }
        condition.unlock()

        lock.lock()
        defer { lock.unlock() }
        if _closed { throw GaussianPagingError.closed }
        if let error = _failChunks[record.chunk], record.core {
            throw error
        }
        if record.isCoarse, _coarsePieceFailures > 0 {
            let attempt = _coarsePieceAttempts[offset, default: 0] + 1
            _coarsePieceAttempts[offset] = attempt
            if attempt <= _coarsePieceFailures {
                throw GaussianPagingError.ioFailure(errno: EIO)
            }
        }
        if identityChanged {
            throw GaussianPagingError.fileChanged
        }
        let start = Int(offset)
        guard start + count <= data.count else { throw GaussianPagingError.truncated }
        data.withUnsafeBytes { bytes in
            destination.copyMemory(from: bytes.baseAddress! + start, byteCount: count)
        }
        if _corruptChunks.contains(record.chunk), record.core, count > 3 {
            destination.storeBytes(of: destination.load(fromByteOffset: 3, as: UInt8.self) ^ 0x5A, toByteOffset: 3, as: UInt8.self)
        }
        if _corruptCoarse, record.coarseLevel != 0, count > 3 {
            destination.storeBytes(of: destination.load(fromByteOffset: 3, as: UInt8.self) ^ 0x5A, toByteOffset: 3, as: UInt8.self)
        }
        successfulReads += 1
        if let limit = _identityChangesAfterRead, successfulReads >= limit {
            identityChanged = true
            _identity = GaussianFileIdentity(fileSize: originalIdentity.fileSize, inode: 2, modificationSeconds: 2, modificationNanoseconds: 0)
        }
    }

    func reopen() throws {
        lock.lock()
        defer { lock.unlock() }
        _reopenCount += 1
        if _closed { throw GaussianPagingError.closed }
        if identityChanged { throw GaussianPagingError.fileChanged }
        _identity = originalIdentity
    }

    func close() {
        lock.lock()
        _closed = true
        lock.unlock()
        condition.lock()
        released = true
        condition.broadcast()
        condition.unlock()
    }
}

/// A whole-buffer twin of a partially resident paged entity: the same records expanded once,
/// with every rank at or beyond its chunk's resident prefix at opacity 0 and the resident tail
/// faded by the opacity band the fused pass applies to a truncated chunk (quota = resident
/// ranks), so a frame of the paged entity and a frame of the twin draw the same splats.
struct GaussianPartialTwin {
    let result: GaussianLoadResult

    /// `residentRanks` per chunk index (missing = whole).
    init(loaded: GaussianChunkLoadResult, residentRanks: [Int: Int]) throws {
        let encoded = try GaussianChunkLoader.decodeEncodedSplats(loaded)
        let splats = encoded.contents().bindMemory(to: EncodedGaussianSplat.self, capacity: loaded.splatCount)
        var firstSplat = 0
        for (chunkIndex, chunk) in loaded.index.chunks.enumerated() {
            let count = Int(chunk.splatCount)
            if let resident = residentRanks[chunkIndex], resident < count {
                for rank in 0 ..< count {
                    let factor = rank < resident
                        ? GaussianChunkCullMath.opacityBandFactor(rank: UInt32(rank), quota: UInt32(resident), splatCount: UInt32(count))
                        : 0
                    var splat = splats[firstSplat + rank]
                    splat.colorAndOpacity.w = Float16(Float(splat.colorAndOpacity.w) * factor)
                    splats[firstSplat + rank] = splat
                }
            }
            firstSplat += count
        }
        result = try XCTUnwrap(buildGaussianLoadResult(
            encodedSplatBuffer: encoded,
            splatCount: UInt(loaded.splatCount),
            sphericalHarmonicsBuffer: loaded.sphericalHarmonicsBuffer,
            sphericalHarmonicsMetadata: loaded.sphericalHarmonicsMetadata,
            boundingBox: loaded.boundingBox
        ))
    }

    /// Runs `body` with `component` swapped onto the whole-buffer path over the twin's buffers.
    func withLegacyBuffers<T>(_ component: GaussianComponent, _ body: () throws -> T) rethrows -> T {
        try GaussianLegacyTwin(result: result).withLegacyBuffers(component, body)
    }
}

/// A whole-resident chunked twin of an entity with per-chunk coarse levels (per-chunk-lod-tiers):
/// every chunk drawn as one fixed level. Its chunk table's rows are the chosen level's own decode
/// constants (the fine row, or the coarse entry's ranges — G1 of the spec: a coarse entry is a
/// chunk entry) over one packed buffer holding the fine records followed by the coarse records
/// as stored, so the fused pass decodes the same 16-byte records against the same ranges as the
/// levelled entity does for that level — bit-identical records and keys when both draw the
/// whole level with no fade. Culled by the chosen level's own box (the levelled entity culls by
/// the fine box), so the comparison holds for chunks well inside the frustum.
struct GaussianLevelTwin {
    let result: GaussianLoadResult
    let table: GaussianChunkTable
    /// The level each chunk draws in the twin.
    let levels: [Int]

    /// `levels[chunk]` = 0 fine, 1, 2 (the file's levels); a level the chunk lacks falls back to
    /// the finest it has.
    init(loaded: GaussianChunkLoadResult, levels: (Int) -> Int) throws {
        let index = loaded.index
        let coarse = try XCTUnwrap(loaded.chunkTable.coarse, "the entity carries coarse levels")
        let device = try XCTUnwrap(renderInfo.device)
        let fineBytes = loaded.packedSplatBuffer.length
        let coarseBytes = coarse.recordsBuffer.length
        let packed = try XCTUnwrap(device.makeBuffer(length: fineBytes + coarseBytes, options: .storageModeShared))
        packed.label = "Gaussian Level Twin Records"
        packed.contents().copyMemory(from: loaded.packedSplatBuffer.contents(), byteCount: fineBytes)
        packed.contents().advanced(by: fineBytes).copyMemory(from: coarse.recordsBuffer.contents(), byteCount: coarseBytes)
        let fineRecords = fineBytes / UntoldGSFormat.coreRecordSize

        var rows: [GaussianChunkDecodeConstants] = []
        var entries: [UntoldGSChunkEntry] = []
        var chosen: [Int] = []
        var total: UInt32 = 0
        var firstFine = 0
        for (chunkIndex, fine) in index.chunks.enumerated() {
            var level = max(0, min(2, levels(chunkIndex)))
            var entry: UntoldGSChunkEntry?
            while level > 0 {
                if let runtime = coarse.fileLevels.firstIndex(of: level), let candidate = loaded.chunkTable.coarseEntry(runtimeLevel: runtime + 1, chunk: chunkIndex) {
                    entry = candidate
                    break
                }
                level -= 1
            }
            let row: GaussianChunkDecodeConstants
            if let entry {
                let firstSplat = fineRecords + Int((entry.payloadOffset - coarse.recordsRange.lowerBound) / UInt64(UntoldGSFormat.coreRecordSize))
                row = GaussianChunkDecodeConstants(
                    aabbMinX: entry.aabbMin.x, aabbMinY: entry.aabbMin.y, aabbMinZ: entry.aabbMin.z, logScaleMin: entry.logScaleMin,
                    aabbMaxX: entry.aabbMax.x, aabbMaxY: entry.aabbMax.y, aabbMaxZ: entry.aabbMax.z, logScaleMax: entry.logScaleMax,
                    firstSplat: UInt32(firstSplat), splatCount: entry.splatCount, _pad0: 0, _pad1: 0
                )
                entries.append(entry)
                total += entry.splatCount
            } else {
                level = 0
                row = GaussianChunkDecodeConstants(
                    aabbMinX: fine.aabbMin.x, aabbMinY: fine.aabbMin.y, aabbMinZ: fine.aabbMin.z, logScaleMin: fine.logScaleMin,
                    aabbMaxX: fine.aabbMax.x, aabbMaxY: fine.aabbMax.y, aabbMaxZ: fine.aabbMax.z, logScaleMax: fine.logScaleMax,
                    firstSplat: UInt32(firstFine), splatCount: fine.splatCount, _pad0: 0, _pad1: 0
                )
                entries.append(fine)
                total += fine.splatCount
            }
            rows.append(row)
            chosen.append(level)
            firstFine += Int(fine.splatCount)
        }
        let constants = try XCTUnwrap(device.makeBuffer(bytes: rows, length: rows.count * MemoryLayout<GaussianChunkDecodeConstants>.stride, options: .storageModeShared))
        constants.label = "Gaussian Level Twin Table"
        // A section-free index over the chosen entries: the twin has no coarse table of its own.
        var header = index.header
        header.flags &= ~UntoldGSFlags.hasCoarseLevels
        header.coarseLevelCount = 0
        header.coarseRatioLog2 = [0, 0]
        header.coarseIndexOffset = 0
        header.coarsePayloadOffset = 0
        header.coarseRecordCount = 0
        header.splatCount = total
        let twinIndex = UntoldGSIndex(header: header, chunks: entries, nodes: index.nodes)
        let table = GaussianChunkTable(constantsBuffer: constants, chunkCount: rows.count, splatsPerChunk: loaded.chunkTable.splatsPerChunk, index: twinIndex)
        result = try XCTUnwrap(buildGaussianLoadResult(
            packedSplatBuffer: packed,
            splatCount: UInt(total),
            sphericalHarmonicsBuffer: nil,
            sphericalHarmonicsMetadata: loaded.sphericalHarmonicsMetadata,
            boundingBox: loaded.boundingBox,
            chunkTable: table
        ))
        self.table = try XCTUnwrap(result.chunkTable)
        self.levels = chosen
    }

    /// Runs `body` with `component` on the whole-resident chunked path over the twin's buffers
    /// (no pager, no coarse table), then puts its own buffers, table and pager back.
    func withTwinBuffers<T>(_ component: GaussianComponent, _ body: () throws -> T) rethrows -> T {
        let saved = (component.packedSplatData, component.sphericalHarmonicsData, component.chunkTable, component.pager)
        component.packedSplatData = result.packedSplatBuffer
        component.sphericalHarmonicsData = nil
        component.chunkTable = result.chunkTable
        component.pager = nil
        defer {
            (component.packedSplatData, component.sphericalHarmonicsData, component.chunkTable, component.pager) = saved
        }
        return try body()
    }
}

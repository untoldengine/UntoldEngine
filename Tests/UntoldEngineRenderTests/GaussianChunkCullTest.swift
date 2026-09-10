//
//  GaussianChunkCullTest.swift
//  UntoldEngine
//
//  The per-chunk path of .untoldgs entities (GaussianChunkCull.metal, GaussianChunkPreprocess.metal)
//  with the budget unlimited: the chunk table and the packed records reach the component and
//  nothing else per splat, the GPU keeps exactly the chunks the CPU mirror predicts, the fused
//  pass compacts exactly the splats the whole-buffer path keeps (a legacy twin of the same file
//  that never runs the chunk code), the frame is the same with the chunk cull on and off and
//  against the whole-buffer path, a partial view culls chunks, the fused pass strides correctly
//  over a chunk wider than its threadgroup, the HZB part of the chunk test culls occluded chunks
//  and only those, the extent padding keeps a chunk whose splats reach into the view, a stereo
//  chunk — and a stereo splat — survives when only one eye sees it (either eye, and the union
//  of two views that each miss part of the asset), in stereo only eye 1's test samples the mono
//  HZB, the fused pass evaluates spherical harmonics by original splat index like the
//  whole-buffer path, and a real stereo frame tests both eyes with the current scene root.
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
final class GaussianChunkCullTest: BaseRenderSetup {
    private var temporaryFiles: [URL] = []
    private var savedDisableHZBOcclusionCull = false
    private var savedDisableChunkCull = false
    private var savedDisableScreenWeightedQuotas = false
    private var savedWorkingSetOverride: Int?
    /// The legacy twin of the last chunked load, and the CPU decode of its positions.
    private var legacyTwin: GaussianLegacyTwin?
    private var indexResolver: GaussianSplatIndexResolver?

    /// The 200-splat fixture baked with 16 splats per chunk: 13 chunks.
    private let expectedChunkCount = 13

    /// Visible chunks at each of `cameras`, so the frustum boundary is known to be exercised.
    private let expectedVisibleChunkCounts = [13, 8, 12]

    /// Three views of the fixture (x, y in ±1.4, z in −0.05…0.55, 16-splat Morton chunks): the
    /// whole asset from afar (13 of 13 chunks), a close view of the +x/+y corner that leaves
    /// five chunks outside the frustum (8 of 13), a close view of the −x side (12 of 13).
    private let cameras: [(eye: simd_float3, target: simd_float3)] = [
        (simd_float3(0, 3, 7), .zero),
        (simd_float3(1.0, 1.0, 0.6), simd_float3(1.0, 1.0, 0)),
        (simd_float3(-1.0, 0.2, 1.0), simd_float3(-1.0, 0.2, 0)),
    ]

    override func setUp() async throws {
        try await super.setUp()
        savedDisableHZBOcclusionCull = GaussianDebugOptions.shared.disableHZBOcclusionCull
        savedDisableChunkCull = GaussianDebugOptions.shared.disableChunkCull
        savedDisableScreenWeightedQuotas = GaussianDebugOptions.shared.disableScreenWeightedQuotas
        savedWorkingSetOverride = GaussianRuntimeLimits.workingSetSplatsOverride
        // Budget unlimited for this suite: the default far exceeds the fixture, and the scale a
        // previous test left behind must not linger through the hysteresis. The quotas weighted:
        // the screen-area assertions are the weighted mode's (uniform mode writes the count).
        GaussianDebugOptions.shared.disableScreenWeightedQuotas = false
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
    }

    override func tearDown() async throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = savedDisableHZBOcclusionCull
        GaussianDebugOptions.shared.disableChunkCull = savedDisableChunkCull
        GaussianDebugOptions.shared.disableScreenWeightedQuotas = savedDisableScreenWeightedQuotas
        GaussianRuntimeLimits.workingSetSplatsOverride = savedWorkingSetOverride
        legacyTwin = nil
        indexResolver = nil
        destroyAllEntities()
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    // MARK: - Helpers

    private func bakeV3(chunkSplats log2: UInt8 = 4) throws -> URL {
        let ply = try XCTUnwrap(LoadingSystem.shared.resourceURL(forResource: "test_gaussians", withExtension: "ply", subResource: nil))
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianChunkCullTest-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")
        var options = UntoldGSCookOptions()
        options.log2ChunkSplats = log2
        let result = try bakeGaussianSplatProgressiveTiers(plyURL: ply, outputBaseURL: output, lodFractions: [1.0], cookOptions: options)
        let url = try XCTUnwrap(result.tiers.first?.url)
        temporaryFiles.append(url)
        return url
    }

    private func loadChunkedEntity() throws -> (entity: EntityID, component: GaussianComponent, table: GaussianChunkTable) {
        let url = try bakeV3()
        let entity = createEntity()
        setEntityGaussian(entityId: entity, filename: url.deletingPathExtension().path, withExtension: "untoldgs")
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        let table = try XCTUnwrap(component.chunkTable, "a .untoldgs load keeps its chunk table")
        XCTAssertTrue(component.isChunked)
        legacyTwin = try GaussianLegacyTwin(loaded: GaussianChunkLoader.load(url: url))
        indexResolver = try GaussianSplatIndexResolver(positions: UntoldGSFormat.read(from: url).encodedSplats.map(\.position))
        return (entity, component, table)
    }

    /// The asset indices of the splats the frame's cull and preprocess compacted into the shared
    /// set for the current camera: the fused per-chunk pass for a chunked entity, the whole-buffer
    /// kernels for a legacy one.
    private func compactedSurvivors() throws -> [UInt32] {
        runGaussianCullAndPreprocess()
        let records = sharedGaussianRecords()
        XCTAssertEqual(sharedGaussianVisibleCount(), records.count)
        return try XCTUnwrap(indexResolver).indices(of: records)
    }

    /// The survivors of the whole-buffer path on the legacy twin of `component`'s file.
    private func legacySurvivors(_ component: GaussianComponent) throws -> [UInt32] {
        try XCTUnwrap(legacyTwin).withLegacyBuffers(component) {
            try compactedSurvivors()
        }
    }

    /// The whole-buffer path's frame for `component`, rendered twice so the HZB is its own.
    private func legacyFrame(_ component: GaussianComponent) throws -> (image: [Float16], visible: Int) {
        try XCTUnwrap(legacyTwin).withLegacyBuffers(component) {
            _ = renderGaussianSplatLayer()
            let image = renderGaussianSplatLayer()
            return (image, sharedGaussianVisibleCount())
        }
    }

    private func frameSlot(for component: GaussianComponent) -> Int {
        let slots = component.chunkTable?.visibleChunkSets.count ?? component.gaussianVisibleCount.count
        return min(renderInfo.currentInFlightFrameSlot, max(0, slots - 1))
    }

    private func visibleSplatIndices(_ component: GaussianComponent, slot: Int) throws -> [UInt32] {
        let set = try XCTUnwrap(component.gaussianVisibleCount[slot]).contents().load(as: GaussianVisibleSet.self)
        let count = Int(set.visibleCount)
        let buffer = try XCTUnwrap(component.gaussianVisibleIndices[slot])
        return Array(UnsafeBufferPointer(start: buffer.contents().bindMemory(to: UInt32.self, capacity: count), count: count))
    }

    /// The matrix the frame's cull tests chunks against in mono: projection × effective view × model.
    private func headViewProjection(entity: EntityID) throws -> simd_float4x4 {
        let camera = try XCTUnwrap(CameraSystem.shared.activeCamera)
        let cameraComponent = try XCTUnwrap(scene.get(component: CameraComponent.self, for: camera))
        let world = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: entity))
        let view = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        return simd_mul(renderInfo.perspectiveSpace, simd_mul(view, world.space))
    }

    private func expectedVisibleChunks(_ table: GaussianChunkTable, viewProjections: [simd_float4x4]) -> Set<UInt32> {
        Set(table.index.chunks.enumerated().compactMap { index, entry in
            GaussianChunkCullMath.chunkIsVisible(entry, viewProjections: viewProjections) ? UInt32(index) : nil
        })
    }

    /// Chunk index of every splat, from the index's contiguous chunk ranges.
    private func chunkOfSplat(_ table: GaussianChunkTable) -> [UInt32] {
        var owner: [UInt32] = []
        for (index, entry) in table.index.chunks.enumerated() {
            owner.append(contentsOf: repeatElement(UInt32(index), count: Int(entry.splatCount)))
        }
        return owner
    }

    /// The depth of an occluder right in front of the camera and of nothing at all, in the
    /// frame's depth convention (reverse-Z in tests).
    private var nearDepth: Float {
        renderInfo.reverseZEnabled ? 0.95 : 0.05
    }

    private var farDepth: Float {
        renderInfo.reverseZEnabled ? 0.0 : 1.0
    }

    /// A chunk table with one chunk of 16 splats over `aabbMin...aabbMax`, its log-scale range
    /// topping out at `logScaleMax`, with the per-slot visible-chunk buffers allocated.
    private func makeOneChunkTable(aabbMin: simd_float3, aabbMax: simd_float3, logScaleMax: Float) throws -> GaussianChunkTable {
        var constants = GaussianChunkDecodeConstants()
        constants.aabbMinX = aabbMin.x
        constants.aabbMinY = aabbMin.y
        constants.aabbMinZ = aabbMin.z
        constants.aabbMaxX = aabbMax.x
        constants.aabbMaxY = aabbMax.y
        constants.aabbMaxZ = aabbMax.z
        constants.logScaleMin = -10
        constants.logScaleMax = logScaleMax
        constants.firstSplat = 0
        constants.splatCount = 16
        let buffer = try XCTUnwrap(renderInfo.device.makeBuffer(bytes: &constants, length: MemoryLayout<GaussianChunkDecodeConstants>.stride, options: .storageModeShared))
        let entry = UntoldGSChunkEntry(payloadOffset: 4096, payloadBytes: 4096, coreBytes: 256, splatCount: 16, aabbMin: aabbMin, aabbMax: aabbMax, logScaleMin: -10, logScaleMax: logScaleMax, crc32: 0)
        let header = UntoldGSHeaderV3(
            log2ChunkSplats: 4, splatCount: 16, chunkCount: 1, nodeCount: 0,
            boundsMin: aabbMin, boundsMax: aabbMax, boundingBoxMin: aabbMin, boundingBoxMax: aabbMax,
            chunkIndexOffset: 256, nodeTreeOffset: 320, payloadOffset: 4096, fileSize: 8192
        )
        let index = UntoldGSIndex(header: header, chunks: [entry], nodes: [])
        let table = GaussianChunkTable(constantsBuffer: buffer, chunkCount: 1, splatsPerChunk: 16, index: index)
        return try XCTUnwrap(allocateGaussianVisibleChunkBuffers(for: table))
    }

    /// The chunk cull and the fused pass by hand with `constants` — the view-projections, view
    /// count and HZB inputs a frame would bind — and the head-centre uniforms of the active
    /// camera, as executeGaussianPreprocess builds them; returns the asset indices compacted.
    private func fusedPassSurvivors(entity: EntityID, component: GaussianComponent, table: GaussianChunkTable, constants: GaussianChunkCullConstants) throws -> [UInt32] {
        let camera = try XCTUnwrap(CameraSystem.shared.activeCamera)
        let cameraComponent = try XCTUnwrap(scene.get(component: CameraComponent.self, for: camera))
        let world = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: entity))
        let viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        var uniforms = Uniforms()
        uniforms.modelMatrix = world.space
        uniforms.viewMatrix = viewMatrix
        uniforms.modelViewMatrix = simd_mul(viewMatrix, world.space)
        uniforms.projectionMatrix = renderInfo.perspectiveSpace
        var entityConstants = GaussianPreprocessEntityConstants()
        entityConstants.workingSetCapacity = UInt32(GaussianSharedWorkingSet.shared.capacity)
        entityConstants.colorGain = simd_float4(1, 1, 1, 1)
        entityConstants.opacityScale = 1
        let pipelines = try XCTUnwrap(GaussianChunkCullPipelineStates.current())
        let workingSet = GaussianSharedWorkingSet.shared
        let sharedSlot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
        let sharedSet = try XCTUnwrap(workingSet.visibleSet(slot: sharedSlot))
        let packedSplats = try XCTUnwrap(component.packedSplatData)

        // The chunk cull with the same views lists the chunks into slot 0; the fused pass follows.
        _ = try cullChunks(table, constants: constants)
        sharedSet.contents().storeBytes(of: makeGaussianVisibleSet(visibleCount: 0), as: GaussianVisibleSet.self)
        let inputs = GaussianChunkPreprocessInputs(
            packedSplats: packedSplats,
            chunkTable: table,
            visibleChunks: table.visibleChunks[0],
            uniforms: uniforms,
            cullConstants: constants,
            viewport: renderInfo.viewPort ?? simd_float2(1, 1),
            sphericalHarmonics: component.sphericalHarmonicsData,
            shMetadata: component.sphericalHarmonicsMetadata ?? GaussianSHMetadata(degree: 0, coefficientsPerChannel: 0, higherOrderCoefficientsPerSplat: 0, _pad0: 0),
            localCameraPosition: gaussianLocalCameraPosition(cameraWorldPosition: SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition), modelMatrix: world.space),
            entityConstants: entityConstants,
            hzbTexture: textureResources.hzbDepthPyramid ?? textureResources.depthMap
        )
        runSynchronously { commandBuffer in
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
            encodeGaussianChunkDecodePreprocess(
                encoder,
                pipelineState: pipelines.decodePreprocess,
                inputs: inputs,
                chunkSet: table.visibleChunkSets[0],
                sharedRecords: workingSet.records(slot: sharedSlot)!,
                sharedKeys: workingSet.keys(slot: sharedSlot)!,
                sharedVisibleSet: sharedSet
            )
            encoder.endEncoding()
        }
        return try XCTUnwrap(indexResolver).indices(of: sharedGaussianRecords())
    }

    /// `cameras[0]` turned around: the asset behind it.
    private func lookingAwayViewProjection(entity: EntityID) throws -> simd_float4x4 {
        try viewProjection(entity: entity, eye: cameras[0].eye, target: cameras[0].eye * 2)
    }

    /// A unit box just past the guard band on the right of a camera looking down −z: outside
    /// the guard-banded frustum by less than 0.1 with a negligible padding.
    private func boxJustOutsideTheGuardBand() throws -> (min: simd_float3, max: simd_float3, viewProjection: simd_float4x4) {
        placeGaussianTestCamera(eye: simd_float3(0, 0, 5), target: .zero)
        let camera = try XCTUnwrap(CameraSystem.shared.activeCamera)
        let view = try XCTUnwrap(scene.get(component: CameraComponent.self, for: camera)).viewSpace
        let viewProjection = simd_mul(renderInfo.perspectiveSpace, view)
        var x: Float = 0
        while GaussianChunkCullMath.boxPassesClipPlanes(boxMin: simd_float3(x - 0.5, -0.5, -0.5), boxMax: simd_float3(x + 0.5, 0.5, 0.5), viewProjection: viewProjection) {
            x += 0.05
            if x > 100 {
                XCTFail("the unit box never left the frustum")
                break
            }
        }
        x += 0.1
        return (simd_float3(x - 0.5, -0.5, -0.5), simd_float3(x + 0.5, 0.5, 0.5), viewProjection)
    }

    private func assertMatricesEqual(_ a: simd_float4x4, _ b: simd_float4x4, accuracy: Float = 1e-5, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        for column in 0 ..< 4 {
            for row in 0 ..< 4 {
                XCTAssertEqual(a[column][row], b[column][row], accuracy: accuracy, "[\(column)][\(row)] \(message)", file: file, line: line)
            }
        }
    }

    // MARK: - (a) The chunk table reaches the component

    func testChunkTableReachesTheComponent() throws {
        let (_, component, table) = try loadChunkedEntity()
        XCTAssertEqual(table.chunkCount, expectedChunkCount)
        XCTAssertEqual(table.index.chunks.count, expectedChunkCount)
        XCTAssertEqual(table.splatsPerChunk, 16)
        XCTAssertEqual(table.constantsBuffer.length, expectedChunkCount * MemoryLayout<GaussianChunkDecodeConstants>.stride)
        XCTAssertEqual(table.visibleChunks.count, maxInFlightCommandBuffers)
        XCTAssertEqual(table.visibleChunkSets.count, maxInFlightCommandBuffers)
        for slot in 0 ..< maxInFlightCommandBuffers {
            XCTAssertEqual(table.visibleChunks[slot].length, expectedChunkCount * MemoryLayout<GaussianVisibleChunk>.stride)
            let record = table.visibleChunkSets[slot].contents().load(as: GaussianVisibleSet.self)
            XCTAssertEqual(record.threadgroupCount, UInt32(expectedChunkCount), "every chunk counts as visible until the first cull")
            XCTAssertEqual(record.threadgroupsPerGrid.0, UInt32(expectedChunkCount))
            XCTAssertEqual(record.visibleCount, UInt32(component.splatCount))
            let entries = UnsafeBufferPointer(start: table.visibleChunks[slot].contents().bindMemory(to: GaussianVisibleChunk.self, capacity: expectedChunkCount), count: expectedChunkCount)
            XCTAssertTrue(entries.allSatisfy { $0.quota == $0.splatCount }, "every chunk starts with its whole count as quota")
            XCTAssertTrue(entries.allSatisfy { $0.screenArea == Float($0.splatCount) }, "and its count as screen area: density 1, the uniform rule, until the first cull")
        }
        // The table's first splats tile the buffer.
        let constants = UnsafeBufferPointer(start: table.constantsBuffer.contents().bindMemory(to: GaussianChunkDecodeConstants.self, capacity: table.chunkCount), count: table.chunkCount)
        var next: UInt32 = 0
        for chunk in constants {
            XCTAssertEqual(chunk.firstSplat, next)
            next += chunk.splatCount
        }
        XCTAssertEqual(next, UInt32(component.splatCount))

        // Per splat only the 16-byte record (and its harmonics) stays resident: no encoded
        // buffer, no per-slot index buffers, and the estimate says so.
        let packed = try XCTUnwrap(component.packedSplatData)
        XCTAssertEqual(packed.length, Int(component.splatCount) * UntoldGSFormat.coreRecordSize)
        XCTAssertNil(component.encodedSplatData)
        XCTAssertTrue(component.gaussianVisibleIndices.isEmpty)
        XCTAssertTrue(component.gaussianVisibleCount.isEmpty)
        XCTAssertEqual(component.estimatedGPUBytes, packed.length + (component.sphericalHarmonicsData?.length ?? 0) + table.gpuBytes)
    }

    func testPLYEntityHasNoChunkTable() throws {
        let entity = createEntity()
        setEntityGaussian(entityId: entity, filename: "test_gaussians", withExtension: "ply")
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        XCTAssertNil(component.chunkTable, "a .ply keeps the whole-buffer per-splat cull")
        placeGaussianTestCamera(eye: cameras[0].eye, target: cameras[0].target)
        runSynchronously { executeGaussianFrustumCulling($0) }
        let visible = try visibleSplatIndices(component, slot: frameSlot(for: component))
        XCTAssertGreaterThan(visible.count, 0)
    }

    // MARK: - (b) GPU chunks match the CPU mirror; the per-splat cull's survivors lie in them

    func testChunkCullMatchesTheCPUMirrorAndBoundsThePerSplatCull() throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = true
        let (entity, component, table) = try loadChunkedEntity()
        let owner = chunkOfSplat(table)
        XCTAssertEqual(owner.count, Int(component.splatCount))

        for (cameraIndex, camera) in cameras.enumerated() {
            let cameraEntity = placeGaussianTestCamera(eye: camera.eye, target: camera.target)
            defer { destroyEntity(entityId: cameraEntity) }
            let viewProjection = try headViewProjection(entity: entity)
            let expected = expectedVisibleChunks(table, viewProjections: [viewProjection])

            GaussianDebugOptions.shared.disableChunkCull = false
            let chunkedSurvivors = try compactedSurvivors()
            let slot = frameSlot(for: component)
            let culled = visibleChunkReadback(table, slot: slot)

            XCTAssertEqual(culled.chunks, expected, "camera \(cameraIndex): the GPU keeps the chunks the CPU mirror predicts")
            XCTAssertEqual(expected.count, expectedVisibleChunkCounts[cameraIndex], "camera \(cameraIndex): the CPU mirror sees the promised \(expectedVisibleChunkCounts[cameraIndex]) of \(expectedChunkCount) chunks")
            if cameraIndex > 0 {
                XCTAssertLessThan(culled.chunks.count, expectedChunkCount, "camera \(cameraIndex): the frustum boundary is exercised — some chunk is culled")
            }
            XCTAssertEqual(culled.record.threadgroupsPerGrid.0, culled.record.threadgroupCount, "camera \(cameraIndex): one threadgroup per visible chunk")
            let expectedSplatTotal = culled.chunks.reduce(UInt32(0)) { $0 + table.index.chunks[Int($1)].splatCount }
            XCTAssertEqual(culled.record.instanceCount, expectedSplatTotal, "camera \(cameraIndex): the record keeps the visible chunks' splat total as the request")
            XCTAssertEqual(culled.record.visibleCount, expectedSplatTotal, "camera \(cameraIndex): with the budget unlimited every chunk is granted its whole count")
            XCTAssertTrue(culled.entries.allSatisfy { $0.quota == $0.splatCount }, "camera \(cameraIndex): unlimited budget, whole quotas")
            // The clipped screen area of every entry is the CPU mirror's (mono, HZB off).
            let chunkConstants = UnsafeBufferPointer(start: table.constantsBuffer.contents().bindMemory(to: GaussianChunkDecodeConstants.self, capacity: table.chunkCount), count: table.chunkCount)
            let frameConstants = gaussianChunkCullConstants(chunkTable: table, modelMatrix: matrix_identity_float4x4, viewMatrix: matrix_identity_float4x4, hzbValid: false, forceAllVisible: false, uniformQuotas: false)
            var mirrorConstants = frameConstants
            mirrorConstants.viewProjection0 = viewProjection
            mirrorConstants.viewProjection1 = viewProjection
            mirrorConstants.viewCount = 1
            for entry in culled.entries {
                XCTAssertGreaterThan(entry.screenArea, 0, "camera \(cameraIndex) chunk \(entry.chunkIndex): a kept chunk has a screen area")
                let expectedArea = GaussianChunkCullMath.chunkScreenArea(chunk: chunkConstants[Int(entry.chunkIndex)], constants: mirrorConstants)
                XCTAssertEqual(entry.screenArea, expectedArea, accuracy: max(1e-5 * expectedArea, 1e-6), "camera \(cameraIndex) chunk \(entry.chunkIndex): the screen area is the CPU mirror's")
            }
            XCTAssertLessThanOrEqual(UInt32(chunkedSurvivors.count), culled.record.visibleCount)
            XCTAssertEqual(Set(chunkedSurvivors).count, chunkedSurvivors.count, "camera \(cameraIndex): each splat appears once")

            // The debug switch: every chunk forced visible, the per-splat test alone decides —
            // still the fused pass, over all 13 chunks.
            GaussianDebugOptions.shared.disableChunkCull = true
            let forcedSurvivors = try compactedSurvivors()
            let forced = visibleChunkReadback(table, slot: slot)
            XCTAssertEqual(forced.chunks.count, expectedChunkCount, "camera \(cameraIndex): disableChunkCull keeps every chunk")
            GaussianDebugOptions.shared.disableChunkCull = false

            // The independent oracle: the whole-buffer gaussianFrustumCull and gaussianPreprocess
            // over the legacy twin's encoded buffer and per-slot buffers, which never touch the
            // chunk table or kernels.
            let legacy = try legacySurvivors(component)
            XCTAssertTrue(component.isChunked, "the chunk table and packed records are back after the legacy run")

            XCTAssertGreaterThan(legacy.count, 0, "camera \(cameraIndex): sanity — the camera sees part of the asset")
            let strays = legacy.filter { !culled.chunks.contains(owner[Int($0)]) }
            XCTAssertEqual(strays.count, 0, "camera \(cameraIndex): \(strays.count) splats the whole-buffer cull keeps lie in chunks the chunk cull dropped")
            XCTAssertEqual(Set(chunkedSurvivors), Set(legacy), "camera \(cameraIndex): the fused pass keeps exactly what the whole-buffer path keeps")
            XCTAssertEqual(chunkedSurvivors.count, legacy.count, "camera \(cameraIndex): and each once")
            XCTAssertEqual(Set(forcedSurvivors), Set(legacy), "camera \(cameraIndex): with every chunk forced visible the fused pass keeps exactly what the whole-buffer path keeps")
        }
    }

    // MARK: - The fused pass strides over a chunk wider than its threadgroup

    /// Real assets hold 1024 or 4096 splats per chunk, so each thread of the fused pass visits
    /// several ranks; the fixture's 16-splat chunks fit one pass at the width the frame
    /// dispatches. Dispatching the kernel by hand with 1, 4 and 16 threads per group makes it
    /// stride 16, 4 and 1 times over every chunk, and each time it has to compact exactly what
    /// the whole-buffer path compacts.
    func testFusedPassStridesOverWideChunks() throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = true
        let (entity, component, table) = try loadChunkedEntity()
        placeGaussianTestCamera(eye: cameras[1].eye, target: cameras[1].target)
        let legacy = try legacySurvivors(component)
        XCTAssertGreaterThan(legacy.count, 0)
        XCTAssertLessThan(legacy.count, Int(component.splatCount), "sanity — the close view culls some splats")

        // Every chunk listed in the slot with its whole quota, as disableChunkCull leaves it.
        GaussianDebugOptions.shared.disableChunkCull = true
        runSynchronously { executeGaussianFrustumCulling($0) }
        let slot = frameSlot(for: component)
        XCTAssertEqual(visibleChunkReadback(table, slot: slot).chunks.count, expectedChunkCount)

        // The fused pass's inputs as executeGaussianPreprocess binds them.
        let camera = try XCTUnwrap(CameraSystem.shared.activeCamera)
        let cameraComponent = try XCTUnwrap(scene.get(component: CameraComponent.self, for: camera))
        let world = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: entity))
        let viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        var uniforms = Uniforms()
        uniforms.modelMatrix = world.space
        uniforms.viewMatrix = viewMatrix
        uniforms.modelViewMatrix = simd_mul(viewMatrix, world.space)
        uniforms.projectionMatrix = renderInfo.perspectiveSpace
        var entityConstants = GaussianPreprocessEntityConstants()
        entityConstants.workingSetCapacity = UInt32(GaussianSharedWorkingSet.shared.capacity)
        entityConstants.colorGain = simd_float4(1, 1, 1, 1)
        entityConstants.opacityScale = 1
        let packedSplats = try XCTUnwrap(component.packedSplatData)
        let inputs = GaussianChunkPreprocessInputs(
            packedSplats: packedSplats,
            chunkTable: table,
            visibleChunks: table.visibleChunks[slot],
            uniforms: uniforms,
            cullConstants: gaussianChunkCullConstants(chunkTable: table, modelMatrix: world.space, viewMatrix: viewMatrix, hzbValid: false, uniformQuotas: false),
            viewport: renderInfo.viewPort ?? simd_float2(1, 1),
            sphericalHarmonics: component.sphericalHarmonicsData,
            shMetadata: component.sphericalHarmonicsMetadata ?? GaussianSHMetadata(degree: 0, coefficientsPerChannel: 0, higherOrderCoefficientsPerSplat: 0, _pad0: 0),
            localCameraPosition: gaussianLocalCameraPosition(cameraWorldPosition: SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition), modelMatrix: world.space),
            entityConstants: entityConstants,
            hzbTexture: textureResources.depthMap
        )
        let pipeline = try XCTUnwrap(GaussianChunkCullPipelineStates.current()).decodePreprocess
        let sharedSlot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
        let workingSet = GaussianSharedWorkingSet.shared
        let sharedSet = try XCTUnwrap(workingSet.visibleSet(slot: sharedSlot))

        for threadsPerChunk in [1, 4, 16] {
            sharedSet.contents().storeBytes(of: makeGaussianVisibleSet(visibleCount: 0), as: GaussianVisibleSet.self)
            runSynchronously { commandBuffer in
                guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
                encodeGaussianChunkDecodePreprocess(
                    encoder,
                    pipelineState: pipeline,
                    inputs: inputs,
                    chunkSet: table.visibleChunkSets[slot],
                    sharedRecords: workingSet.records(slot: sharedSlot)!,
                    sharedKeys: workingSet.keys(slot: sharedSlot)!,
                    sharedVisibleSet: sharedSet,
                    threadsPerThreadgroup: threadsPerChunk,
                    threadgroups: expectedChunkCount
                )
                encoder.endEncoding()
            }
            let strided = try XCTUnwrap(indexResolver).indices(of: sharedGaussianRecords())
            XCTAssertEqual(strided.count, legacy.count, "\(threadsPerChunk) threads per chunk: the strided pass keeps each survivor once")
            XCTAssertEqual(Set(strided), Set(legacy), "\(threadsPerChunk) threads per chunk: the strided pass keeps exactly what the whole-buffer path keeps")
        }
    }

    // MARK: - (c) The frame is the same with the chunk cull on and off

    func testChunkCullRendersTheSameFrame() throws {
        let (_, component, _) = try loadChunkedEntity()
        for hzbEnabled in [false, true] {
            GaussianDebugOptions.shared.disableHZBOcclusionCull = !hzbEnabled
            for (cameraIndex, camera) in cameras.enumerated() {
                let cameraEntity = placeGaussianTestCamera(eye: camera.eye, target: camera.target)
                defer { destroyEntity(entityId: cameraEntity) }

                // The HZB is temporal: one frame builds the pyramid the next frame's cull reads.
                GaussianDebugOptions.shared.disableChunkCull = false
                _ = renderGaussianSplatLayer()
                if hzbEnabled {
                    XCTAssertTrue(renderInfo.hzbIsValid, "a rendered frame leaves a valid HZB behind")
                }
                let chunked = renderGaussianSplatLayer()
                let chunkedVisible = sharedGaussianVisibleCount()

                GaussianDebugOptions.shared.disableChunkCull = true
                _ = renderGaussianSplatLayer()
                let legacy = renderGaussianSplatLayer()
                let legacyVisible = sharedGaussianVisibleCount()

                // The whole-buffer path on the legacy twin: the frame this file rendered before
                // the chunk path existed, never through the chunk code.
                GaussianDebugOptions.shared.disableChunkCull = false
                let (kernel, kernelVisible) = try legacyFrame(component)

                let quality = compareGaussianSplatLayers(chunked, legacy)
                XCTAssertGreaterThan(quality.covered, 500, "camera \(cameraIndex) hzb=\(hzbEnabled): sanity — the asset covers part of the frame")
                XCTAssertEqual(chunkedVisible, legacyVisible, "camera \(cameraIndex) hzb=\(hzbEnabled): the same splats reach the shared set with the chunk cull on and off")
                XCTAssertLessThanOrEqual(quality.differingPixels, 50, "camera \(cameraIndex) hzb=\(hzbEnabled): \(quality.differingPixels) of \(quality.covered) covered pixels differ by more than one 8-bit step between the chunk cull on and off")
                XCTAssertGreaterThan(quality.psnr, 55, "camera \(cameraIndex) hzb=\(hzbEnabled): \(quality.psnr) dB over covered pixels between the chunk cull on and off")

                let kernelQuality = compareGaussianSplatLayers(chunked, kernel)
                XCTAssertEqual(chunkedVisible, kernelVisible, "camera \(cameraIndex) hzb=\(hzbEnabled): the fused pass sends the same splats to the shared set as the whole-buffer path")
                XCTAssertLessThanOrEqual(kernelQuality.differingPixels, 50, "camera \(cameraIndex) hzb=\(hzbEnabled): \(kernelQuality.differingPixels) of \(kernelQuality.covered) covered pixels differ by more than one 8-bit step from the whole-buffer path's frame")
                XCTAssertGreaterThan(kernelQuality.psnr, 55, "camera \(cameraIndex) hzb=\(hzbEnabled): \(kernelQuality.psnr) dB over covered pixels against the whole-buffer path's frame")
            }
        }
    }

    // MARK: - (d) A partial view culls chunks

    func testPartialViewCullsChunks() throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = true
        GaussianDebugOptions.shared.disableChunkCull = false
        let (entity, component, table) = try loadChunkedEntity()
        placeGaussianTestCamera(eye: cameras[1].eye, target: cameras[1].target)
        let viewProjection = try headViewProjection(entity: entity)

        let survivors = try compactedSurvivors()
        let slot = frameSlot(for: component)
        let culled = visibleChunkReadback(table, slot: slot)

        XCTAssertGreaterThan(culled.chunks.count, 0, "the camera looks at part of the asset")
        XCTAssertLessThan(culled.chunks.count, expectedChunkCount, "a close view of one corner leaves chunks outside the frustum")
        XCTAssertEqual(culled.chunks, expectedVisibleChunks(table, viewProjections: [viewProjection]))
        XCTAssertGreaterThan(survivors.count, 0)
        XCTAssertLessThan(survivors.count, Int(component.splatCount))
    }

    // MARK: - (e) Either eye keeps a chunk

    /// Two views: eye 0 looks away from the asset, eye 1 at it. The predicate is "visible to
    /// either eye", so every chunk eye 1 sees survives — on the CPU mirror and on the GPU kernel
    /// driven with the two matrices the way a stereo frame drives it.
    func testChunkVisibleToOneEyeSurvives() throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = true
        let (entity, _, table) = try loadChunkedEntity()
        placeGaussianTestCamera(eye: cameras[0].eye, target: cameras[0].target)
        let world = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: entity))
        let lookingAt = try headViewProjection(entity: entity)
        // The same camera turned around: the asset is behind it.
        let cameraEntity = try XCTUnwrap(CameraSystem.shared.activeCamera)
        cameraLookAt(entityId: cameraEntity, eye: cameras[0].eye, target: cameras[0].eye * 2, up: simd_float3(0, 1, 0))
        let awayView = try XCTUnwrap(scene.get(component: CameraComponent.self, for: cameraEntity)).viewSpace
        let lookingAway = simd_mul(renderInfo.perspectiveSpace, simd_mul(awayView, world.space))

        let seenByEye1 = expectedVisibleChunks(table, viewProjections: [lookingAt])
        let seenByEye0 = expectedVisibleChunks(table, viewProjections: [lookingAway])
        XCTAssertEqual(seenByEye0.count, 0, "sanity — nothing is in front of the turned camera")
        XCTAssertGreaterThan(seenByEye1.count, 0, "sanity — the camera sees the asset")

        // CPU mirror: either eye.
        let eitherEye = expectedVisibleChunks(table, viewProjections: [lookingAway, lookingAt])
        XCTAssertEqual(eitherEye, seenByEye1)
        for (index, entry) in table.index.chunks.enumerated() where seenByEye1.contains(UInt32(index)) {
            XCTAssertFalse(GaussianChunkCullMath.chunkIsVisible(entry, viewProjections: [lookingAway]))
            XCTAssertTrue(GaussianChunkCullMath.chunkIsVisible(entry, viewProjections: [lookingAway, lookingAt]), "chunk \(index) outside eye 0 but inside eye 1 is visible")
        }

        // GPU kernel with eye 0 = away, eye 1 = at, as a stereo frame binds them.
        var constants = gaussianChunkCullConstants(chunkTable: table, modelMatrix: world.space, viewMatrix: matrix_identity_float4x4, hzbValid: false, forceAllVisible: false, uniformQuotas: false)
        constants.viewProjection0 = lookingAway
        constants.viewProjection1 = lookingAt
        constants.viewCount = 2
        XCTAssertEqual(try cullChunks(table, constants: constants).chunks, seenByEye1, "the GPU keeps every chunk eye 1 sees although eye 0 sees none")

        // And with eye 0 alone (viewCount 1) the away view keeps nothing.
        constants.viewCount = 1
        let awayOnly = try cullChunks(table, constants: constants)
        XCTAssertEqual(awayOnly.chunks.count, 0)
        XCTAssertEqual(awayOnly.record.threadgroupsPerGrid.0, 0)
        XCTAssertEqual(awayOnly.record.visibleCount, 0)
    }

    /// The same for the fused pass: driven with eye 0 looking away and eye 1 at the asset (the
    /// head-centre uniforms of eye 1), it compacts every splat the whole-buffer path keeps for
    /// eye 1; with eye 0 alone it compacts nothing. In a stereo frame a splat only one eye sees
    /// is therefore drawn, where the whole-buffer path would have culled it against the head.
    func testFusedPassKeepsASplatOnlyEyeOneSees() throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = true
        let (entity, component, table) = try loadChunkedEntity()
        placeGaussianTestCamera(eye: cameras[0].eye, target: cameras[0].target)
        let lookingAt = try headViewProjection(entity: entity)
        let legacy = try legacySurvivors(component)
        XCTAssertGreaterThan(legacy.count, 0)
        let lookingAway = try lookingAwayViewProjection(entity: entity)
        XCTAssertEqual(expectedVisibleChunks(table, viewProjections: [lookingAway]).count, 0, "sanity — nothing is in front of the turned camera")

        var constants = try stereoConstants(table: table, entity: entity, eye0: lookingAway, eye1: lookingAt)
        let eitherEye = try fusedPassSurvivors(entity: entity, component: component, table: table, constants: constants)
        XCTAssertEqual(Set(eitherEye), Set(legacy), "with eye 0 seeing nothing the fused pass keeps every splat eye 1 sees")
        XCTAssertEqual(eitherEye.count, legacy.count)

        constants.viewCount = 1
        XCTAssertEqual(try fusedPassSurvivors(entity: entity, component: component, table: table, constants: constants).count, 0, "eye 0 alone, looking away, keeps nothing")
    }

    /// Mirrored: eye 0 at the asset, eye 1 away. Eye 0's matrix alone decides, so a stereo
    /// branch that only read eye 1 would keep nothing here — for the chunk kernel and the fused
    /// pass. In mono (viewCount 1) the head-centre uniforms decide and the eye matrices are
    /// ignored.
    func testFusedPassKeepsASplatOnlyEyeZeroSees() throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = true
        let (entity, component, table) = try loadChunkedEntity()
        placeGaussianTestCamera(eye: cameras[0].eye, target: cameras[0].target)
        let lookingAt = try headViewProjection(entity: entity)
        let legacy = try legacySurvivors(component)
        XCTAssertGreaterThan(legacy.count, 0)
        let lookingAway = try lookingAwayViewProjection(entity: entity)
        let seenByEye0 = expectedVisibleChunks(table, viewProjections: [lookingAt])
        XCTAssertEqual(seenByEye0.count, expectedChunkCount)

        var constants = try stereoConstants(table: table, entity: entity, eye0: lookingAt, eye1: lookingAway)
        XCTAssertEqual(try cullChunks(table, constants: constants).chunks, seenByEye0, "the chunk kernel keeps every chunk eye 0 sees although eye 1 sees none")
        let eitherEye = try fusedPassSurvivors(entity: entity, component: component, table: table, constants: constants)
        XCTAssertEqual(Set(eitherEye), Set(legacy), "with eye 1 seeing nothing the fused pass keeps every splat eye 0 sees")
        XCTAssertEqual(eitherEye.count, legacy.count)

        // Mono with the eye matrices swapped to the away view: the head-centre uniforms decide.
        constants.viewProjection0 = lookingAway
        constants.viewProjection1 = lookingAway
        constants.viewCount = 1
        var forced = constants
        forced.forceAllVisible = 1
        XCTAssertEqual(try Set(fusedPassSurvivors(entity: entity, component: component, table: table, constants: forced)), Set(legacy), "in mono the fused pass tests against the head-centre uniforms, not the eye matrices")
    }

    /// Two eyes that each miss part of the asset — the corner view and the −x view — keep the
    /// union of what each keeps alone, strictly more than either: on the chunk kernel against the
    /// CPU mirror, and on the fused pass against the whole-buffer path run at each view.
    func testStereoKeepsTheUnionOfTwoPartialViews() throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = true
        let (entity, component, table) = try loadChunkedEntity()

        placeGaussianTestCamera(eye: cameras[1].eye, target: cameras[1].target)
        let cornerViewProjection = try headViewProjection(entity: entity)
        let cornerLegacy = try Set(legacySurvivors(component))
        // The −x view is the head-centre view the fused pass projects with; its splats all lie
        // in front of both cameras, so either can be the head.
        placeGaussianTestCamera(eye: cameras[2].eye, target: cameras[2].target)
        let sideViewProjection = try headViewProjection(entity: entity)
        let sideLegacy = try Set(legacySurvivors(component))
        XCTAssertFalse(cornerLegacy.isSubset(of: sideLegacy), "sanity — the corner view keeps splats the −x view culls")
        XCTAssertFalse(sideLegacy.isSubset(of: cornerLegacy), "sanity — and the other way round")

        let cornerChunks = expectedVisibleChunks(table, viewProjections: [cornerViewProjection])
        let sideChunks = expectedVisibleChunks(table, viewProjections: [sideViewProjection])
        let unionChunks = expectedVisibleChunks(table, viewProjections: [cornerViewProjection, sideViewProjection])
        XCTAssertEqual(unionChunks, cornerChunks.union(sideChunks))
        XCTAssertGreaterThan(unionChunks.count, max(cornerChunks.count, sideChunks.count), "sanity — each view misses a chunk the other keeps")

        let constants = try stereoConstants(table: table, entity: entity, eye0: cornerViewProjection, eye1: sideViewProjection)
        XCTAssertEqual(try cullChunks(table, constants: constants).chunks, unionChunks, "the chunk kernel keeps the union of the two eyes")
        let survivors = try fusedPassSurvivors(entity: entity, component: component, table: table, constants: constants)
        XCTAssertEqual(Set(survivors), cornerLegacy.union(sideLegacy), "the fused pass keeps the union of what the whole-buffer path keeps at each eye")
        XCTAssertEqual(survivors.count, cornerLegacy.union(sideLegacy).count, "each once")
        XCTAssertGreaterThan(survivors.count, max(cornerLegacy.count, sideLegacy.count))

        // Swapping the eyes changes nothing.
        let swapped = try stereoConstants(table: table, entity: entity, eye0: sideViewProjection, eye1: cornerViewProjection)
        XCTAssertEqual(try cullChunks(table, constants: swapped).chunks, unionChunks)
        XCTAssertEqual(try Set(fusedPassSurvivors(entity: entity, component: component, table: table, constants: swapped)), cornerLegacy.union(sideLegacy))
    }

    /// The HZB is the mono pyramid of the last eye drawn (eye 1), so in stereo only eye 1's
    /// test samples it: a solid pyramid culls nothing eye 0 sees and everything eye 1 sees —
    /// on the chunk kernel and the fused pass — while in mono it culls everything as before.
    func testStereoSamplesTheHZBForEyeOneOnly() throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = true
        let (entity, component, table) = try loadChunkedEntity()
        placeGaussianTestCamera(eye: cameras[0].eye, target: cameras[0].target)
        let lookingAt = try headViewProjection(entity: entity)
        let legacyWithoutHZB = try Set(legacySurvivors(component))
        XCTAssertGreaterThan(legacyWithoutHZB.count, 0)
        let lookingAway = try lookingAwayViewProjection(entity: entity)
        let allChunks = expectedVisibleChunks(table, viewProjections: [lookingAt])
        XCTAssertEqual(allChunks.count, expectedChunkCount)

        GaussianDebugOptions.shared.disableHZBOcclusionCull = false
        try withInjectedHZB(depths: [nearDepth], valid: true) {
            // Eye 0 sees the asset, eye 1 looks away: eye 0 decides by its frustum alone.
            let eyeZeroSees = try stereoConstants(table: table, entity: entity, eye0: lookingAt, eye1: lookingAway, hzbValid: true)
            XCTAssertEqual(eyeZeroSees.hzbValid, 1)
            XCTAssertEqual(try cullChunks(table, constants: eyeZeroSees).chunks, allChunks, "the solid pyramid is not eye 0's: every chunk eye 0 sees survives")
            XCTAssertEqual(try Set(fusedPassSurvivors(entity: entity, component: component, table: table, constants: eyeZeroSees)), legacyWithoutHZB, "and so does every splat eye 0 sees")

            // Eye 0 looks away, eye 1 sees the asset behind the occluder: nothing survives.
            let eyeOneSees = try stereoConstants(table: table, entity: entity, eye0: lookingAway, eye1: lookingAt, hzbValid: true)
            XCTAssertEqual(try cullChunks(table, constants: eyeOneSees).chunks.count, 0, "eye 1's test samples the pyramid")
            XCTAssertEqual(try fusedPassSurvivors(entity: entity, component: component, table: table, constants: eyeOneSees).count, 0)

            // Mono: the head view is the pyramid's, and it culls everything.
            var mono = eyeZeroSees
            mono.viewCount = 1
            XCTAssertEqual(try cullChunks(table, constants: mono).chunks.count, 0)
            XCTAssertEqual(try fusedPassSurvivors(entity: entity, component: component, table: table, constants: mono).count, 0)
        }
    }

    // MARK: - Spherical harmonics by original splat index

    /// A synthetic asset with distinct degree-1 harmonics per splat in four chunks: for every
    /// compacted splat the fused pass's colour is the whole-buffer path's for the same splat at
    /// each of the three cameras (the harmonics are read by original index, so a chunk's second
    /// splat does not get the first's), the colour is view-dependent, and the frames match.
    func testFusedPassEvaluatesHarmonicsByOriginalSplatIndex() throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = true
        GaussianDebugOptions.shared.disableChunkCull = false
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianChunkCullTest-SH-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")
        try GaussianSyntheticAsset.writeHarmonicsAsset(splatCount: 256, degree: 1, log2ChunkSplats: 6, to: url)
        temporaryFiles.append(url)
        let entity = createEntity()
        setEntityGaussian(entityId: entity, filename: url.deletingPathExtension().path, withExtension: "untoldgs")
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        let table = try XCTUnwrap(component.chunkTable)
        XCTAssertEqual(table.chunkCount, 4)
        XCTAssertTrue(table.index.chunks.dropLast().allSatisfy { $0.splatCount == 64 })
        let metadata = try XCTUnwrap(component.sphericalHarmonicsMetadata, "the load keeps the harmonics")
        XCTAssertEqual(metadata.degree, 1)
        XCTAssertEqual(try XCTUnwrap(component.sphericalHarmonicsData).length, 256 * 9)
        legacyTwin = try GaussianLegacyTwin(loaded: GaussianChunkLoader.load(url: url))
        XCTAssertNotNil(legacyTwin?.result.sphericalHarmonicsBuffer)
        indexResolver = try GaussianSplatIndexResolver(positions: UntoldGSFormat.read(from: url).encodedSplats.map(\.position))

        func coloursByIndex() throws -> [UInt32: simd_float3] {
            let records = sharedGaussianRecords()
            let indices = try XCTUnwrap(indexResolver).indices(of: records)
            var colours: [UInt32: simd_float3] = [:]
            for (record, index) in zip(records, indices) {
                colours[index] = simd_float3(record.color.x, record.color.y, record.color.z)
            }
            XCTAssertEqual(colours.count, records.count, "each splat once")
            return colours
        }

        var coloursPerCamera: [[UInt32: simd_float3]] = []
        for (cameraIndex, camera) in cameras.enumerated() {
            let cameraEntity = placeGaussianTestCamera(eye: camera.eye, target: camera.target)
            defer { destroyEntity(entityId: cameraEntity) }

            runGaussianCullAndPreprocess()
            let fused = try coloursByIndex()
            let legacy = try XCTUnwrap(legacyTwin).withLegacyBuffers(component) {
                runGaussianCullAndPreprocess()
                return try coloursByIndex()
            }
            XCTAssertGreaterThan(fused.count, 10, "camera \(cameraIndex): sanity — part of the cloud is in view")
            XCTAssertEqual(Set(fused.keys), Set(legacy.keys), "camera \(cameraIndex): the same splats")
            var maxDelta: Float = 0
            for (index, colour) in fused {
                guard let expected = legacy[index] else { continue }
                maxDelta = max(maxDelta, simd_reduce_max(abs(colour - expected)))
            }
            XCTAssertLessThanOrEqual(maxDelta, 1e-3, "camera \(cameraIndex): the fused pass reads each splat's harmonics by its original index — largest channel difference \(maxDelta)")
            coloursPerCamera.append(fused)

            _ = renderGaussianSplatLayer()
            let chunked = renderGaussianSplatLayer()
            let (kernel, _) = try legacyFrame(component)
            let quality = compareGaussianSplatLayers(chunked, kernel)
            XCTAssertGreaterThan(quality.covered, 500, "camera \(cameraIndex): sanity — the cloud covers part of the frame")
            XCTAssertLessThanOrEqual(quality.differingPixels, 50, "camera \(cameraIndex): \(quality.differingPixels) of \(quality.covered) covered pixels differ by more than one 8-bit step from the whole-buffer path's frame")
            XCTAssertGreaterThan(quality.psnr, 55, "camera \(cameraIndex): \(quality.psnr) dB over covered pixels")
        }

        // The harmonics do something: a splat's colour differs between the far and the −x view.
        let shared = Set(coloursPerCamera[0].keys).intersection(coloursPerCamera[2].keys)
        XCTAssertGreaterThan(shared.count, 30)
        let viewDependent = shared.filter { simd_reduce_max(abs(coloursPerCamera[0][$0]! - coloursPerCamera[2][$0]!)) > 1e-3 }
        XCTAssertGreaterThan(viewDependent.count, shared.count / 2, "the colour is view-dependent for most splats, so the oracle is not the base colour")
    }

    // MARK: - (f) The HZB part of the chunk test

    /// A full-frame occluder right in front of the camera: no chunk survives, no splat is
    /// appended; with the chunk stage forced open every chunk is listed and the per-splat HZB
    /// test still keeps nothing.
    func testChunkCullAgainstASolidHZBCullsEveryChunk() throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = false
        let (_, component, table) = try loadChunkedEntity()
        placeGaussianTestCamera(eye: cameras[0].eye, target: cameras[0].target)
        try withInjectedHZB(depths: [nearDepth], valid: true) {
            GaussianDebugOptions.shared.disableChunkCull = false
            XCTAssertEqual(try compactedSurvivors().count, 0)
            let slot = frameSlot(for: component)
            let culled = visibleChunkReadback(table, slot: slot)
            XCTAssertEqual(culled.chunks.count, 0, "every chunk lies behind the occluder")
            XCTAssertEqual(culled.record.threadgroupsPerGrid.0, 0)
            XCTAssertEqual(culled.record.visibleCount, 0)

            GaussianDebugOptions.shared.disableChunkCull = true
            XCTAssertEqual(try compactedSurvivors().count, 0, "the per-splat HZB test culls what the chunk stage let through")
            let forced = visibleChunkReadback(table, slot: slot)
            XCTAssertEqual(forced.chunks.count, expectedChunkCount, "disableChunkCull lists every chunk regardless of the HZB")
        }
    }

    /// A pyramid at the far plane occludes nothing: the chunk set and the survivors are the
    /// frustum-only ones.
    func testChunkCullAgainstAFarHZBMatchesTheFrustum() throws {
        let (entity, component, table) = try loadChunkedEntity()
        placeGaussianTestCamera(eye: cameras[1].eye, target: cameras[1].target)
        GaussianDebugOptions.shared.disableChunkCull = false
        let slot = frameSlot(for: component)
        let frustumOnly = try expectedVisibleChunks(table, viewProjections: [headViewProjection(entity: entity)])

        GaussianDebugOptions.shared.disableHZBOcclusionCull = true
        let frustumSurvivors = try compactedSurvivors()
        XCTAssertEqual(visibleChunkReadback(table, slot: slot).chunks, frustumOnly)

        GaussianDebugOptions.shared.disableHZBOcclusionCull = false
        try withInjectedHZB(depths: [farDepth], valid: true) {
            let survivors = try compactedSurvivors()
            XCTAssertEqual(visibleChunkReadback(table, slot: slot).chunks, frustumOnly, "nothing is behind the far plane")
            XCTAssertEqual(Set(survivors), Set(frustumSurvivors))
        }
    }

    /// The horizontal screen span (u, 0 left to 1 right) of a chunk's padded box under
    /// `viewProjection`, the rect `projectAABBToScreenRect` builds for the HZB test.
    private func screenURange(_ entry: UntoldGSChunkEntry, viewProjection: simd_float4x4) -> (min: Float, max: Float) {
        let box = GaussianChunkCullMath.paddedBox(aabbMin: entry.aabbMin, aabbMax: entry.aabbMax, logScaleMax: entry.logScaleMax)
        var range: (min: Float, max: Float) = (1, 0)
        for c in 0 ..< 8 {
            let corner = simd_float3((c & 1) != 0 ? box.max.x : box.min.x, (c & 2) != 0 ? box.max.y : box.min.y, (c & 4) != 0 ? box.max.z : box.min.z)
            let clip = simd_mul(viewProjection, simd_float4(corner, 1))
            let u = (clip.x / clip.w) * 0.5 + 0.5
            range.min = min(range.min, u)
            range.max = max(range.max, u)
        }
        return range
    }

    /// An occluder over a vertical band of the frame: the chunks whose rect lies inside the band
    /// are culled, chunks straddling its edge or outside it survive (the 5×5 samples reach the
    /// open texels), and every splat the per-splat pass keeps against the same pyramid lies in
    /// a surviving chunk — with the chunk cull on, forced open, and through the whole-buffer
    /// kernel. The band starts at the left edge of the right-most chunk, so at least that chunk
    /// is inside it; the fixture's Morton chunks span most of the width, so a plain half split
    /// would isolate none.
    func testChunkCullAgainstABandOccludingHZBCullsOnlyOccludedChunks() throws {
        let (entity, component, table) = try loadChunkedEntity()
        let owner = chunkOfSplat(table)
        placeGaussianTestCamera(eye: cameras[0].eye, target: cameras[0].target)
        GaussianDebugOptions.shared.disableChunkCull = false
        let slot = frameSlot(for: component)
        let viewProjection = try headViewProjection(entity: entity)
        let frustumOnly = expectedVisibleChunks(table, viewProjections: [viewProjection])
        XCTAssertEqual(frustumOnly.count, expectedChunkCount, "sanity — the far camera sees every chunk")

        // The band: texel columns from the right-most chunk's left edge (one texel of margin
        // so no sample of that chunk lands on the edge) to the right edge of the screen.
        let texelCount = 64
        let ranges = table.index.chunks.map { screenURange($0, viewProjection: viewProjection) }
        let rightMost = try XCTUnwrap(ranges.indices.max { ranges[$0].min < ranges[$1].min })
        let bandStart = max(0, Int(ranges[rightMost].min * Float(texelCount)) - 1)
        let bandEdge = Float(bandStart) / Float(texelCount)
        XCTAssertGreaterThan(bandStart, 0, "sanity — the right-most chunk is not at the left edge")
        XCTAssertLessThan(bandEdge, ranges[rightMost].min)
        let expectedOccluded = Set(ranges.indices.filter { ranges[$0].min >= bandEdge }.map { UInt32($0) })
        XCTAssertTrue(expectedOccluded.contains(UInt32(rightMost)))
        XCTAssertLessThan(expectedOccluded.count, expectedChunkCount, "sanity — some chunk straddles or misses the band")
        let depths = (0 ..< texelCount).map { $0 >= bandStart ? nearDepth : farDepth }

        GaussianDebugOptions.shared.disableHZBOcclusionCull = true
        let frustumSurvivors = try Set(compactedSurvivors())

        GaussianDebugOptions.shared.disableHZBOcclusionCull = false
        try withInjectedHZB(depths: depths, valid: true) {
            let chunkedSurvivors = try compactedSurvivors()
            let culled = visibleChunkReadback(table, slot: slot)
            XCTAssertEqual(culled.chunks, frustumOnly.subtracting(expectedOccluded), "the chunks whose rect lies inside the band are culled, no others")
            XCTAssertFalse(culled.chunks.contains(UInt32(rightMost)), "the right-most chunk lies behind the occluder")
            XCTAssertGreaterThan(culled.chunks.count, 0, "chunks straddling the band's edge survive")
            XCTAssertEqual(culled.record.threadgroupsPerGrid.0, culled.record.threadgroupCount)
            XCTAssertGreaterThan(chunkedSurvivors.count, 0)
            XCTAssertTrue(Set(chunkedSurvivors).isSubset(of: frustumSurvivors), "the HZB only removes splats")
            XCTAssertLessThan(chunkedSurvivors.count, frustumSurvivors.count, "the band's splats are gone")
            XCTAssertEqual(chunkedSurvivors.filter { !culled.chunks.contains(owner[Int($0)]) }.count, 0, "every survivor lies in a surviving chunk")

            GaussianDebugOptions.shared.disableChunkCull = true
            let forcedSurvivors = try compactedSurvivors()
            GaussianDebugOptions.shared.disableChunkCull = false
            XCTAssertEqual(Set(forcedSurvivors), Set(chunkedSurvivors), "the per-splat HZB test alone keeps the same splats")
            let strays = forcedSurvivors.filter { !culled.chunks.contains(owner[Int($0)]) }
            XCTAssertEqual(strays.count, 0, "\(strays.count) splats the per-splat HZB test keeps lie in chunks the chunk HZB test dropped")

            let legacy = try legacySurvivors(component)
            XCTAssertEqual(Set(legacy), Set(chunkedSurvivors), "the whole-buffer path keeps the same splats against the same pyramid")
        }
    }

    /// An occluding pyramid marked invalid is ignored, as in the whole-buffer kernel.
    func testChunkCullIgnoresAnHZBMarkedInvalid() throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = false
        GaussianDebugOptions.shared.disableChunkCull = false
        let (entity, component, table) = try loadChunkedEntity()
        placeGaussianTestCamera(eye: cameras[1].eye, target: cameras[1].target)
        let frustumOnly = try expectedVisibleChunks(table, viewProjections: [headViewProjection(entity: entity)])
        try withInjectedHZB(depths: [nearDepth], valid: false) {
            let survivors = try compactedSurvivors()
            let slot = frameSlot(for: component)
            XCTAssertEqual(visibleChunkReadback(table, slot: slot).chunks, frustumOnly, "hzbIsValid=false disables the chunk HZB test regardless of the texture")
            XCTAssertGreaterThan(survivors.count, 0)
        }
    }

    // MARK: - (g) The extent padding

    /// The padding is kGaussianQuadSigma·exp(logScaleMax): a unit box just outside the guard
    /// band is culled while the chunk's largest splat is negligible, and kept once that splat's
    /// footprint (3.5σ of scale 0.5, 1.75 units) reaches into the band — on the CPU mirror.
    func testExtentPaddingKeepsAChunkWhoseSplatsReachIntoTheView() throws {
        let box = try boxJustOutsideTheGuardBand()
        XCTAssertEqual(GaussianChunkCullMath.extentPadding(logScaleMax: log(0.5)), 3.5 * 0.5, accuracy: 1e-5)
        XCTAssertLessThan(GaussianChunkCullMath.extentPadding(logScaleMax: -10), 1e-3)
        XCTAssertFalse(GaussianChunkCullMath.chunkIsVisible(aabbMin: box.min, aabbMax: box.max, logScaleMax: -10, viewProjections: [box.viewProjection]), "a box just outside the guard band with no splat extent is culled")
        XCTAssertTrue(GaussianChunkCullMath.chunkIsVisible(aabbMin: box.min, aabbMax: box.max, logScaleMax: log(0.5), viewProjections: [box.viewProjection]), "the same box holding a splat of scale 0.5 reaches into the view")
        // The padding is symmetric: the mirror's padded box grows by the same amount on every side.
        let padded = GaussianChunkCullMath.paddedBox(aabbMin: box.min, aabbMax: box.max, logScaleMax: log(0.5))
        XCTAssertEqual(padded.min, box.min - simd_float3(repeating: 1.75))
        XCTAssertEqual(padded.max, box.max + simd_float3(repeating: 1.75))
    }

    /// The same on the GPU kernel with a synthetic one-chunk table: the record flips from no
    /// visible chunk to one when only logScaleMax changes.
    func testGPUChunkCullPadsTheBoxByTheLargestSplat() throws {
        let box = try boxJustOutsideTheGuardBand()
        let table = try makeOneChunkTable(aabbMin: box.min, aabbMax: box.max, logScaleMax: -10)
        var constants = gaussianChunkCullConstants(chunkTable: table, modelMatrix: matrix_identity_float4x4, viewMatrix: matrix_identity_float4x4, hzbValid: false, forceAllVisible: false, uniformQuotas: false)
        constants.viewProjection0 = box.viewProjection
        constants.viewProjection1 = box.viewProjection
        constants.viewCount = 1
        XCTAssertEqual(constants.chunkCount, 1)

        let unpadded = try cullChunks(table, constants: constants)
        XCTAssertEqual(unpadded.record.threadgroupsPerGrid.0, 0, "no splat extent: the box just outside the guard band is culled")
        XCTAssertEqual(unpadded.record.visibleCount, 0)

        var chunk = table.constantsBuffer.contents().load(as: GaussianChunkDecodeConstants.self)
        chunk.logScaleMax = log(0.5)
        table.constantsBuffer.contents().storeBytes(of: chunk, as: GaussianChunkDecodeConstants.self)
        let padded = try cullChunks(table, constants: constants)
        XCTAssertEqual(padded.record.threadgroupsPerGrid.0, 1, "a splat of scale 0.5 pads the box by 1.75 into the view")
        XCTAssertEqual(padded.record.visibleCount, 16)
        XCTAssertEqual(padded.chunks, [0])

        // Dropping exp() or reading logScaleMin (−10) would leave the box culled.
        chunk.logScaleMax = -10
        chunk.logScaleMin = log(0.5)
        table.constantsBuffer.contents().storeBytes(of: chunk, as: GaussianChunkDecodeConstants.self)
        XCTAssertEqual(try cullChunks(table, constants: constants).record.threadgroupsPerGrid.0, 0, "the padding follows logScaleMax, not logScaleMin")
    }

    // MARK: - (h) A stereo frame tests both eyes with the current scene root

    /// The matrices a stereo frame's chunk cull actually uses (gaussianChunkCullViewProjections):
    /// eye i is projection_i × effective view of the raw view renderXR last received × model,
    /// rebuilt with the scene root of the frame being culled. So both eyes are tested, they
    /// differ, eye 1 is exactly the per-splat pass's matrix even on a frame the root jumped
    /// (where the composed xrEye1ViewProjection of the previous frame is not), and before the
    /// first stereo frame has written the eye matrices the cull falls back to the head view.
    func testStereoFrameTestsBothEyesWithTheCurrentSceneRoot() throws {
        let savedStereo = renderInfo.isXRStereoMode
        let savedEyes = (renderInfo.xrEye0View, renderInfo.xrEye0Projection, renderInfo.xrEye1View, renderInfo.xrEye1Projection)
        let savedComposed = (renderInfo.xrEye0ViewProjection, renderInfo.xrEye1ViewProjection)
        let savedProjection = renderInfo.perspectiveSpace
        defer {
            renderInfo.isXRStereoMode = savedStereo
            (renderInfo.xrEye0View, renderInfo.xrEye0Projection, renderInfo.xrEye1View, renderInfo.xrEye1Projection) = savedEyes
            (renderInfo.xrEye0ViewProjection, renderInfo.xrEye1ViewProjection) = savedComposed
            renderInfo.perspectiveSpace = savedProjection
            SceneRootTransform.shared.reset()
        }
        SceneRootTransform.shared.reset()
        GaussianDebugOptions.shared.disableHZBOcclusionCull = true
        let (entity, _, table) = try loadChunkedEntity()
        placeGaussianTestCamera(eye: cameras[0].eye, target: cameras[0].target)
        let camera = try XCTUnwrap(CameraSystem.shared.activeCamera)
        let cameraComponent = try XCTUnwrap(scene.get(component: CameraComponent.self, for: camera))
        let model = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: entity)).space

        // Two distinct eyes: the head view shifted ±3.2 cm, two asymmetric projections.
        let headView = cameraComponent.viewSpace
        let eye0View = simd_mul(matrix4x4Translation(0.032, 0, 0), headView)
        let eye1View = simd_mul(matrix4x4Translation(-0.032, 0, 0), headView)
        var eye0Projection = renderInfo.perspectiveSpace
        eye0Projection.columns.2.x = 0.05
        var eye1Projection = renderInfo.perspectiveSpace
        eye1Projection.columns.2.x = -0.05

        // As renderXR leaves the frame: raw per-eye matrices, the composed ones with the root
        // of that frame (identity), and the last eye's matrices as the head-centre camera.
        renderInfo.isXRStereoMode = true
        renderInfo.xrEye0View = eye0View
        renderInfo.xrEye0Projection = eye0Projection
        renderInfo.xrEye1View = eye1View
        renderInfo.xrEye1Projection = eye1Projection
        renderInfo.xrEye0ViewProjection = simd_mul(eye0Projection, eye0View)
        renderInfo.xrEye1ViewProjection = simd_mul(eye1Projection, eye1View)
        cameraComponent.viewSpace = eye1View
        renderInfo.perspectiveSpace = eye1Projection

        func perSplatMatrix() -> simd_float4x4 {
            simd_mul(renderInfo.perspectiveSpace, simd_mul(SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace), model))
        }
        func frameConstants() -> GaussianChunkCullConstants {
            gaussianChunkCullConstants(chunkTable: table, modelMatrix: model, viewMatrix: SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace), hzbValid: false, forceAllVisible: false, uniformQuotas: false)
        }

        var constants = frameConstants()
        XCTAssertEqual(constants.viewCount, 2, "a stereo frame tests both eyes")
        assertMatricesEqual(constants.viewProjection0, simd_mul(eye0Projection, simd_mul(eye0View, model)), "eye 0 with the identity root")
        assertMatricesEqual(constants.viewProjection1, simd_mul(eye1Projection, simd_mul(eye1View, model)), "eye 1 with the identity root")
        XCTAssertNotEqual(constants.viewProjection0, constants.viewProjection1, "the two eyes differ")
        assertMatricesEqual(constants.viewProjection1, perSplatMatrix(), "eye 1 is the per-splat matrix")

        // The scene root jumps this frame (a recentre or a large pinch-drag delta): the chunk
        // cull follows it, so eye 1 is still exactly the per-splat matrix, while the previous
        // frame's composed matrix is not.
        SceneRootTransform.shared.position = simd_float3(0.6, 0.2, -0.4)
        SceneRootTransform.shared.rotation = simd_quatf(angle: 0.3, axis: simd_float3(0, 1, 0))
        SceneRootTransform.shared.updateIfNeeded()
        constants = frameConstants()
        XCTAssertEqual(constants.viewCount, 2)
        assertMatricesEqual(constants.viewProjection1, perSplatMatrix(), "eye 1 follows the scene root the per-splat pass uses")
        assertMatricesEqual(constants.viewProjection0, simd_mul(eye0Projection, simd_mul(SceneRootTransform.shared.effectiveViewMatrix(eye0View), model)), "eye 0 follows the scene root too")
        XCTAssertNotEqual(constants.viewProjection1, simd_mul(renderInfo.xrEye1ViewProjection, model), "the previous frame's composed eye matrix carries the old root")
        XCTAssertNotEqual(constants.viewProjection0, simd_mul(renderInfo.xrEye0ViewProjection, model))

        // Through the GPU: the two-eye run keeps the CPU mirror's either-eye set with the moved
        // root, which holds every chunk the per-splat matrix alone keeps.
        let eitherEye = expectedVisibleChunks(table, viewProjections: [constants.viewProjection0, constants.viewProjection1])
        let culled = try cullChunks(table, constants: constants)
        XCTAssertEqual(culled.chunks, eitherEye)
        XCTAssertTrue(expectedVisibleChunks(table, viewProjections: [perSplatMatrix()]).isSubset(of: culled.chunks), "no chunk the per-splat frustum keeps is dropped")
        XCTAssertGreaterThan(culled.chunks.count, 0, "sanity — the camera still sees the asset")

        // Before the first stereo frame has written the eye matrices: mono, the head view.
        renderInfo.xrEye1Projection = matrix_identity_float4x4
        constants = frameConstants()
        XCTAssertEqual(constants.viewCount, 1)
        assertMatricesEqual(constants.viewProjection0, perSplatMatrix(), "without eye matrices the chunk cull uses the per-splat matrix")
        XCTAssertEqual(constants.viewProjection0, constants.viewProjection1)

        // And a mono frame ignores eye matrices that happen to be set.
        renderInfo.xrEye1Projection = eye1Projection
        renderInfo.isXRStereoMode = false
        constants = frameConstants()
        XCTAssertEqual(constants.viewCount, 1)
        assertMatricesEqual(constants.viewProjection0, perSplatMatrix())
    }

    /// The stereo matrices only replace the head-centre view once a stereo frame has written them.
    func testMonoFrameUsesOneView() throws {
        let (entity, _, table) = try loadChunkedEntity()
        placeGaussianTestCamera(eye: cameras[0].eye, target: cameras[0].target)
        let world = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: entity))
        let constants = gaussianChunkCullConstants(chunkTable: table, modelMatrix: world.space, viewMatrix: matrix_identity_float4x4, hzbValid: false, uniformQuotas: false)
        XCTAssertEqual(constants.viewCount, 1)
        XCTAssertEqual(constants.viewProjection0, constants.viewProjection1)
        XCTAssertEqual(constants.chunkCount, UInt32(expectedChunkCount))
        XCTAssertEqual(constants.clipGuardBand, gaussianCullClipGuardBand)
        XCTAssertEqual(constants.hzbOcclusionBias, gaussianCullHZBOcclusionBias)
        XCTAssertEqual(constants.uniformQuotas, 0, "the weighted quotas are the default")
        XCTAssertEqual(gaussianChunkCullConstants(chunkTable: table, modelMatrix: world.space, viewMatrix: matrix_identity_float4x4, hzbValid: false, uniformQuotas: true).uniformQuotas, 1)
        XCTAssertEqual(MemoryLayout<GaussianChunkCullConstants>.stride, 176)
        XCTAssertEqual(MemoryLayout<GaussianVisibleChunk>.stride, 16)
        XCTAssertEqual(MemoryLayout<GaussianBudgetState>.stride, 32)
        XCTAssertEqual(MemoryLayout<GaussianBudgetScaleConstants>.stride, 32)
    }
}

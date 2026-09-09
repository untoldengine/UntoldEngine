//
//  GaussianChunkCullTest.swift
//  UntoldEngine
//
//  The chunk-level cull of .untoldgs entities (GaussianChunkCull.metal): the chunk table reaches
//  the component, the GPU keeps exactly the chunks the CPU mirror predicts, every splat the
//  per-splat cull keeps lies in a surviving chunk, the frame is the same with the chunk cull on
//  and off, a partial view culls chunks, and a stereo chunk survives when only one eye sees it.
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

    /// The 200-splat fixture baked with 16 splats per chunk: 13 chunks.
    private let expectedChunkCount = 13

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
    }

    override func tearDown() async throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = savedDisableHZBOcclusionCull
        GaussianDebugOptions.shared.disableChunkCull = savedDisableChunkCull
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
        return (entity, component, table)
    }

    private func runSynchronously(_ encode: (MTLCommandBuffer) -> Void) {
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Expected to allocate a command buffer")
            return
        }
        encode(commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        XCTAssertEqual(commandBuffer.status, .completed)
    }

    private func frameSlot(for component: GaussianComponent) -> Int {
        min(renderInfo.currentInFlightFrameSlot, component.gaussianVisibleCount.count - 1)
    }

    /// The visible-chunk list and record of the current slot, as the GPU left them.
    private func visibleChunkReadback(_ table: GaussianChunkTable, slot: Int) -> (chunks: Set<UInt32>, record: GaussianVisibleSet) {
        let record = table.visibleChunkSets[slot].contents().load(as: GaussianVisibleSet.self)
        let count = Int(record.threadgroupCount)
        let entries = UnsafeBufferPointer(start: table.visibleChunks[slot].contents().bindMemory(to: GaussianVisibleChunk.self, capacity: count), count: count)
        return (Set(entries.map(\.chunkIndex)), record)
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
        }
        // The table's first splats tile the buffer.
        let constants = UnsafeBufferPointer(start: table.constantsBuffer.contents().bindMemory(to: GaussianChunkDecodeConstants.self, capacity: table.chunkCount), count: table.chunkCount)
        var next: UInt32 = 0
        for chunk in constants {
            XCTAssertEqual(chunk.firstSplat, next)
            next += chunk.splatCount
        }
        XCTAssertEqual(next, UInt32(component.splatCount))
        XCTAssertGreaterThanOrEqual(component.estimatedGPUBytes, table.gpuBytes + Int(component.splatCount) * MemoryLayout<EncodedGaussianSplat>.stride)
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
            runSynchronously { executeGaussianFrustumCulling($0) }
            let slot = frameSlot(for: component)
            let culled = visibleChunkReadback(table, slot: slot)
            let chunkedSurvivors = try visibleSplatIndices(component, slot: slot)

            XCTAssertEqual(culled.chunks, expected, "camera \(cameraIndex): the GPU keeps the chunks the CPU mirror predicts")
            XCTAssertEqual(culled.record.threadgroupsPerGrid.0, culled.record.threadgroupCount, "camera \(cameraIndex): one threadgroup per visible chunk")
            let expectedSplatTotal = culled.chunks.reduce(UInt32(0)) { $0 + table.index.chunks[Int($1)].splatCount }
            XCTAssertEqual(culled.record.visibleCount, expectedSplatTotal, "camera \(cameraIndex): the record sums the visible chunks' splats")
            XCTAssertLessThanOrEqual(UInt32(chunkedSurvivors.count), culled.record.visibleCount)
            XCTAssertEqual(Set(chunkedSurvivors).count, chunkedSurvivors.count, "camera \(cameraIndex): each splat appears once")

            // The legacy set: every chunk forced visible, the per-splat test alone decides.
            GaussianDebugOptions.shared.disableChunkCull = true
            runSynchronously { executeGaussianFrustumCulling($0) }
            let forced = visibleChunkReadback(table, slot: slot)
            let legacySurvivors = try visibleSplatIndices(component, slot: slot)
            XCTAssertEqual(forced.chunks.count, expectedChunkCount, "camera \(cameraIndex): disableChunkCull keeps every chunk")

            XCTAssertGreaterThan(legacySurvivors.count, 0, "camera \(cameraIndex): sanity — the camera sees part of the asset")
            let strays = legacySurvivors.filter { !culled.chunks.contains(owner[Int($0)]) }
            XCTAssertEqual(strays.count, 0, "camera \(cameraIndex): \(strays.count) splats the per-splat cull keeps lie in chunks the chunk cull dropped")
            XCTAssertEqual(Set(chunkedSurvivors), Set(legacySurvivors), "camera \(cameraIndex): the chunk path keeps exactly the per-splat cull's splats")
        }
    }

    // MARK: - (c) The frame is the same with the chunk cull on and off

    func testChunkCullRendersTheSameFrame() throws {
        _ = try loadChunkedEntity()
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

                let quality = compareGaussianSplatLayers(chunked, legacy)
                XCTAssertGreaterThan(quality.covered, 500, "camera \(cameraIndex) hzb=\(hzbEnabled): sanity — the asset covers part of the frame")
                XCTAssertEqual(chunkedVisible, legacyVisible, "camera \(cameraIndex) hzb=\(hzbEnabled): the same splats reach the shared set")
                XCTAssertLessThanOrEqual(quality.differingPixels, 50, "camera \(cameraIndex) hzb=\(hzbEnabled): \(quality.differingPixels) of \(quality.covered) covered pixels differ by more than one 8-bit step")
                XCTAssertGreaterThan(quality.psnr, 55, "camera \(cameraIndex) hzb=\(hzbEnabled): \(quality.psnr) dB over covered pixels")
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

        runSynchronously { executeGaussianFrustumCulling($0) }
        let slot = frameSlot(for: component)
        let culled = visibleChunkReadback(table, slot: slot)
        let survivors = try visibleSplatIndices(component, slot: slot)

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
        let pipelines = try XCTUnwrap(GaussianChunkCullPipelineStates.current())
        var constants = gaussianChunkCullConstants(chunkTable: table, modelMatrix: world.space, viewMatrix: matrix_identity_float4x4, hzbValid: false, forceAllVisible: false)
        constants.viewProjection0 = lookingAway
        constants.viewProjection1 = lookingAt
        constants.viewCount = 2
        let slot = 0
        runSynchronously { commandBuffer in
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
            _ = encodeGaussianChunkCull(
                encoder,
                pipelines: pipelines,
                chunkTable: table,
                visibleChunks: table.visibleChunks[slot],
                chunkSet: table.visibleChunkSets[slot],
                constants: constants,
                hzbTexture: textureResources.depthMap
            )
            encoder.endEncoding()
        }
        XCTAssertEqual(visibleChunkReadback(table, slot: slot).chunks, seenByEye1, "the GPU keeps every chunk eye 1 sees although eye 0 sees none")

        // And with eye 0 alone (viewCount 1) the away view keeps nothing.
        constants.viewCount = 1
        runSynchronously { commandBuffer in
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
            _ = encodeGaussianChunkCull(
                encoder,
                pipelines: pipelines,
                chunkTable: table,
                visibleChunks: table.visibleChunks[slot],
                chunkSet: table.visibleChunkSets[slot],
                constants: constants,
                hzbTexture: textureResources.depthMap
            )
            encoder.endEncoding()
        }
        let awayOnly = visibleChunkReadback(table, slot: slot)
        XCTAssertEqual(awayOnly.chunks.count, 0)
        XCTAssertEqual(awayOnly.record.threadgroupsPerGrid.0, 0)
        XCTAssertEqual(awayOnly.record.visibleCount, 0)
    }

    /// The stereo matrices only replace the head-centre view once a stereo frame has written them.
    func testMonoFrameUsesOneView() throws {
        let (entity, _, table) = try loadChunkedEntity()
        placeGaussianTestCamera(eye: cameras[0].eye, target: cameras[0].target)
        let world = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: entity))
        let constants = gaussianChunkCullConstants(chunkTable: table, modelMatrix: world.space, viewMatrix: matrix_identity_float4x4, hzbValid: false)
        XCTAssertEqual(constants.viewCount, 1)
        XCTAssertEqual(constants.viewProjection0, constants.viewProjection1)
        XCTAssertEqual(constants.chunkCount, UInt32(expectedChunkCount))
        XCTAssertEqual(constants.clipGuardBand, gaussianCullClipGuardBand)
        XCTAssertEqual(constants.hzbOcclusionBias, gaussianCullHZBOcclusionBias)
        XCTAssertEqual(MemoryLayout<GaussianChunkCullConstants>.stride, 176)
        XCTAssertEqual(MemoryLayout<GaussianVisibleChunk>.stride, 8)
    }
}

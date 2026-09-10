//
//  MeshOccluderShellRenderTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Metal
import simd
@testable import UntoldEngine
import XCTest

/// The pieces a splat stand-in for a mesh is built from: a colour-off mesh still hides splats
/// behind its shrunk depth shell, the mesh fade dithers the colour out or in, and a `.untold`
/// scene's `gaussianAsset` record arrives as link data that a URL load turns into a splat
/// sharing the entity with its mesh.
@MainActor
final class MeshOccluderShellRenderTest: BaseRenderSetup {
    private var temporaryFiles: [URL] = []

    override func tearDown() async throws {
        GaussianDebugOptions.shared.disableOccluderShell = false
        GaussianDebugOptions.shared.disableHZBOcclusionCull = false
        LoadingSystem.shared.resourceURLFn = getResourceURL
        destroyAllEntities()
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    // MARK: - Scene helpers

    private func testPLYURL() throws -> URL {
        try XCTUnwrap(LoadingSystem.shared.resourceURL(forResource: "test_gaussians", withExtension: "ply", subResource: nil))
    }

    @discardableResult
    private func createTestCamera(eye: simd_float3, target: simd_float3) -> EntityID {
        let cameraEntity = createEntity()
        if let cameraComponent = scene.assign(to: cameraEntity, component: CameraComponent.self) {
            CameraSystem.shared.activeCamera = cameraEntity
            cameraComponent.viewSpace = matrix_identity_float4x4
            cameraComponent.localPosition = .zero
        }
        cameraLookAt(entityId: cameraEntity, eye: eye, target: target, up: simd_float3(0, 1, 0))
        return cameraEntity
    }

    /// A cube whose near face covers the whole frame (see GaussianRenderingTest's occlusion
    /// tests). The material is emissive so the lit colour does not depend on the test IBL bake.
    private func makeCube(at position: simd_float3, extent: Float = 8.0) -> EntityID {
        let entity = createEntity()
        var meshes = BasicPrimitives.createCube(extent: extent)
        let emissiveMaterial = Material(
            runtimeMaterial: RuntimeMaterialSource(
                baseColorFactor: simd_float4(0, 0, 0, 1),
                emissiveFactor: simd_float3(0.8, 0.6, 0.4),
                metallicFactor: 0.0,
                roughnessFactor: 1.0
            ),
            device: renderInfo.device
        )
        for meshIndex in meshes.indices {
            for submeshIndex in meshes[meshIndex].submeshes.indices {
                meshes[meshIndex].submeshes[submeshIndex].material = emissiveMaterial
            }
        }
        if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
            renderComponent.mesh = meshes
            renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/occluder.untold")
        }
        if let local = scene.get(component: LocalTransformComponent.self, for: entity) {
            local.position = position
            local.boundingBox = Mesh.computeMeshBoundingBox(for: meshes)
        }
        if let world = scene.get(component: WorldTransformComponent.self, for: entity) {
            var space = matrix_identity_float4x4
            space.columns.3 = simd_float4(position, 1.0)
            world.space = space
        }
        setVisibleEntities()
        return entity
    }

    /// Puts the test splat on the cube's entity (its cloud then sits inside the cube).
    private func loadSplat(onto entity: EntityID, opacityScale: Float) async throws {
        let url = try testPLYURL()
        let loaded = await setEntityGaussianAsync(entityId: entity, url: url, opacityScale: opacityScale)
        XCTAssertTrue(loaded, "The test splat should load onto the mesh entity")
    }

    // MARK: - Readback

    private struct FrameReadback {
        /// Highest alpha anywhere in the splat target: is the splat visible somewhere.
        var splatMaxAlpha: Float
        /// Pixels of the lit opaque colour that differ from the empty-scene background.
        var litCoverage: Int
    }

    private func pixels(of texture: MTLTexture) -> [Float16] {
        precondition(texture.pixelFormat == .rgba16Float, "Test assumes rgba16Float targets")
        let width = texture.width
        let height = texture.height
        var data = [Float16](repeating: 0, count: width * height * 4)
        data.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: width * 8, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        return data
    }

    private var backgroundLit: [Float16]?

    /// Draws one frame and blocks until its command buffer completed, so the shared targets can
    /// be read back on the spot. The visible list is re-seeded first: the GPU cull of the
    /// previous frame is temporal (its HZB holds a full-frame cube's own near face), so the tests
    /// pin the list to every mesh entity the way the single-frame occlusion tests do.
    private func drawFrameAndWait() {
        setVisibleEntities()
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()
    }

    private func render() throws -> FrameReadback {
        drawFrameAndWait()
        let splatTarget = try XCTUnwrap(renderInfo.gaussianRenderPassDescriptor.colorAttachments[0].texture)
        let lit = try XCTUnwrap(textureResources.deferredColorMap)

        let splat = pixels(of: splatTarget)
        var best: Float = 0
        var index = 3
        while index < splat.count {
            best = max(best, Float(splat[index]))
            index += 4
        }

        let litPixels = pixels(of: lit)
        let background = backgroundLit ?? [Float16](repeating: 0, count: litPixels.count)
        var covered = 0
        var pixel = 0
        while pixel < litPixels.count {
            let differs = (0 ..< 3).contains { abs(Float(litPixels[pixel + $0]) - Float(background[pixel + $0])) > 1e-3 }
            if differs {
                covered += 1
            }
            pixel += 4
        }
        return FrameReadback(splatMaxAlpha: best, litCoverage: covered)
    }

    /// Renders the camera alone and keeps its lit colour as the "nothing drawn" reference.
    private func captureBackground() throws {
        drawFrameAndWait()
        backgroundLit = try pixels(of: XCTUnwrap(textureResources.deferredColorMap))
    }

    // MARK: - Tests

    /// A colour-off mesh with an occluder shell draws no lit colour, yet the shell still hides
    /// the splat cloud inside it. Turning the shells off (debug switch) is the control: the cloud
    /// shows. The splat cull's temporal HZB pre-cull is off so only the depth snapshot the splat
    /// pass tests against — the shell's depth — decides.
    func testColourOffMeshDrawsNothingButItsShellStillOccludes() async throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = true
        let eye = simd_float3(0, 3, 7)
        let target = simd_float3(0, 0, 0)
        createTestCamera(eye: eye, target: target)
        try captureBackground()

        let nearPoint = eye + 0.657 * (target - eye)
        let entity = makeCube(at: nearPoint)

        let plain = try render()
        XCTAssertGreaterThan(plain.litCoverage, 1000, "Sanity: the mesh fills the frame")
        XCTAssertLessThan(plain.splatMaxAlpha, 0.05, "No splat yet")

        try await loadSplat(onto: entity, opacityScale: 1)
        let occluder = try XCTUnwrap(scene.assign(to: entity, component: MeshOccluderComponent.self))
        occluder.drawsColor = false
        let shelled = try render()
        XCTAssertLessThan(shelled.litCoverage, plain.litCoverage / 50, "Colour off: nothing lit (got \(shelled.litCoverage) of \(plain.litCoverage))")
        XCTAssertLessThan(shelled.splatMaxAlpha, 0.05, "The shell hides the cloud inside the mesh, got \(shelled.splatMaxAlpha)")

        GaussianDebugOptions.shared.disableOccluderShell = true
        let noShell = try render()
        XCTAssertGreaterThan(noShell.splatMaxAlpha, 0.05, "Without the shell nothing writes the mesh's depth and the cloud shows")
        GaussianDebugOptions.shared.disableOccluderShell = false

        occluder.drawsColor = true
        let colourBack = try render()
        XCTAssertGreaterThan(colourBack.litCoverage, plain.litCoverage * 9 / 10, "Colour on again with the shell still present: the full mesh is back")
    }

    /// A quarter of the way, fading out still keeps three quarters of the pixels and fading in
    /// keeps one quarter: the two directions are complementary halves of the same dither.
    func testMeshFadeKeepsComplementaryPixelSetsInEachDirection() throws {
        let eye = simd_float3(0, 3, 7)
        let target = simd_float3(0, 0, 0)
        createTestCamera(eye: eye, target: target)
        try captureBackground()

        let nearPoint = eye + 0.657 * (target - eye)
        let entity = makeCube(at: nearPoint)
        let plain = try render()
        XCTAssertGreaterThan(plain.litCoverage, 1000)

        let fade = try XCTUnwrap(scene.assign(to: entity, component: MeshFadeComponent.self))
        fade.direction = .fadeOut
        fade.progress = 0.25
        let fadingOut = try render()
        let outRatio = Float(fadingOut.litCoverage) / Float(plain.litCoverage)
        XCTAssertEqual(outRatio, 0.75, accuracy: 0.1, "Fading out at 0.25 discards a quarter of the pixels, kept \(outRatio)")

        fade.direction = .fadeIn
        let fadingIn = try render()
        let inRatio = Float(fadingIn.litCoverage) / Float(plain.litCoverage)
        XCTAssertEqual(inRatio, 0.25, accuracy: 0.1, "Fading in at 0.25 keeps a quarter of the pixels, kept \(inRatio)")
        XCTAssertEqual(outRatio + inRatio, 1.0, accuracy: 0.1, "The two directions are complementary")

        scene.remove(component: MeshFadeComponent.self, from: entity)
        let back = try render()
        XCTAssertGreaterThan(back.litCoverage, plain.litCoverage * 9 / 10, "Fade removed: the full mesh is back")
    }

    /// A `.untold` scene whose entity carries a `gaussianAsset` record comes up with the link
    /// data on the mesh entity; loading that payload by URL puts the splat beside the mesh, with
    /// the ledger and the bounding box accounting for both, and removing it takes only its share.
    func testUntoldSceneLinkLoadsASplatBesideTheMesh() async throws {
        let fixture = try makeLinkedSceneFixture()
        let entity = createEntity()
        setEntityMesh(entityId: entity, filename: fixture.untoldURL.deletingPathExtension().path, withExtension: "untold")

        let link = try XCTUnwrap(scene.get(component: GaussianAssetLinkComponent.self, for: entity), "The gaussianAsset record arrives as link data on the mesh entity")
        XCTAssertEqual(link.payloadURL?.standardizedFileURL, fixture.payloadURL.standardizedFileURL, "Payload resolved next to the .untold file")
        XCTAssertTrue(link.isMeshTwin)
        XCTAssertEqual(link.occluderShrinkMeters, 0.03)
        XCTAssertEqual(link.exposureOffsetEV, 0.5)
        XCTAssertEqual(link.swapDistanceMeters, 12)
        XCTAssertEqual(link.alignment, GaussianSplatAlignment(translation: SIMD3<Float>(0, 0.02, 0), yawDegrees: 90, scale: 1.02), "The record's alignment arrives on the link")
        XCTAssertEqual(link.lodCount, 1)
        XCTAssertEqual(link.lodSplatCounts.count, 1)
        XCTAssertEqual(link.lodSwitchScreenHeights.count, 1)
        XCTAssertNil(scene.get(component: GaussianComponent.self, for: entity), "Linking loads nothing")

        let meshBox = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: entity)).boundingBox
        XCTAssertEqual(meshBox.max.x, 1, accuracy: 1e-5, "Sanity: the fixture mesh box is the unit box")
        let meshBytes = MemoryBudgetManager.shared.getMemorySize(for: entity) ?? 0
        XCTAssertGreaterThan(meshBytes, 0, "The mesh registers its own bytes")

        let payloadURL = try XCTUnwrap(link.payloadURL)
        let loaded = await setEntityGaussianAsync(entityId: entity, url: payloadURL, opacityScale: 0)
        XCTAssertTrue(loaded)
        let gaussian = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        XCTAssertEqual(gaussian.opacityScale, 0, "Resident but hidden, as requested")
        XCTAssertGreaterThan(gaussian.estimatedGPUBytes, 0)

        // The mesh keeps its own box; the splat's box (about ±1.4 in x, past the unit box) is on
        // the component for whoever needs it.
        let boxAfter = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: entity)).boundingBox
        XCTAssertEqual(boxAfter.min, meshBox.min, "The mesh box is untouched by the splat")
        XCTAssertEqual(boxAfter.max, meshBox.max)
        let splatBox = try XCTUnwrap(gaussian.localBoundingBox)
        XCTAssertGreaterThan(splatBox.max.x, meshBox.max.x, "The splat's own box is kept on the component")
        XCTAssertEqual(MemoryBudgetManager.shared.getMemorySize(for: entity) ?? 0, meshBytes, "The mesh entry is untouched by the splat")
        XCTAssertEqual(MemoryBudgetManager.shared.auxiliaryMeshBytes(for: entity), gaussian.estimatedGPUBytes, "The splat's bytes ride beside it")

        removeEntityGaussian(entityId: entity)
        XCTAssertNil(scene.get(component: GaussianComponent.self, for: entity))
        XCTAssertEqual(MemoryBudgetManager.shared.getMemorySize(for: entity) ?? 0, meshBytes)
        XCTAssertEqual(MemoryBudgetManager.shared.auxiliaryMeshBytes(for: entity), 0)
    }

    /// The two representations may arrive and leave in either order; the ledger holds the mesh
    /// entry plus the splat's bytes beside it whenever both are resident, and the survivor's
    /// bytes alone otherwise.
    func testLedgerFollowsTheMeshAndSplatInEitherOrder() async throws {
        // Splat first, on an entity with no mesh: the splat is the entry.
        let entity = createEntity()
        let url = try testPLYURL()
        let loadedAlone = await setEntityGaussianAsync(entityId: entity, url: url, opacityScale: 0)
        XCTAssertTrue(loadedAlone)
        let gaussian = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        let splatBytes = gaussian.estimatedGPUBytes
        XCTAssertGreaterThan(splatBytes, 0)
        XCTAssertEqual(MemoryBudgetManager.shared.getMemorySize(for: entity), splatBytes, "Alone, the splat is the entry")
        XCTAssertEqual(MemoryBudgetManager.shared.auxiliaryMeshBytes(for: entity), 0)
        let splatBox = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: entity)).boundingBox

        // Then the mesh arrives: it takes the entry, the splat's bytes move beside it, and the
        // entity takes the mesh's box.
        let meshes = BasicPrimitives.createCube(extent: 1.0)
        setEntityMeshDirect(entityId: entity, meshes: meshes, assetName: "cube")
        let meshBytes = MemoryBudgetManager.shared.getMemorySize(for: entity) ?? 0
        XCTAssertGreaterThan(meshBytes, 0)
        XCTAssertNotEqual(meshBytes, splatBytes, "The entry is now the mesh's")
        XCTAssertEqual(MemoryBudgetManager.shared.auxiliaryMeshBytes(for: entity), splatBytes, "The splat rides beside it")
        let meshBox = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: entity)).boundingBox
        XCTAssertLessThan(meshBox.max.x, splatBox.max.x, "The entity's box is the mesh's, not the splat's")
        XCTAssertNotNil(scene.get(component: GaussianComponent.self, for: entity), "The splat survived the mesh registration")

        // The mesh leaves: the splat is the entry again and the box is the splat's.
        removeEntityMesh(entityId: entity)
        XCTAssertEqual(MemoryBudgetManager.shared.getMemorySize(for: entity), splatBytes, "The splat's bytes take the entry back")
        XCTAssertEqual(MemoryBudgetManager.shared.auxiliaryMeshBytes(for: entity), 0)
        let boxAfter = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: entity)).boundingBox
        XCTAssertEqual(boxAfter.max.x, splatBox.max.x, accuracy: 1e-5)

        // And the splat leaves last: nothing remains in the ledger.
        removeEntityGaussian(entityId: entity)
        XCTAssertNil(MemoryBudgetManager.shared.getMemorySize(for: entity))
        XCTAssertEqual(MemoryBudgetManager.shared.auxiliaryMeshBytes(for: entity), 0)
    }

    // MARK: - .untold fixture with a gaussianAsset chunk

    private struct LinkedSceneFixture {
        let untoldURL: URL
        let payloadURL: URL
    }

    private func makeLinkedSceneFixture() throws -> LinkedSceneFixture {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MeshOccluderShellRenderTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryFiles.append(directory)

        // The payload: the test splat cooked to .untoldgs, next to the scene file.
        var cookOptions = UntoldGSCookOptions()
        cookOptions.log2ChunkSplats = 8
        let bake = try bakeGaussianSplatProgressiveTiers(
            plyURL: testPLYURL(),
            outputBaseURL: directory.appendingPathComponent("chair.untoldgs"),
            lodFractions: [1.0],
            cookOptions: cookOptions
        )
        let payloadURL = try XCTUnwrap(bake.tiers.first?.url)

        let strings = makeStringTable(["chair", "chair_mesh", "chair_mat", "albedo.ktx2", payloadURL.lastPathComponent])
        let bounds = UntoldAABB(min: SIMD3<Float>(-1, -1, -1), max: SIMD3<Float>(1, 1, 1))
        let entity = UntoldEntityRecordV1(
            entityId: 0,
            nameOffset: strings.offsets["chair"]!,
            firstMeshRecordIndex: 0,
            meshRecordCount: 1,
            localBounds: bounds,
            worldBounds: bounds
        )
        let material = UntoldMaterialRecordV1(
            nameOffset: strings.offsets["chair_mat"]!,
            baseColorTextureIndex: UntoldFormat.invalidIndex
        )
        let texture = UntoldTextureRefRecordV1(
            nameOffset: strings.offsets["albedo.ktx2"]!,
            uriOffset: strings.offsets["albedo.ktx2"]!,
            textureFormat: .rgba8,
            width: 16,
            height: 16,
            mipCount: 1
        )
        let vertexWriter = UntoldBinaryWriter()
        for position in [SIMD3<Float>(-1, -1, 0), SIMD3<Float>(1, -1, 0), SIMD3<Float>(0, 1, 0)] {
            UntoldPBRStaticVertexV1(
                position: position,
                normalPacked: UntoldVertexPacking.packNormal(SIMD3<Float>(0, 0, 1)),
                tangentPacked: UntoldVertexPacking.packTangent(SIMD3<Float>(1, 0, 0), handedness: 1)
            ).encode(to: vertexWriter)
        }
        let vertexData = vertexWriter.data
        let indexWriter = UntoldBinaryWriter()
        indexWriter.writeUInt16LE(0)
        indexWriter.writeUInt16LE(1)
        indexWriter.writeUInt16LE(2)
        let indexData = indexWriter.data
        let mesh = UntoldMeshRecordV1(
            entityId: 0,
            meshNameOffset: strings.offsets["chair_mesh"]!,
            materialIndex: 0,
            indexType: .uint16,
            vertexCount: 3,
            indexCount: 3,
            vertexStrideBytes: UInt32(vertexData.count / 3),
            vertexDataOffset: 0,
            indexDataOffset: 0,
            vertexDataSizeBytes: UInt64(vertexData.count),
            indexDataSizeBytes: UInt64(indexData.count),
            estimatedGPUBytes: UInt64(vertexData.count + indexData.count),
            localBounds: bounds
        )
        let linkRecord = UntoldGaussianAssetRecordV1(
            entityId: 0,
            payloadPathOffset: strings.offsets[payloadURL.lastPathComponent]!,
            flags: UntoldGaussianAssetFlags.meshTwin,
            lodCount: 1,
            occluderShrinkMeters: 0.03,
            exposureOffsetEV: 0.5,
            swapDistanceMeters: 12,
            alignment: GaussianSplatAlignment(translation: SIMD3<Float>(0, 0.02, 0), yawDegrees: 90, scale: 1.02)
        )

        var header = UntoldFileHeaderV1(
            fileType: .tile,
            chunkCount: 0,
            meshCount: 1,
            materialCount: 1,
            textureRefCount: 1,
            entityCount: 1,
            vertexLayout: .pbrStaticV1,
            worldBounds: bounds
        )
        let payloads: [(UntoldChunkType, Data, UInt32)] = [
            (.stringTable, strings.data, 0),
            (.entityTable, encodeRecords([entity]), 1),
            (.meshTable, encodeRecords([mesh]), 1),
            (.materialTable, encodeRecords([material]), 1),
            (.textureTable, encodeRecords([texture]), 1),
            (.vertexData, vertexData, 0),
            (.indexData, indexData, 0),
            (.gaussianAssetTable, encodeRecords([linkRecord]), 1),
        ]
        header.chunkCount = UInt32(payloads.count)
        let untoldURL = directory.appendingPathComponent("chair.untold")
        let fileData = buildFileData(header: header, payloads: payloads)
        try fileData.write(to: untoldURL, options: .atomic)
        let decoded = try UntoldReader().readAsset(from: fileData)
        XCTAssertEqual(decoded.gaussianAssets.count, 1, "Fixture carries one gaussianAsset record")
        return LinkedSceneFixture(untoldURL: untoldURL, payloadURL: payloadURL)
    }

    private func encodeRecords(_ records: [some UntoldBinaryEncodable]) -> Data {
        let writer = UntoldBinaryWriter()
        for record in records {
            record.encode(to: writer)
        }
        return writer.data
    }

    private func makeStringTable(_ strings: [String]) -> (data: Data, offsets: [String: UInt32]) {
        let writer = UntoldBinaryWriter()
        var offsets: [String: UInt32] = [:]
        for string in strings {
            offsets[string] = UInt32(writer.count)
            writer.writeNullTerminatedUTF8(string)
        }
        return (writer.data, offsets)
    }

    private func buildFileData(header: UntoldFileHeaderV1, payloads: [(UntoldChunkType, Data, UInt32)]) -> Data {
        let headerWriter = UntoldBinaryWriter()
        header.encode(to: headerWriter)
        let alignment = Int(UntoldFormat.fileAlignment)
        func aligned(_ value: Int) -> Int {
            let remainder = value % alignment
            return remainder == 0 ? value : value + (alignment - remainder)
        }

        var runningOffset = headerWriter.count + 40 * payloads.count
        var entries: [UntoldChunkEntryV1] = []
        for payload in payloads {
            runningOffset = aligned(runningOffset)
            entries.append(UntoldChunkEntryV1(
                chunkType: payload.0,
                fileOffset: UInt64(runningOffset),
                compressedSize: UInt64(payload.1.count),
                uncompressedSize: UInt64(payload.1.count),
                elementCount: payload.2
            ))
            runningOffset += payload.1.count
        }

        let writer = UntoldBinaryWriter()
        header.encode(to: writer)
        for entry in entries {
            entry.encode(to: writer)
        }
        for payload in payloads {
            writer.align(to: alignment)
            writer.writeData(payload.1)
        }
        return writer.data
    }
}

//
//  GaussianSplatAlignmentRenderTest.swift
//  UntoldEngine
//
//  `GaussianComponent.splatToEntity`: the splat's placement inside its entity, composed onto the
//  entity's world transform by the cull, the preprocess and the draw. Moving the splat through it
//  must render exactly like moving the entity, on both the whole-buffer and the chunked path.
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

final class GaussianSplatAlignmentRenderTest: BaseRenderSetup {
    private var temporaryFiles: [URL] = []
    private var savedDisableHZBOcclusionCull = false
    private var savedDisableChunkCull = false
    private var savedDisableWorkingSetBudget = false

    /// The far camera of the other Gaussian tests: the whole 200-splat fixture in view, with room
    /// for it to move a metre and grow by half.
    private let camera = (eye: simd_float3(0, 3, 7), target: simd_float3.zero)
    /// A camera close enough that the whole fixture just fits: the alignment pushes part of it
    /// past the guard-banded frustum, so the cull has splats to drop.
    private let nearCamera = (eye: simd_float3(0, 1.5, 3), target: simd_float3.zero)
    /// The alignment under test: a metre along +X, 30° about +Y, 1.5× uniform.
    private let alignment = GaussianSplatAlignment(translation: SIMD3<Float>(1, 0, 0), yawDegrees: 30, scale: 1.5)
    /// A pose for the entity that is not the identity in any part: the composition order shows.
    private let entityPose = GaussianSplatAlignment(translation: SIMD3<Float>(2, 0, -1), yawDegrees: 90, scale: 0.8)

    override func setUp() async throws {
        try await super.setUp()
        savedDisableHZBOcclusionCull = GaussianDebugOptions.shared.disableHZBOcclusionCull
        savedDisableChunkCull = GaussianDebugOptions.shared.disableChunkCull
        savedDisableWorkingSetBudget = GaussianDebugOptions.shared.disableWorkingSetBudget
        // The previous frame's HZB would make the first of two frames differ from the second.
        GaussianDebugOptions.shared.disableHZBOcclusionCull = true
        GaussianDebugOptions.shared.disableChunkCull = false
        GaussianDebugOptions.shared.disableWorkingSetBudget = true
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
    }

    override func tearDown() async throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = savedDisableHZBOcclusionCull
        GaussianDebugOptions.shared.disableChunkCull = savedDisableChunkCull
        GaussianDebugOptions.shared.disableWorkingSetBudget = savedDisableWorkingSetBudget
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        destroyAllEntities()
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    // MARK: - Helpers

    private func bakeV3(chunkSplats log2: UInt8) throws -> URL {
        let ply = try XCTUnwrap(LoadingSystem.shared.resourceURL(forResource: "test_gaussians", withExtension: "ply", subResource: nil))
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianSplatAlignmentRenderTest-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")
        var options = UntoldGSCookOptions()
        options.log2ChunkSplats = log2
        let result = try bakeGaussianSplatProgressiveTiers(plyURL: ply, outputBaseURL: output, lodFractions: [1.0], cookOptions: options)
        let url = try XCTUnwrap(result.tiers.first?.url)
        temporaryFiles.append(url)
        return url
    }

    /// Two frames (the first settles the in-flight slots), the second one's splat layer.
    private func settledSplatLayer() -> [Float16] {
        _ = renderGaussianSplatLayer()
        return renderGaussianSplatLayer()
    }

    private func setEntityTransform(_ entity: EntityID, translation: simd_float3, yawDegrees: Float, scale: Float) {
        translateTo(entityId: entity, position: translation)
        rotateTo(entityId: entity, angle: yawDegrees, axis: simd_float3(0, 1, 0))
        scaleTo(entityId: entity, scale: simd_float3(repeating: scale))
    }

    private func assertSameImage(_ a: [Float16], _ b: [Float16], _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        let quality = compareGaussianSplatLayers(a, b)
        XCTAssertGreaterThan(quality.covered, 500, "sanity — the asset covers part of the frame", file: file, line: line)
        XCTAssertLessThanOrEqual(quality.differingPixels, 50, "\(what): \(quality.differingPixels) of \(quality.covered) covered pixels differ by more than one 8-bit step", file: file, line: line)
        XCTAssertGreaterThan(quality.psnr, 55, "\(what): \(quality.psnr) dB over covered pixels", file: file, line: line)
    }

    private func assertEqual(_ a: simd_float4x4, _ b: simd_float4x4, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        for column in 0 ..< 4 {
            for row in 0 ..< 4 {
                XCTAssertEqual(a[column][row], b[column][row], accuracy: 1e-5, "\(what) [\(column)][\(row)]", file: file, line: line)
            }
        }
    }

    // MARK: - Tests

    /// A splat at the origin with `splatToEntity = T·R_y·S` renders like the same splat with an
    /// identity `splatToEntity` on an entity carrying that very T·R·S.
    func testSplatToEntityRendersLikeTheSameTransformOnTheEntity() throws {
        placeGaussianTestCamera(eye: camera.eye, target: camera.target)
        let entity = createEntity()
        setEntityGaussian(entityId: entity, filename: "test_gaussians", withExtension: "ply")
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        XCTAssertEqual(component.splatToEntity, matrix_identity_float4x4, "identity until set")

        let atRest = settledSplatLayer()

        // The reference: the entity itself moved, turned and scaled.
        setEntityTransform(entity, translation: alignment.translation, yawDegrees: alignment.yawDegrees, scale: alignment.scale)
        let world = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: entity)).space
        assertEqual(world, alignment.matrix, "the entity's T·R·S is the alignment matrix")
        let entityMoved = settledSplatLayer()
        let moved = compareGaussianSplatLayers(atRest, entityMoved)
        XCTAssertGreaterThan(moved.differingPixels, 500, "sanity — the transform visibly moves the splat (\(moved.differingPixels) pixels differ)")

        // The entity back at the origin, the same transform on the splat alone.
        setEntityTransform(entity, translation: .zero, yawDegrees: 0, scale: 1)
        setGaussianSplatToEntity(entityId: entity, alignment.matrix)
        XCTAssertEqual(component.splatToEntity, alignment.matrix)
        let splatMoved = settledSplatLayer()
        assertSameImage(entityMoved, splatMoved, "splatToEntity against the entity transform")

        setGaussianSplatToEntity(entityId: entity, matrix_identity_float4x4)
        assertSameImage(atRest, settledSplatLayer(), "identity again")
    }

    /// The order of the composition: `worldTransform × splatToEntity`, the alignment inside the
    /// entity's frame. With the entity posed under a parent that moves, turns and scales it,
    /// the splat at local A under that parent renders like the splat at identity under the same
    /// parent with `splatToEntity = A` — and not like A applied in world space, which the
    /// identity-entity case above cannot tell apart.
    func testSplatToEntityComposesUnderTheEntityTransform() throws {
        placeGaussianTestCamera(eye: camera.eye, target: camera.target)
        let parent = createEntity()
        setEntityTransform(parent, translation: entityPose.translation, yawDegrees: entityPose.yawDegrees, scale: entityPose.scale)
        let entity = createEntity()
        setEntityGaussian(entityId: entity, filename: "test_gaussians", withExtension: "ply")
        setParent(childId: entity, parentId: parent)
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))

        // The reference: the child at local A under the posed parent.
        setEntityTransform(entity, translation: alignment.translation, yawDegrees: alignment.yawDegrees, scale: alignment.scale)
        let composed = simd_mul(entityPose.matrix, alignment.matrix)
        let world = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: entity)).space
        assertEqual(world, composed, "the child's world transform is E·A")
        let childMoved = settledSplatLayer()

        // The child back at identity under the parent, A on the splat alone.
        setEntityTransform(entity, translation: .zero, yawDegrees: 0, scale: 1)
        let childWorld = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: entity)).space
        assertEqual(childWorld, entityPose.matrix, "the child's world transform is E")
        setGaussianSplatToEntity(entityId: entity, alignment.matrix)
        XCTAssertEqual(component.splatToEntity, alignment.matrix)
        let splatMoved = settledSplatLayer()
        assertSameImage(childMoved, splatMoved, "splatToEntity under a posed parent against the same local transform")

        // The other order would not pass: A applied to the entity's world pose puts the splat
        // origin nearly a metre away, far past the tolerance of the comparison above.
        let swapped = simd_mul(alignment.matrix, entityPose.matrix)
        XCTAssertGreaterThan(simd_length(swapped.columns.3 - composed.columns.3), 0.5, "sanity — the two orders place the splat apart")
    }

    /// The cull composes the alignment too: with the fixture at the frustum edge the alignment
    /// pushes splats out of view, and the visible set of the splatToEntity render is the visible
    /// set of the entity-transform render, not the unaligned one.
    func testTheCullComposesTheAlignmentAtTheFrustumEdge() throws {
        placeGaussianTestCamera(eye: nearCamera.eye, target: nearCamera.target)
        let entity = createEntity()
        setEntityGaussian(entityId: entity, filename: "test_gaussians", withExtension: "ply")
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        let splatCount = Int(component.splatCount)

        let atRest = settledSplatLayer()
        let atRestVisible = sharedGaussianVisibleCount()
        XCTAssertEqual(atRestVisible, splatCount, "sanity — the near camera still holds the unaligned fixture")

        setEntityTransform(entity, translation: alignment.translation, yawDegrees: alignment.yawDegrees, scale: alignment.scale)
        let entityMoved = settledSplatLayer()
        let entityMovedVisible = sharedGaussianVisibleCount()
        XCTAssertLessThan(entityMovedVisible, atRestVisible, "sanity — the transform pushes part of the fixture out of the frustum (\(entityMovedVisible) of \(atRestVisible) left)")
        XCTAssertGreaterThan(compareGaussianSplatLayers(atRest, entityMoved).differingPixels, 500, "sanity — the transform visibly moves the splat")

        setEntityTransform(entity, translation: .zero, yawDegrees: 0, scale: 1)
        setGaussianSplatToEntity(entityId: entity, alignment.matrix)
        let splatMoved = settledSplatLayer()
        XCTAssertEqual(sharedGaussianVisibleCount(), entityMovedVisible, "the cull sees the splat where the alignment puts it")
        assertSameImage(entityMoved, splatMoved, "splatToEntity against the entity transform at the frustum edge")

        setGaussianSplatToEntity(entityId: entity, matrix_identity_float4x4)
        assertSameImage(atRest, settledSplatLayer(), "identity again")
        XCTAssertEqual(sharedGaussianVisibleCount(), atRestVisible)
    }

    /// The chunked (`.untoldgs`) path — chunk cull, fused decode-and-preprocess — composes the
    /// alignment into its constants like the whole-buffer path does.
    func testChunkedPathMatchesTheLegacyPathWithAnAlignment() throws {
        placeGaussianTestCamera(eye: camera.eye, target: camera.target)
        let url = try bakeV3(chunkSplats: 4)
        let entity = createEntity()
        setEntityGaussian(entityId: entity, filename: url.deletingPathExtension().path, withExtension: "untoldgs")
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        XCTAssertTrue(component.isChunked)
        let legacy = try GaussianLegacyTwin(loaded: GaussianChunkLoader.load(url: url))

        setGaussianSplatToEntity(entityId: entity, alignment.matrix)
        let chunked = settledSplatLayer()
        let wholeBuffer = legacy.withLegacyBuffers(component) { settledSplatLayer() }
        assertSameImage(chunked, wholeBuffer, "chunked against whole-buffer with an alignment")

        // And the alignment moved it: the aligned chunked frame is not the unaligned one.
        setGaussianSplatToEntity(entityId: entity, matrix_identity_float4x4)
        let unaligned = settledSplatLayer()
        XCTAssertGreaterThan(compareGaussianSplatLayers(chunked, unaligned).differingPixels, 500, "sanity — the alignment visibly moves the chunked splat")
    }

    /// The chunk cull and the fused per-chunk preprocess compose the alignment like the
    /// whole-buffer cull does: at the frustum edge both paths keep the same splats.
    func testChunkedCullMatchesTheWholeBufferCullAtTheFrustumEdge() throws {
        placeGaussianTestCamera(eye: nearCamera.eye, target: nearCamera.target)
        let url = try bakeV3(chunkSplats: 4)
        let entity = createEntity()
        setEntityGaussian(entityId: entity, filename: url.deletingPathExtension().path, withExtension: "untoldgs")
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        XCTAssertTrue(component.isChunked)
        let legacy = try GaussianLegacyTwin(loaded: GaussianChunkLoader.load(url: url))

        _ = settledSplatLayer()
        let unalignedVisible = sharedGaussianVisibleCount()
        XCTAssertEqual(unalignedVisible, Int(component.splatCount), "sanity — the near camera still holds the unaligned fixture")

        setGaussianSplatToEntity(entityId: entity, alignment.matrix)
        let chunked = settledSplatLayer()
        let chunkedVisible = sharedGaussianVisibleCount()
        XCTAssertLessThan(chunkedVisible, unalignedVisible, "sanity — the alignment pushes part of the fixture out of the frustum (\(chunkedVisible) of \(unalignedVisible) left)")
        let (wholeBuffer, wholeBufferVisible) = legacy.withLegacyBuffers(component) { (settledSplatLayer(), sharedGaussianVisibleCount()) }
        XCTAssertEqual(chunkedVisible, wholeBufferVisible, "the chunked path culls the aligned splat like the whole-buffer path")
        assertSameImage(chunked, wholeBuffer, "chunked against whole-buffer with an alignment at the frustum edge")
    }

    /// The alignment belongs to the entity, not the payload: a reload of the same entity keeps
    /// it, and a splat-only entity's bounding box is the splat's box carried through it — as
    /// soon as it is set, not only at the next load.
    func testAReloadKeepsSplatToEntityAndTheEntityBoxFollowsIt() throws {
        let entity = createEntity()
        setEntityGaussian(entityId: entity, filename: "test_gaussians", withExtension: "ply")
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        let splatBox = try XCTUnwrap(component.localBoundingBox)
        let unalignedBox = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: entity)).boundingBox
        XCTAssertEqual(unalignedBox.min, splatBox.min)
        XCTAssertEqual(unalignedBox.max, splatBox.max)

        // Set on the resident splat: the component and the entity box follow at once.
        setGaussianSplatToEntity(entityId: entity, alignment.matrix)
        XCTAssertEqual(component.splatToEntity, alignment.matrix)
        let expected = gaussianEntityBoundingBox(splatBox, splatToEntity: alignment.matrix)
        let liveBox = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: entity)).boundingBox
        XCTAssertEqual(liveBox.min, expected.min, "the entity box follows the set, with no reload")
        XCTAssertEqual(liveBox.max, expected.max)
        XCTAssertEqual(try XCTUnwrap(component.localBoundingBox).min, splatBox.min, "the splat's own box is untouched")

        setEntityGaussian(entityId: entity, filename: "test_gaussians", withExtension: "ply")
        let reloaded = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        XCTAssertTrue(reloaded !== component, "a reload builds a fresh component")
        XCTAssertEqual(reloaded.splatToEntity, alignment.matrix, "…that keeps the entity's alignment")
        XCTAssertEqual(try XCTUnwrap(reloaded.localBoundingBox).min, splatBox.min, "the splat's own box is the payload's")

        let entityBox = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: entity)).boundingBox
        XCTAssertEqual(entityBox.min, expected.min)
        XCTAssertEqual(entityBox.max, expected.max)
        XCTAssertGreaterThan(entityBox.max.x, splatBox.max.x, "moved a metre along +X and grown: the box followed")

        // Back to identity: the box is the splat's again. On an entity without a splat the
        // call is a no-op.
        setGaussianSplatToEntity(entityId: entity, matrix_identity_float4x4)
        let restored = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: entity)).boundingBox
        XCTAssertEqual(restored.min, splatBox.min)
        XCTAssertEqual(restored.max, splatBox.max)
        let bare = createEntity()
        setGaussianSplatToEntity(entityId: bare, alignment.matrix)
        XCTAssertNil(scene.get(component: GaussianComponent.self, for: bare))

        // The corner sweep: a translated, turned and scaled unit box.
        let unit = (min: simd_float3(repeating: -1), max: simd_float3(repeating: 1))
        let swept = gaussianEntityBoundingBox(unit, splatToEntity: alignment.matrix)
        let halfDiagonal = 1.5 * (cos(30 * Float.pi / 180) + sin(30 * Float.pi / 180))
        XCTAssertEqual(swept.min.x, 1 - halfDiagonal, accuracy: 1e-5)
        XCTAssertEqual(swept.max.x, 1 + halfDiagonal, accuracy: 1e-5)
        XCTAssertEqual(swept.min.y, -1.5, accuracy: 1e-5)
        XCTAssertEqual(swept.max.y, 1.5, accuracy: 1e-5)
        XCTAssertEqual(swept.min.z, -halfDiagonal, accuracy: 1e-5)
        XCTAssertEqual(swept.max.z, halfDiagonal, accuracy: 1e-5)
        let identity = gaussianEntityBoundingBox(unit, splatToEntity: matrix_identity_float4x4)
        XCTAssertEqual(identity.min, unit.min)
        XCTAssertEqual(identity.max, unit.max)
    }
}

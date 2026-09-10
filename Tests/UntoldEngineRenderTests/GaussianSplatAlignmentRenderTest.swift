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
    /// The alignment under test: a metre along +X, 30° about +Y, 1.5× uniform.
    private let alignment = GaussianSplatAlignment(translation: SIMD3<Float>(1, 0, 0), yawDegrees: 30, scale: 1.5)

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
        for column in 0 ..< 4 {
            for row in 0 ..< 4 {
                XCTAssertEqual(world[column][row], alignment.matrix[column][row], accuracy: 1e-5, "the entity's T·R·S is the alignment matrix [\(column)][\(row)]")
            }
        }
        let entityMoved = settledSplatLayer()
        let moved = compareGaussianSplatLayers(atRest, entityMoved)
        XCTAssertGreaterThan(moved.differingPixels, 500, "sanity — the transform visibly moves the splat (\(moved.differingPixels) pixels differ)")

        // The entity back at the origin, the same transform on the splat alone.
        setEntityTransform(entity, translation: .zero, yawDegrees: 0, scale: 1)
        component.splatToEntity = alignment.matrix
        let splatMoved = settledSplatLayer()
        assertSameImage(entityMoved, splatMoved, "splatToEntity against the entity transform")

        component.splatToEntity = matrix_identity_float4x4
        assertSameImage(atRest, settledSplatLayer(), "identity again")
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

        component.splatToEntity = alignment.matrix
        let chunked = settledSplatLayer()
        let wholeBuffer = legacy.withLegacyBuffers(component) { settledSplatLayer() }
        assertSameImage(chunked, wholeBuffer, "chunked against whole-buffer with an alignment")

        // And the alignment moved it: the aligned chunked frame is not the unaligned one.
        component.splatToEntity = matrix_identity_float4x4
        let unaligned = settledSplatLayer()
        XCTAssertGreaterThan(compareGaussianSplatLayers(chunked, unaligned).differingPixels, 500, "sanity — the alignment visibly moves the chunked splat")
    }

    /// The alignment belongs to the entity, not the payload: a reload of the same entity keeps
    /// it, and a splat-only entity's bounding box is the splat's box carried through it.
    func testAReloadKeepsSplatToEntityAndTheEntityBoxFollowsIt() throws {
        let entity = createEntity()
        setEntityGaussian(entityId: entity, filename: "test_gaussians", withExtension: "ply")
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        let splatBox = try XCTUnwrap(component.localBoundingBox)
        component.splatToEntity = alignment.matrix

        setEntityGaussian(entityId: entity, filename: "test_gaussians", withExtension: "ply")
        let reloaded = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        XCTAssertTrue(reloaded !== component, "a reload builds a fresh component")
        XCTAssertEqual(reloaded.splatToEntity, alignment.matrix, "…that keeps the entity's alignment")
        XCTAssertEqual(try XCTUnwrap(reloaded.localBoundingBox).min, splatBox.min, "the splat's own box is the payload's")

        let entityBox = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: entity)).boundingBox
        let expected = gaussianEntityBoundingBox(splatBox, splatToEntity: alignment.matrix)
        XCTAssertEqual(entityBox.min, expected.min)
        XCTAssertEqual(entityBox.max, expected.max)
        XCTAssertGreaterThan(entityBox.max.x, splatBox.max.x, "moved a metre along +X and grown: the box followed")

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

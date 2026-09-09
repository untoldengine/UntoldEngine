//
//  GaussianSharedSortTest.swift
//  UntoldEngine
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

/// Splats of every entity are compacted into one shared working set, sorted once and drawn
/// once, so overlapping entities blend in true depth order. The test asset is split into two
/// interleaved halves that occupy the same space: drawn as two entities they must composite to
/// the same image as the whole asset drawn as one, in either creation order.
final class GaussianSharedSortTest: BaseRenderSetup {
    private var asset: GaussianSplatAsset?

    override func setUp() async throws {
        try await super.setUp()
        let url = LoadingSystem.shared.resourceURL(forResource: "test_gaussians", withExtension: "ply", subResource: nil)!
        asset = try PLYReader.readGaussianAsset(from: url)
    }

    override func tearDown() async throws {
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    // MARK: - Helpers

    private func addEntity(splats: [GaussianSplat]) -> EntityID? {
        guard let result = buildGaussianLoadResult(
            encodedSplats: splats.map(encodeGaussianSplatForTBDR),
            packedSphericalHarmonics: nil,
            meanSquaredSplatExtent: meanSquaredSplatExtent(splats, keeping: Array(splats.indices)),
            sourceDescription: "shared sort test"
        ) else {
            XCTFail("Expected the splats to build")
            return nil
        }
        let entity = createEntity()
        registerComponent(entityId: entity, componentType: GaussianComponent.self)
        registerComponent(entityId: entity, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entity, componentType: LocalTransformComponent.self)
        scene.get(component: WorldTransformComponent.self, for: entity)?.space = matrix_identity_float4x4
        if let component = scene.get(component: GaussianComponent.self, for: entity) {
            copyGaussianLoadResult(result, to: component)
        }
        return entity
    }

    private func lookAtAsset() -> EntityID {
        placeGaussianTestCamera(eye: simd_float3(0, 3, 7))
    }

    /// Frame readback and layer comparison live in GaussianRenderTestSupport.swift.
    private func renderSplatLayer() -> [Float16] {
        renderGaussianSplatLayer()
    }

    private func compare(_ a: [Float16], _ b: [Float16]) -> GaussianLayerComparison {
        compareGaussianSplatLayers(a, b)
    }

    private func sharedVisibleCount() -> Int {
        sharedGaussianVisibleCount()
    }

    // MARK: - Tests

    /// Two overlapping entities composite like the merged asset (Appendix A of the proposal,
    /// "two overlapping twins"), and the result does not depend on which entity was created first.
    func testTwoOverlappingEntitiesMatchTheMergedAsset() {
        guard let asset else { return }
        let evens = asset.splats.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
        let odds = asset.splats.enumerated().filter { $0.offset % 2 == 1 }.map(\.element)

        _ = lookAtAsset()
        guard addEntity(splats: asset.splats) != nil else { return }
        let merged = renderSplatLayer()
        let mergedVisible = sharedVisibleCount()
        destroyAllEntities()

        _ = lookAtAsset()
        guard addEntity(splats: evens) != nil, addEntity(splats: odds) != nil else { return }
        let split = renderSplatLayer()
        let splitVisible = sharedVisibleCount()
        destroyAllEntities()

        _ = lookAtAsset()
        guard addEntity(splats: odds) != nil, addEntity(splats: evens) != nil else { return }
        let splitReversed = renderSplatLayer()
        destroyAllEntities()

        XCTAssertGreaterThan(mergedVisible, 0)
        XCTAssertEqual(splitVisible, mergedVisible, "Both entities' visible splats land in one shared set")

        // The three renders blend the same splats in the same depth order, so they must agree
        // to within blending round-off: no pixel off by more than one 8-bit step (a small
        // allowance for splats at exactly equal depth, whose relative order follows the
        // nondeterministic append order), and PSNR over the covered pixels far above what
        // entity-order blending achieves.
        let quality = compare(merged, split)
        let orderQuality = compare(split, splitReversed)
        XCTAssertGreaterThan(quality.covered, 1000, "Sanity check: the asset covers part of the frame")
        XCTAssertLessThanOrEqual(quality.differingPixels, 50, "Two entities drawn through the shared sort differ from the merged asset in \(quality.differingPixels) of \(quality.covered) covered pixels")
        XCTAssertGreaterThan(quality.psnr, 60, "Two entities drawn through the shared sort differ from the merged asset by \(quality.psnr) dB PSNR over covered pixels")
        XCTAssertLessThanOrEqual(orderQuality.differingPixels, 50, "Entity creation order changes \(orderQuality.differingPixels) of \(orderQuality.covered) covered pixels")
        XCTAssertGreaterThan(orderQuality.psnr, 60, "Entity creation order changes the composite by \(orderQuality.psnr) dB PSNR over covered pixels")
    }

    /// The shared set holds every entity's visible splats with its own entity index, and the
    /// draw constants table covers both.
    func testSharedSetRecordsCarryEachEntity() throws {
        guard let asset else { return }
        let half = asset.splats.count / 2
        _ = lookAtAsset()
        guard addEntity(splats: Array(asset.splats[..<half])) != nil, addEntity(splats: Array(asset.splats[half...])) != nil else { return }

        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else { return }
        executeGaussianFrustumCulling(commandBuffer)
        executeGaussianPreprocess(commandBuffer)
        executeRadixSort(commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let slot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
        let count = sharedVisibleCount()
        XCTAssertGreaterThan(count, 0)
        let recordsBuffer = try XCTUnwrap(GaussianSharedWorkingSet.shared.records(slot: slot))
        let records = recordsBuffer.contents().bindMemory(to: GaussianWorkingSetSplat.self, capacity: count)
        var perEntity = [0, 0]
        for i in 0 ..< count where records[i].entityIndex < 2 {
            perEntity[Int(records[i].entityIndex)] += 1
        }
        XCTAssertGreaterThan(perEntity[0], 0, "entity 0 contributed to the shared set")
        XCTAssertGreaterThan(perEntity[1], 0, "entity 1 contributed to the shared set")
        XCTAssertEqual(perEntity[0] + perEntity[1], count, "every record names one of the two entities")
    }
}

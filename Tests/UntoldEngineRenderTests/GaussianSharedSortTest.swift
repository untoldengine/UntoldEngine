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
        let cameraEntity = createEntity()
        if let cameraComponent = scene.assign(to: cameraEntity, component: CameraComponent.self) {
            CameraSystem.shared.activeCamera = cameraEntity
            cameraComponent.viewSpace = matrix_identity_float4x4
            cameraComponent.localPosition = .zero
        }
        cameraLookAt(entityId: cameraEntity, eye: simd_float3(0, 3, 7), target: .zero, up: simd_float3(0, 1, 0))
        return cameraEntity
    }

    /// Renders one frame, waits for its command buffer, and returns the splat layer
    /// (premultiplied colour and alpha, rgba16Float).
    private func renderSplatLayer() -> [Float16] {
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()
        let texture = renderInfo.gaussianRenderPassDescriptor.colorAttachments[0].texture!
        var pixels = [Float16](repeating: 0, count: texture.width * texture.height * 4)
        texture.getBytes(&pixels, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        return pixels
    }

    /// Compares two splat layers over the pixels either of them covers: PSNR over those pixels
    /// and the number of pixels where any channel differs by more than one 8-bit step. The old
    /// entity-order blending measured about 56 dB over the whole (mostly empty) frame on this
    /// asset, so the bounds below have to be far tighter than that.
    private func compare(_ a: [Float16], _ b: [Float16]) -> (psnr: Float, differingPixels: Int, covered: Int) {
        var sum: Double = 0
        var covered = 0
        var differing = 0
        for i in stride(from: 0, to: a.count, by: 4) {
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
        return (mse == 0 ? .infinity : Float(10 * log10(1 / mse)), differing, covered)
    }

    private func sharedVisibleCount() -> Int {
        let slot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
        return Int(GaussianSharedWorkingSet.shared.visibleSet(slot: slot)!.contents().load(as: GaussianVisibleSet.self).visibleCount)
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

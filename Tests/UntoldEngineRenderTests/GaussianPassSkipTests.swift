//
//  GaussianPassSkipTests.swift
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

/// A frame without a splat entity skips the Gaussian pass whole (the depth snapshot, the tile
/// pass, the clear of its layer), and the composite ignores whatever the layer holds from an
/// earlier frame.
@MainActor
final class GaussianPassSkipTests: BaseRenderSetup {
    override func tearDown() async throws {
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        let camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: simd_float3(0, 1, 4), target: .zero, up: simd_float3(0, 1, 0))
        let box = createEntity()
        setEntityMeshDirect(entityId: box, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Box")
        translateTo(entityId: box, position: simd_float3(0, 0.5, 0))
    }

    private func drawFrame() {
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()
    }

    /// Fills the Gaussian pass's layer, as a frame that drew splats would have left it.
    private func fillSplatLayer(_ color: MTLClearColor) throws {
        let layer = try XCTUnwrap(renderInfo.gaussianRenderPassDescriptor.colorAttachments[0].texture)
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = layer
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = color
        let commandBuffer = try XCTUnwrap(renderInfo.commandQueue.makeCommandBuffer())
        try XCTUnwrap(commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)).endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    private func readFloats(_ texture: MTLTexture) -> [Float] {
        var halves = [UInt16](repeating: 0, count: texture.width * texture.height * 4)
        halves.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        }
        return halves.map { Float(Float16(bitPattern: $0)) }
    }

    func testFrameWithoutSplatEntitiesSkipsThePass() {
        drawFrame()
        XCTAssertFalse(renderInfo.gaussianCoverageWritten, "no splat entity: the pass is skipped and its layer is not read")
        let slot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
        XCTAssertTrue(GaussianSharedWorkingSet.shared.entityOrder(slot: slot).isEmpty, "the preprocess leaves the slot's order empty")
    }

    func testCompositeIgnoresTheLayerOfAnEarlierFrame() throws {
        // Two frames settle the frame-to-frame state (shadows, the depth pyramid) so that the
        // two frames compared below differ in the layer alone.
        drawFrame()
        drawFrame()

        // Opaque red where a frame that drew splats left its layer: a skipped pass does not clear it.
        try fillSplatLayer(MTLClearColor(red: 1, green: 0, blue: 0, alpha: 1))
        drawFrame()
        XCTAssertFalse(renderInfo.gaussianCoverageWritten)
        let withStaleLayer = try readFloats(XCTUnwrap(textureResources.sceneCompositeTexture))

        try fillSplatLayer(MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0))
        drawFrame()
        let withEmptyLayer = try readFloats(XCTUnwrap(textureResources.sceneCompositeTexture))

        XCTAssertGreaterThan(withEmptyLayer.max() ?? 0, 0.01, "the scene draws something")
        var maxDifference: Float = 0
        for i in 0 ..< min(withStaleLayer.count, withEmptyLayer.count) {
            maxDifference = max(maxDifference, abs(withStaleLayer[i] - withEmptyLayer[i]))
        }
        XCTAssertEqual(maxDifference, 0, accuracy: 1e-3, "the composite reads the layer only on a frame the pass drew it")
    }
}

/// A scene that had splats and loses them stops the pass.
@MainActor
final class GaussianPassSkipAfterRemovalTests: BaseRenderSetup {
    override func tearDown() async throws {
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        let gaussian = createEntity()
        setEntityGaussian(entityId: gaussian, filename: "test_gaussians", withExtension: "ply")
        _ = placeGaussianTestCamera(eye: simd_float3(0, 0, 3))
    }

    private func drawFrame() {
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()
    }

    func testRemovingTheLastSplatEntityStopsThePass() {
        for _ in 0 ..< maxInFlightCommandBuffers {
            drawFrame()
        }
        XCTAssertTrue(renderInfo.gaussianCoverageWritten, "with a splat entity the pass draws its layer")

        let gaussianId = getComponentId(for: GaussianComponent.self)
        for entity in queryEntitiesWithComponentIds([gaussianId], in: scene) {
            destroyEntity(entityId: entity)
        }
        for _ in 0 ..< maxInFlightCommandBuffers {
            drawFrame()
        }
        XCTAssertFalse(renderInfo.gaussianCoverageWritten, "without one the pass is skipped")
        for slot in 0 ..< maxInFlightCommandBuffers {
            XCTAssertTrue(GaussianSharedWorkingSet.shared.entityOrder(slot: slot).isEmpty, "slot \(slot): the preprocess cleared the order its records were stamped with")
        }
    }
}

//
//  TileLightStageTests.swift
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

/// The deferred light pass as a tile stage lights each pixel once per colour it holds; the
/// quad lights every sample. Both must produce the same lit scene, with and without MSAA.
@MainActor
final class TileLightStageTests: BaseRenderSetup {
    private var savedMode: AntiAliasingMode = .fxaa

    override func setUp() async throws {
        try await super.setUp()
        // The stage lights the indirect part itself: the geometry must not carry it.
        setRendering(.perFragmentIndirectLighting(.disabled))
        savedMode = antiAliasingMode
    }

    override func tearDown() async throws {
        setRendering(.tileLightStage(.enabled))
        setRendering(.perFragmentIndirectLighting(.enabled))
        setRendering(.multisampleCount(4))
        antiAliasingMode = savedMode
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
        // A thin bar at an angle: many edge pixels, where the tile stage lights per colour.
        let bar = createEntity()
        setEntityMeshDirect(entityId: bar, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Bar")
        scaleTo(entityId: bar, scale: simd_float3(4, 0.05, 0.05))
        rotateTo(entityId: bar, angle: 20, axis: simd_float3(0, 0, 1))
        translateTo(entityId: bar, position: simd_float3(0, 1.6, -1))
        let sun = createEntity()
        createDirLight(entityId: sun)
        rotateTo(entityId: sun, pitch: -40, yaw: 30, roll: 0)
        applyIBL = true
    }

    private var tileShadingAvailable: Bool {
        PipelineManager.shared.renderPipelinesByType[.lightTile]?.success == true
    }

    private func drawFrame() {
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()
    }

    private func readFloats(_ texture: MTLTexture) -> [Float] {
        var halves = [UInt16](repeating: 0, count: texture.width * texture.height * 4)
        halves.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        }
        return halves.map { Float(Float16(bitPattern: $0)) }
    }

    /// Fills the lit scene with a colour no lighting produces, so that a pass that failed to
    /// run (an encoder Metal refused) cannot pass as the previous frame's result.
    private func markLitScene() throws {
        let texture = try XCTUnwrap(textureResources.deferredColorMap)
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 0, blue: 1, alpha: 1)
        let commandBuffer = try XCTUnwrap(renderInfo.commandQueue.makeCommandBuffer())
        try XCTUnwrap(commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)).endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    /// The lit scene after a few frames, through the tile stage or the quad.
    private func litScene(tileStage: Bool, requireStage: Bool = true) throws -> [Float] {
        setRendering(.tileLightStage(tileStage ? .enabled : .disabled))
        for _ in 0 ..< 3 {
            try markLitScene()
            drawFrame()
        }
        if requireStage || !tileStage {
            XCTAssertEqual(renderInfo.tileLightStageUsed, tileStage, "the frame lit through the \(tileStage ? "tile stage" : "quad")")
        }
        let lit = try readFloats(XCTUnwrap(textureResources.deferredColorMap))
        var marked = 0
        for i in stride(from: 0, to: lit.count, by: 4) where lit[i] > 0.99 && lit[i + 1] < 0.01 && lit[i + 2] > 0.99 {
            marked += 1
        }
        XCTAssertEqual(marked, 0, "the pass ran and overwrote the marker")
        return lit
    }

    private func assertSameLitScene(requireStage: Bool = true, file: StaticString = #filePath, line: UInt = #line) throws {
        let quad = try litScene(tileStage: false)
        let tile = try litScene(tileStage: true, requireStage: requireStage)
        XCTAssertGreaterThan(quad.max() ?? 0, 0.01, "the scene draws something", file: file, line: line)
        var maxDifference: Float = 0
        var covered = 0
        for i in stride(from: 0, to: min(quad.count, tile.count), by: 4) where quad[i + 3] > 0 || tile[i + 3] > 0 {
            covered += 1
            for c in 0 ..< 4 {
                maxDifference = max(maxDifference, abs(quad[i + c] - tile[i + c]))
            }
        }
        XCTAssertGreaterThan(covered, 1000, "the scene covers pixels", file: file, line: line)
        XCTAssertLessThanOrEqual(maxDifference, 2e-3, "the tile stage and the quad light the same scene, edges included (max difference \(maxDifference))", file: file, line: line)
    }

    func testTileStageLightsTheSameSceneAsTheQuad() throws {
        try XCTSkipUnless(tileShadingAvailable, "tile shading is unavailable here")
        antiAliasingMode = .none
        try assertSameLitScene()
    }

    func testTileStageLightsTheSameMultisampledSceneAsTheQuad() throws {
        try XCTSkipUnless(tileShadingAvailable, "tile shading is unavailable here")
        try XCTSkipUnless(renderInfo.device.supportsTextureSampleCount(2), "no 2× MSAA here")
        // Two samples: the G-buffer's imageblock fits the tile memory of every Apple GPU.
        setRendering(.multisampleCount(2))
        antiAliasingMode = .msaa
        drawFrame()
        XCTAssertEqual(renderInfo.opaqueSampleCount, 2)
        let pipeline = try XCTUnwrap(PipelineManager.shared.renderPipelinesByType[.lightTile])
        XCTAssertEqual(pipeline.rasterSampleCount, 2, "the tile pipeline follows the pass's sample count")
        try assertSameLitScene()
    }

    /// Four samples of the G-buffer do not fit a tile on every GPU; where they do not, the pass
    /// refuses the stage up front (asking Metal for it would assert under API validation) and
    /// the quad lights the frame instead.
    func testFourSamplesLightThroughTheStageOrFallBackToTheQuad() throws {
        try XCTSkipUnless(tileShadingAvailable, "tile shading is unavailable here")
        try XCTSkipUnless(renderInfo.device.supportsTextureSampleCount(4), "no 4× MSAA here")
        antiAliasingMode = .msaa
        drawFrame()
        XCTAssertEqual(renderInfo.opaqueSampleCount, 4)
        try assertSameLitScene(requireStage: false)
        print("Tile light stage at 4 samples on this GPU: \(renderInfo.tileLightStageUsed ? "runs" : "refused, the quad lit the frame")")
    }

    func testTileStageFollowsTheSetting() throws {
        try XCTSkipUnless(tileShadingAvailable, "tile shading is unavailable here")
        antiAliasingMode = .none
        setRendering(.tileLightStage(.disabled))
        drawFrame()
        XCTAssertFalse(renderInfo.tileLightStageUsed)
        XCTAssertEqual(renderInfo.offscreenRenderPassDescriptor.imageblockSampleLength, 0, "the quad needs no imageblock")
        setRendering(.tileLightStage(.enabled))
        drawFrame()
        XCTAssertTrue(renderInfo.tileLightStageUsed)
        XCTAssertEqual(renderInfo.offscreenRenderPassDescriptor.tileWidth, 0, "the tile size is left to Metal")
        XCTAssertGreaterThan(renderInfo.offscreenRenderPassDescriptor.imageblockSampleLength, 0, "the stage tells the pass its imageblock")
    }
}

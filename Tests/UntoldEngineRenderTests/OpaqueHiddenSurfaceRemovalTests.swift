//
//  OpaqueHiddenSurfaceRemovalTests.swift
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

/// Opaque draws that never discard a fragment go through the model pipeline compiled without
/// discards, so the GPU resolves visibility before shading them; a masked material or a fade
/// keeps the general pipeline. Either way the picture is the same.
@MainActor
final class OpaqueHiddenSurfaceRemovalTests: BaseRenderSetup {
    private var box: EntityID = 0
    private var savedMode: AntiAliasingMode = .fxaa

    override func setUp() async throws {
        try await super.setUp()
        savedMode = antiAliasingMode
    }

    override func tearDown() async throws {
        setRendering(.opaqueHiddenSurfaceRemoval(.enabled))
        antiAliasingMode = savedMode
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        let camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: simd_float3(0, 1, 4), target: .zero, up: simd_float3(0, 1, 0))
        box = createEntity()
        setEntityMeshDirect(entityId: box, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Box")
        translateTo(entityId: box, position: simd_float3(0, 0.5, 0))
        // A second surface in front of the box: fragments of the box behind it are hidden.
        let slab = createEntity()
        setEntityMeshDirect(entityId: slab, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Slab")
        scaleTo(entityId: slab, scale: simd_float3(1.5, 0.4, 0.05))
        translateTo(entityId: slab, position: simd_float3(0, 0.5, 1.0))
        let sun = createEntity()
        createDirLight(entityId: sun)
        rotateTo(entityId: sun, pitch: -40, yaw: 30, roll: 0)
        applyIBL = true
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

    private func litScene(hiddenSurfaceRemoval: Bool) throws -> [Float] {
        setRendering(.opaqueHiddenSurfaceRemoval(hiddenSurfaceRemoval ? .enabled : .disabled))
        for _ in 0 ..< 3 {
            drawFrame()
        }
        return try readFloats(XCTUnwrap(textureResources.deferredColorMap))
    }

    private func assertSameLitScene(file: StaticString = #filePath, line: UInt = #line) throws {
        let general = try litScene(hiddenSurfaceRemoval: false)
        XCTAssertEqual(renderInfo.opaqueDrawsPlain, 0, "disabled, every draw takes the general pipeline", file: file, line: line)
        let plain = try litScene(hiddenSurfaceRemoval: true)
        XCTAssertGreaterThan(general.max() ?? 0, 0.01, "the scene draws something", file: file, line: line)
        var maxDifference: Float = 0
        for i in 0 ..< min(general.count, plain.count) {
            maxDifference = max(maxDifference, abs(general[i] - plain[i]))
        }
        XCTAssertLessThanOrEqual(maxDifference, 1e-3, "the plain pipeline draws the same picture (max difference \(maxDifference))", file: file, line: line)
    }

    func testBothModelPipelinesExistAndFollowTheSampleCount() throws {
        let general = try XCTUnwrap(PipelineManager.shared.renderPipelinesByType[.model])
        let plain = try XCTUnwrap(PipelineManager.shared.renderPipelinesByType[.modelOpaque])
        XCTAssertTrue(plain.success)
        XCTAssertEqual(plain.rasterSampleCount, general.rasterSampleCount)
        guard renderInfo.device.supportsTextureSampleCount(4) else { return }
        antiAliasingMode = .msaa
        drawFrame()
        XCTAssertEqual(renderInfo.opaqueSampleCount, 4)
        let plainMSAA = try XCTUnwrap(PipelineManager.shared.renderPipelinesByType[.modelOpaque])
        XCTAssertEqual(plainMSAA.rasterSampleCount, 4, "the plain pipeline is rebuilt with the pass's sample count")
    }

    func testOpaqueDrawsTakeThePlainPipelineAndDrawTheSamePicture() throws {
        antiAliasingMode = .none
        try assertSameLitScene()
        XCTAssertEqual(renderInfo.opaqueDrawsDiscarding, 0, "nothing in this scene discards")
        XCTAssertEqual(renderInfo.opaqueDrawsPlain, 2, "the box and the slab")
    }

    func testOpaqueDrawsTakeThePlainPipelineUnderMSAA() throws {
        try XCTSkipUnless(renderInfo.device.supportsTextureSampleCount(4), "no 4× MSAA here")
        antiAliasingMode = .msaa
        try assertSameLitScene()
        XCTAssertEqual(renderInfo.opaqueDrawsPlain, 2)
    }

    func testAMaskedMaterialKeepsTheGeneralPipelineAndItsHoles() throws {
        antiAliasingMode = .none
        // The box's base colour: a 2×2 texture whose alpha is 0 on one diagonal. Masked at 0.5,
        // half of every face is cut away; only the general pipeline can cut it.
        let render = try XCTUnwrap(scene.get(component: RenderComponent.self, for: box))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 2, height: 2, mipmapped: false)
        descriptor.usage = [.shaderRead]
        let texture = try XCTUnwrap(renderInfo.device.makeTexture(descriptor: descriptor))
        let texels: [UInt8] = [200, 200, 200, 255, 200, 200, 200, 0, 200, 200, 200, 0, 200, 200, 200, 255]
        texels.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0, 0, 2, 2), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 8) }
        for meshIndex in render.mesh.indices {
            for subIndex in render.mesh[meshIndex].submeshes.indices {
                render.mesh[meshIndex].submeshes[subIndex].material?.baseColor.texture = texture
                render.mesh[meshIndex].submeshes[subIndex].material?.alphaMode = .mask
                render.mesh[meshIndex].submeshes[subIndex].material?.alphaCutoff = 0.5
            }
        }

        let general = try litScene(hiddenSurfaceRemoval: false)
        let withRemoval = try litScene(hiddenSurfaceRemoval: true)
        XCTAssertEqual(renderInfo.opaqueDrawsDiscarding, 1, "the masked box keeps the general pipeline")
        XCTAssertEqual(renderInfo.opaqueDrawsPlain, 1, "the slab takes the plain one")
        var maxDifference: Float = 0
        for i in 0 ..< min(general.count, withRemoval.count) {
            maxDifference = max(maxDifference, abs(general[i] - withRemoval[i]))
        }
        XCTAssertLessThanOrEqual(maxDifference, 1e-3, "the same picture with and without the plain pipeline")
    }

    func testAFadingEntityKeepsTheGeneralPipeline() throws {
        antiAliasingMode = .none
        let fade = try XCTUnwrap(scene.assign(to: box, component: MeshFadeComponent.self))
        fade.direction = .fadeOut
        fade.progress = 0.5
        setRendering(.opaqueHiddenSurfaceRemoval(.enabled))
        drawFrame()
        XCTAssertEqual(renderInfo.opaqueDrawsDiscarding, 1, "the fading box dithers, so it keeps the general pipeline")
        XCTAssertEqual(renderInfo.opaqueDrawsPlain, 1, "the slab takes the plain one")
        scene.remove(component: MeshFadeComponent.self, from: box)
    }
}

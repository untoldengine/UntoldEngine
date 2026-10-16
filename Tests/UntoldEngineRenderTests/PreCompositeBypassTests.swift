//
//  PreCompositeBypassTests.swift
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

/// In XR passthrough the pre-composite pass copies the lit scene whenever no layer joins it;
/// such a frame skips the pass and the look pass reads the lit scene directly.
@MainActor
final class PreCompositeBypassTests: BaseRenderSetup {
    private var savedImmersionStyle: UntoldImmersionMode = .none
    private var savedGameMode = false
    private var savedSSAO = false
    private var savedAntiAliasing: AntiAliasingMode = .fxaa

    override func setUp() async throws {
        try await super.setUp()
        // No splat entity here; an order a Gaussian test left in the shared set would say otherwise.
        for slot in 0 ..< maxInFlightCommandBuffers {
            GaussianSharedWorkingSet.shared.setEntityOrder([], slot: slot)
        }
        savedImmersionStyle = renderInfo.immersionStyle
        savedGameMode = gameMode
        savedSSAO = SSAOParams.shared.enabled
        savedAntiAliasing = antiAliasingMode
    }

    override func tearDown() async throws {
        renderInfo.immersionStyle = savedImmersionStyle
        gameMode = savedGameMode
        SSAOParams.shared.enabled = savedSSAO
        antiAliasingMode = savedAntiAliasing
        setRendering(.preCompositeBypass(.enabled))
        renderInfo.preCompositeBypassSource = nil
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

    private func readFloats(_ texture: MTLTexture) -> [Float] {
        var halves = [UInt16](repeating: 0, count: texture.width * texture.height * 4)
        halves.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        }
        return halves.map { Float(Float16(bitPattern: $0)) }
    }

    func testPassthroughFrameWithNoLayerToJoinSkipsThePass() throws {
        renderInfo.immersionStyle = .mixed
        gameMode = true
        SSAOParams.shared.enabled = false
        antiAliasingMode = .none

        // A few frames settle the frame-to-frame state (the GPU culling's in-flight results, the
        // shadows, the depth pyramid) so that the two frames compared differ in the pass alone.
        for _ in 0 ..< 3 {
            drawFrame()
        }
        drawFrame()
        XCTAssertNotNil(renderInfo.preCompositeBypassSource, "the pass is skipped: the look pass reads the lit scene")
        let bypassed = try readFloats(XCTUnwrap(textureResources.lookTexture))

        setRendering(.preCompositeBypass(.disabled))
        drawFrame()
        XCTAssertNil(renderInfo.preCompositeBypassSource, "disabled, the pass runs on every frame")
        let composited = try readFloats(XCTUnwrap(textureResources.lookTexture))

        XCTAssertGreaterThan(composited.max() ?? 0, 0.01, "the scene draws something")
        var maxDifference: Float = 0
        for i in 0 ..< min(bypassed.count, composited.count) {
            maxDifference = max(maxDifference, abs(bypassed[i] - composited[i]))
        }
        XCTAssertEqual(maxDifference, 0, accuracy: 1e-3, "the look pass sees the same pixels whether the composite pass copied them or not")
    }

    func testThePassRunsWhereverALayerJoinsTheScene() {
        gameMode = true
        SSAOParams.shared.enabled = false
        antiAliasingMode = .none

        // The environment lies behind the scene outside passthrough.
        renderInfo.immersionStyle = .none
        drawFrame()
        XCTAssertNil(renderInfo.preCompositeBypassSource, "the environment joins the scene")

        renderInfo.immersionStyle = .mixed
        SSAOParams.shared.enabled = true
        drawFrame()
        XCTAssertNil(renderInfo.preCompositeBypassSource, "ambient occlusion joins the scene")
        SSAOParams.shared.enabled = false

        gameMode = false
        drawFrame()
        XCTAssertNil(renderInfo.preCompositeBypassSource, "the editor's gizmo layer joins the scene")
        gameMode = true

        drawFrame()
        XCTAssertNotNil(renderInfo.preCompositeBypassSource, "nothing joins the lit scene: the pass is skipped")
    }
}

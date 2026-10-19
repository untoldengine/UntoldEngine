//
//  TAATransparentHistoryTests.swift
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

/// Over a transparent background (a headset's passthrough) a surface that moves across the
/// frame covers pixels whose history holds no surface at all. The resolve gives such a history
/// no weight: the surface's leading edge stays as opaque and as bright as its middle, instead
/// of fading toward the room behind it for the twenty frames the history takes to catch up.
@MainActor
final class TAATransparentHistoryTests: BaseRenderSetup {
    private var savedMode: AntiAliasingMode = .fxaa
    private var savedImmersion: UntoldImmersionMode = .none
    private var box: EntityID = .max

    override func setUp() async throws {
        try await super.setUp()
        savedMode = antiAliasingMode
        savedImmersion = renderInfo.immersionStyle
        // The passthrough's immersion style: the composite keeps the scene's coverage, so the
        // background stays transparent, as on a headset.
        renderInfo.immersionStyle = .mixed
    }

    override func tearDown() async throws {
        antiAliasingMode = savedMode
        renderInfo.immersionStyle = savedImmersion
        setRendering(.environment(.visible(true)))
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        let camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: simd_float3(0, 0, 4), target: .zero, up: simd_float3(0, 1, 0))
        box = createEntity()
        setEntityMeshDirect(entityId: box, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Box")
        let sun = createEntity()
        createDirLight(entityId: sun)
        rotateTo(entityId: sun, pitch: -40, yaw: 30, roll: 0)
        applyIBL = true
        // Nothing behind the box: the background stays the clear colour, transparent.
        setRendering(.environment(.visible(false)))
    }

    private func drawFrame() {
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()
    }

    /// The look output's pixels (the resolved frame in the temporal modes), as floats.
    private func frame() throws -> (pixels: [Float], width: Int, height: Int) {
        let texture = try XCTUnwrap(antiAliasingMode.isTemporal ? TemporalAntiAliasing.shared.resolvedTexture : textureResources.lookTexture)
        let shared = try XCTUnwrap(renderInfo.device.makeTexture(descriptor: {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: texture.pixelFormat, width: texture.width, height: texture.height, mipmapped: false)
            d.storageMode = .shared
            d.usage = [.shaderRead]
            return d
        }()))
        let copy = try XCTUnwrap(renderInfo.commandQueue.makeCommandBuffer())
        let blit = try XCTUnwrap(copy.makeBlitCommandEncoder())
        blit.copy(from: texture, to: shared)
        blit.endEncoding()
        copy.commit()
        copy.waitUntilCompleted()
        var halves = [UInt16](repeating: 0, count: shared.width * shared.height * 4)
        halves.withUnsafeMutableBytes { bytes in
            shared.getBytes(bytes.baseAddress!, bytesPerRow: shared.width * 8, from: MTLRegionMake2D(0, 0, shared.width, shared.height), mipmapLevel: 0)
        }
        return (halves.map { Float(Float16(bitPattern: $0)) }, shared.width, shared.height)
    }

    func testASurfaceMovingOverTheTransparentBackgroundKeepsItsLeadingEdge() throws {
        antiAliasingMode = .taa
        translateTo(entityId: box, position: simd_float3(1.2, 0, 0))
        for _ in 0 ..< 6 {
            drawFrame()
        }
        let still = try frame()
        let row = still.height / 2
        try XCTSkipUnless(still.pixels[(row * still.width + 8) * 4 + 3] < 0.01, "the background is not transparent here: alpha \(still.pixels[(row * still.width + 8) * 4 + 3])")
        // The box moves left, about forty pixels a frame; the pixels it covers each frame had
        // only the background in the history.
        var x = Float(1.2)
        for _ in 0 ..< 5 {
            x -= 0.16
            translateTo(entityId: box, position: simd_float3(x, 0, 0))
            drawFrame()
        }
        let moving = try frame()
        // The leading edge: the leftmost pixel of the box's middle row with some coverage.
        var leading = -1
        for px in 0 ..< moving.width where moving.pixels[(row * moving.width + px) * 4 + 3] > 0.5 {
            leading = px
            break
        }
        XCTAssertGreaterThan(leading, 0, "the box is in the frame")
        // Ten pixels inside the edge the box is opaque and as bright as its middle.
        var centre = -1
        for px in leading ..< moving.width where moving.pixels[(row * moving.width + px) * 4 + 3] < 0.5 {
            centre = (leading + px) / 2
            break
        }
        XCTAssertGreaterThan(centre, leading + 40, "the box spans more than eighty pixels")
        func luminance(_ px: Int) -> Float {
            let i = (row * moving.width + px) * 4
            return moving.pixels[i] * 0.2126 + moving.pixels[i + 1] * 0.7152 + moving.pixels[i + 2] * 0.0722
        }
        let edgeAlpha = moving.pixels[(row * moving.width + leading + 10) * 4 + 3]
        XCTAssertGreaterThan(edgeAlpha, 0.95, "the leading edge is opaque (alpha \(edgeAlpha))")
        let edge = luminance(leading + 10), middle = luminance(centre)
        XCTAssertGreaterThan(middle, 0.02, "the box is lit")
        XCTAssertGreaterThan(edge, middle * 0.8, "the leading edge is as bright as the middle (\(edge) against \(middle))")
    }
}

//
//  TAAPresentFoldTests.swift
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

/// When nothing sits between the temporal resolve and the output in the frame's graph, the
/// resolve presents the frame itself — the display's colour, encoded, and the opaque depth —
/// and the output transform pass stands down. The display gets what the output pass would
/// have written from the resolve.
@MainActor
final class TAAPresentFoldTests: BaseRenderSetup {
    private var savedMode: AntiAliasingMode = .fxaa

    override func setUp() async throws {
        try await super.setUp()
        savedMode = antiAliasingMode
        // The view's drawable is the display here; readable, to check what was presented.
        renderer.metalView.framebufferOnly = false
        setRendering(.gpuPassTiming(.enabled))
    }

    override func tearDown() async throws {
        setRendering(.gpuPassTiming(.disabled))
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
        let sun = createEntity()
        createDirLight(entityId: sun)
        rotateTo(entityId: sun, pitch: -40, yaw: 30, roll: 0)
        applyIBL = true
    }

    private func drawFrames(_ count: Int) {
        for _ in 0 ..< count {
            renderer.draw(in: renderer.metalView)
            renderInfo.lastCommandBuffer?.waitUntilCompleted()
        }
    }

    private func linearToSRGB(_ x: Float) -> Float {
        x <= 0.0031308 ? x * 12.92 : 1.055 * powf(max(x, 0), 1 / 2.4) - 0.055
    }

    func testTheResolvePresentsAndTheOutputPassStandsDown() throws {
        try XCTSkipUnless(renderInfo.device.supportsCounterSampling(.atStageBoundary), "no pass timing here")
        antiAliasingMode = .taa
        drawFrames(4)
        let presented = try XCTUnwrap(renderInfo.renderPassDescriptor?.colorAttachments[0].texture, "the view has a drawable")
        try XCTSkipUnless(presented.pixelFormat == .bgra8Unorm_srgb || presented.pixelFormat == .bgra8Unorm, "unexpected display format \(presented.pixelFormat.rawValue)")
        XCTAssertTrue(renderInfo.temporalResolveMayPresent, "nothing registered between the resolve and the output")
        XCTAssertTrue(TemporalAntiAliasing.shared.presentedThisFrame, "the resolve presented")
        let passes = Set(GPUPassTiming.shared.lastFrame().passes.map(\.label))
        XCTAssertTrue(passes.contains("TAA"))
        XCTAssertFalse(passes.contains("Output"), "the output transform pass stood down: \(passes.sorted())")

        // The display holds the resolve, encoded as the output pass encodes it.
        let resolved = try XCTUnwrap(TemporalAntiAliasing.shared.resolvedTexture)
        let shared = try XCTUnwrap(renderInfo.device.makeTexture(descriptor: {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: resolved.pixelFormat, width: resolved.width, height: resolved.height, mipmapped: false)
            d.storageMode = .shared
            d.usage = [.shaderRead]
            return d
        }()))
        let copy = try XCTUnwrap(renderInfo.commandQueue.makeCommandBuffer())
        let blit = try XCTUnwrap(copy.makeBlitCommandEncoder())
        blit.copy(from: resolved, to: shared)
        blit.endEncoding()
        copy.commit()
        copy.waitUntilCompleted()
        var halves = [UInt16](repeating: 0, count: shared.width * shared.height * 4)
        halves.withUnsafeMutableBytes { bytes in
            shared.getBytes(bytes.baseAddress!, bytesPerRow: shared.width * 8, from: MTLRegionMake2D(0, 0, shared.width, shared.height), mipmapLevel: 0)
        }
        var bytes = [UInt8](repeating: 0, count: presented.width * presented.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            presented.getBytes(buffer.baseAddress!, bytesPerRow: presented.width * 4, from: MTLRegionMake2D(0, 0, presented.width, presented.height), mipmapLevel: 0)
        }
        // The pass encodes when the pipeline says so; an sRGB display format encodes in hardware.
        let encodes = renderInfo.colorPipeline.present.encodingMode.rawValue == 1 || presented.pixelFormat == .bgra8Unorm_srgb
        var checked = 0
        for (x, y) in [(presented.width / 2, presented.height / 2), (presented.width / 3, presented.height * 2 / 3), (presented.width * 2 / 3, presented.height / 3)] {
            let i = y * presented.width + x
            for (channel, byteIndex) in [(0, 2), (1, 1), (2, 0)] { // bgra
                var value = Float(Float16(bitPattern: halves[i * 4 + channel]))
                value = max(value, 0)
                if encodes { value = linearToSRGB(value) }
                let expected = min(max(value, 0), 1) * 255
                XCTAssertEqual(Float(bytes[i * 4 + byteIndex]), expected, accuracy: 2.5, "pixel (\(x), \(y)) channel \(channel)")
                checked += 1
            }
        }
        XCTAssertEqual(checked, 9)
    }

    func testNoFoldWithoutTheTemporalResolve() throws {
        try XCTSkipUnless(renderInfo.device.supportsCounterSampling(.atStageBoundary), "no pass timing here")
        antiAliasingMode = .fxaa
        drawFrames(3)
        XCTAssertFalse(renderInfo.temporalResolveMayPresent)
        XCTAssertFalse(TemporalAntiAliasing.shared.presentedThisFrame)
        let passes = Set(GPUPassTiming.shared.lastFrame().passes.map(\.label))
        XCTAssertTrue(passes.contains("Output"), "the output transform pass presents: \(passes.sorted())")
    }
}

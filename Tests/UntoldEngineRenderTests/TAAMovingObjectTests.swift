//
//  TAAMovingObjectTests.swift
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

/// A surface that moves on its own under a still camera: the opaque pass writes its motion per
/// pixel and the resolve finds its history where it was, so the resolve of a moving box differs
/// from the box's own frame about as little as a resolve held still does, instead of trailing
/// a ghost of where the box has been.
@MainActor
final class TAAMovingObjectTests: BaseRenderSetup {
    private var camera: EntityID = 0
    private var box: EntityID = 0
    private var savedMode: AntiAliasingMode = .fxaa

    override func setUp() async throws {
        try await super.setUp()
        savedMode = antiAliasingMode
    }

    override func tearDown() async throws {
        antiAliasingMode = savedMode
        TemporalAntiAliasing.shared.invalidateHistory()
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: simd_float3(0, 1, 4), target: .zero, up: simd_float3(0, 1, 0))
        box = createEntity()
        setEntityMeshDirect(entityId: box, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Box")
        translateTo(entityId: box, position: simd_float3(-0.6, 0.5, 0))
        let sun = createEntity()
        createDirLight(entityId: sun)
        rotateTo(entityId: sun, pitch: -40, yaw: 30, roll: 0)
        applyIBL = true
    }

    private func drawFrame() {
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()
    }

    private func readFloats(_ texture: MTLTexture) throws -> [Float] {
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
        return halves.map { Float(Float16(bitPattern: $0)) }
    }

    /// The frame as the output pass would present it: the resolve in a temporal mode, the look output otherwise.
    private func readOutput() throws -> [Float] {
        try readFloats(XCTUnwrap(antiAliasingMode.isTemporal ? TemporalAntiAliasing.shared.resolvedTexture : textureResources.lookTexture))
    }

    private func meanAbsoluteDifference(_ a: [Float], _ b: [Float]) -> Float {
        var sum: Float = 0
        for i in stride(from: 0, to: min(a.count, b.count), by: 4) {
            sum += abs(a[i] - b[i]) + abs(a[i + 1] - b[i + 1]) + abs(a[i + 2] - b[i + 2])
        }
        return sum / Float(min(a.count, b.count) / 4 * 3)
    }

    func testTheResolveFollowsAMovingBoxWithoutAGhost() throws {
        func pose(_ frame: Int) -> simd_float3 {
            simd_float3(-0.6 + 0.16 * Float(frame), 0.5, 0)
        }
        let frameCount = 8

        antiAliasingMode = .none
        translateTo(entityId: box, position: pose(0))
        drawFrame()
        drawFrame()
        let first = try readOutput()
        translateTo(entityId: box, position: pose(frameCount - 1))
        drawFrame()
        drawFrame()
        let last = try readOutput()
        let motion = meanAbsoluteDifference(first, last)
        XCTAssertGreaterThan(motion, 0.002, "the box's path moves it in the frame")

        for mode in [AntiAliasingMode.taa, .msaaTaa] {
            antiAliasingMode = mode
            TemporalAntiAliasing.shared.invalidateHistory()
            for frame in 0 ..< frameCount {
                translateTo(entityId: box, position: pose(frame))
                drawFrame()
            }
            let moved = try readOutput()
            TemporalAntiAliasing.shared.invalidateHistory()
            for _ in 0 ..< frameCount {
                drawFrame()
            }
            let held = try readOutput()
            let shadow = meanAbsoluteDifference(moved, last)
            let floor = meanAbsoluteDifference(held, last)
            print("TAA moving-box \(mode): resolve differs from the box's own frame by \(shadow), held still by \(floor), the first pose by \(motion)")
            XCTAssertLessThan(shadow, floor + 0.1 * motion, "\(mode): the resolve follows the box: it differs from the box's own frame by \(shadow), held still by \(floor), the first pose differs by \(motion)")
        }
    }
}

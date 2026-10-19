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

/// A surface that moves on its own under a still camera. On the forward path the opaque pass
/// writes its motion per pixel and the resolve finds its history where it was, so the resolve
/// of a moving box differs from the box's own frame about as little as a resolve held still
/// does, instead of trailing a ghost of where the box has been. The deferred and hybrid paths
/// write no motion: there the neighbourhood clip is what bounds the ghost. Measured (M4 Max,
/// a plain box over a plain background): the excess over a resolve held still is 0.1–0.3 % of
/// the box's motion with the motion written, 0.2–0.4 % without, at either stride below.
@MainActor
final class TAAMovingObjectTests: BaseRenderSetup {
    private var camera: EntityID = 0
    private var box: EntityID = 0
    private var savedMode: AntiAliasingMode = .fxaa
    private var savedPath: RenderPath = .deferred

    override func setUp() async throws {
        try await super.setUp()
        savedMode = antiAliasingMode
        savedPath = getRenderPath()
    }

    override func tearDown() async throws {
        antiAliasingMode = savedMode
        setRendering(.renderPath(savedPath))
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

    /// How far the resolve of the moving box ends from the box's own frame (`shadow`), against
    /// how far a resolve held still on that frame ends from it (`floor`): the excess is the
    /// ghost. `motion` is how far apart the box's first and last frames are.
    private struct Ghost {
        let motion: Float
        let shadow: Float
        let floor: Float
    }

    /// A stride of 0.16 a frame crosses the box's width in six frames: a pixel the box leaves
    /// has only the background around it, so the clip alone rejects the box's history there.
    private static let fastStride: Float = 0.16
    /// A stride of 0.02 a frame, a few pixels, is the ghosting case: the pixels the trailing
    /// edge leaves still have the box in their neighbourhood, so the clip keeps part of the
    /// stale history, while the motion vectors find the surface's own history instead.
    private static let slowStride: Float = 0.02

    /// The box walks eight poses, a stride apart, under the temporal resolve on the given path,
    /// then the resolve is held on the last pose for as long.
    private func ghost(on path: RenderPath, mode: AntiAliasingMode, stride: Float) throws -> Ghost {
        func pose(_ frame: Int) -> simd_float3 {
            simd_float3(-0.6 + stride * Float(frame), 0.5, 0)
        }
        let frameCount = 8

        setRendering(.renderPath(path))
        antiAliasingMode = .none
        translateTo(entityId: box, position: pose(0))
        drawFrame()
        drawFrame()
        let first = try readOutput()
        translateTo(entityId: box, position: pose(frameCount - 1))
        drawFrame()
        drawFrame()
        let last = try readOutput()
        XCTAssertEqual(getRenderPath(), path)
        XCTAssertEqual(renderInfo.perFragmentLightingBuilt, path == .forward, "the pipelines follow the path")

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
        let measured = Ghost(motion: meanAbsoluteDifference(first, last), shadow: meanAbsoluteDifference(moved, last), floor: meanAbsoluteDifference(held, last))
        print("TAA moving-box \(path) \(mode) stride \(stride): resolve differs from the box's own frame by \(measured.shadow), held still by \(measured.floor), the first pose by \(measured.motion)")
        XCTAssertGreaterThan(measured.motion, 0.0005, "the box's path moves it in the frame")
        return measured
    }

    func testTheResolveFollowsAMovingBoxWithoutAGhost() throws {
        for mode in [AntiAliasingMode.taa, .msaaTaa] {
            for stride in [Self.fastStride, Self.slowStride] {
                let measured = try ghost(on: .forward, mode: mode, stride: stride)
                XCTAssertLessThan(measured.shadow, measured.floor + 0.1 * measured.motion, "\(mode), stride \(stride): the resolve follows the box: it differs from the box's own frame by \(measured.shadow), held still by \(measured.floor), the first pose differs by \(measured.motion)")
            }
        }
    }

    /// Without motion vectors the resolve looks for the box's history where the camera alone
    /// puts it — where the box was — and the clip to the neighbourhood is what keeps that
    /// history from trailing. The ghost it leaves is bounded as the forward path's is, at a
    /// tenth of the motion (a clip that let the history through would leave most of it), and
    /// is about twice the forward path's in the measurement above.
    func testWithoutMotionVectorsTheClipBoundsTheGhost() throws {
        for path in [RenderPath.deferred, .hybrid] {
            for mode in [AntiAliasingMode.taa, .msaaTaa] {
                for stride in [Self.fastStride, Self.slowStride] {
                    let measured = try ghost(on: path, mode: mode, stride: stride)
                    XCTAssertLessThan(measured.shadow, measured.floor + 0.1 * measured.motion, "\(path) \(mode), stride \(stride): the clip bounds the ghost: the resolve differs from the box's own frame by \(measured.shadow), held still by \(measured.floor), the first pose differs by \(measured.motion)")
                }
            }
        }
    }
}

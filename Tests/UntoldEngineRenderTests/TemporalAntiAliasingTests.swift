//
//  TemporalAntiAliasingTests.swift
//  UntoldEngine
//
//  The temporal resolve (TemporalAntiAliasing.swift, TAAShader.metal): the jitter sequence,
//  the jitter going into and out of the projection, and the resolve of a still scene settling
//  to a stable image that stays close to the un-anti-aliased frame.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

@MainActor
final class TemporalAntiAliasingTests: BaseRenderSetup {
    private var camera: EntityID = 0
    private var savedMode: AntiAliasingMode = .fxaa

    override func setUp() async throws {
        try await super.setUp()
        savedMode = antiAliasingMode
    }

    override func tearDown() async throws {
        antiAliasingMode = savedMode
        TemporalAntiAliasing.shared.applyJitter()
        TemporalAntiAliasing.shared.invalidateHistory()
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: simd_float3(0, 1, 4), target: .zero, up: simd_float3(0, 1, 0))
        let box = createEntity()
        setEntityMeshDirect(entityId: box, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Box")
        translateTo(entityId: box, position: simd_float3(0, 0.5, 0))
        let slab = createEntity()
        setEntityMeshDirect(entityId: slab, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Slab")
        scaleTo(entityId: slab, scale: simd_float3(4, 0.05, 0.05))
        translateTo(entityId: slab, position: simd_float3(0, 1.6, -1))
    }

    // MARK: - Helpers

    private func drawFrame() {
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()
    }

    /// The anti-aliasing output as floats, RGBA per pixel.
    private func readAntiAliasingOutput() throws -> [Float] {
        let texture = try XCTUnwrap(textureResources.antiAliasingTexture)
        XCTAssertEqual(texture.pixelFormat, .rgba16Float)
        var halves = [UInt16](repeating: 0, count: texture.width * texture.height * 4)
        halves.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        }
        return halves.map { Float(Float16(bitPattern: $0)) }
    }

    private func meanAbsoluteDifference(_ a: [Float], _ b: [Float]) -> Float {
        var total: Float = 0
        for i in 0 ..< min(a.count, b.count) {
            total += abs(a[i] - b[i])
        }
        return total / Float(max(1, min(a.count, b.count)))
    }

    // MARK: - Tests

    func testJitterSequenceIsSubPixelAndCentred() {
        XCTAssertEqual(taaJitterSequence.count, 8)
        var mean = simd_float2.zero
        for offset in taaJitterSequence {
            XCTAssertLessThanOrEqual(abs(offset.x), 0.5)
            XCTAssertLessThanOrEqual(abs(offset.y), 0.5)
            mean += offset
        }
        mean /= Float(taaJitterSequence.count)
        XCTAssertLessThan(abs(mean.x), 0.1, "the offsets average near the pixel centre")
        XCTAssertLessThan(abs(mean.y), 0.1)
        XCTAssertEqual(Set(taaJitterSequence.map { "\($0.x),\($0.y)" }).count, 8, "eight distinct offsets")
    }

    func testJitterGoesIntoAndOutOfTheProjection() {
        antiAliasingMode = .fxaa
        TemporalAntiAliasing.shared.applyJitter()
        let base = renderInfo.perspectiveSpace

        antiAliasingMode = .taa
        TemporalAntiAliasing.shared.applyJitter()
        let jittered = renderInfo.perspectiveSpace
        let pixels = TemporalAntiAliasing.shared.currentJitterPixels
        XCTAssertNotEqual(pixels, .zero)
        XCTAssertEqual(jittered.columns.2.x - base.columns.2.x, 2 * pixels.x / renderInfo.viewPort.x, accuracy: 1e-6)
        XCTAssertEqual(jittered.columns.2.y - base.columns.2.y, 2 * pixels.y / renderInfo.viewPort.y, accuracy: 1e-6)
        XCTAssertEqual(jittered.columns.0, base.columns.0)
        XCTAssertEqual(jittered.columns.1, base.columns.1)
        XCTAssertEqual(jittered.columns.3, base.columns.3)
        XCTAssertEqual(TemporalAntiAliasing.shared.unjitteredProjection, base, "the unjittered projection is the base one")

        TemporalAntiAliasing.shared.applyJitter()
        XCTAssertNotEqual(renderInfo.perspectiveSpace.columns.2.x, jittered.columns.2.x, "the next frame takes the next offset, not a sum")

        antiAliasingMode = .fxaa
        TemporalAntiAliasing.shared.applyJitter()
        XCTAssertEqual(renderInfo.perspectiveSpace, base, "leaving the temporal mode leaves the projection as it was")
    }

    func testResolveSettlesOnAStillSceneCloseToTheSingleSampleFrame() throws {
        antiAliasingMode = .none
        for _ in 0 ..< 2 {
            drawFrame()
        }
        // The look output is what the output pass shows without a post-look pass.
        let lookTexture = try XCTUnwrap(textureResources.lookTexture)
        var reference = [UInt16](repeating: 0, count: lookTexture.width * lookTexture.height * 4)
        reference.withUnsafeMutableBytes { bytes in
            lookTexture.getBytes(bytes.baseAddress!, bytesPerRow: lookTexture.width * 8, from: MTLRegionMake2D(0, 0, lookTexture.width, lookTexture.height), mipmapLevel: 0)
        }
        let single = reference.map { Float(Float16(bitPattern: $0)) }
        XCTAssertGreaterThan(single.max() ?? 0, 0.01, "the scene draws something")

        antiAliasingMode = .taa
        TemporalAntiAliasing.shared.invalidateHistory()
        for _ in 0 ..< 10 {
            drawFrame()
        }
        let settled = try readAntiAliasingOutput()
        drawFrame()
        let next = try readAntiAliasingOutput()

        XCTAssertFalse(settled.contains { $0.isNaN || $0.isInfinite }, "no NaN or infinity in the resolve")
        XCTAssertLessThan(meanAbsoluteDifference(settled, next), 0.004, "a still scene no longer changes between frames")
        XCTAssertLessThan(meanAbsoluteDifference(settled, single), 0.02, "the resolve stays close to the single-sample frame: no drift, no smear")
        XCTAssertGreaterThan(meanAbsoluteDifference(settled, single), 0, "and is not the single-sample frame")
    }
}

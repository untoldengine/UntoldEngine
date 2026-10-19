//
//  PerFragmentLightingTests.swift
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

/// The geometry lights itself whole once per fragment — the sun, a point light, the indirect
/// light, the shadows — and writes the lit colour, so the light quad stands down: the forward
/// path. The picture is the one the quad makes lighting once per sample over the indirect light
/// the geometry carried (the hybrid path), the quad's draw is gone from the frame, and the
/// pipelines follow the path on the next frame.
@MainActor
final class PerFragmentLightingTests: BaseRenderSetup {
    private var savedMode: AntiAliasingMode = .fxaa
    private var savedPath: RenderPath = .deferred
    private var pointLight: EntityID = .max

    override func setUp() async throws {
        try await super.setUp()
        savedMode = antiAliasingMode
        savedPath = getRenderPath()
    }

    override func tearDown() async throws {
        setRendering(.renderPath(savedPath))
        antiAliasingMode = savedMode
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        let camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: simd_float3(0, 2, 5), target: simd_float3(0, 0.3, 0), up: simd_float3(0, 1, 0))
        // A box over a slab under the sun and a point light: the sun's shadow falls on the slab,
        // the point light reaches the box's near side, and the indirect light is everywhere.
        let box = createEntity()
        setEntityMeshDirect(entityId: box, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Box")
        translateTo(entityId: box, position: simd_float3(0, 0.5, 0))
        let slab = createEntity()
        setEntityMeshDirect(entityId: slab, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Slab")
        scaleTo(entityId: slab, scale: simd_float3(6, 0.1, 6))
        translateTo(entityId: slab, position: simd_float3(0, -0.05, 0))
        let sun = createEntity()
        createDirLight(entityId: sun)
        rotateTo(entityId: sun, pitch: -55, yaw: 30, roll: 0)
        pointLight = createEntity()
        createPointLight(entityId: pointLight)
        translateTo(entityId: pointLight, position: simd_float3(1.2, 1.2, 1.5))
        applyIBL = true
    }

    private func drawFrames(_ count: Int = 3) {
        for _ in 0 ..< count {
            renderer.draw(in: renderer.metalView)
            renderInfo.lastCommandBuffer?.waitUntilCompleted()
        }
    }

    private func litFrame(on path: RenderPath) throws -> [Float] {
        setRendering(.renderPath(path))
        drawFrames()
        XCTAssertEqual(getRenderPath(), path)
        XCTAssertEqual(renderInfo.perFragmentLightingBuilt, path == .forward, "the pipelines follow the path")
        XCTAssertTrue(renderInfo.perFragmentIndirectLightingBuilt, "the indirect light stays per fragment either way")
        let texture = try XCTUnwrap(textureResources.deferredColorMap)
        var halves = [UInt16](repeating: 0, count: texture.width * texture.height * 4)
        halves.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        }
        return halves.map { Float(Float16(bitPattern: $0)) }
    }

    private func compare(_ a: [Float], _ b: [Float]) -> (mean: Float, max: Float, lit: Int) {
        var sum: Float = 0, maxDifference: Float = 0, lit = 0
        for i in stride(from: 0, to: a.count, by: 4) {
            for c in 0 ..< 3 {
                let d = abs(a[i + c] - b[i + c])
                sum += d
                maxDifference = max(maxDifference, d)
            }
            if a[i] + a[i + 1] + a[i + 2] > 0.02 { lit += 1 }
        }
        return (sum / Float(a.count / 4 * 3), maxDifference, lit)
    }

    func testTheSamePictureAtOneSample() throws {
        antiAliasingMode = .none
        let quad = try litFrame(on: .hybrid)
        let perFragment = try litFrame(on: .forward)
        let result = compare(quad, perFragment)
        XCTAssertGreaterThan(result.lit, 1000, "the scene is lit")
        XCTAssertLessThan(result.mean, 0.0005, "mean difference per channel")
        XCTAssertLessThan(result.max, 0.02, "the G-buffer's half-precision records, which the quad lit from, bound the per-pixel difference (measured 0.001)")
        print(String(format: "Per-fragment lighting at 1 sample: mean difference %.5f, max %.4f over %d lit pixels", result.mean, result.max, result.lit))
    }

    func testTheSamePictureUnderMSAA() throws {
        try XCTSkipUnless(renderInfo.device.supportsTextureSampleCount(4), "no 4× MSAA here")
        antiAliasingMode = .msaa
        setRendering(.multisampleCount(4))
        let quad = try litFrame(on: .hybrid)
        XCTAssertEqual(renderInfo.opaqueSampleCount, 4)
        let perFragment = try litFrame(on: .forward)
        let result = compare(quad, perFragment)
        XCTAssertGreaterThan(result.lit, 1000, "the scene is lit")
        XCTAssertLessThan(result.mean, 0.001, "mean difference per channel: only edge pixels differ, lit once instead of once per sample (measured 0.00003)")
        print(String(format: "Per-fragment lighting at 4 samples: mean difference %.5f, max %.4f over %d lit pixels", result.mean, result.max, result.lit))
    }

    func testTheQuadStandsDown() throws {
        antiAliasingMode = .none
        _ = try litFrame(on: .hybrid)
        let withQuad = RenderStatsCollector.shared.snapshot().drawCallsTotal
        _ = try litFrame(on: .forward)
        let without = RenderStatsCollector.shared.snapshot().drawCallsTotal
        XCTAssertFalse(renderInfo.tileLightStageUsed)
        XCTAssertEqual(without, withQuad - 1, "the frame has the same draws but the light quad's")
    }

    func testThePointLightIsThere() throws {
        antiAliasingMode = .none
        let withLight = try litFrame(on: .forward)
        destroyEntity(entityId: pointLight)
        let without = try litFrame(on: .forward)
        let result = compare(withLight, without)
        XCTAssertGreaterThan(result.max, 0.05, "the point light lit the box's near side (max difference \(result.max))")
    }
}

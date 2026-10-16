//
//  HybridRenderPathTests.swift
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

/// The hybrid path, drawn: the geometry carries the image-based light and the sun's shadow in
/// the G-buffer and the light quad adds the direct lights once per sample. Its picture is the
/// deferred path's and the forward path's; the quad still draws, the tile light stage stands
/// aside, and a point light is counted once — by the quad, not by the geometry as well.
@MainActor
final class HybridRenderPathTests: BaseRenderSetup {
    private var savedMode: AntiAliasingMode = .fxaa
    private var savedPath: RenderPath = .deferred
    private var pointLight: EntityID = .max

    override func setUp() async throws {
        try await super.setUp()
        savedMode = antiAliasingMode
        savedPath = getRenderPath()
        antiAliasingMode = .none
    }

    override func tearDown() async throws {
        setRendering(.renderPath(savedPath))
        setRendering(.multisampleCount(4))
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

    /// The lit scene colour of a frame on the path, the pipelines rebuilt for it.
    private func frame(on path: RenderPath) throws -> [Float] {
        setRendering(.renderPath(path))
        drawFrames()
        XCTAssertEqual(getRenderPath(), path)
        XCTAssertEqual(renderInfo.perFragmentIndirectLightingBuilt, path != .deferred, "the pipelines follow the path")
        XCTAssertEqual(renderInfo.perFragmentLightingBuilt, path == .forward, "the pipelines follow the path")
        let texture = try XCTUnwrap(textureResources.deferredColorMap)
        var halves = [UInt16](repeating: 0, count: texture.width * texture.height * 4)
        halves.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        }
        return halves.map { Float(Float16(bitPattern: $0)) }
    }

    private struct Difference {
        let mean: Float
        let max: Float
        let lit: Int
    }

    private func compare(_ a: [Float], _ b: [Float]) -> Difference {
        var sum: Float = 0, maxDifference: Float = 0, lit = 0
        for i in stride(from: 0, to: a.count, by: 4) {
            for c in 0 ..< 3 {
                let d = abs(a[i + c] - b[i + c])
                sum += d
                maxDifference = max(maxDifference, d)
            }
            if a[i] + a[i + 1] + a[i + 2] > 0.02 { lit += 1 }
        }
        return Difference(mean: sum / Float(a.count / 4 * 3), max: maxDifference, lit: lit)
    }

    func testTheSamePictureAsDeferredAtOneSample() throws {
        let deferred = try frame(on: .deferred)
        let hybrid = try frame(on: .hybrid)
        let result = compare(deferred, hybrid)
        XCTAssertGreaterThan(result.lit, 1000, "the scene is lit")
        XCTAssertLessThan(result.mean, 0.002, "mean difference per channel")
        XCTAssertLessThan(result.max, 0.06, "the material's 8-bit roughness and metallic in the G-buffer, which the deferred light pass read the indirect light from, bound the per-pixel difference")
        print(String(format: "Hybrid against deferred at 1 sample: mean difference %.5f, max %.4f over %d lit pixels", result.mean, result.max, result.lit))
    }

    func testTheSamePictureAsDeferredUnderMSAA() throws {
        try XCTSkipUnless(renderInfo.device.supportsTextureSampleCount(4), "no 4× MSAA here")
        antiAliasingMode = .msaa
        setRendering(.multisampleCount(4))
        let deferred = try frame(on: .deferred)
        XCTAssertEqual(renderInfo.opaqueSampleCount, 4)
        let hybrid = try frame(on: .hybrid)
        let result = compare(deferred, hybrid)
        XCTAssertGreaterThan(result.lit, 1000, "the scene is lit")
        XCTAssertLessThan(result.mean, 0.003, "mean difference per channel: only edge pixels differ, the indirect light evaluated once per pixel instead of once per sample")
        print(String(format: "Hybrid against deferred at 4 samples: mean difference %.5f, max %.4f over %d lit pixels", result.mean, result.max, result.lit))
    }

    func testTheSamePictureAsForward() throws {
        let hybrid = try frame(on: .hybrid)
        let forward = try frame(on: .forward)
        let result = compare(hybrid, forward)
        XCTAssertGreaterThan(result.lit, 1000, "the scene is lit")
        XCTAssertLessThan(result.mean, 0.0005, "mean difference per channel")
        XCTAssertLessThan(result.max, 0.02, "the G-buffer's half-precision records, which the quad lit the direct part from, bound the per-pixel difference")
        print(String(format: "Hybrid against forward at 1 sample: mean difference %.5f, max %.4f over %d lit pixels", result.mean, result.max, result.lit))
    }

    func testTheQuadDrawsAndTheTileStageStandsAside() throws {
        _ = try frame(on: .forward)
        let forwardDraws = RenderStatsCollector.shared.snapshot().drawCallsTotal
        _ = try frame(on: .hybrid)
        let hybridDraws = RenderStatsCollector.shared.snapshot().drawCallsTotal
        XCTAssertEqual(hybridDraws, forwardDraws + 1, "the light quad's draw is back: the direct lights are its")
        XCTAssertFalse(renderInfo.tileLightStageUsed, "the tile light stage would light the indirect part a second time")
    }

    func testThePointLightIsCountedOnce() throws {
        // The point light's own contribution on each path: the frame with it less the frame
        // without. The quad adds the light once per sample on both; were the geometry adding it
        // as well on the hybrid path, the contribution would double.
        let hybridWith = try frame(on: .hybrid)
        let deferredWith = try frame(on: .deferred)
        destroyEntity(entityId: pointLight)
        let deferredWithout = try frame(on: .deferred)
        let hybridWithout = try frame(on: .hybrid)
        let hybridLight = zip(hybridWith, hybridWithout).map { $0 - $1 }
        let deferredLight = zip(deferredWith, deferredWithout).map { $0 - $1 }
        let present = compare(hybridLight, [Float](repeating: 0, count: hybridLight.count))
        XCTAssertGreaterThan(present.max, 0.05, "the point light lit the box's near side (max contribution \(present.max))")
        let once = compare(hybridLight, deferredLight)
        XCTAssertLessThan(once.max, 0.03, "the light's contribution is the deferred path's, not twice it (max difference \(once.max) against a contribution of \(present.max))")
        XCTAssertLessThan(once.mean, 0.0005, "mean difference per channel")
        print(String(format: "Point light on hybrid against deferred: contribution max %.4f, difference mean %.5f, max %.4f", present.max, once.mean, once.max))
    }
}

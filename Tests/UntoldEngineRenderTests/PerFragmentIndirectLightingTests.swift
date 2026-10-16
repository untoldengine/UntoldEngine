//
//  PerFragmentIndirectLightingTests.swift
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

/// The geometry evaluates the image-based light and the sun's cascade shadow once per fragment
/// and carries them in the G-buffer; the light pass adds them from there: the hybrid path. The
/// picture is the one the light pass makes computing them once per sample (the deferred path),
/// and the pipelines follow the path on the next frame. `HybridRenderPathTests` has the rest of
/// the hybrid path: the quad's draw, the tile stage, the direct lights counted once.
@MainActor
final class PerFragmentIndirectLightingTests: BaseRenderSetup {
    private var savedMode: AntiAliasingMode = .fxaa
    private var savedPath: RenderPath = .deferred

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
        // A box over a slab: the box's shadow falls on the slab, so both the indirect light and
        // the sun's shadow show in the picture.
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
        XCTAssertEqual(renderInfo.perFragmentIndirectLightingBuilt, path == .hybrid, "the pipelines follow the path")
        XCTAssertFalse(renderInfo.perFragmentLightingBuilt, "the quad lights on both paths")
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
        let perSample = try litFrame(on: .deferred)
        let perFragment = try litFrame(on: .hybrid)
        let result = compare(perSample, perFragment)
        XCTAssertGreaterThan(result.lit, 1000, "the scene is lit")
        XCTAssertLessThan(result.mean, 0.002, "mean difference per channel")
        XCTAssertLessThan(result.max, 0.06, "the material's 8-bit roughness and metallic in the G-buffer bound the per-pixel difference")
        print(String(format: "Per-fragment indirect at 1 sample: mean difference %.5f, max %.4f over %d lit pixels", result.mean, result.max, result.lit))
    }

    func testTheSamePictureUnderMSAA() throws {
        try XCTSkipUnless(renderInfo.device.supportsTextureSampleCount(4), "no 4× MSAA here")
        antiAliasingMode = .msaa
        setRendering(.multisampleCount(4))
        let perSample = try litFrame(on: .deferred)
        XCTAssertEqual(renderInfo.opaqueSampleCount, 4)
        let perFragment = try litFrame(on: .hybrid)
        let result = compare(perSample, perFragment)
        XCTAssertGreaterThan(result.lit, 1000, "the scene is lit")
        XCTAssertLessThan(result.mean, 0.003, "mean difference per channel: only edge pixels differ")
        print(String(format: "Per-fragment indirect at 4 samples: mean difference %.5f, max %.4f over %d lit pixels", result.mean, result.max, result.lit))
    }

    func testTheShadowIsCarried() throws {
        antiAliasingMode = .none
        let perFragment = try litFrame(on: .hybrid)
        let texture = try XCTUnwrap(textureResources.deferredColorMap)
        // The slab fills the lower part of the frame; the box's shadow is its darkest region,
        // the open slab its brightest. Both modes made the same picture (above), so this is
        // the shadow being there at all.
        var luminance: [Float] = []
        for y in Int(Double(texture.height) * 0.6) ..< Int(Double(texture.height) * 0.95) {
            for x in 0 ..< texture.width {
                let i = (y * texture.width + x) * 4
                luminance.append(perFragment[i] * 0.2126 + perFragment[i + 1] * 0.7152 + perFragment[i + 2] * 0.0722)
            }
        }
        luminance.sort()
        let dark = luminance[luminance.count / 50], bright = luminance[luminance.count * 49 / 50]
        XCTAssertGreaterThan(bright, 0.05, "the slab is lit")
        XCTAssertLessThan(dark, bright * 0.7, "the slab has the box's shadow (\(dark) against \(bright))")
    }
}

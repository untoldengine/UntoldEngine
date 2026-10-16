//
//  XRProbeOrientationTests.swift
//  UntoldEngine
//
//  The room probe's faces light the sides of the world they stand for: its +y face, the
//  ceiling, lights what faces up; its +z face, behind the wearer, lights what faces them.
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

@MainActor
final class XRProbeOrientationTests: BaseRenderSetup {
    private var savedMode: AntiAliasingMode = .fxaa
    private var savedPath: RenderPath = .deferred
    private var sphere: EntityID = 0

    override func setUp() async throws {
        try await super.setUp()
        savedMode = antiAliasingMode
        antiAliasingMode = .none
        applyIBL = true
        savedPath = getRenderPath()
        setRendering(.renderPath(.forward))
        // The probe alone: the harness's scene brings a sun of its own.
        LightingSystem.shared.activeDirectionalLight = nil
    }

    override func tearDown() async throws {
        RuntimeEnvironmentLightingStore.shared.publishXRLighting(nil)
        RuntimeEnvironmentLightingStore.shared.setMode(.staticIBL)
        setRendering(.renderPath(savedPath))
        antiAliasingMode = savedMode
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        let camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: .zero, target: simd_float3(0, 0, -1), up: simd_float3(0, 1, 0))
        // A white rough sphere 2 m ahead: what each side of it gets is the light from that side.
        sphere = createEntity()
        setEntityMeshDirect(entityId: sphere, meshes: BasicPrimitives.createSphere(extent: 0.5), assetName: "Sphere")
        translateTo(entityId: sphere, position: simd_float3(0, 0, -2))
        updateMaterialColor(entityId: sphere, color: .white)
        updateMaterialRoughness(entityId: sphere, roughness: 1)
        updateMaterialMetallic(entityId: sphere, metallic: 0)
    }

    /// A probe of one bright face, pre-filtered as the headset's room probe is, published as
    /// the scene's light.
    private func light(fromFace bright: Int) throws {
        let device = try XCTUnwrap(renderInfo.device)
        let descriptor = MTLTextureDescriptor.textureCubeDescriptor(pixelFormat: .rgba16Float, size: 8, mipmapped: false)
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        let cube = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        for face in 0 ..< 6 {
            let value = Float16(face == bright ? 1.0 : 0.02)
            var texels = [UInt16](repeating: 0, count: 8 * 8 * 4)
            for i in 0 ..< 64 {
                texels[i * 4] = value.bitPattern
                texels[i * 4 + 1] = value.bitPattern
                texels[i * 4 + 2] = value.bitPattern
                texels[i * 4 + 3] = Float16(1.0).bitPattern
            }
            texels.withUnsafeBytes { bytes in
                cube.replace(region: MTLRegionMake2D(0, 0, 8, 8), mipmapLevel: 0, slice: face, withBytes: bytes.baseAddress!, bytesPerRow: 8 * 8, bytesPerImage: 8 * 8 * 8)
            }
        }
        let set = try XCTUnwrap(makeRuntimeEnvironmentLightingTextureSet(labelPrefix: "Orientation test"))
        let commandBuffer = try XCTUnwrap(renderInfo.commandQueue.makeCommandBuffer())
        XCTAssertTrue(executeXRIBLCubePreFilterPass(commandBuffer: commandBuffer, environmentCubeTexture: cube, target: set))
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        RuntimeEnvironmentLightingStore.shared.publishXRLighting(RuntimeEnvironmentLighting(irradianceMap: set.irradianceMap, specularMap: set.specularMap, brdfMap: set.brdfMap, intensityScale: 1, isValid: true))
        RuntimeEnvironmentLightingStore.shared.setMode(.realWorldEstimate)
        for _ in 0 ..< 2 {
            renderer.draw(in: renderer.metalView)
            renderInfo.lastCommandBuffer?.waitUntilCompleted()
        }
    }

    /// The lit colour at a point of the frame.
    private func lit(_ x: Int, _ y: Int) throws -> Float {
        let texture = try XCTUnwrap(textureResources.deferredColorMap)
        var halves = [UInt16](repeating: 0, count: 4)
        halves.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: 8, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0)
        }
        return Float(Float16(bitPattern: halves[0]))
    }

    /// The sphere's centre (its side facing the camera, +z), and its top, bottom, left and
    /// right at three quarters of its radius on screen.
    private func sides() throws -> (centre: Float, top: Float, bottom: Float, left: Float, right: Float) {
        let texture = try XCTUnwrap(textureResources.deferredColorMap)
        let width = texture.width, height = texture.height
        // The sphere's radius on screen from the projection in use: its angular radius
        // (0.25 at 2 m) times the projection's vertical scale, in half-heights.
        let verticalScale = renderInfo.perspectiveSpace.columns.1.y
        let r = Int(0.25 / 2 * verticalScale * Float(height) / 2 * 0.6)
        let cx = width / 2, cy = height / 2
        return try (lit(cx, cy), lit(cx, cy - r), lit(cx, cy + r), lit(cx - r, cy), lit(cx + r, cy))
    }

    // A side facing the bright face gets its light whole, a side at right angles to it a
    // share (the irradiance integrates the hemisphere), and the side facing away next to none.

    func testTheCeilingFaceLightsWhatFacesUp() throws {
        try light(fromFace: 2) // +y
        let s = try sides()
        XCTAssertGreaterThan(s.top, s.bottom * 3, "lit from above")
        XCTAssertGreaterThan(s.top, s.left * 2)
        XCTAssertGreaterThan(s.top, s.right * 2)
    }

    func testTheFaceBehindTheWearerLightsWhatFacesThem() throws {
        try light(fromFace: 4) // +z: behind the camera, which looks down −z
        let s = try sides()
        XCTAssertGreaterThan(s.centre, s.top * 1.1, "lit from the camera's side")
        XCTAssertGreaterThan(s.centre, s.bottom * 1.1)
        XCTAssertGreaterThan(s.centre, s.left * 1.1)
        XCTAssertGreaterThan(s.centre, s.right * 1.1)
    }

    func testTheRightFaceLightsWhatFacesRight() throws {
        try light(fromFace: 0) // +x
        let s = try sides()
        XCTAssertGreaterThan(s.right, s.left * 3, "lit from the right")
        XCTAssertGreaterThan(s.right, s.top * 2)
        XCTAssertGreaterThan(s.right, s.bottom * 2)
    }
}

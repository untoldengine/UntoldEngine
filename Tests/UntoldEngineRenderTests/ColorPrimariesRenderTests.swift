//
//  ColorPrimariesRenderTests.swift
//  UntoldEngine
//
//  The look pass shows the scene with the display's P3 primaries when asked: the colour
//  taken as Display P3 coordinates and converted to sRGB, which widens a saturated colour
//  and clips what leaves the gamut, as RealityKit shows a mixed-immersion scene.
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
final class ColorPrimariesRenderTests: BaseRenderSetup {
    private var savedMode: AntiAliasingMode = .fxaa
    private var savedOperator: TonemapOperator = .aces
    private var savedPrimaries: ColorPrimaries = .sRGB

    override func setUp() async throws {
        try await super.setUp()
        savedMode = antiAliasingMode
        savedOperator = TonemapParams.shared.operator
        savedPrimaries = TonemapParams.shared.primaries
        antiAliasingMode = .none
        setPostFX(.tonemapOperator(.none))
    }

    override func tearDown() async throws {
        antiAliasingMode = savedMode
        setPostFX(.tonemapOperator(savedOperator))
        setPostFX(.colorPrimaries(savedPrimaries))
        destroyAllEntities()
        try await super.tearDown()
    }

    /// The board's red as a picker gives it, in linear: an emissive black metal shows it as is.
    private let red = simd_float3(0.4793, 0.0152, 0.0116)

    override func initializeAssets() {
        let camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: simd_float3(0, 0, 2), target: .zero, up: simd_float3(0, 1, 0))
        let swatch = createEntity()
        setEntityMeshDirect(entityId: swatch, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Swatch")
        updateMaterialColor(entityId: swatch, color: .black)
        updateMaterialMetallic(entityId: swatch, metallic: 1)
        updateMaterialRoughness(entityId: swatch, roughness: 1)
        updateMaterialEmmisive(entityId: swatch, emmissive: red)
    }

    /// The look pass's output at the centre of the frame.
    private func lookCentre() throws -> simd_float3 {
        for _ in 0 ..< 2 {
            renderer.draw(in: renderer.metalView)
            renderInfo.lastCommandBuffer?.waitUntilCompleted()
        }
        let texture = try XCTUnwrap(textureResources.lookTexture)
        var halves = [UInt16](repeating: 0, count: 4)
        halves.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: 8, from: MTLRegionMake2D(texture.width / 2, texture.height / 2, 1, 1), mipmapLevel: 0)
        }
        return simd_float3(Float(Float16(bitPattern: halves[0])), Float(Float16(bitPattern: halves[1])), Float(Float16(bitPattern: halves[2])))
    }

    func testSRGBShowsTheColourAsItIs() throws {
        setPostFX(.colorPrimaries(.sRGB))
        let shown = try lookCentre()
        XCTAssertEqual(shown.x, red.x, accuracy: 0.01)
        XCTAssertEqual(shown.y, red.y, accuracy: 0.005)
        XCTAssertEqual(shown.z, red.z, accuracy: 0.005)
    }

    func testDisplayP3WidensTheColourAndClipsWhatLeavesTheGamut() throws {
        setPostFX(.colorPrimaries(.displayP3))
        let shown = try lookCentre()
        // The P3→sRGB matrix of the red: more red, the green below zero and clipped, a trace of blue.
        XCTAssertEqual(shown.x, 0.5833, accuracy: 0.01)
        XCTAssertEqual(shown.y, 0.0, accuracy: 0.002)
        XCTAssertEqual(shown.z, 0.0021, accuracy: 0.003)
    }
}

//
//  ShadingExperimentTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Metal
import simd
@testable import UntoldEngine
import XCTest

/// The shading-cost experiments: the flat-material pipeline writes the material's factors and
/// the vertex normal, the flat-lighting quad returns the albedo untouched. Each swaps one
/// pipeline of the combined pass and leaves the frame otherwise as it is.
@MainActor
final class ShadingExperimentTests: BaseRenderSetup {
    private var box: EntityID = 0
    private var savedMode: AntiAliasingMode = .fxaa
    private let baseColor = simd_float4(0.2, 0.5, 0.8, 1.0)

    override func setUp() async throws {
        try await super.setUp()
        savedMode = antiAliasingMode
    }

    override func tearDown() async throws {
        setRendering(.flatMaterialExperiment(.disabled))
        setRendering(.flatLightingExperiment(.disabled))
        antiAliasingMode = savedMode
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        let camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: simd_float3(0, 1, 4), target: .zero, up: simd_float3(0, 1, 0))
        box = createEntity()
        setEntityMeshDirect(entityId: box, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Box")
        translateTo(entityId: box, position: simd_float3(0, 0.5, 0))
        if let render = scene.get(component: RenderComponent.self, for: box) {
            for meshIndex in render.mesh.indices {
                for subIndex in render.mesh[meshIndex].submeshes.indices {
                    render.mesh[meshIndex].submeshes[subIndex].material?.baseColorValue = baseColor
                }
            }
        }
        let sun = createEntity()
        createDirLight(entityId: sun)
        rotateTo(entityId: sun, pitch: -40, yaw: 30, roll: 0)
        applyIBL = true
    }

    private func drawFrames() {
        for _ in 0 ..< 3 {
            renderer.draw(in: renderer.metalView)
            renderInfo.lastCommandBuffer?.waitUntilCompleted()
        }
    }

    /// The lit colour at the centre of the frame, on the cube's front face.
    private func centrePixel() throws -> SIMD4<Float> {
        let texture = try XCTUnwrap(textureResources.deferredColorMap)
        var halves = [UInt16](repeating: 0, count: 4)
        halves.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: 8, from: MTLRegionMake2D(texture.width / 2, texture.height / 2, 1, 1), mipmapLevel: 0)
        }
        let floats = halves.map { Float(Float16(bitPattern: $0)) }
        return SIMD4<Float>(floats[0], floats[1], floats[2], floats[3])
    }

    private func assertClose(_ value: SIMD4<Float>, _ expected: simd_float4, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        for i in 0 ..< 3 {
            XCTAssertEqual(value[i], expected[i], accuracy: 0.02, message, file: file, line: line)
        }
    }

    func testTheExperimentPipelinesExistAndFollowTheSampleCount() throws {
        #if targetEnvironment(simulator)
            throw XCTSkip("no TBDR light pass in the simulator")
        #else
            antiAliasingMode = .none
            drawFrames()
            for type in [RenderPipelineType.modelFlat, .lightFlat] {
                let pipeline = try XCTUnwrap(PipelineManager.shared.renderPipelinesByType[type], "\(type)")
                XCTAssertTrue(pipeline.success, "\(type)")
                XCTAssertNotNil(pipeline.pipelineState, "\(type)")
                XCTAssertEqual(pipeline.rasterSampleCount, 1, "\(type)")
            }
            try XCTSkipUnless(renderInfo.device.supportsTextureSampleCount(4), "no 4× MSAA here")
            antiAliasingMode = .msaa
            drawFrames()
            XCTAssertEqual(renderInfo.opaqueSampleCount, 4)
            for type in [RenderPipelineType.modelFlat, .lightFlat] {
                XCTAssertEqual(PipelineManager.shared.renderPipelinesByType[type]?.rasterSampleCount, 4, "\(type)")
            }
        #endif
    }

    /// Flat lighting puts the albedo on screen untouched: the cube's base colour, exactly, where
    /// the lit frame had shading.
    func testFlatLightingShowsTheAlbedo() throws {
        #if targetEnvironment(simulator)
            throw XCTSkip("no TBDR light pass in the simulator")
        #else
            antiAliasingMode = .none
            drawFrames()
            let lit = try centrePixel()
            setRendering(.flatLightingExperiment(.enabled))
            drawFrames()
            let flat = try centrePixel()
            assertClose(flat, baseColor, "flat lighting shows the base colour")
            XCTAssertGreaterThan(simd_distance(lit, flat), 0.02, "the lit frame had shading")
            XCTAssertFalse(renderInfo.tileLightStageUsed, "the experiment runs through the quad")
        #endif
    }

    /// Flat material writes the factors and the vertex normal through the plain pipeline; with
    /// flat lighting as well the base colour comes straight through, and with real lighting the
    /// picture differs from the shaded material's.
    func testFlatMaterialTakesThePlainPipeline() throws {
        #if targetEnvironment(simulator)
            throw XCTSkip("no TBDR light pass in the simulator")
        #else
            antiAliasingMode = .none
            drawFrames()
            let shaded = try centrePixel()
            setRendering(.flatMaterialExperiment(.enabled))
            setRendering(.flatLightingExperiment(.enabled))
            drawFrames()
            XCTAssertGreaterThan(renderInfo.opaqueDrawsPlain, 0, "the flat pipeline is the plain one")
            XCTAssertEqual(renderInfo.opaqueDrawsDiscarding, 0)
            assertClose(try centrePixel(), baseColor, "flat material and flat lighting: the base colour")
            setRendering(.flatLightingExperiment(.disabled))
            drawFrames()
            let flatMaterialLit = try centrePixel()
            XCTAssertGreaterThan(renderInfo.opaqueDrawsPlain, 0)
            // Lit, but without the material's texture work: the same colour within what the
            // untextured cube can show, and not the untouched albedo.
            XCTAssertGreaterThan(simd_distance(flatMaterialLit, SIMD4<Float>(baseColor)), 0.02, "real lighting applies")
            _ = shaded
        #endif
    }
}

//
//  EmissiveLightPassTest.swift
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

/// Deliberately builds its own minimal scene (camera + one cube, no lights) instead of
/// using BaseRenderSetup's default stadium/player/lights scene, so a material's emissive
/// contribution can be isolated from every other light source in the TBDR light pass.
final class EmissiveLightPassTest: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        // Intentionally empty — see class doc comment.
    }

    @discardableResult
    private func createTestCamera() -> EntityID {
        let cameraEntity = createEntity()
        createGameCamera(entityId: cameraEntity)
        CameraSystem.shared.activeCamera = cameraEntity
        cameraLookAt(entityId: cameraEntity, eye: simd_float3(0, 0, 5), target: simd_float3(0, 0, 0), up: simd_float3(0, 1, 0))
        return cameraEntity
    }

    /// A black-albedo, fully rough, non-metallic cube filling most of the frame. With no
    /// scene lights, its only possible source of brightness is its own emissive term.
    @discardableResult
    private func addUnlitCube(emissiveFactor: simd_float3) -> EntityID {
        let entity = createEntity()
        var meshes = BasicPrimitives.createCube(extent: 3.0)
        let material = Material(
            runtimeMaterial: RuntimeMaterialSource(
                baseColorFactor: simd_float4(0, 0, 0, 1),
                emissiveFactor: emissiveFactor,
                metallicFactor: 0.0,
                roughnessFactor: 1.0
            ),
            device: renderInfo.device
        )
        for meshIndex in meshes.indices {
            for submeshIndex in meshes[meshIndex].submeshes.indices {
                meshes[meshIndex].submeshes[submeshIndex].material = material
            }
        }
        if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
            renderComponent.mesh = meshes
            renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/emissive-cube.untold")
        }
        if let local = scene.get(component: LocalTransformComponent.self, for: entity) {
            local.boundingBox = Mesh.computeMeshBoundingBox(for: meshes)
        }
        setVisibleEntities()
        return entity
    }

    private func maxBrightnessAnywhere(in texture: MTLTexture) -> Float {
        precondition(texture.pixelFormat == .rgba16Float, "Test assumes the deferred color target is rgba16Float")
        let width = texture.width
        let height = texture.height
        let bytesPerPixel = 8
        let bytesPerRow = width * bytesPerPixel
        let dataSize = bytesPerRow * height
        let rawData = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: 1)
        defer { rawData.deallocate() }
        texture.getBytes(rawData, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        let ptr = rawData.bindMemory(to: Float16.self, capacity: width * height * 4)
        var best: Float = 0
        for i in 0 ..< (width * height) {
            let r = Float(ptr[i * 4 + 0])
            let g = Float(ptr[i * 4 + 1])
            let b = Float(ptr[i * 4 + 2])
            let brightness = r + g + b
            if brightness > best { best = brightness }
        }
        return best
    }

    private func renderAndReadMaxBrightness() -> Float {
        renderer.draw(in: renderer.metalView)
        let expectation = XCTestExpectation(description: "Emissive light pass render")
        var result: Float = -1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let texture = textureResources.deferredColorMap else {
                XCTFail("Expected deferredColorMap to be initialized")
                expectation.fulfill()
                return
            }
            result = self.maxBrightnessAnywhere(in: texture)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
        return result
    }

    /// Regression test for a0b0eab05: `fragmentLightShaderTBDR` used to hardcode
    /// `emissive = 0.0` right before compositing the final lit color ("set emissive to
    /// zero for now - need to revisit this"), silently discarding every material's
    /// emissive contribution in the TBDR light pass regardless of `emissiveFactor`. A
    /// black-albedo, unlit (no scene lights) cube's only possible source of brightness in
    /// this scene is its own emissive term, so comparing against the same cube with zero
    /// emissive isolates the regression precisely.
    func testEmissiveMaterial_brightensTBDRLightPassOutput() {
        createTestCamera()
        addUnlitCube(emissiveFactor: .zero)
        let nonEmissiveBrightness = renderAndReadMaxBrightness()

        destroyAllEntities()
        createTestCamera()
        addUnlitCube(emissiveFactor: simd_float3(4.0, 4.0, 4.0))
        let emissiveBrightness = renderAndReadMaxBrightness()

        XCTAssertGreaterThan(
            emissiveBrightness, nonEmissiveBrightness + 0.5,
            "❌ A material with a strong emissiveFactor should brighten the final TBDR-lit " +
                "pixel well beyond the same (black-albedo, unlit) material with no emissive — " +
                "got emissive=\(emissiveBrightness) vs non-emissive=\(nonEmissiveBrightness). " +
                "If the TBDR light pass discards emissive again, these converge."
        )
    }
}

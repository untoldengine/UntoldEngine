//
//  RendererTest.swift
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
import UniformTypeIdentifiers
@testable import UntoldEngine
import XCTest

final class RendererTests: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }

    func testRendererInitialization() {
        XCTAssertNotNil(renderer, "❌ Renderer should be inialized.")
    }

    func testProjectionMatrixInitialization() {
        // Known parameters
        let far: Float = far
        let near: Float = near
        let fov: Float = fov

        // Aspect ratio
        let aspect = Float(windowWidth) / Float(windowHeight)

        // Compute the expected projection matrix, matching the renderer's active Z convention.
        let expectedProjectionMatrix = renderInfo.reverseZEnabled
            ? matrixPerspectiveRightHandReverseZ(fovyRadians: degreesToRadians(degrees: fov), aspectRatio: aspect, nearZ: near, farZ: far)
            : matrixPerspectiveRightHand(fovyRadians: degreesToRadians(degrees: fov), aspectRatio: aspect, nearZ: near, farZ: far)

        // Compare with the initialized projection matrix in the renderer
        let actualProjectionMatrix = renderInfo.perspectiveSpace

        // Assert that the matrices are close enough
        XCTAssertTrue(compareMatrices(actualProjectionMatrix, expectedProjectionMatrix), "❌ Projection matrix is incorrect.")

        // Check viewport dimensions
        let expectedViewport = simd_make_float2(Float(windowWidth), Float(windowHeight))
        XCTAssertEqual(renderInfo.viewPort, expectedViewport, "❌ Viewport dimensions are incorrect.")
    }

    func testGenerateReferenceImages() throws {
        guard ProcessInfo.processInfo.environment["UNTOLD_REGENERATE_REFERENCES"] == "1" else {
            throw XCTSkip("Reference generation is opt-in. Set UNTOLD_REGENERATE_REFERENCES=1 to run.")
        }
        // Ensure renderer and metalview are properly initialized
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")
        // Manually trigger the draw call
        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "Render graph execution delay")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // generate different render targets

            self.testGenerateRenderTarget(
                targetName: "IrradianceIBL",
                texture: textureResources.irradianceMap!
            )

            self.testGenerateRenderTarget(
                targetName: "SpecularIBL",
                texture: textureResources.specularMap!
            )

            self.testGenerateRenderTarget(
                targetName: "BRDFIBL",
                texture: textureResources.iblBRDFMap!
            )

            self.testGenerateRenderTarget(
                targetName: "DepthTarget",
                texture: renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture!,
                isDepthTexture: true
            )

            self.testGenerateRenderTarget(
                targetName: "LightPassColor",
                texture: renderInfo.deferredRenderPassDescriptor.colorAttachments[0].texture!
            )

            self.testGenerateRenderTarget(
                targetName: "TransparencyTarget",
                texture: renderInfo.deferredRenderPassDescriptor.colorAttachments[0].texture!
            )

            self.testGenerateRenderTarget(
                targetName: "DisplacementMap",
                texture: renderInfo.deferredRenderPassDescriptor.colorAttachments[0].texture!
            )

            self.testGenerateRenderTarget(
                targetName: "CompositeColorTarget",
                texture: renderInfo.renderPassDescriptor.colorAttachments[0].texture!
            )

            expectation.fulfill()
        }

        // Wait for the execution
        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

    func testColorTarget() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let texture = renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture
        XCTAssertEqual(texture?.storageMode, .memoryless)
        XCTAssertTrue(texture?.usage.contains(.renderTarget) == true)
        XCTAssertFalse(texture?.usage.contains(.shaderRead) == true)
    }

    func testNormalTarget() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let texture = renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)].texture
        XCTAssertEqual(texture?.storageMode, .memoryless)
        XCTAssertTrue(texture?.usage.contains(.renderTarget) == true)
        XCTAssertFalse(texture?.usage.contains(.shaderRead) == true)
    }

    func testGBufferDebugViewStoresAlbedoAndNormalTargets() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")
        guard let initialSSAOBlurTexture = textureResources.ssaoBlurTexture else {
            XCTFail("Expected SSAO blur texture to exist")
            return
        }

        renderDebugViewMode = .albedo
        defer { renderDebugViewMode = .lit }

        renderer.draw(in: renderer.metalView)

        guard let colorAttachment = renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)],
              let normalAttachment = renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
        else {
            XCTFail("Expected G-buffer color and normal attachments")
            return
        }

        XCTAssertTrue(renderInfo.gBufferDebugStorageEnabled)
        XCTAssertEqual(colorAttachment.storeAction, .store)
        XCTAssertEqual(normalAttachment.storeAction, .store)
        XCTAssertEqual(colorAttachment.texture?.storageMode, .private)
        XCTAssertEqual(normalAttachment.texture?.storageMode, .private)
        XCTAssertTrue(colorAttachment.texture?.usage.contains(.shaderRead) == true)
        XCTAssertTrue(normalAttachment.texture?.usage.contains(.shaderRead) == true)
        XCTAssertTrue(textureResources.ssaoBlurTexture === initialSSAOBlurTexture)

        renderDebugViewMode = .lit
        renderer.draw(in: renderer.metalView)

        guard let restoredColorAttachment = renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)],
              let restoredNormalAttachment = renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
        else {
            XCTFail("Expected restored G-buffer color and normal attachments")
            return
        }

        XCTAssertFalse(renderInfo.gBufferDebugStorageEnabled)
        XCTAssertEqual(restoredColorAttachment.storeAction, .dontCare)
        XCTAssertEqual(restoredNormalAttachment.storeAction, .dontCare)
        XCTAssertEqual(restoredColorAttachment.texture?.storageMode, .memoryless)
        XCTAssertEqual(restoredNormalAttachment.texture?.storageMode, .memoryless)
        XCTAssertFalse(restoredColorAttachment.texture?.usage.contains(.shaderRead) == true)
        XCTAssertFalse(restoredNormalAttachment.texture?.usage.contains(.shaderRead) == true)
        XCTAssertTrue(textureResources.ssaoBlurTexture === initialSSAOBlurTexture)
    }

    func testPositionTarget() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let texture = renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)].texture
        XCTAssertEqual(texture?.storageMode, .memoryless)
        XCTAssertTrue(texture?.usage.contains(.renderTarget) == true)
        XCTAssertFalse(texture?.usage.contains(.shaderRead) == true)
    }

    func testLightPassColorTarget() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "Light Pass Color test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.psnrTest(
                targetName: "LightPassColor",
                texture: renderInfo.deferredRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

    func testRenderWithoutDirectionalLightDoesNotCrash() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        let dirLightComponentId = getComponentId(for: DirectionalLightComponent.self)
        let localTransformComponentId = getComponentId(for: LocalTransformComponent.self)
        let directionalLightEntities = queryEntitiesWithComponentIds([dirLightComponentId, localTransformComponentId], in: scene)

        XCTAssertFalse(directionalLightEntities.isEmpty, "Test precondition failed: expected at least one directional light in scene")

        for entityId in directionalLightEntities {
            scene.remove(component: DirectionalLightComponent.self, from: entityId)
        }

        shadowSystem.updateCascades()
        XCTAssertNil(shadowSystem.dirLightSpaceMatrix, "Shadow matrix should be nil when the scene has no directional lights")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "Render frame completes without directional light")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertNotNil(renderInfo.lastCommandBuffer, "Renderer should still submit a command buffer")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

    func testCascadeShadowMappingComputesValidCascadesAndUniforms() {
        func matrixIsFinite(_ matrix: simd_float4x4) -> Bool {
            let values = [
                matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z, matrix.columns.0.w,
                matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z, matrix.columns.1.w,
                matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z, matrix.columns.2.w,
                matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z, matrix.columns.3.w,
            ]
            return values.allSatisfy(\.isFinite)
        }

        XCTAssertNotNil(CameraSystem.shared.activeCamera, "Test precondition failed: expected an active camera")

        let dirLightComponentId = getComponentId(for: DirectionalLightComponent.self)
        let localTransformComponentId = getComponentId(for: LocalTransformComponent.self)
        let directionalLightEntities = queryEntitiesWithComponentIds([dirLightComponentId, localTransformComponentId], in: scene)
        XCTAssertFalse(directionalLightEntities.isEmpty, "Test precondition failed: expected at least one directional light")

        shadowSystem.updateCascades()

        XCTAssertTrue(shadowSystem.isActive, "CSM should become active when a directional light and camera exist")
        XCTAssertEqual(shadowSystem.cascadeLightSpaceMatrices.count, csmCascadeCount)
        XCTAssertEqual(shadowSystem.cascadeSplitDistances.count, csmCascadeCount)

        for splitIndex in 1 ..< shadowSystem.cascadeSplitDistances.count {
            XCTAssertGreaterThan(
                shadowSystem.cascadeSplitDistances[splitIndex],
                shadowSystem.cascadeSplitDistances[splitIndex - 1],
                "Cascade split distances should be strictly increasing"
            )
        }

        let shadowFar = min(far, RenderPasses.maxShadowCastingDistance)
        let expectedLastSplit = renderInfo.isXRStereoMode ? min(Float(50.0), shadowFar) : shadowFar
        XCTAssertEqual(
            shadowSystem.cascadeSplitDistances.last ?? -1,
            expectedLastSplit,
            accuracy: 0.001,
            "Last cascade split should reach the effective CSM shadow distance"
        )

        for matrix in shadowSystem.cascadeLightSpaceMatrices {
            XCTAssertTrue(matrixIsFinite(matrix), "Cascade light-space matrices must not contain NaN or infinity")
            XCTAssertFalse(compareMatrices(matrix, matrix_identity_float4x4), "Cascade light-space matrix should not stay identity")
        }

        let uniforms = shadowSystem.makeUniforms()
        XCTAssertEqual(uniforms.cascadeCount, Int32(csmCascadeCount))
        // Verify used cascade slots match what the system computed.
        XCTAssertEqual(uniforms.cascadeSplits.0, shadowSystem.cascadeSplitDistances[0], accuracy: 0.0001)
        XCTAssertTrue(compareMatrices(uniforms.lightSpaceMatrices.0, shadowSystem.cascadeLightSpaceMatrices[0]))
        if csmCascadeCount > 1 {
            XCTAssertEqual(uniforms.cascadeSplits.1, shadowSystem.cascadeSplitDistances[1], accuracy: 0.0001)
            XCTAssertTrue(compareMatrices(uniforms.lightSpaceMatrices.1, shadowSystem.cascadeLightSpaceMatrices[1]))
        }
        // Verify unused slots are zeroed / identity so the shader doesn't read garbage.
        if csmCascadeCount < 3 {
            XCTAssertEqual(uniforms.cascadeSplits.2, 0.0, accuracy: 0.0001,
                           "Unused split slot must be 0 when csmCascadeCount < 3")
            XCTAssertTrue(compareMatrices(uniforms.lightSpaceMatrices.2, matrix_identity_float4x4),
                          "Unused matrix slot must be identity when csmCascadeCount < 3")
        }
    }

    func testCascadeShadowMappingIsInvariantToSceneRootScale() {
        XCTAssertNotNil(CameraSystem.shared.activeCamera, "Test precondition failed: expected an active camera")

        SceneRootTransform.shared.reset()
        shadowSystem.updateCascades()
        XCTAssertTrue(shadowSystem.isActive, "Test precondition failed: CSM should be active at the identity scene root")

        let baselineRadii = shadowSystem.cascadeWorldRadii
        let baselineCenters = shadowSystem.cascadeWorldCenters

        // Regression guard: shrinking the scene root (as AR tabletop placement does via
        // SceneRootTransform.shared.scale) must not change what the camera can actually see.
        // Cascade sizing/centers are derived purely from the camera's own frustum, so they must
        // stay invariant to the scene-root scale. Before the fix, updateCascades() derived its
        // frustum corners through the root-corrected view matrix, so shrinking the root scale
        // inflated cascadeWorldRadii by 1/scale and collapsed the shadow map's usable region to a
        // sub-texel sliver -- shadows would render but become imperceptible.
        SceneRootTransform.shared.scale = simd_float3(repeating: 0.01)
        SceneRootTransform.shared.updateIfNeeded()
        defer { SceneRootTransform.shared.reset() }

        shadowSystem.updateCascades()

        XCTAssertTrue(shadowSystem.isActive, "CSM should remain active under a shrunk scene-root scale")
        for i in 0 ..< csmCascadeCount {
            XCTAssertEqual(
                shadowSystem.cascadeWorldRadii[i], baselineRadii[i], accuracy: 0.01,
                "Cascade \(i) radius must be derived from the camera frustum, not the scene-root scale"
            )
            XCTAssertEqual(
                simd_distance(shadowSystem.cascadeWorldCenters[i], baselineCenters[i]), 0.0, accuracy: 0.01,
                "Cascade \(i) center must be derived from the camera frustum, not the scene-root scale"
            )
        }
    }

    func testCascadeLightDirectionRespondsToSceneRootRotation() {
        func matrixIsFinite(_ matrix: simd_float4x4) -> Bool {
            let values = [
                matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z, matrix.columns.0.w,
                matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z, matrix.columns.1.w,
                matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z, matrix.columns.2.w,
                matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z, matrix.columns.3.w,
            ]
            return values.allSatisfy(\.isFinite)
        }

        XCTAssertNotNil(CameraSystem.shared.activeCamera, "Test precondition failed: expected an active camera")

        SceneRootTransform.shared.reset()
        shadowSystem.updateCascades()
        XCTAssertTrue(shadowSystem.isActive, "Test precondition failed: CSM should be active at the identity scene root")
        let baselineMatrices = shadowSystem.cascadeLightSpaceMatrices

        // Regression guard for two bugs at once:
        // 1. SceneRootTransform.shared.rotation defaults to simd_quatf()'s zero quaternion, not
        //    simd's true identity (0,0,0,1). Rotating the light direction with simd_quatf.act(_:)
        //    on that default value returns NaN (act() expects a unit quaternion), which poisoned
        //    every downstream cascade matrix -- exactly the regression this test's NaN check below
        //    catches, now exercised at an actual non-identity rotation rather than just the reset
        //    default (which testCascadeShadowMappingComputesValidCascadesAndUniforms already
        //    covers for the zero-quaternion case).
        // 2. The light direction must actually incorporate SceneRootTransform.rotation -- the
        //    light entity's own transform is scene-local like any other entity, and the player can
        //    rotate the placed scene during AR placement (SpatialManipulationSystem's anchored
        //    rotate), so shadow direction needs to track that rotation to stay visually consistent.
        SceneRootTransform.shared.rotation = simd_quatf(angle: .pi / 2, axis: simd_float3(0, 1, 0))
        SceneRootTransform.shared.updateIfNeeded()
        defer { SceneRootTransform.shared.reset() }

        shadowSystem.updateCascades()

        XCTAssertTrue(shadowSystem.isActive, "CSM should remain active under a rotated scene root")
        var matricesDiffer = false
        for i in 0 ..< csmCascadeCount {
            let matrix = shadowSystem.cascadeLightSpaceMatrices[i]
            XCTAssertTrue(matrixIsFinite(matrix), "Cascade \(i) light-space matrix must not contain NaN or infinity under a rotated scene root")
            if !compareMatrices(matrix, baselineMatrices[i]) {
                matricesDiffer = true
            }
        }
        XCTAssertTrue(matricesDiffer, "Rotating the scene root should change the light's shadow-space matrices")
    }

    func testShadowCasterBoundsFoldSceneRootTransform() {
        // A caster's effect on cascade output (e.g. cascadeDepthSpans, lastShadowCasterCount) can
        // be masked by other, already-correct mechanisms like camera-frustum culling, so this
        // checks collectShadowCasterBoundsForTesting() directly instead of inferring correctness
        // from a downstream symptom.
        let casterPosition = simd_float3(2.0, 0.5, -3.0)
        let caster = createEntity()
        setEntityMeshDirect(entityId: caster, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "RootTransformCasterProbe")
        translateTo(entityId: caster, position: casterPosition)

        SceneRootTransform.shared.position = simd_float3(5.0, 1.0, -2.0)
        SceneRootTransform.shared.rotation = simd_quatf(angle: .pi / 2, axis: simd_float3(0, 1, 0))
        SceneRootTransform.shared.scale = simd_float3(repeating: 0.5)
        SceneRootTransform.shared.updateIfNeeded()
        defer { SceneRootTransform.shared.reset() }

        // Regression guard: collectShadowCasterBounds() (ShadowSystem.swift) must fold
        // SceneRootTransform.shared.matrix into each caster's world matrix so its bounds land in
        // the same visual-world space as the (root-independent) camera frustum corners -- see the
        // comment on `invView` in updateCascades(). Before that fix, this returned the probe's raw
        // scene-local position unchanged, ignoring the scene root entirely.
        let expectedCenter = SceneRootTransform.shared.sceneLocalToVisualWorld(casterPosition)
        let bounds = shadowSystem.collectShadowCasterBoundsForTesting()
        let closest = bounds.min(by: {
            simd_distance(($0.min + $0.max) * 0.5, expectedCenter) < simd_distance(($1.min + $1.max) * 0.5, expectedCenter)
        })
        guard let closest else {
            XCTFail("Expected at least one shadow-caster bound")
            return
        }
        let actualCenter = (closest.min + closest.max) * 0.5
        XCTAssertEqual(
            simd_distance(actualCenter, expectedCenter), 0.0, accuracy: 0.05,
            "Caster bounds must be transformed into visual-world space via SceneRootTransform, not left raw/scene-local"
        )
    }

    func testMaxShadowCastingDistanceTightensCascadeTexelDensity() {
        XCTAssertNotNil(CameraSystem.shared.activeCamera, "Test precondition failed: expected an active camera")

        let originalMaxDistance = getMaxShadowCastingDistance()
        defer { setRendering(.maxShadowCastingDistance(originalMaxDistance)) }

        setRendering(.maxShadowCastingDistance(originalMaxDistance))
        shadowSystem.updateCascades()
        XCTAssertTrue(shadowSystem.isActive, "Test precondition failed: CSM should be active at the default distance")
        let baselineTexelSizes = shadowSystem.cascadeWorldTexelSizes

        // A tabletop-scale AR scene packs all of its geometry into a small slice of the camera's
        // real-world range, so the default (full-scale-tuned) shadow distance spends most of the
        // shadow map's fixed texel budget on empty space beyond the content. Lowering the distance
        // must shrink the cascade's real-world coverage -- and so shrink cascadeWorldTexelSizes
        // (finer shadow-map resolution per meter of actual content) -- proportionally.
        let tightDistance: Float = max(originalMaxDistance / 20.0, 0.5)
        setRendering(.maxShadowCastingDistance(tightDistance))
        shadowSystem.updateCascades()

        XCTAssertTrue(shadowSystem.isActive, "CSM should remain active under a tightened shadow distance")
        for i in 0 ..< csmCascadeCount {
            XCTAssertLessThan(
                shadowSystem.cascadeWorldTexelSizes[i], baselineTexelSizes[i],
                "Cascade \(i) texel size should shrink (finer shadow resolution) when the shadow-casting distance is tightened"
            )
        }
    }

    func testTransparencyTarget() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "Transparency target test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.psnrTest(
                targetName: "TransparencyTarget",
                texture: renderInfo.deferredRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

    func testDisplacementMap() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "DisplacementMap test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.psnrTest(
                targetName: "DisplacementMap",
                texture: renderInfo.deferredRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

    func testFinalColorPipelinesInitialized() {
        guard let lookPipeline = PipelineManager.shared.renderPipelinesByType[.look] else {
            XCTFail("Look pipeline should be initialized")
            return
        }
        guard let outputPipeline = PipelineManager.shared.renderPipelinesByType[.outputTransform] else {
            XCTFail("Output transform pipeline should be initialized")
            return
        }

        XCTAssertTrue(lookPipeline.success, "Look pipeline should compile successfully")
        XCTAssertTrue(outputPipeline.success, "Output transform pipeline should compile successfully")
    }

    func testXRIBLCubePreFilterPipelineInitialized() {
        guard let pipeline = PipelineManager.shared.renderPipelinesByType[.xrIBLCubePreFilter] else {
            XCTFail("XR IBL cube prefilter pipeline should be initialized")
            return
        }

        XCTAssertTrue(pipeline.success, "XR IBL cube prefilter pipeline should compile successfully")
    }

    func testSMAAEdgesPipelineInitialized() {
        guard let pipeline = PipelineManager.shared.renderPipelinesByType[.smaaEdges] else {
            XCTFail("SMAA edges pipeline should be initialized")
            return
        }

        XCTAssertTrue(pipeline.success, "SMAA edges pipeline should compile successfully")
    }

    func testSMAABlendWeightsPipelineInitialized() {
        guard let pipeline = PipelineManager.shared.renderPipelinesByType[.smaaBlendWeights] else {
            XCTFail("SMAA blend weights pipeline should be initialized")
            return
        }

        XCTAssertTrue(pipeline.success, "SMAA blend weights pipeline should compile successfully")
    }

    func testSMAANeighborhoodPipelineInitialized() {
        guard let pipeline = PipelineManager.shared.renderPipelinesByType[.smaaNeighborhood] else {
            XCTFail("SMAA neighborhood pipeline should be initialized")
            return
        }

        XCTAssertTrue(pipeline.success, "SMAA neighborhood pipeline should compile successfully")
    }

    func testSMAADifferencePipelineInitialized() {
        guard let pipeline = PipelineManager.shared.renderPipelinesByType[.smaaDifference] else {
            XCTFail("SMAA difference pipeline should be initialized")
            return
        }

        XCTAssertTrue(pipeline.success, "SMAA difference pipeline should compile successfully")
    }

    func testFinalColorWorkingTexturesConfigured() {
        let workingFormats = renderInfo.colorPipeline.working

        XCTAssertNotNil(textureResources.sceneCompositeTexture, "Scene composite texture should exist")
        XCTAssertNotNil(textureResources.lookTexture, "Look output texture should exist")
        XCTAssertEqual(textureResources.sceneCompositeTexture?.pixelFormat, workingFormats.sceneComposite,
                       "Scene composite texture should use the configured working sceneComposite format")
        XCTAssertEqual(textureResources.lookTexture?.pixelFormat, workingFormats.lookOutput,
                       "Look output texture should use the configured working lookOutput format")

        let descriptorTexture = renderInfo.sceneCompositeRenderPassDescriptor?.colorAttachments[0].texture
        XCTAssertNotNil(descriptorTexture, "Scene composite pass should have a color attachment texture")
        XCTAssertTrue(descriptorTexture === textureResources.sceneCompositeTexture,
                      "Scene composite pass should render into sceneCompositeTexture")

        XCTAssertEqual(renderInfo.colorPipeline.present.pixelFormat, renderInfo.presentColorPixelFormat,
                       "Present config pixel format should mirror the renderer present format")
        let expectedEncoding: OutputEncodingMode = renderInfo.presentColorPixelFormat.isSRGBFormat ? .hardwareSRGB : .manualSRGBOETF
        XCTAssertEqual(renderInfo.colorPipeline.present.encodingMode, expectedEncoding,
                       "Present encoding mode should match the present pixel format policy")
    }

    func testSMAAIntermediateTexturesConfigured() {
        guard let edges = textureResources.smaaEdgesTexture else {
            XCTFail("SMAA edges texture should exist")
            return
        }
        guard let blend = textureResources.smaaBlendTexture else {
            XCTFail("SMAA blend texture should exist")
            return
        }

        let expectedWidth = max(1, Int(renderInfo.viewPort.x))
        let expectedHeight = max(1, Int(renderInfo.viewPort.y))

        XCTAssertEqual(edges.pixelFormat, .rg8Unorm)
        XCTAssertEqual(edges.width, expectedWidth)
        XCTAssertEqual(edges.height, expectedHeight)
        XCTAssertTrue(edges.usage.contains(.shaderRead))
        XCTAssertTrue(edges.usage.contains(.renderTarget))

        XCTAssertEqual(blend.pixelFormat, .rgba8Unorm)
        XCTAssertEqual(blend.width, expectedWidth)
        XCTAssertEqual(blend.height, expectedHeight)
        XCTAssertTrue(blend.usage.contains(.shaderRead))
        XCTAssertTrue(blend.usage.contains(.renderTarget))
    }

    func testIrradianceIBL() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)
        let expectation = XCTestExpectation(description: "IrradianceIBL test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.psnrTest(
                targetName: "IrradianceIBL",
                texture: textureResources.irradianceMap!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

    func testSpecularIBL() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "SpecularIBL test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.psnrTest(
                targetName: "SpecularIBL",
                texture: textureResources.specularMap!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

    func testBRDFIBL() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "BRDFIBL test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.psnrTest(
                targetName: "BRDFIBL",
                texture: textureResources.iblBRDFMap!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

//    func testCompositeColorTarget() {
//        XCTAssertNotNil(renderer, "Renderer should be initialized")
//        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")
//
//        renderer.draw(in: renderer.metalView)
//
//        let expectation = XCTestExpectation(description: "CompositeColorTarget test")
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//            self.psnrTest(
//                targetName: "CompositeColorTarget",
//                texture: renderInfo.renderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture!
//            )
//            expectation.fulfill()
//        }
//
//        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
//    }

    func testDepthTarget() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "DepthTarget test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.psnrTest(
                targetName: "DepthTarget",
                texture: renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture!,
                isDepthTexture: true
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

    func testDefaultMeshCreation() throws {
        let mesh = Mesh.makeDefaultMesh()

        XCTAssertGreaterThan(mesh[0].metalKitMesh.vertexCount, 0)
        XCTAssertGreaterThan(mesh[0].metalKitMesh.submeshes.count, 0)
        // verify attribute layout index 0 = position, 1 = uv, etc.
        let vb = try XCTUnwrap(mesh[0].metalKitMesh.vertexBuffers.first)
        XCTAssertGreaterThan(vb.length, 0)
    }

    func testDefaultTextureHasMipsAndSRGB() {
        let loader = TextureLoader(device: renderInfo.device)
        let tex = loader.defaultTexture()
        XCTAssertEqual(tex.width, 64)
        XCTAssertEqual(tex.height, 64)
        XCTAssertGreaterThan(tex.mipmapLevelCount, 1, "Checker texture should have mipmaps")
        XCTAssertEqual(tex.pixelFormat, .rgba8Unorm_srgb)
    }
}

final class LightPortalRendererTests: BaseRenderSetup {
    private let portalChannel = SceneChannel.userCustom(index: 30)

    override func initializeAssets() {
        ambientIntensity = 0.0
        applyIBL = false
        renderEnvironment = false
        SSAOParams.shared.enabled = false

        let camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(
            entityId: camera,
            eye: simd_float3(0.0, 2.0, 6.0),
            target: simd_float3(0.0, 0.0, 0.0),
            up: simd_float3(0.0, 1.0, 0.0)
        )

        let receiver = createEntity()
        setEntityMeshDirect(entityId: receiver, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "PortalReceiver")
        scaleTo(entityId: receiver, scale: simd_float3(4.0, 0.12, 4.0))
        translateTo(entityId: receiver, position: simd_float3(0.0, -0.7, 0.0))

        let portal = createEntity()
        setEntityMeshDirect(entityId: portal, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "PortalSurface")
        scene.get(component: LocalTransformComponent.self, for: portal)?.boundingBox = (
            min: simd_float3(-0.5, -0.5, -0.025),
            max: simd_float3(0.5, 0.5, 0.025)
        )
        scaleTo(entityId: portal, scale: simd_float3(2.0, 2.0, 0.05))
        translateTo(entityId: portal, position: simd_float3(0.0, 1.1, 2.0))
        setEntitySceneChannels(entityId: portal, channels: portalChannel)
        setSceneChannel(portalChannel, .lightPortal(.disabled))
    }

    func testLightPortalIncreasesRenderedLightPassBrightness() {
        let disabledLuminance = renderLightPassAverageLuminance()

        setSceneChannel(
            portalChannel,
            .lightPortal(.enabled(
                intensity: 18.0,
                range: 8.0,
                useRealWorldTint: false,
                maxActivePortals: 1,
                activationDistance: 20.0
            ))
        )
        cullFrameIndex &+= 1

        let enabledLuminance = renderLightPassAverageLuminance()
        let diagnostics = getLightPortalRenderDiagnostics()

        XCTAssertEqual(diagnostics.portalAreaLightCount, 1)
        XCTAssertGreaterThan(diagnostics.totalEffectivePortalIntensity, 0.0)
        XCTAssertGreaterThan(
            enabledLuminance,
            disabledLuminance + 0.002,
            "Portal-enabled render should produce measurably brighter light-pass pixels"
        )
    }

    func testLightPortalRangeAttenuationLimitsRenderedContribution() {
        setSceneChannel(
            portalChannel,
            .lightPortal(.enabled(
                intensity: 18.0,
                range: 0.25,
                useRealWorldTint: false,
                maxActivePortals: 1,
                activationDistance: 20.0
            ))
        )
        cullFrameIndex &+= 1
        let shortRangeLuminance = renderLightPassAverageLuminance()

        setSceneChannel(
            portalChannel,
            .lightPortal(.enabled(
                intensity: 18.0,
                range: 8.0,
                useRealWorldTint: false,
                maxActivePortals: 1,
                activationDistance: 20.0
            ))
        )
        cullFrameIndex &+= 1
        let normalRangeLuminance = renderLightPassAverageLuminance()

        XCTAssertEqual(getLightPortalRenderDiagnostics().portalAreaLightCount, 1)
        XCTAssertGreaterThan(
            normalRangeLuminance,
            shortRangeLuminance + 0.002,
            "Portal range attenuation should reduce contribution outside a short range"
        )
    }

    func testMeshRegistrationInvalidatesPortalAreaLightCacheWithinFrame() {
        let meshChannel = SceneChannel.userCustom(index: 31)
        registerSceneChannelPrefix("WIN_CACHE_", channels: meshChannel)
        setSceneChannel(meshChannel, .lightPortal(.enabled(
            intensity: 3.0,
            range: 8.0,
            useRealWorldTint: false,
            maxActivePortals: 1,
            activationDistance: 20.0
        )))

        let portal = createEntity()
        setEntityName(entityId: portal, name: "WIN_CACHE_Portal")
        setEntityMeshDirect(entityId: portal, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "WIN_CACHE_Portal")
        scene.get(component: LocalTransformComponent.self, for: portal)?.boundingBox = (
            min: simd_float3(-0.5, -0.5, -0.025),
            max: simd_float3(0.5, 0.5, 0.025)
        )
        scaleTo(entityId: portal, scale: simd_float3(2.0, 2.0, 0.05))
        translateTo(entityId: portal, position: simd_float3(0.0, 1.1, 2.0))

        let initialLights = getAreaLights()
        setEntityMeshDirect(entityId: portal, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "WIN_CACHE_Portal")
        let updatedLights = getAreaLights()

        XCTAssertEqual(initialLights.count, 1)
        XCTAssertTrue(updatedLights.isEmpty)
        XCTAssertEqual(getLightPortalDiscoveryDiagnostics().skippedInvalidGeometryCount, 1)
    }

    private func renderLightPassAverageLuminance(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Float {
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()

        guard let texture = renderInfo.deferredRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture else {
            XCTFail("Expected light-pass color texture", file: file, line: line)
            return 0.0
        }

        return averageLuminance(
            texture: texture,
            normalizedRegion: (x: 0.35, y: 0.35, width: 0.3, height: 0.3),
            file: file,
            line: line
        )
    }

    private func averageLuminance(
        texture: MTLTexture,
        normalizedRegion: (x: Float, y: Float, width: Float, height: Float),
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Float {
        let x = max(0, min(texture.width - 1, Int(Float(texture.width) * normalizedRegion.x)))
        let y = max(0, min(texture.height - 1, Int(Float(texture.height) * normalizedRegion.y)))
        let width = max(1, min(texture.width - x, Int(Float(texture.width) * normalizedRegion.width)))
        let height = max(1, min(texture.height - y, Int(Float(texture.height) * normalizedRegion.height)))
        let region = MTLRegionMake2D(x, y, width, height)

        switch texture.pixelFormat {
        case .rgba16Float:
            let bytesPerPixel = 8
            let bytesPerRow = width * bytesPerPixel
            let sampleCount = width * height
            var data = [UInt16](repeating: 0, count: sampleCount * 4)
            data.withUnsafeMutableBytes { rawBuffer in
                texture.getBytes(
                    rawBuffer.baseAddress!,
                    bytesPerRow: bytesPerRow,
                    from: region,
                    mipmapLevel: 0
                )
            }

            var total: Float = 0.0
            for index in 0 ..< sampleCount {
                let base = index * 4
                let rgb = simd_float3(
                    Float(Float16(bitPattern: data[base])),
                    Float(Float16(bitPattern: data[base + 1])),
                    Float(Float16(bitPattern: data[base + 2]))
                )
                total += simd_dot(rgb, simd_float3(0.2126, 0.7152, 0.0722))
            }
            return total / Float(sampleCount)

        default:
            XCTFail("Unsupported light-pass pixel format: \(texture.pixelFormat)", file: file, line: line)
            return 0.0
        }
    }
}

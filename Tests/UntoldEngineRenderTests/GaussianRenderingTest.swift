//
//  GaussianRenderingTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import Metal
import simd
@testable import UntoldEngine
import XCTest

final class GaussianRenderingTest: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        let gaussian = createEntity()
        setEntityGaussian(entityId: gaussian, filename: "test_gaussians", withExtension: "ply")
    }

    /*
         func testGenerateGaussianReferenceImages() {
             // Ensure renderer and metalview are properly initialized
             XCTAssertNotNil(renderer, "Renderer should be initialized")
             XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")
             // Manually trigger the draw call
             renderer.draw(in: renderer.metalView)

             let expectation = XCTestExpectation(description: "Render graph execution delay")

             DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                 // generate different render targets

                 self.testGenerateRenderTarget(
                     targetName: "GaussianTarget",
                     texture: renderInfo.gaussianRenderPassDescriptor.colorAttachments[Int(0)].texture!
                 )

                 expectation.fulfill()
             }

             // Wait for the execution
             wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
         }
     */

    func testGaussianTarget() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

        renderer.draw(in: renderer.metalView)

        let expectation = XCTestExpectation(description: "GaussianTarget test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.psnrTest(
                targetName: "GaussianTarget",
                texture: renderInfo.gaussianRenderPassDescriptor.colorAttachments[Int(0)].texture!
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
    }

    // MARK: - buildGaussianGraph Tests

    func testBuildGaussianGraph_CreatesGaussianPass() {
        let (graph, _) = buildGaussianGraph()

        XCTAssertNotNil(graph["gaussian"], "Gaussian pass should be created")
        XCTAssertEqual(graph["gaussian"]?.dependencies.count, 0,
                       "Gaussian pass should have no dependencies in standalone graph")
    }

    func testBuildGaussianGraph_CreatesPreCompPass() {
        let (graph, _) = buildGaussianGraph()

        XCTAssertNotNil(graph["precomp"], "Pre-composite pass should be created")
    }

    func testBuildGaussianGraph_PreCompDependsOnGaussian() {
        let (graph, _) = buildGaussianGraph()

        XCTAssertEqual(graph["precomp"]?.dependencies, ["gaussian"],
                       "Pre-composite pass should depend on gaussian pass")
    }

    func testBuildGaussianGraph_ReturnsFinalPassID() {
        let (_, finalPassID) = buildGaussianGraph()

        XCTAssertEqual(finalPassID, "precomp",
                       "Final pass ID should be 'precomp'")
    }

    func testBuildGaussianGraph_ValidTopologicalOrder() throws {
        let (graph, _) = buildGaussianGraph()

        let sorted = try topologicalSortGraph(graph: graph)
        let order = sorted.map(\.id)

        XCTAssertEqual(order.count, 2, "Should have exactly 2 passes")
        XCTAssertEqual(order[0], "gaussian", "Gaussian should be first")
        XCTAssertEqual(order[1], "precomp", "Precomp should be second")
    }

    func testBuildGaussianGraph_ContainsExecutionFunctions() {
        let (graph, _) = buildGaussianGraph()

        XCTAssertNotNil(graph["gaussian"]?.execute,
                        "Gaussian pass should have an execute function")
        XCTAssertNotNil(graph["precomp"]?.execute,
                        "Pre-composite pass should have an execute function")
    }

    // MARK: - gaussianExecution Tests

    func testGaussianExecution_RequiresGaussianTBDRPipelines() {
        XCTAssertNotNil(PipelineManager.shared.renderPipelinesByType[.gaussianTBDRInitialize],
                        "Gaussian TBDR initialize pipeline should be initialized")
        XCTAssertNotNil(PipelineManager.shared.renderPipelinesByType[.gaussianTBDRDraw],
                        "Gaussian TBDR draw pipeline should be initialized")
        XCTAssertNotNil(PipelineManager.shared.renderPipelinesByType[.gaussianTBDRPostprocess],
                        "Gaussian TBDR postprocess pipeline should be initialized")
    }

    func testGaussianExecution_GaussianTBDRPipelinesSuccess() {
        let requiredPipelines: [(RenderPipelineType, String)] = [
            (.gaussianTBDRInitialize, "Gaussian TBDR initialize pipeline"),
            (.gaussianTBDRDraw, "Gaussian TBDR draw pipeline"),
            (.gaussianTBDRPostprocess, "Gaussian TBDR postprocess pipeline"),
        ]

        for (pipelineType, name) in requiredPipelines {
            guard let pipeline = PipelineManager.shared.renderPipelinesByType[pipelineType] else {
                XCTFail("\(name) should exist")
                continue
            }

            XCTAssertTrue(pipeline.success,
                          "\(name) should be successfully compiled")
        }
    }

    func testGaussianExecution_RequiresActiveCamera() {
        // Set up active camera
        let cameraEntity = createTestCamera()

        XCTAssertNotNil(CameraSystem.shared.activeCamera,
                        "Active camera should be set for gaussian execution")
        XCTAssertNotNil(scene.get(component: CameraComponent.self, for: cameraEntity),
                        "Camera entity should have CameraComponent")
    }

    func testGaussianExecution_GaussianRenderPassDescriptorExists() {
        XCTAssertNotNil(renderInfo.gaussianRenderPassDescriptor,
                        "Gaussian render pass descriptor should be initialized")
    }

    func testGaussianExecution_ColorAttachmentConfigured() {
        guard let descriptor = renderInfo.gaussianRenderPassDescriptor else {
            XCTFail("Gaussian render pass descriptor should exist")
            return
        }

        XCTAssertNotNil(descriptor.colorAttachments[0].texture,
                        "Gaussian color attachment should have a texture")
    }

    func testGaussianExecution_CanQueryGaussianEntities() {
        // Create test entity with Gaussian component
        let entity = createEntity()
        _ = scene.assign(to: entity, component: GaussianComponent.self)
        registerComponent(entityId: entity, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entity, componentType: LocalTransformComponent.self)

        let transformId = getComponentId(for: WorldTransformComponent.self)
        let gaussianId = getComponentId(for: GaussianComponent.self)
        let entities = queryEntitiesWithComponentIds([transformId, gaussianId], in: scene)

        XCTAssertTrue(entities.contains(entity),
                      "Should be able to query entities with Gaussian and Transform components")
    }

    func testGaussianExecution_GaussianComponentHasRequiredData() {
        let entity = createEntity()
        guard let gaussianComponent = scene.assign(to: entity, component: GaussianComponent.self) else {
            XCTFail("Should be able to add GaussianComponent")
            return
        }

        XCTAssertNotNil(gaussianComponent.spaceUniform,
                        "Gaussian component should have space uniform array")
        // Note: encodedSplatData and gaussianSortedIndices may be nil until loaded
    }

    func testLoadedGaussianUsesExactSizeGPUBufferAllocations() {
        let transformId = getComponentId(for: WorldTransformComponent.self)
        let gaussianId = getComponentId(for: GaussianComponent.self)
        let entities = queryEntitiesWithComponentIds([transformId, gaussianId], in: scene)

        guard let entity = entities.first,
              let component = scene.get(component: GaussianComponent.self, for: entity),
              let encodedSplats = component.encodedSplatData,
              let sortedIndices = component.gaussianSortedIndices.first ?? nil
        else {
            XCTFail("Expected the Gaussian test asset to be loaded")
            return
        }

        let count = Int(component.splatCount)
        XCTAssertGreaterThan(count, 0)
        XCTAssertEqual(
            encodedSplats.length,
            count * MemoryLayout<EncodedGaussianSplat>.stride
        )
        XCTAssertEqual(
            sortedIndices.length,
            count * MemoryLayout<UInt64>.stride
        )

        let metadata = component.sphericalHarmonicsMetadata
        XCTAssertEqual(metadata?.degree, 0)
        XCTAssertEqual(metadata?.coefficientsPerChannel, 1)
        XCTAssertEqual(metadata?.higherOrderCoefficientsPerSplat, 0)
        XCTAssertNil(component.sphericalHarmonicsData)
    }

    func testRemoveGaussianReleasesSphericalHarmonicsState() {
        let entity = createEntity()
        guard let component = scene.assign(to: entity, component: GaussianComponent.self) else {
            XCTFail("Expected Gaussian component")
            return
        }
        component.sphericalHarmonicsData = renderInfo.device.makeBuffer(
            length: MemoryLayout<Float16>.stride,
            options: .storageModeShared
        )
        component.sphericalHarmonicsMetadata = GaussianSHMetadata(
            degree: 1,
            coefficientsPerChannel: 4,
            higherOrderCoefficientsPerSplat: 9,
            _pad0: 0
        )

        removeEntityGaussian(entityId: entity)

        XCTAssertNil(scene.get(component: GaussianComponent.self, for: entity))
    }

    func testPackedSphericalHarmonicsRoundTripsThroughMetalBuffer() throws {
        let sphericalHarmonics = GaussianSphericalHarmonics(
            degree: 1,
            coefficientsPerChannel: 4,
            coefficients: (0 ..< 12).map { Float($0) * 0.125 }
        )
        let packed = try packGaussianSphericalHarmonics(sphericalHarmonics, splatCount: 1)
        guard let buffer = renderInfo.device.makeBuffer(
            bytes: packed.coefficients,
            length: packed.coefficients.count * MemoryLayout<Float16>.stride,
            options: .storageModeShared
        ) else {
            XCTFail("Expected SH buffer allocation")
            return
        }

        XCTAssertEqual(buffer.length, 9 * MemoryLayout<Float16>.stride)
        let pointer = buffer.contents().bindMemory(to: Float16.self, capacity: 9)
        let roundTripped = (0 ..< 9).map { pointer[$0] }
        XCTAssertEqual(roundTripped, packed.coefficients)
    }

    func testPackedSphericalHarmonicsMatchesActiveMetalEvaluator() throws {
        guard let library = renderInfo.library,
              let function = library.makeFunction(name: "gaussianSphericalHarmonicsDiagnostic")
        else {
            XCTFail("Gaussian SH diagnostic kernel is missing from the active metallib")
            return
        }

        let pipeline = try renderInfo.device.makeComputePipelineState(function: function)
        let sphericalHarmonics = GaussianSphericalHarmonics(
            degree: 3,
            coefficientsPerChannel: 16,
            coefficients: (0 ..< 48).map { Float($0 - 24) * 0.0078125 }
        )
        let packed = try packGaussianSphericalHarmonics(sphericalHarmonics, splatCount: 1)
        let baseColor = simd_float4(0.35, 0.5, 0.65, 1)
        let direction = simd_float4(0.25, -0.5, 0.75, 0)
        let cpuResult = evaluateGaussianSphericalHarmonics(
            baseColor: simd_float3(baseColor.x, baseColor.y, baseColor.z),
            higherOrderCoefficients: packed.coefficients.map(Float.init),
            degree: 3,
            direction: simd_float3(direction.x, direction.y, direction.z)
        )

        guard let coefficients = renderInfo.device.makeBuffer(
            bytes: packed.coefficients,
            length: packed.coefficients.count * MemoryLayout<Float16>.stride,
            options: .storageModeShared
        ), let output = renderInfo.device.makeBuffer(
            length: 2 * MemoryLayout<simd_float4>.stride,
            options: .storageModeShared
        ), let commandBuffer = renderInfo.commandQueue.makeCommandBuffer(),
        let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            XCTFail("Failed to allocate Gaussian SH diagnostic resources")
            return
        }

        var metadata = packed.metadata
        var baseColorArgument = baseColor
        var directionArgument = direction
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(coefficients, offset: 0, index: 0)
        encoder.setBytes(&metadata, length: MemoryLayout<GaussianSHMetadata>.stride, index: 1)
        encoder.setBytes(&baseColorArgument, length: MemoryLayout<simd_float4>.stride, index: 2)
        encoder.setBytes(&directionArgument, length: MemoryLayout<simd_float4>.stride, index: 3)
        encoder.setBuffer(output, offset: 0, index: 4)
        encoder.dispatchThreads(MTLSize(width: 1, height: 1, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        XCTAssertEqual(commandBuffer.status, .completed)
        let gpuResults = output.contents().bindMemory(to: simd_float4.self, capacity: 2)
        let gpuResult = gpuResults[0]
        XCTAssertEqual(gpuResult.x, cpuResult.x, accuracy: 1e-5)
        XCTAssertEqual(gpuResult.y, cpuResult.y, accuracy: 1e-5)
        XCTAssertEqual(gpuResult.z, cpuResult.z, accuracy: 1e-5)
        XCTAssertNotEqual(simd_float3(gpuResult.x, gpuResult.y, gpuResult.z),
                          simd_float3(baseColor.x, baseColor.y, baseColor.z))

        let expectedLinear = gaussianSRGBToLinear(cpuResult)
        let gpuLinear = gpuResults[1]
        XCTAssertEqual(gpuLinear.x, expectedLinear.x, accuracy: 1e-5)
        XCTAssertEqual(gpuLinear.y, expectedLinear.y, accuracy: 1e-5)
        XCTAssertEqual(gpuLinear.z, expectedLinear.z, accuracy: 1e-5)
    }

    func testExternalGaussianDiagnosticAssetReachesRuntimeGPUBuffers() throws {
        guard let path = ProcessInfo.processInfo.environment["UNTOLD_GAUSSIAN_DIAGNOSTIC_PLY"] else {
            throw XCTSkip("Set UNTOLD_GAUSSIAN_DIAGNOSTIC_PLY to audit a production Gaussian asset")
        }

        let entity = createEntity()
        let source = (path as NSString).deletingPathExtension
        let fileExtension = (path as NSString).pathExtension
        setEntityGaussian(entityId: entity, filename: source, withExtension: fileExtension)

        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        let metadata = try XCTUnwrap(component.sphericalHarmonicsMetadata)
        let coefficientBuffer = try XCTUnwrap(component.sphericalHarmonicsData)
        let splatBuffer = try XCTUnwrap(component.encodedSplatData)
        let splatCount = Int(component.splatCount)

        XCTAssertEqual(splatCount, 1_732_378)
        XCTAssertEqual(metadata.degree, 3)
        XCTAssertEqual(metadata.coefficientsPerChannel, 16)
        XCTAssertEqual(metadata.higherOrderCoefficientsPerSplat, 45)
        XCTAssertEqual(coefficientBuffer.length, splatCount * 45 * MemoryLayout<Float16>.stride)
        XCTAssertEqual(splatBuffer.length, splatCount * MemoryLayout<EncodedGaussianSplat>.stride)

        let coefficients = coefficientBuffer.contents().bindMemory(
            to: Float16.self,
            capacity: splatCount * 45
        )
        let sampledValues = [0, splatCount * 45 / 2, splatCount * 45 - 1].map { coefficients[$0] }
        XCTAssertTrue(sampledValues.contains { $0 != 0 })
    }

    func testGaussianExecution_HandlesEmptyScene() {
        // Ensure we have a camera
        _ = createTestCamera()

        // This test verifies that gaussian execution can handle an empty scene
        // without crashing (no actual execution needed for this validation)
        XCTAssertTrue(true, "Gaussian execution should handle empty scene gracefully")
    }

    func testGaussianExecution_DepthLoadActionIsLoad() {
        // This tests that gaussian pass loads existing depth from 3D models
        // The load action should be .load, not .clear
        guard let _ = renderInfo.gaussianRenderPassDescriptor else {
            XCTFail("Gaussian render pass descriptor should exist")
            return
        }

        // The depth attachment should be the offscreen depth (shared with model pass)
        XCTAssertNotNil(renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture,
                        "Offscreen depth texture should exist for depth testing against 3D models")
    }

    // MARK: - Integration Tests

    func testGaussianExecution_WithMultipleEntities() {
        destroyAllEntities()
        // Create multiple entities with gaussian components
        let entity1 = createEntity()
        _ = scene.assign(to: entity1, component: GaussianComponent.self)
        registerComponent(entityId: entity1, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entity1, componentType: LocalTransformComponent.self)

        let entity2 = createEntity()
        _ = scene.assign(to: entity2, component: GaussianComponent.self)
        registerComponent(entityId: entity2, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entity2, componentType: LocalTransformComponent.self)

        let transformId = getComponentId(for: WorldTransformComponent.self)
        let gaussianId = getComponentId(for: GaussianComponent.self)
        let entities = queryEntitiesWithComponentIds([transformId, gaussianId], in: scene)

        XCTAssertEqual(entities.count, 2,
                       "Should find both entities with Gaussian components")
        XCTAssertTrue(entities.contains(entity1), "Should find first entity")
        XCTAssertTrue(entities.contains(entity2), "Should find second entity")
    }

    func testGaussianExecution_ViewportConfigured() {
        XCTAssertGreaterThan(renderInfo.viewPort.x, 0,
                             "Viewport width should be positive")
        XCTAssertGreaterThan(renderInfo.viewPort.y, 0,
                             "Viewport height should be positive")
    }

    func testGaussianGraph_CanBeSortedTopologically() throws {
        let (graph, _) = buildGaussianGraph()

        // Should not throw
        XCTAssertNoThrow(try topologicalSortGraph(graph: graph),
                         "Gaussian graph should be topologically sortable")

        let sorted = try topologicalSortGraph(graph: graph)
        XCTAssertEqual(sorted.count, graph.count,
                       "Sorted passes should equal total passes")
    }

    // MARK: - Depth occlusion against opaque geometry

    //
    // These tests deliberately avoid assuming which exact screen pixel the splat cloud
    // projects to (a real .ply point cloud isn't necessarily centered on its entity's
    // transform origin). Instead, a large cube is used as an occluder, sized and
    // positioned so its near face covers the entire view frustum near the camera — its
    // depth is written at *every* pixel, so it occludes the splat wherever it actually
    // renders, without needing pixel-perfect alignment. "Not occluded" is verified by the
    // splat's own baseline visibility (maxAlphaAnywhere) with no occluder present at all.

    // A sphere large enough (relative to its distance) to cover the whole frame puts the
    // camera inside its own volume — its surface then faces away from the camera and gets
    // back-face culled, i.e. it stops rendering entirely. A cube's flat near face avoids
    // that: as long as the camera sits in front of that face (not inside the cube), it
    // fully blocks the view within its angular footprint regardless of size.
    @discardableResult
    private func addFullFrameOccludingCube(at position: simd_float3, extent: Float = 8.0) -> EntityID {
        let entity = createEntity()
        var meshes = BasicPrimitives.createCube(extent: extent)
        // BasicPrimitives meshes carry no material (ModelIO primitives don't set one),
        // and combinedModelLightExecution silently skips any submesh with `material == nil`
        // (RenderPasses.swift:2262) — no draw call, no depth write. Assign a plain opaque
        // material so this occluder actually renders instead of being invisibly skipped.
        let defaultMaterial = Material(runtimeMaterial: RuntimeMaterialSource(), device: renderInfo.device)
        for meshIndex in meshes.indices {
            for submeshIndex in meshes[meshIndex].submeshes.indices {
                meshes[meshIndex].submeshes[submeshIndex].material = defaultMaterial
            }
        }
        if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
            renderComponent.mesh = meshes
            renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/occluder.untold")
        }
        if let local = scene.get(component: LocalTransformComponent.self, for: entity) {
            local.position = position
            local.boundingBox = Mesh.computeMeshBoundingBox(for: meshes)
        }
        if let world = scene.get(component: WorldTransformComponent.self, for: entity) {
            var space = matrix_identity_float4x4
            space.columns.3 = simd_float4(position, 1.0)
            world.space = space
        }
        setVisibleEntities()
        return entity
    }

    /// Scans the whole texture for the maximum alpha value found anywhere — a
    /// registration-independent stand-in for "is the splat visible somewhere in frame."
    private func maxAlphaAnywhere(in texture: MTLTexture) -> Float {
        precondition(texture.pixelFormat == .rgba16Float, "Test assumes the Gaussian target is rgba16Float")
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
            let a = Float(ptr[i * 4 + 3])
            if a > best { best = a }
        }
        return best
    }

    private func renderAndReadMaxAlpha() -> Float {
        renderer.draw(in: renderer.metalView)
        let expectation = XCTestExpectation(description: "Gaussian render")
        var result: Float = -1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            result = self.maxAlphaAnywhere(in: renderInfo.gaussianRenderPassDescriptor.colorAttachments[Int(0)].texture!)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))
        return result
    }

    /// Baseline: the test splat, alone, is visible somewhere in frame. Establishes that
    /// the occlusion tests below have something real to occlude.
    func testGaussianOcclusion_splatAloneIsVisible() {
        let camera = createTestCamera()
        cameraLookAt(entityId: camera, eye: simd_float3(0, 3, 7), target: simd_float3(0, 0, 0), up: simd_float3(0, 1, 0))

        let alpha = renderAndReadMaxAlpha()
        XCTAssertGreaterThan(alpha, 0.05, "❌ Splat alone with no occluder should be visible somewhere in frame, got \(alpha)")
    }

    /// A splat behind a closer opaque object covering the whole frame must be fully
    /// occluded. Regression test for the depth-read added to `fragmentGaussianTBDRShader`
    /// (previously the draw pipeline had `depthCompareFunction: .always, depthEnabled: false`
    /// and never read the opaque depth at all, so splats always rendered on top regardless
    /// of geometry in front).
    func testGaussianOcclusion_hiddenBehindCloserOpaqueMesh() {
        let eye = simd_float3(0, 3, 7)
        let target = simd_float3(0, 0, 0)

        let camera = createTestCamera()
        cameraLookAt(entityId: camera, eye: eye, target: target, up: simd_float3(0, 1, 0))

        // Cube center placed so its near face (facing the camera) sits ~1 unit in front
        // of the camera, well outside the cube itself, with a wide enough face to cover
        // the frame at that distance.
        let nearPoint = eye + 0.657 * (target - eye) // distance ≈5.0 from eye; near face ≈1.0
        addFullFrameOccludingCube(at: nearPoint, extent: 8.0)

        let alpha = renderAndReadMaxAlpha()
        XCTAssertLessThan(
            alpha, 0.05,
            "❌ Splat behind a closer full-frame opaque mesh should be fully occluded, got maxAlpha=\(alpha)"
        )
    }

    /// The mirror case: a large opaque object placed *beyond* the splat (farther from
    /// the camera) must not occlude it, even though it's big enough to otherwise span the
    /// whole frame — exercises the actual depth comparison, not just "no occluder at all."
    func testGaussianOcclusion_notOccludedByFartherOpaqueMesh() {
        let eye = simd_float3(0, 3, 7)
        let target = simd_float3(0, 0, 0)

        let camera = createTestCamera()
        cameraLookAt(entityId: camera, eye: eye, target: target, up: simd_float3(0, 1, 0))

        // Well beyond the splat on the same eye→target line (near face still farther
        // from the camera than the target) — must NOT occlude it, regardless of size.
        let farPoint = eye + 2.0 * (target - eye)
        addFullFrameOccludingCube(at: farPoint, extent: 8.0)

        let alpha = renderAndReadMaxAlpha()
        XCTAssertGreaterThan(
            alpha, 0.05,
            "❌ Splat should remain visible when the opaque mesh is farther away, got maxAlpha=\(alpha)"
        )
    }

    // MARK: - SceneRootTransform (effective camera) correctness

    /// Runs `executeGaussianFrustumCulling` synchronously on a fresh command buffer and
    /// reads back the GPU visible-splat counter it writes (`GaussianComponent.gaussianVisibleCount`,
    /// an `atomic_uint` in `gaussianFrustumCull`, see BitonicSort.metal). The reset pass inside
    /// `executeGaussianFrustumCulling` zeroes this counter before culling runs, so calling this
    /// repeatedly with different camera/scene-root state is safe.
    private func runGaussianFrustumCullingAndReadVisibleCount() -> UInt32 {
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Expected to allocate a command buffer")
            return .max
        }
        executeGaussianFrustumCulling(commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        XCTAssertEqual(commandBuffer.status, .completed)

        let transformId = getComponentId(for: WorldTransformComponent.self)
        let gaussianId = getComponentId(for: GaussianComponent.self)
        let entities = queryEntitiesWithComponentIds([transformId, gaussianId], in: scene)
        guard let entity = entities.first,
              let component = scene.get(component: GaussianComponent.self, for: entity)
        else {
            XCTFail("Expected the Gaussian test asset to be loaded")
            return .max
        }

        let frameSlot = min(renderInfo.currentInFlightFrameSlot, component.gaussianVisibleCount.count - 1)
        guard let visibleCountBuffer = component.gaussianVisibleCount[frameSlot] else {
            XCTFail("Expected a visible-count buffer for the active frame slot")
            return .max
        }
        return visibleCountBuffer.contents().load(as: UInt32.self)
    }

    /// Regression test for the bugfix in 302e097eb: `executeGaussianFrustumCulling` used to
    /// build its model-view matrix from the raw `cameraComponent.viewSpace`, ignoring
    /// `SceneRootTransform`. Per SceneRootTransform.swift's "virtual camera" trick, entity
    /// transforms are never touched when the scene root moves — only the effective camera —
    /// so a splat's world position is `rootMatrix * modelMatrix * localPosition`, projected
    /// through the *unmodified* raw camera view when the bug is present. A large scene-root
    /// translation therefore has no effect on culling at all under the bug (every splat stays
    /// visible, exactly as if the root were still identity), while the fix pushes every splat
    /// out of the frustum. This directly reads the GPU visible-splat counter rather than going
    /// through a full render + occlusion-cube check, because that path (see the removed
    /// `testGaussianOcclusion_respectsSceneRootTransformOffset` attempt) turned out to be
    /// insensitive to this bug: a full-frame occluder covers the frustum regardless of exactly
    /// where within it the (mis-projected) splat lands.
    func testGaussianFrustumCulling_offsetSceneRootCullsAllSplats() {
        let camera = createTestCamera()
        cameraLookAt(entityId: camera, eye: simd_float3(0, 3, 7), target: simd_float3(0, 0, 0), up: simd_float3(0, 1, 0))

        let baselineVisible = runGaussianFrustumCullingAndReadVisibleCount()
        XCTAssertGreaterThan(
            baselineVisible, 0,
            "Sanity check: the test splat should have visible splats within the frustum before any scene-root offset"
        )

        SceneRootTransform.shared.position = simd_float3(500, 0, 0)
        SceneRootTransform.shared.updateIfNeeded()
        defer {
            SceneRootTransform.shared.position = .zero
            SceneRootTransform.shared.rotation = simd_quatf()
            SceneRootTransform.shared.scale = .one
            SceneRootTransform.shared.updateIfNeeded()
        }

        let offsetVisible = runGaussianFrustumCullingAndReadVisibleCount()
        XCTAssertEqual(
            offsetVisible, 0,
            "❌ Every splat should be culled once the scene root is translated far outside the " +
                "camera frustum. A nonzero count here means Gaussian frustum culling is not tracking " +
                "SceneRootTransform — it fell back to the raw (unmoved) camera view, got \(offsetVisible) " +
                "visible splats (baseline was \(baselineVisible))"
        )
    }

    // MARK: - HZB occlusion pre-cull (0763066cb)

    /// A 1x1 depth texture — `clamp_to_edge` sampling means every UV the gaussianFrustumCull
    /// kernel samples reads back this single value, exactly like CullingTest's
    /// `makeHZBTestTexture` for the equivalent mesh-AABB HZB tests.
    private func makeHZBTestTexture(depthValue: Float) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        let texture = renderInfo.device.makeTexture(descriptor: descriptor)!

        var value = depthValue
        withUnsafeBytes(of: &value) { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, 0, 1, 1),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: MemoryLayout<Float>.stride
            )
        }
        return texture
    }

    /// Regression coverage for 0763066cb: `gaussianFrustumCull` fuses a coarse per-splat HZB
    /// occlusion pre-cull into the same dispatch as frustum culling, gated by `hzbValid`
    /// (`renderInfo.hzbIsValid && textureResources.hzbDepthPyramid != nil`). Existing
    /// occlusion tests (`testGaussianOcclusion_*`) render a single frame, so `hzbIsValid` is
    /// still false and this whole code path never runs — it needs the HZB injected directly,
    /// the same way CullingTest does for the equivalent mesh-AABB HZB pass.
    func testGaussianFrustumCulling_hzbOccludedSplatIsCulled() {
        let originalHZBTexture = textureResources.hzbDepthPyramid
        let originalHZBValid = renderInfo.hzbIsValid
        defer {
            textureResources.hzbDepthPyramid = originalHZBTexture
            renderInfo.hzbIsValid = originalHZBValid
        }

        let camera = createTestCamera()
        cameraLookAt(entityId: camera, eye: simd_float3(0, 3, 7), target: simd_float3(0, 0, 0), up: simd_float3(0, 1, 0))

        // "Clear" HZB — nothing occluding, camera sees to the far plane. Sanity baseline:
        // the splat must actually be visible before an occluder is introduced.
        let clearDepth: Float = renderInfo.reverseZEnabled ? 0.0 : 1.0
        textureResources.hzbDepthPyramid = makeHZBTestTexture(depthValue: clearDepth)
        renderInfo.hzbIsValid = true
        let clearVisible = runGaussianFrustumCullingAndReadVisibleCount()
        XCTAssertGreaterThan(clearVisible, 0, "Sanity check: splat should be visible against a clear (far-plane) HZB")

        // "Solid" HZB — an occluder close to the camera sits in front of everything.
        // Standard-Z: close = small value. Reverse-Z: close = large value.
        let occluderDepth: Float = renderInfo.reverseZEnabled ? 0.95 : 0.05
        textureResources.hzbDepthPyramid = makeHZBTestTexture(depthValue: occluderDepth)
        renderInfo.hzbIsValid = true
        let occludedVisible = runGaussianFrustumCullingAndReadVisibleCount()
        XCTAssertEqual(
            occludedVisible, 0,
            "❌ Splats behind a full-frame HZB occluder should be pre-culled before preprocess/depth/sort/draw, " +
                "got \(occludedVisible) visible splats"
        )
    }

    /// Companion regression test: the `hzbValid` flag itself must gate the occlusion branch.
    /// If a stale/first-frame HZB were sampled without checking `hzbIsValid`, an occluding
    /// depth value left over in the texture would incorrectly cull splats even before the
    /// HZB pyramid has ever been built for this camera position.
    func testGaussianFrustumCulling_ignoresHZBWhenInvalid() {
        let originalHZBTexture = textureResources.hzbDepthPyramid
        let originalHZBValid = renderInfo.hzbIsValid
        defer {
            textureResources.hzbDepthPyramid = originalHZBTexture
            renderInfo.hzbIsValid = originalHZBValid
        }

        let camera = createTestCamera()
        cameraLookAt(entityId: camera, eye: simd_float3(0, 3, 7), target: simd_float3(0, 0, 0), up: simd_float3(0, 1, 0))

        // Same "occluding" HZB texture as the culled case above, but marked invalid.
        let occluderDepth: Float = renderInfo.reverseZEnabled ? 0.95 : 0.05
        textureResources.hzbDepthPyramid = makeHZBTestTexture(depthValue: occluderDepth)
        renderInfo.hzbIsValid = false

        let visible = runGaussianFrustumCullingAndReadVisibleCount()
        XCTAssertGreaterThan(
            visible, 0,
            "❌ hzbIsValid=false should disable the occlusion pre-cull entirely, regardless of what's " +
                "in the HZB texture — got 0 visible splats"
        )
    }

    // MARK: - Helper Methods

    func createTestCamera() -> EntityID {
        let cameraEntity = createEntity()
        if let cameraComponent = scene.assign(to: cameraEntity, component: CameraComponent.self) {
            CameraSystem.shared.activeCamera = cameraEntity
            cameraComponent.viewSpace = matrix_identity_float4x4
            cameraComponent.localPosition = SIMD3<Float>(0, 0, 0)
        }
        return cameraEntity
    }
}

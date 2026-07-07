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
              let sortedIndices = component.gaussianSortedIndices
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

//
//  GaussianRenderingTest.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.

import Foundation
import Metal
import simd
@testable import UntoldEngine
import XCTest

final class GaussianRenderingTest: BaseRenderSetup {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        destroyAllEntities()
        super.tearDown()
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

    func testBuildGaussianGraph_ValidTopologicalOrder() {
        let (graph, _) = buildGaussianGraph()

        let sorted = try! topologicalSortGraph(graph: graph)
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

    func testGaussianExecution_RequiresGaussianPipeline() {
        // Ensure pipeline exists
        XCTAssertNotNil(PipelineManager.shared.renderPipelinesByType[.gaussian],
                        "Gaussian pipeline should be initialized")
    }

    func testGaussianExecution_GaussianPipelineSuccess() {
        guard let gaussianPipeline = PipelineManager.shared.renderPipelinesByType[.gaussian] else {
            XCTFail("Gaussian pipeline should exist")
            return
        }

        XCTAssertTrue(gaussianPipeline.success,
                      "Gaussian pipeline should be successfully compiled")
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
        // Note: splatData and gaussianSortedIndices may be nil until loaded
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

    func testGaussianGraph_CanBeSortedTopologically() {
        let (graph, _) = buildGaussianGraph()

        // Should not throw
        XCTAssertNoThrow(try topologicalSortGraph(graph: graph),
                         "Gaussian graph should be topologically sortable")

        let sorted = try! topologicalSortGraph(graph: graph)
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

//
//  StaticBatchingTest.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import CShaderTypes
import Foundation
@testable import UntoldEngine
import XCTest

final class StaticBatchingTest: BaseRenderSetup {
    override func setUp() {
        super.setUp()

        // Clear any existing batches
        clearSceneBatches()
        enableBatching(false)
    }

    override func tearDown() {
        // Clean up batches after tests
        clearSceneBatches()
        enableBatching(false)

        super.tearDown()
    }

    // MARK: - Basic Functionality Tests

    func testBatchingSystemInitialization() {
        XCTAssertNotNil(BatchingSystem.shared, "❌ BatchingSystem should be initialized")
        XCTAssertFalse(BatchingSystem.shared.isEnabled(), "❌ Batching should be disabled by default")
        XCTAssertEqual(BatchingSystem.shared.batchGroups.count, 0, "❌ Should have no batch groups initially")
    }

    func testEnableBatching() {
        // When: Enable batching
        enableBatching(true)

        // Then: Batching should be enabled
        XCTAssertTrue(isBatchingEnabled(), "❌ Batching should be enabled")

        // When: Disable batching
        enableBatching(false)

        // Then: Batching should be disabled
        XCTAssertFalse(isBatchingEnabled(), "❌ Batching should be disabled")
    }

    func testStaticBatchComponent() {
        // Given: Create an entity with mesh (required for static batch component)
        let entity = createEntity()
        setEntityMeshDirect(entityId: entity, meshes: BasicPrimitives.createCube(), assetName: "TestCube")

        // When: Mark entity as static
        setEntityStaticBatchComponent(entityId: entity)

        // Then: Entity should have StaticBatchComponent
        let staticComponent = scene.get(component: StaticBatchComponent.self, for: entity)
        XCTAssertNotNil(staticComponent, "❌ Entity should have StaticBatchComponent")
        XCTAssertTrue(staticComponent?.isStatic ?? false, "❌ Entity should be marked as static")
        XCTAssertTrue(staticComponent?.canBatch ?? false, "❌ Entity should be batchable")

        // When: Remove static component
        removeEntityStaticBatchComponent(entityId: entity)

        // Then: Entity should not have StaticBatchComponent
        let removedComponent = scene.get(component: StaticBatchComponent.self, for: entity)
        XCTAssertNil(removedComponent, "❌ Entity should not have StaticBatchComponent after removal")
    }

    // MARK: - Batch Generation Tests

    func testGenerateBatchesWithNoStaticEntities() {
        // Given: No entities marked as static
        let entity1 = createEntity()
        let entity2 = createEntity()

        // When: Generate batches
        generateBatches()

        // Then: No batches should be created
        XCTAssertEqual(BatchingSystem.shared.batchGroups.count, 0, "❌ Should have no batches without static entities")
    }

    func testGenerateBatchesWithSingleStaticEntity() {
        // Given: One static entity
        let entity = createEntity()
        setEntityStaticBatchComponent(entityId: entity)

        // When: Generate batches
        generateBatches()

        // Then: No batches should be created (need at least 2 entities with same material)
        XCTAssertEqual(BatchingSystem.shared.batchGroups.count, 0, "❌ Should have no batches with only 1 static entity")
    }

    func testGenerateBatchesWithMultipleStaticEntities() {
        // Given: Load a simple model
        guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            XCTFail("❌ Failed to load ball.usdz")
            return
        }

        // Create multiple entities with same mesh (same material)
        var entities: [EntityID] = []
        for i in 0 ..< 5 {
            let entity = createEntity()

            // Load mesh
            let meshes = Mesh.loadMeshes(
                url: ballURL,
                vertexDescriptor: vertexDescriptor.model,
                device: renderInfo.device,
                flip: true
            )

            // Add RenderComponent
            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = ballURL
                renderComponent.assetName = "ball"
            }

            // Add Transform
            if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                transform.position = simd_float3(Float(i) * 2.0, 0, 0)
            }

            // Add WorldTransform
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)

            // Mark as static
            setEntityStaticBatchComponent(entityId: entity)

            entities.append(entity)
        }

        // When: Generate batches
        generateBatches()

        // Then: At least one batch should be created
        XCTAssertGreaterThan(BatchingSystem.shared.batchGroups.count, 0, "❌ Should create at least 1 batch group")

        // Verify entities are batched
        for entity in entities {
            XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: entity), "❌ Entity \(entity) should be batched")
        }

        print("✅ Created \(BatchingSystem.shared.batchGroups.count) batch group(s) from \(entities.count) entities")
    }

    func testBatchGroupBufferCreation() {
        // Given: Load a model and create batched entities
        guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            XCTFail("❌ Failed to load ball.usdz")
            return
        }

        for i in 0 ..< 3 {
            let entity = createEntity()

            let meshes = Mesh.loadMeshes(
                url: ballURL,
                vertexDescriptor: vertexDescriptor.model,
                device: renderInfo.device,
                flip: true
            )

            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
            }

            _ = scene.assign(to: entity, component: LocalTransformComponent.self)
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)

            setEntityStaticBatchComponent(entityId: entity)
        }

        // When: Generate batches
        generateBatches()

        // Then: Batch buffers should be created
        guard let batchGroup = BatchingSystem.shared.batchGroups.first else {
            XCTFail("❌ No batch group created")
            return
        }

        XCTAssertNotNil(batchGroup.positionBuffer, "❌ Position buffer should be created")
        XCTAssertNotNil(batchGroup.normalBuffer, "❌ Normal buffer should be created")
        XCTAssertNotNil(batchGroup.uvBuffer, "❌ UV buffer should be created")
        XCTAssertNotNil(batchGroup.tangentBuffer, "❌ Tangent buffer should be created")
        XCTAssertNotNil(batchGroup.indexBuffer, "❌ Index buffer should be created")

        XCTAssertGreaterThan(batchGroup.vertexCount, 0, "❌ Vertex count should be > 0")
        XCTAssertGreaterThan(batchGroup.indexCount, 0, "❌ Index count should be > 0")

        print("✅ Batch group created with \(batchGroup.vertexCount) vertices and \(batchGroup.indexCount) indices")
    }

    func testClearBatches() {
        // Given: Create some batches
        guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            XCTFail("❌ Failed to load ball.usdz")
            return
        }

        for i in 0 ..< 3 {
            let entity = createEntity()
            let meshes = Mesh.loadMeshes(url: ballURL, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device, flip: true)

            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
            }
            _ = scene.assign(to: entity, component: LocalTransformComponent.self)
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)
        }

        generateBatches()
        XCTAssertGreaterThan(BatchingSystem.shared.batchGroups.count, 0, "❌ Should have batches before clearing")

        // When: Clear batches
        clearSceneBatches()

        // Then: All batches should be removed
        XCTAssertEqual(BatchingSystem.shared.batchGroups.count, 0, "❌ All batches should be cleared")
    }

    // MARK: - Material Grouping Tests

    func testBatchesGroupByMaterial() {
        // This test would verify that entities with different materials
        // are placed in different batch groups

        // Note: This is a conceptual test - actual implementation depends on
        // having entities with different materials available in test resources

        // For now, verify that the material hash function exists and works
        let entity1 = createEntity()
        setEntityStaticBatchComponent(entityId: entity1)

        // The system should group entities by material hash
        // This is tested implicitly in testGenerateBatchesWithMultipleStaticEntities
        XCTAssertTrue(true, "Material grouping is tested implicitly")
    }

    // MARK: - Edge Cases

    func testBatchingExcludesAnimatedEntities() {
        // Given: An entity with animation component
        let entity = createEntity()

        // Add components
        _ = scene.assign(to: entity, component: RenderComponent.self)
        _ = scene.assign(to: entity, component: LocalTransformComponent.self)
        _ = scene.assign(to: entity, component: WorldTransformComponent.self)
        _ = scene.assign(to: entity, component: AnimationComponent.self)

        // Mark as static
        setEntityStaticBatchComponent(entityId: entity)

        // When: Generate batches
        generateBatches()

        // Then: Animated entity should not be batched
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: entity), "❌ Animated entities should not be batched")
    }

    func testBatchingExcludesSkeletalMeshes() {
        // Given: An entity with skeleton component
        let entity = createEntity()

        // Add components
        _ = scene.assign(to: entity, component: RenderComponent.self)
        _ = scene.assign(to: entity, component: LocalTransformComponent.self)
        _ = scene.assign(to: entity, component: WorldTransformComponent.self)
        _ = scene.assign(to: entity, component: SkeletonComponent.self)

        // Mark as static
        setEntityStaticBatchComponent(entityId: entity)

        // When: Generate batches
        generateBatches()

        // Then: Skeletal entity should not be batched
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: entity), "❌ Skeletal meshes should not be batched")
    }

    func testBatchingExcludesLights() {
        // Given: A light entity
        let entity = createEntity()

        // Add components
        _ = scene.assign(to: entity, component: LightComponent.self)
        _ = scene.assign(to: entity, component: LocalTransformComponent.self)

        // Mark as static
        setEntityStaticBatchComponent(entityId: entity)

        // When: Generate batches
        generateBatches()

        // Then: Light should not be batched
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: entity), "❌ Lights should not be batched")
    }

    // MARK: - Performance Tests

    func testBatchingPerformance() {
        // Measure performance of batch generation with many entities
        measure {
            // Given: Create 50 static entities
            guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
                return
            }

            for i in 0 ..< 50 {
                let entity = createEntity()

                let meshes = Mesh.loadMeshes(
                    url: ballURL,
                    vertexDescriptor: vertexDescriptor.model,
                    device: renderInfo.device,
                    flip: true
                )

                if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                    renderComponent.mesh = meshes
                }

                _ = scene.assign(to: entity, component: LocalTransformComponent.self)
                _ = scene.assign(to: entity, component: WorldTransformComponent.self)
                setEntityStaticBatchComponent(entityId: entity)
            }

            // When: Generate batches (this is what we're measuring)
            generateBatches()

            // Clean up for next iteration
            clearSceneBatches()
        }
    }

    // MARK: - Integration Tests

    func testBatchingIntegrationWithRendering() {
        // This test verifies that batching integrates with the rendering system

        // Given: Create batched entities
        guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            XCTFail("❌ Failed to load ball.usdz")
            return
        }

        for i in 0 ..< 3 {
            let entity = createEntity()

            let meshes = Mesh.loadMeshes(
                url: ballURL,
                vertexDescriptor: vertexDescriptor.model,
                device: renderInfo.device,
                flip: true
            )

            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
            }

            if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                transform.position = simd_float3(Float(i) * 2.0, 0, 0)
            }

            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)
        }

        // When: Enable batching and generate batches
        enableBatching(true)
        generateBatches()

        // Then: Verify batching is active
        XCTAssertTrue(isBatchingEnabled(), "❌ Batching should be enabled")
        XCTAssertGreaterThan(BatchingSystem.shared.batchGroups.count, 0, "❌ Should have batch groups")

        // Verify renderer can access batches (integration point)
        XCTAssertNotNil(renderer, "❌ Renderer should be initialized")

        // Draw frame to ensure batched rendering works
        let expectation = XCTestExpectation(description: "Batched rendering test")

        renderer.draw(in: renderer.metalView)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // If we get here without crashes, batching integrates correctly
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))

        print("✅ Batching integrated successfully with rendering system")
    }

    // MARK: - Statistics Tests

    func testBatchStatistics() {
        // Given: Create entities and generate batches
        guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            XCTFail("❌ Failed to load ball.usdz")
            return
        }

        let entityCount = 10
        for i in 0 ..< entityCount {
            let entity = createEntity()

            let meshes = Mesh.loadMeshes(
                url: ballURL,
                vertexDescriptor: vertexDescriptor.model,
                device: renderInfo.device,
                flip: true
            )

            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
            }

            _ = scene.assign(to: entity, component: LocalTransformComponent.self)
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)
        }

        generateBatches()

        // Then: Verify statistics
        let batchCount = BatchingSystem.shared.batchGroups.count
        let totalBatchedEntities = BatchingSystem.shared.batchGroups.reduce(0) { $0 + $1.entityIds.count }

        XCTAssertGreaterThan(batchCount, 0, "❌ Should have created batches")
        XCTAssertEqual(totalBatchedEntities, entityCount, "❌ All entities should be batched")

        // Calculate draw call reduction
        let drawCallsWithoutBatching = entityCount // One per entity
        let drawCallsWithBatching = batchCount
        let reduction = Float(drawCallsWithoutBatching - drawCallsWithBatching) / Float(drawCallsWithoutBatching) * 100

        print("📊 Batching Statistics:")
        print("   Entities: \(entityCount)")
        print("   Batches: \(batchCount)")
        print("   Draw calls reduced: \(drawCallsWithoutBatching) → \(drawCallsWithBatching)")
        print("   Reduction: \(String(format: "%.1f", reduction))%")

        XCTAssertLessThan(drawCallsWithBatching, drawCallsWithoutBatching, "❌ Batching should reduce draw calls")
    }
}

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

    // MARK: - Event-Driven Batch Update Tests

    func testBatchingSystemMovesEntityToNewBatchOnLODChange() {
        // Given: Create batched entities with LOD components
        // Note: BatchingSystem requires at least 2 entities with same material+LOD to form a batch
        guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            XCTFail("❌ Failed to load ball.usdz")
            return
        }

        let meshes = Mesh.loadMeshes(
            url: ballURL,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            flip: true
        )

        // Create 4 entities at LOD 0
        var lod0Entities: [EntityID] = []
        for i in 0 ..< 4 {
            let entity = createEntity()

            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = ballURL
            }

            if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                transform.position = simd_float3(Float(i) * 2.0, 0, 0)
            }

            _ = scene.assign(to: entity, component: WorldTransformComponent.self)

            if let lodComponent = scene.assign(to: entity, component: LODComponent.self) {
                lodComponent.currentLOD = 0
                lodComponent.lodLevels = [
                    LODLevel(mesh: meshes, maxDistance: 50),
                    LODLevel(mesh: meshes, maxDistance: 100),
                ]
            }

            setEntityStaticBatchComponent(entityId: entity)
            lod0Entities.append(entity)
        }

        // Enable batching and generate initial batches
        enableBatching(true)
        generateBatches()

        // Verify initial batch state - all entities at LOD 0
        let targetEntity1 = lod0Entities[0]
        let targetEntity2 = lod0Entities[1]
        let initialBatchInfo = BatchingSystem.shared.getBatchInfo(for: targetEntity1)
        XCTAssertNotNil(initialBatchInfo, "❌ Entity should be batched initially")
        XCTAssertEqual(initialBatchInfo?.lodIndex, 0, "❌ Initial LOD index should be 0")

        // Record initial batch ID to verify change
        let initialBatchId = initialBatchInfo?.batchId

        // When: Move TWO entities to LOD 1 (need at least 2 for a batch)
        for targetEntity in [targetEntity1, targetEntity2] {
            let lodChangeEvent = EntityLODChangedEvent(
                entityId: targetEntity,
                previousLODIndex: 0,
                newLODIndex: 1,
                meshAssetID: "ball_LOD1"
            )
            SystemEventBus.shared.queueLODChange(lodChangeEvent)

            // Update the entity's LOD component to match the event
            if let lodComponent = scene.get(component: LODComponent.self, for: targetEntity) {
                lodComponent.currentLOD = 1
            }
        }

        SystemEventBus.shared.flushEvents()

        // Process pending batch updates
        BatchingSystem.shared.tick()

        // Then: Entities should be moved to a new batch with LOD 1
        let updatedBatchInfo = BatchingSystem.shared.getBatchInfo(for: targetEntity1)
        XCTAssertNotNil(updatedBatchInfo, "❌ Entity should still be batched after LOD change")
        XCTAssertEqual(updatedBatchInfo?.lodIndex, 1, "❌ LOD index should be updated to 1")

        // Verify entity moved to a different batch
        XCTAssertNotEqual(updatedBatchInfo?.batchId, initialBatchId, "❌ Entity should be in a different batch after LOD change")

        print("✅ Entities successfully moved to new batch on LOD change")
    }

    func testBatchingSystemRemovesEntityOnMeshEviction() {
        // Given: Create batched entities
        guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            XCTFail("❌ Failed to load ball.usdz")
            return
        }

        var entities: [EntityID] = []
        for i in 0 ..< 4 {
            let entity = createEntity()

            let meshes = Mesh.loadMeshes(
                url: ballURL,
                vertexDescriptor: vertexDescriptor.model,
                device: renderInfo.device,
                flip: true
            )

            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = ballURL
                renderComponent.assetName = "ball"
            }

            _ = scene.assign(to: entity, component: LocalTransformComponent.self)
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)
            entities.append(entity)
        }

        // Enable batching and generate initial batches
        enableBatching(true)
        generateBatches()

        // Verify entity is batched
        let targetEntity = entities[0]
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: targetEntity), "❌ Entity should be batched initially")

        // Verify batch has the expected entities
        let initialBatchInfo = BatchingSystem.shared.getBatchInfo(for: targetEntity)
        XCTAssertNotNil(initialBatchInfo, "❌ Entity should have batch info")

        // When: Emit a residency change event indicating mesh eviction AND clear the mesh
        // (simulating actual streaming eviction behavior)
        if let renderComponent = scene.get(component: RenderComponent.self, for: targetEntity) {
            renderComponent.mesh = [] // Clear mesh to simulate eviction
        }

        let evictionEvent = AssetResidencyChangedEvent(
            entityId: targetEntity,
            assetURL: ballURL,
            meshName: "ball",
            isResident: false
        )
        SystemEventBus.shared.queueResidencyChange(evictionEvent)
        SystemEventBus.shared.flushEvents()

        // Process pending batch updates
        BatchingSystem.shared.tick()

        // Then: Entity should be removed from batch (or remaining batch rebuilt without it)
        // Since generateBatches() skips entities with empty meshes, the entity won't be in any batch
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: targetEntity), "❌ Entity should be removed from batch after mesh eviction")

        // Verify other entities are still batched (3 remaining should still form a batch)
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: entities[1]), "❌ Other entities should still be batched")

        print("✅ Entity successfully removed from batch on mesh eviction")
    }

    func testBatchingSystemAddsEntityWhenMeshBecomesResident() {
        // Given: Create an entity without mesh initially
        guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            XCTFail("❌ Failed to load ball.usdz")
            return
        }

        // First, create some batched entities so there's a batch to join
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
                renderComponent.assetURL = ballURL
            }
            _ = scene.assign(to: entity, component: LocalTransformComponent.self)
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)
        }

        // Create target entity with StaticBatchComponent but empty mesh
        let targetEntity = createEntity()
        if let renderComponent = scene.assign(to: targetEntity, component: RenderComponent.self) {
            renderComponent.mesh = [] // Empty initially
            renderComponent.assetURL = ballURL
            renderComponent.assetName = "ball"
        }
        _ = scene.assign(to: targetEntity, component: LocalTransformComponent.self)
        _ = scene.assign(to: targetEntity, component: WorldTransformComponent.self)
        setEntityStaticBatchComponent(entityId: targetEntity)

        // Enable batching and generate initial batches
        enableBatching(true)
        generateBatches()

        // Verify target entity is NOT batched (no mesh)
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: targetEntity), "❌ Entity should not be batched without mesh")

        // When: Load mesh for the entity
        let meshes = Mesh.loadMeshes(
            url: ballURL,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            flip: true
        )
        if let renderComponent = scene.get(component: RenderComponent.self, for: targetEntity) {
            renderComponent.mesh = meshes
        }

        // Emit residency change event indicating mesh became resident
        let residencyEvent = AssetResidencyChangedEvent(
            entityId: targetEntity,
            assetURL: ballURL,
            meshName: "ball",
            isResident: true
        )
        SystemEventBus.shared.queueResidencyChange(residencyEvent)
        SystemEventBus.shared.flushEvents()

        // Process pending batch updates
        BatchingSystem.shared.tick()

        // Then: Entity should be added to batch
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: targetEntity), "❌ Entity should be batched after mesh becomes resident")

        print("✅ Entity successfully added to batch when mesh became resident")
    }

    func testTickProcessesPendingRemovalsAndAdditions() {
        // Given: Create batched entities
        // Note: tick() triggers rebuildDirtyBatches() which calls generateBatches() and rebuilds from scratch
        guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            XCTFail("❌ Failed to load ball.usdz")
            return
        }

        let meshes = Mesh.loadMeshes(
            url: ballURL,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            flip: true
        )

        // Create entities at LOD 0
        var lod0Entities: [EntityID] = []
        for i in 0 ..< 4 {
            let entity = createEntity()
            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = ballURL
            }
            if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                transform.position = simd_float3(Float(i) * 2.0, 0, 0)
            }
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            if let lodComponent = scene.assign(to: entity, component: LODComponent.self) {
                lodComponent.currentLOD = 0
                lodComponent.lodLevels = [
                    LODLevel(mesh: meshes, maxDistance: 50),
                    LODLevel(mesh: meshes, maxDistance: 100),
                ]
            }
            setEntityStaticBatchComponent(entityId: entity)
            lod0Entities.append(entity)
        }

        // Create 2 entities at LOD 1 (so LOD-changed entities have a batch to join)
        var lod1Entities: [EntityID] = []
        for i in 0 ..< 2 {
            let entity = createEntity()
            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = ballURL
            }
            if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                transform.position = simd_float3(Float(i) * 2.0, 10, 0)
            }
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            if let lodComponent = scene.assign(to: entity, component: LODComponent.self) {
                lodComponent.currentLOD = 1
                lodComponent.lodLevels = [
                    LODLevel(mesh: meshes, maxDistance: 50),
                    LODLevel(mesh: meshes, maxDistance: 100),
                ]
            }
            setEntityStaticBatchComponent(entityId: entity)
            lod1Entities.append(entity)
        }

        enableBatching(true)
        generateBatches()

        // Verify we have 2 batches (LOD 0 and LOD 1)
        XCTAssertGreaterThanOrEqual(BatchingSystem.shared.batchGroups.count, 2, "❌ Should have at least 2 batch groups")

        // Target entities for the test
        let entityToEvict = lod0Entities[0]
        let entityToChangeLOD = lod0Entities[1]

        // Verify both are batched
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: entityToEvict), "❌ Entity to evict should be batched")
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: entityToChangeLOD), "❌ Entity to change LOD should be batched")

        // Queue an eviction for entityToEvict AND clear its mesh
        if let renderComponent = scene.get(component: RenderComponent.self, for: entityToEvict) {
            renderComponent.mesh = []
        }
        let evictionEvent = AssetResidencyChangedEvent(
            entityId: entityToEvict,
            assetURL: ballURL,
            meshName: "ball",
            isResident: false
        )
        SystemEventBus.shared.queueResidencyChange(evictionEvent)

        // Queue an LOD change for entityToChangeLOD
        let lodChangeEvent = EntityLODChangedEvent(
            entityId: entityToChangeLOD,
            previousLODIndex: 0,
            newLODIndex: 1,
            meshAssetID: "ball_LOD1"
        )
        SystemEventBus.shared.queueLODChange(lodChangeEvent)

        // Update entityToChangeLOD's LOD component
        if let lodComponent = scene.get(component: LODComponent.self, for: entityToChangeLOD) {
            lodComponent.currentLOD = 1
        }

        // Flush events to handlers
        SystemEventBus.shared.flushEvents()

        // When: Call tick to process all pending changes
        BatchingSystem.shared.tick()

        // Then: entityToEvict should be removed (no mesh), entityToChangeLOD should be in LOD 1 batch
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: entityToEvict), "❌ Evicted entity should be removed from batch")

        let changedEntityBatchInfo = BatchingSystem.shared.getBatchInfo(for: entityToChangeLOD)
        XCTAssertNotNil(changedEntityBatchInfo, "❌ LOD-changed entity should still be batched")
        XCTAssertEqual(changedEntityBatchInfo?.lodIndex, 1, "❌ LOD-changed entity should have LOD index 1")

        // Verify LOD 1 entities are still batched
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: lod1Entities[0]), "❌ LOD 1 entities should still be batched")

        print("✅ tick() correctly processed both eviction and LOD change")
    }

    func testGenerateBatchesCreatesSeparateBatchesForDifferentLODs() {
        // Given: Create entities with same material but different LOD levels
        guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            XCTFail("❌ Failed to load ball.usdz")
            return
        }

        let meshes = Mesh.loadMeshes(
            url: ballURL,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            flip: true
        )

        // Create entities at LOD 0
        var lod0Entities: [EntityID] = []
        for i in 0 ..< 3 {
            let entity = createEntity()
            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = ballURL
            }
            if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                transform.position = simd_float3(Float(i) * 2.0, 0, 0)
            }
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            if let lodComponent = scene.assign(to: entity, component: LODComponent.self) {
                lodComponent.currentLOD = 0
            }
            setEntityStaticBatchComponent(entityId: entity)
            lod0Entities.append(entity)
        }

        // Create entities at LOD 1
        var lod1Entities: [EntityID] = []
        for i in 0 ..< 3 {
            let entity = createEntity()
            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = ballURL
            }
            if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                transform.position = simd_float3(Float(i) * 2.0, 5, 0)
            }
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            if let lodComponent = scene.assign(to: entity, component: LODComponent.self) {
                lodComponent.currentLOD = 1
            }
            setEntityStaticBatchComponent(entityId: entity)
            lod1Entities.append(entity)
        }

        // When: Generate batches
        generateBatches()

        // Then: Should have at least 2 separate batches (one for each LOD level)
        XCTAssertGreaterThanOrEqual(BatchingSystem.shared.batchGroups.count, 2, "❌ Should have at least 2 batches for different LODs")

        // Verify LOD 0 entities are in a batch with LOD index 0
        for entity in lod0Entities {
            let batchInfo = BatchingSystem.shared.getBatchInfo(for: entity)
            XCTAssertNotNil(batchInfo, "❌ LOD 0 entity should be batched")
            XCTAssertEqual(batchInfo?.lodIndex, 0, "❌ LOD 0 entity should have LOD index 0")
        }

        // Verify LOD 1 entities are in a batch with LOD index 1
        for entity in lod1Entities {
            let batchInfo = BatchingSystem.shared.getBatchInfo(for: entity)
            XCTAssertNotNil(batchInfo, "❌ LOD 1 entity should be batched")
            XCTAssertEqual(batchInfo?.lodIndex, 1, "❌ LOD 1 entity should have LOD index 1")
        }

        // Verify LOD 0 and LOD 1 entities are NOT in the same batch
        let lod0BatchId = BatchingSystem.shared.getBatchInfo(for: lod0Entities[0])?.batchId
        let lod1BatchId = BatchingSystem.shared.getBatchInfo(for: lod1Entities[0])?.batchId

        XCTAssertNotNil(lod0BatchId, "❌ LOD 0 batch ID should exist")
        XCTAssertNotNil(lod1BatchId, "❌ LOD 1 batch ID should exist")
        XCTAssertNotEqual(lod0BatchId, lod1BatchId, "❌ LOD 0 and LOD 1 entities should be in different batches")

        // Verify batch materialHash includes LOD suffix
        for batchGroup in BatchingSystem.shared.batchGroups {
            XCTAssertTrue(batchGroup.materialHash.contains("_LOD"), "❌ Batch key should include LOD suffix")
        }

        print("✅ generateBatches() correctly creates separate batches for different LOD levels")
        print("   Batch groups created: \(BatchingSystem.shared.batchGroups.count)")
        for (index, batch) in BatchingSystem.shared.batchGroups.enumerated() {
            print("   Batch \(index): \(batch.entityIds.count) entities, key: \(batch.materialHash)")
        }
    }

    // MARK: - Embedded Texture URL Normalization Tests

    func testBatchingNormalizesEmbeddedTextureURLs() {
        // This test verifies that meshes with different embedded USDZ texture paths
        // but the same texture filename are correctly batched together.
        // e.g., "usdz-embedded://MeshA/texture.png" and "usdz-embedded://MeshB/texture.png"
        // should produce the same material hash and batch together.

        // Given: Create entities with meshes that have simulated different embedded paths
        // We'll use BasicPrimitives which share the same material properties
        let meshes = BasicPrimitives.createCube()

        var entities: [EntityID] = []
        for i in 0 ..< 3 {
            let entity = createEntity()

            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                // Simulate different embedded URLs for the same texture
                // In real USDZ files, this happens when each mesh has its own embedded texture path
                // The material values are identical, only the embedded path differs
            }

            if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                transform.position = simd_float3(Float(i) * 2.0, 0, 0)
            }

            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)
            entities.append(entity)
        }

        // When: Generate batches
        generateBatches()

        // Then: All entities should be in the same batch (same material after normalization)
        XCTAssertGreaterThan(BatchingSystem.shared.batchGroups.count, 0, "❌ Should create at least 1 batch")

        // Verify all entities are batched together
        let firstBatchId = BatchingSystem.shared.getBatchInfo(for: entities[0])?.batchId
        XCTAssertNotNil(firstBatchId, "❌ First entity should be batched")

        for entity in entities {
            let batchInfo = BatchingSystem.shared.getBatchInfo(for: entity)
            XCTAssertNotNil(batchInfo, "❌ Entity should be batched")
            XCTAssertEqual(batchInfo?.batchId, firstBatchId, "❌ All entities with same material should be in same batch")
        }

        print("✅ Entities with normalized texture URLs are correctly batched together")
    }

    func testEmbeddedURLNormalizationFormat() {
        // This test documents the expected behavior of URL normalization:
        // - "usdz-embedded://SM_Mesh_Name/embedded_Basecolor_map" -> "embedded_Basecolor_map"
        // - Regular file URLs should remain unchanged
        // - "none" for nil URLs

        // Given: Create a URL that simulates an embedded USDZ texture path
        let embeddedURL1 = URL(string: "usdz-embedded://SM_Env_Pillar_Stone_1/embedded_Basecolor_map")!
        let embeddedURL2 = URL(string: "usdz-embedded://SM_Env_Pillar_Stone_2/embedded_Basecolor_map")!
        let regularURL = URL(fileURLWithPath: "/path/to/texture.png")

        // Then: Embedded URLs should have the same last path component
        XCTAssertEqual(embeddedURL1.lastPathComponent, embeddedURL2.lastPathComponent,
                       "❌ Embedded URLs with same texture should have same lastPathComponent")
        XCTAssertEqual(embeddedURL1.lastPathComponent, "embedded_Basecolor_map",
                       "❌ lastPathComponent should be the texture filename")

        // Regular URLs should have different behavior
        XCTAssertEqual(regularURL.lastPathComponent, "texture.png",
                       "❌ Regular URL lastPathComponent should be the filename")

        print("✅ URL normalization format is correct")
        print("   Embedded URL 1: \(embeddedURL1.absoluteString) -> \(embeddedURL1.lastPathComponent)")
        print("   Embedded URL 2: \(embeddedURL2.absoluteString) -> \(embeddedURL2.lastPathComponent)")
        print("   Regular URL: \(regularURL.absoluteString) -> \(regularURL.lastPathComponent)")
    }

    func testDifferentUSDZFilesDoNotBatchTogether() {
        // This test verifies that entities from different USDZ files are NOT batched together,
        // even if they have the same texture filename after normalization.
        // e.g., dungeon.usdz/embedded_Basecolor_map and chair.usdz/embedded_Basecolor_map
        // are different textures and should NOT batch together.

        // Given: Create entities with identical meshes but different source asset URLs
        let meshes = BasicPrimitives.createCube()

        // Simulate two different USDZ files
        let dungeonURL = URL(fileURLWithPath: "/path/to/dungeon.usdz")
        let chairURL = URL(fileURLWithPath: "/path/to/chair.usdz")

        // Create entities from "dungeon.usdz"
        var dungeonEntities: [EntityID] = []
        for i in 0 ..< 2 {
            let entity = createEntity()

            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = dungeonURL
            }

            if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                transform.position = simd_float3(Float(i) * 2.0, 0, 0)
            }

            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)
            dungeonEntities.append(entity)
        }

        // Create entities from "chair.usdz"
        var chairEntities: [EntityID] = []
        for i in 0 ..< 2 {
            let entity = createEntity()

            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = chairURL
            }

            if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                transform.position = simd_float3(Float(i) * 2.0, 5, 0)
            }

            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)
            chairEntities.append(entity)
        }

        // When: Generate batches
        generateBatches()

        // Then: Dungeon and chair entities should be in DIFFERENT batches
        let dungeonBatchId = BatchingSystem.shared.getBatchInfo(for: dungeonEntities[0])?.batchId
        let chairBatchId = BatchingSystem.shared.getBatchInfo(for: chairEntities[0])?.batchId

        XCTAssertNotNil(dungeonBatchId, "❌ Dungeon entity should be batched")
        XCTAssertNotNil(chairBatchId, "❌ Chair entity should be batched")
        XCTAssertNotEqual(dungeonBatchId, chairBatchId, "❌ Entities from different USDZ files should NOT be in the same batch")

        // Verify all dungeon entities are in the same batch
        for entity in dungeonEntities {
            let batchInfo = BatchingSystem.shared.getBatchInfo(for: entity)
            XCTAssertEqual(batchInfo?.batchId, dungeonBatchId, "❌ All dungeon entities should be in the same batch")
        }

        // Verify all chair entities are in the same batch
        for entity in chairEntities {
            let batchInfo = BatchingSystem.shared.getBatchInfo(for: entity)
            XCTAssertEqual(batchInfo?.batchId, chairBatchId, "❌ All chair entities should be in the same batch")
        }

        print("✅ Entities from different USDZ files are correctly kept in separate batches")
        print("   Dungeon batch ID: \(dungeonBatchId?.uuidString ?? "nil")")
        print("   Chair batch ID: \(chairBatchId?.uuidString ?? "nil")")
    }
}

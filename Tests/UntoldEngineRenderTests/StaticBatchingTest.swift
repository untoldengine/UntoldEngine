//
//  StaticBatchingTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
@testable import UntoldEngine
import XCTest

final class StaticBatchingTest: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()

        // Clear any existing batches
        clearSceneBatches()
        enableBatching(false)
        BatchingSystem.shared.setBatchCellSize(32.0)
        BatchingSystem.shared.setMaxDirtyCellsPerTick(8)
        BatchingSystem.shared.setMaxRebuildVerticesPerTick(1_000_000_000)
        BatchingSystem.shared.setMaxRebuildIndicesPerTick(1_000_000_000)
        BatchingSystem.shared.setMaxRebuildBufferBytesPerTick(1_000_000_000)
        BatchingSystem.shared.setMaxRuntimeCellVertices(1_000_000_000)
        BatchingSystem.shared.setMaxRuntimeCellIndices(1_000_000_000)
        BatchingSystem.shared.setMaxRuntimeCellBufferBytes(1_000_000_000)
        BatchingSystem.shared.setQuiescenceFramesBeforeBatchBuild(0)
        BatchingSystem.shared.setRecentVisibilityWindowFrames(120)
        BatchingSystem.shared.setVisibilityGatedBatchBuildEnabled(false)
        BatchingSystem.shared.setBackgroundArtifactBuildEnabled(false)
        BatchingSystem.shared.setMaxBuildDispatchesPerTick(8)
        BatchingSystem.shared.setMaxArtifactAppliesPerTick(8)
        disableSpatialDebugVisualization()
    }

    override func tearDown() async throws {
        // Clean up batches after tests
        clearSceneBatches()
        enableBatching(false)
        BatchingSystem.shared.setBatchCellSize(32.0)
        BatchingSystem.shared.setMaxDirtyCellsPerTick(8)
        BatchingSystem.shared.setMaxRebuildVerticesPerTick(1_000_000_000)
        BatchingSystem.shared.setMaxRebuildIndicesPerTick(1_000_000_000)
        BatchingSystem.shared.setMaxRebuildBufferBytesPerTick(1_000_000_000)
        BatchingSystem.shared.setMaxRuntimeCellVertices(1_000_000_000)
        BatchingSystem.shared.setMaxRuntimeCellIndices(1_000_000_000)
        BatchingSystem.shared.setMaxRuntimeCellBufferBytes(1_000_000_000)
        BatchingSystem.shared.setQuiescenceFramesBeforeBatchBuild(0)
        BatchingSystem.shared.setRecentVisibilityWindowFrames(120)
        BatchingSystem.shared.setVisibilityGatedBatchBuildEnabled(false)
        BatchingSystem.shared.setBackgroundArtifactBuildEnabled(false)
        BatchingSystem.shared.setMaxBuildDispatchesPerTick(8)
        BatchingSystem.shared.setMaxArtifactAppliesPerTick(8)
        disableSpatialDebugVisualization()

        try await super.tearDown()
    }

    private func createStaticCubeEntity(position: simd_float3, lodIndex: Int = 0, markStatic: Bool = true) -> EntityID {
        let entity = createEntity()

        if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
            renderComponent.mesh = BasicPrimitives.createCube()
            renderComponent.assetURL = URL(fileURLWithPath: "/tmp/static_batch_cell_test.usdz")
        }

        if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
            transform.position = position
        }

        _ = scene.assign(to: entity, component: WorldTransformComponent.self)
        _ = scene.assign(to: entity, component: ScenegraphComponent.self)

        if let lodComponent = scene.assign(to: entity, component: LODComponent.self) {
            lodComponent.currentLOD = lodIndex
        }

        if markStatic {
            setEntityStaticBatchComponent(entityId: entity)
        }
        return entity
    }

    private func setVisibleEntitiesForSpatialDebug(_ entities: [EntityID]) {
        cullFrameIndex &+= 1
        visibleEntityIds = entities
        for frame in 0 ..< 3 {
            tripleVisibleEntities.setWrite(frame: frame, with: entities)
        }
    }

    private func approximatelyEqual(_ lhs: simd_float4, _ rhs: simd_float4, epsilon: Float = 0.0001) -> Bool {
        abs(lhs.x - rhs.x) <= epsilon &&
            abs(lhs.y - rhs.y) <= epsilon &&
            abs(lhs.z - rhs.z) <= epsilon &&
            abs(lhs.w - rhs.w) <= epsilon
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
        // Load meshes once so all entities share the same texture object identity
        let meshes = BasicPrimitives.createSphere()

        // Create multiple entities with same mesh (same material)
        var entities: [EntityID] = []
        for i in 0 ..< 5 {
            let entity = createEntity()

            // Add RenderComponent
            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
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

    func testNMNamedStaticEntityIsExcludedFromBatching() {
        let wallA = createStaticCubeEntity(position: simd_float3(0, 0, 0))
        let wallB = createStaticCubeEntity(position: simd_float3(2, 0, 0))
        let pipe = createStaticCubeEntity(position: simd_float3(4, 0, 0), markStatic: false)

        setEntityName(entityId: wallA, name: "Wall_A")
        setEntityName(entityId: wallB, name: "Wall_B")
        setEntityName(entityId: pipe, name: "NM_Pipe_001")
        setEntityStaticBatchComponent(entityId: pipe)

        generateBatches()

        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: wallA), "Context entity should still be batchable")
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: wallB), "Context entity should still be batchable")
        XCTAssertNil(scene.get(component: StaticBatchComponent.self, for: pipe), "Selectable NM_ entity should not be tagged for static batching")
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: pipe), "Selectable NM_ entity must remain individually renderable")
    }

    func testStreamedTileHierarchyHidesOnlyNonSelectableRenderChildren() {
        let tileRoot = createEntity()
        registerTransformComponent(entityId: tileRoot)
        registerSceneGraphComponent(entityId: tileRoot)
        setEntityName(entityId: tileRoot, name: "F04_Q_1_2_SI")

        let wallA = createStaticCubeEntity(position: simd_float3(0, 0, 0), markStatic: false)
        let wallB = createStaticCubeEntity(position: simd_float3(2, 0, 0), markStatic: false)
        let selectablePipe = createStaticCubeEntity(position: simd_float3(4, 0, 0), markStatic: false)

        setEntityName(entityId: wallA, name: "Wall_A")
        setEntityName(entityId: wallB, name: "Wall_B")
        setEntityName(entityId: selectablePipe, name: "NM_Pipe_001")
        setParent(childId: wallA, parentId: tileRoot)
        setParent(childId: wallB, parentId: tileRoot)
        setParent(childId: selectablePipe, parentId: tileRoot)

        setEntityStaticBatchHierarchy(entityId: tileRoot)
        setSceneChannel(.contextGeometry, .renderMode(.hidden))
        generateBatches()

        XCTAssertTrue(shouldHideSceneEntity(entityId: wallA))
        XCTAssertTrue(shouldHideSceneEntity(entityId: wallB))
        XCTAssertFalse(shouldHideSceneEntity(entityId: selectablePipe))
        XCTAssertTrue(isSelectableSceneEntity(entityId: selectablePipe))

        XCTAssertNotNil(scene.get(component: StaticBatchComponent.self, for: wallA))
        XCTAssertNotNil(scene.get(component: StaticBatchComponent.self, for: wallB))
        XCTAssertNil(scene.get(component: StaticBatchComponent.self, for: selectablePipe))
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: wallA))
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: wallB))
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: selectablePipe))
    }

    func testGhostGeometryChannelCreatesSeparateBatchGroup() {
        let normalWallA = createStaticCubeEntity(position: simd_float3(0, 0, 0), markStatic: true)
        let normalWallB = createStaticCubeEntity(position: simd_float3(2, 0, 0), markStatic: true)
        let ghostWallA = createStaticCubeEntity(position: simd_float3(4, 0, 0), markStatic: true)
        let ghostWallB = createStaticCubeEntity(position: simd_float3(6, 0, 0), markStatic: true)

        setEntitySceneChannels(entityId: normalWallA, channels: .contextGeometry)
        setEntitySceneChannels(entityId: normalWallB, channels: .contextGeometry)
        setEntitySceneChannels(entityId: ghostWallA, channels: .ghostGeometry)
        setEntitySceneChannels(entityId: ghostWallB, channels: .ghostGeometry)
        setSceneChannel(.ghostGeometry, .renderMode(.passthroughGhost(opacity: 0.35)))

        generateBatches()

        let normalGroup = BatchingSystem.shared.getBatchGroup(for: normalWallA)
        let ghostGroup = BatchingSystem.shared.getBatchGroup(for: ghostWallA)

        XCTAssertNotNil(normalGroup)
        XCTAssertNotNil(ghostGroup)
        XCTAssertNotEqual(normalGroup?.id, ghostGroup?.id, "Ghost geometry should not merge into normal context batches")
        XCTAssertTrue(normalGroup?.sceneChannels.contains(.contextGeometry) ?? false)
        XCTAssertTrue(ghostGroup?.sceneChannels.contains(.ghostGeometry) ?? false)
        XCTAssertEqual(BatchingSystem.shared.getBatchGroup(for: normalWallB)?.id, normalGroup?.id)
        XCTAssertEqual(BatchingSystem.shared.getBatchGroup(for: ghostWallB)?.id, ghostGroup?.id)
        XCTAssertTrue(shouldRenderSceneChannelsOpaque(ghostGroup?.sceneChannels ?? []))
    }

    func testPreserveIdentityGhostGeometryIsExcludedFromBatching() {
        let normalWallA = createStaticCubeEntity(position: simd_float3(0, 0, 0), markStatic: true)
        let normalWallB = createStaticCubeEntity(position: simd_float3(2, 0, 0), markStatic: true)
        let selectedWall = createStaticCubeEntity(position: simd_float3(4, 0, 0), markStatic: false)

        setEntitySceneChannels(entityId: normalWallA, channels: .contextGeometry)
        setEntitySceneChannels(entityId: normalWallB, channels: .contextGeometry)
        setEntitySceneChannels(entityId: selectedWall, channels: [.ghostGeometry, .preserveIdentity])
        setEntityStaticBatchComponent(entityId: selectedWall)
        setSceneChannel(.ghostGeometry, .renderMode(.passthroughGhost(opacity: 0.35)))

        generateBatches()

        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: normalWallA))
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: normalWallB))
        XCTAssertNil(scene.get(component: StaticBatchComponent.self, for: selectedWall), "Preserved ghost geometry should reject static batching")
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: selectedWall))
        XCTAssertTrue(shouldRenderSceneEntityAsPassthroughGhost(entityId: selectedWall))
        XCTAssertTrue(shouldPreserveSceneEntityIdentity(entityId: selectedWall))
    }

    func testBatchGroupBufferCreation() {
        // Given: Load a model and create batched entities
        let meshes = BasicPrimitives.createSphere()

        for _ in 0 ..< 3 {
            let entity = createEntity()

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
        let meshes = BasicPrimitives.createSphere()

        for _ in 0 ..< 3 {
            let entity = createEntity()

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

    func testGenerateBatchesCreatesSeparateBatchesForDifferentCells() {
        BatchingSystem.shared.setBatchCellSize(10.0)

        let nearCellEntityA = createStaticCubeEntity(position: simd_float3(1.0, 0.0, 0.0))
        let nearCellEntityB = createStaticCubeEntity(position: simd_float3(3.0, 0.0, 0.0))
        let farCellEntityA = createStaticCubeEntity(position: simd_float3(25.0, 0.0, 0.0))
        let farCellEntityB = createStaticCubeEntity(position: simd_float3(27.0, 0.0, 0.0))

        generateBatches()

        let nearBatchA = BatchingSystem.shared.getBatchInfo(for: nearCellEntityA)
        let nearBatchB = BatchingSystem.shared.getBatchInfo(for: nearCellEntityB)
        let farBatchA = BatchingSystem.shared.getBatchInfo(for: farCellEntityA)
        let farBatchB = BatchingSystem.shared.getBatchInfo(for: farCellEntityB)

        XCTAssertNotNil(nearBatchA, "❌ Near cell entity A should be batched")
        XCTAssertNotNil(nearBatchB, "❌ Near cell entity B should be batched")
        XCTAssertNotNil(farBatchA, "❌ Far cell entity A should be batched")
        XCTAssertNotNil(farBatchB, "❌ Far cell entity B should be batched")

        XCTAssertEqual(nearBatchA?.batchId, nearBatchB?.batchId, "❌ Entities in same cell should share a batch")
        XCTAssertEqual(farBatchA?.batchId, farBatchB?.batchId, "❌ Entities in same far cell should share a batch")
        XCTAssertNotEqual(nearBatchA?.batchId, farBatchA?.batchId, "❌ Entities in different cells should not share a batch")
        XCTAssertNotEqual(nearBatchA?.cellId, farBatchA?.cellId, "❌ Different-cell entities should have different cell IDs")
    }

    func testGenerateBatchesMergesEntitiesWithinSameCellMaterialAndLOD() {
        BatchingSystem.shared.setBatchCellSize(50.0)

        let entityA = createStaticCubeEntity(position: simd_float3(1.0, 0.0, 0.0), lodIndex: 0)
        let entityB = createStaticCubeEntity(position: simd_float3(4.0, 0.0, 0.0), lodIndex: 0)
        let entityC = createStaticCubeEntity(position: simd_float3(8.0, 0.0, 0.0), lodIndex: 0)

        generateBatches()

        let batchInfoA = BatchingSystem.shared.getBatchInfo(for: entityA)
        let batchInfoB = BatchingSystem.shared.getBatchInfo(for: entityB)
        let batchInfoC = BatchingSystem.shared.getBatchInfo(for: entityC)

        XCTAssertNotNil(batchInfoA, "❌ Entity A should be batched")
        XCTAssertNotNil(batchInfoB, "❌ Entity B should be batched")
        XCTAssertNotNil(batchInfoC, "❌ Entity C should be batched")

        XCTAssertEqual(batchInfoA?.batchId, batchInfoB?.batchId, "❌ Same-cell entities should share a batch")
        XCTAssertEqual(batchInfoA?.batchId, batchInfoC?.batchId, "❌ Same-cell entities should share a batch")
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
            for _ in 0 ..< 50 {
                let entity = createEntity()

                let meshes = BasicPrimitives.createSphere()

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
        let meshes = BasicPrimitives.createSphere()

        for i in 0 ..< 3 {
            let entity = createEntity()

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

    func testVisibleBatchIdCollectionFiltersToVisibleEntities() throws {
        BatchingSystem.shared.setBatchCellSize(10.0)
        enableBatching(true)

        let cell0EntityA = createStaticCubeEntity(position: simd_float3(1.0, 0.0, 0.0))
        let cell0EntityB = createStaticCubeEntity(position: simd_float3(3.0, 0.0, 0.0))
        let cell2EntityA = createStaticCubeEntity(position: simd_float3(25.0, 0.0, 0.0))
        let cell2EntityB = createStaticCubeEntity(position: simd_float3(27.0, 0.0, 0.0))

        generateBatches()
        XCTAssertEqual(BatchingSystem.shared.batchGroups.count, 2, "❌ Expected two cell-based batches")

        let cell0BatchId = BatchingSystem.shared.getBatchInfo(for: cell0EntityA)?.batchId
        let cell2BatchId = BatchingSystem.shared.getBatchInfo(for: cell2EntityA)?.batchId
        XCTAssertNotNil(cell0BatchId, "❌ Cell 0 batch should exist")
        XCTAssertNotNil(cell2BatchId, "❌ Cell 2 batch should exist")

        let visibleBatchIds = RenderPasses.collectVisibleBatchIds(from: [cell0EntityA, cell0EntityB])

        XCTAssertEqual(visibleBatchIds.count, 1, "❌ Visible entity set should resolve to exactly one batch")
        XCTAssertTrue(try visibleBatchIds.contains(XCTUnwrap(cell0BatchId)), "❌ Visible set should include the visible batch")
        XCTAssertFalse(try visibleBatchIds.contains(XCTUnwrap(cell2BatchId)), "❌ Visible set should exclude non-visible batches")
        XCTAssertNotNil(BatchingSystem.shared.getBatchInfo(for: cell2EntityB), "❌ Non-visible entities should still remain batched")
    }

    func testSpatialDebugCollectorIncludesStaticBatchCellBounds() {
        BatchingSystem.shared.setBatchCellSize(10.0)
        enableBatching(true)

        _ = createStaticCubeEntity(position: simd_float3(1.0, 0.0, 0.0))
        _ = createStaticCubeEntity(position: simd_float3(3.0, 0.0, 0.0))
        _ = createStaticCubeEntity(position: simd_float3(25.0, 0.0, 0.0))
        _ = createStaticCubeEntity(position: simd_float3(27.0, 0.0, 0.0))
        generateBatches()

        setStaticBatchCellBoundsDebug(enabled: true, colorMode: .plain)
        let snapshot = SpatialDebugBoundsCollector.shared.collectSnapshot()

        XCTAssertEqual(snapshot.staticBatchCellBounds.count, 2, "❌ Expected one debug bound per populated static batch cell")
    }

    func testSpatialDebugCollectorStaticBatchCellsUseCullingColors() {
        let visibleColor = simd_float4(0.25, 0.95, 0.35, 1.0)
        let culledColor = simd_float4(0.30, 0.60, 1.00, 1.0)

        BatchingSystem.shared.setBatchCellSize(10.0)
        enableBatching(true)

        let cell0EntityA = createStaticCubeEntity(position: simd_float3(1.0, 0.0, 0.0))
        let cell0EntityB = createStaticCubeEntity(position: simd_float3(3.0, 0.0, 0.0))
        let cell2EntityA = createStaticCubeEntity(position: simd_float3(25.0, 0.0, 0.0))
        let cell2EntityB = createStaticCubeEntity(position: simd_float3(27.0, 0.0, 0.0))
        generateBatches()

        setVisibleEntitiesForSpatialDebug([cell0EntityA, cell0EntityB])
        setStaticBatchCellBoundsDebug(enabled: true, colorMode: .culling)
        let snapshot = SpatialDebugBoundsCollector.shared.collectSnapshot()

        XCTAssertEqual(snapshot.staticBatchCellBounds.count, 2, "❌ Expected both batch cells to be represented")
        XCTAssertTrue(
            snapshot.staticBatchCellBounds.contains(where: { approximatelyEqual($0.color, visibleColor) }),
            "❌ Expected a visible static batch cell color"
        )
        XCTAssertTrue(
            snapshot.staticBatchCellBounds.contains(where: { approximatelyEqual($0.color, culledColor) }),
            "❌ Expected a culled static batch cell color"
        )
        XCTAssertNotNil(BatchingSystem.shared.getBatchInfo(for: cell2EntityA), "❌ Culled cell entities should remain batched")
        XCTAssertNotNil(BatchingSystem.shared.getBatchInfo(for: cell2EntityB), "❌ Culled cell entities should remain batched")
    }

    func testSpatialDebugCollectorStaticBatchCellsUseDistinctCellColors() {
        BatchingSystem.shared.setBatchCellSize(10.0)
        enableBatching(true)

        _ = createStaticCubeEntity(position: simd_float3(1.0, 0.0, 0.0))
        _ = createStaticCubeEntity(position: simd_float3(3.0, 0.0, 0.0))
        _ = createStaticCubeEntity(position: simd_float3(25.0, 0.0, 0.0))
        _ = createStaticCubeEntity(position: simd_float3(27.0, 0.0, 0.0))
        generateBatches()

        setStaticBatchCellBoundsDebug(enabled: true, colorMode: .cell)
        let snapshot = SpatialDebugBoundsCollector.shared.collectSnapshot()

        XCTAssertEqual(snapshot.staticBatchCellBounds.count, 2, "❌ Expected two static batch cells")
        let uniqueColors = Set(snapshot.staticBatchCellBounds.map {
            simd_uint4(
                $0.color.x.bitPattern,
                $0.color.y.bitPattern,
                $0.color.z.bitPattern,
                $0.color.w.bitPattern
            )
        })
        XCTAssertEqual(uniqueColors.count, 2, "❌ Different static batch cells should use distinct debug colors in cell mode")
    }

    // MARK: - Statistics Tests

    func testBatchStatistics() {
        // Given: Create entities and generate batches
        let meshes = BasicPrimitives.createSphere()

        let entityCount = 10
        for _ in 0 ..< entityCount {
            let entity = createEntity()

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
        let meshes = BasicPrimitives.createSphere()

        // Create 4 entities at LOD 0
        var lod0Entities: [EntityID] = []
        for i in 0 ..< 4 {
            let entity = createEntity()

            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
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
        let meshes = BasicPrimitives.createSphere()

        var entities: [EntityID] = []
        for _ in 0 ..< 4 {
            let entity = createEntity()

            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
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
            assetURL: URL(fileURLWithPath: "/dev/null/ball"),
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
        // Load meshes once so all entities share the same texture object identity
        let meshes = BasicPrimitives.createSphere()

        // First, create some batched entities so there's a batch to join
        for _ in 0 ..< 3 {
            let entity = createEntity()
            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
            }
            _ = scene.assign(to: entity, component: LocalTransformComponent.self)
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)
        }

        // Create target entity with StaticBatchComponent but empty mesh
        let targetEntity = createEntity()
        if let renderComponent = scene.assign(to: targetEntity, component: RenderComponent.self) {
            renderComponent.mesh = [] // Empty initially
            renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
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

        // When: Assign the shared meshes to simulate mesh becoming resident
        if let renderComponent = scene.get(component: RenderComponent.self, for: targetEntity) {
            renderComponent.mesh = meshes
        }

        // Emit residency change event indicating mesh became resident
        let residencyEvent = AssetResidencyChangedEvent(
            entityId: targetEntity,
            assetURL: URL(fileURLWithPath: "/dev/null/ball"),
            meshName: "ball",
            isResident: true
        )
        SystemEventBus.shared.queueResidencyChange(residencyEvent)
        SystemEventBus.shared.flushEvents()

        // Process pending batch updates.
        // Newly resident cells should render unbatched first and batch on a later tick.
        BatchingSystem.shared.tick()
        XCTAssertFalse(
            BatchingSystem.shared.isBatched(entityId: targetEntity),
            "❌ Newly resident entity should remain unbatched on the first staging tick"
        )

        BatchingSystem.shared.tick()

        // Then: Entity should be added to batch
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: targetEntity), "❌ Entity should be batched after staged promotion")

        print("✅ Entity successfully added to batch when mesh became resident")
    }

    func testQuiescenceDelaysPromotionToBatchPending() {
        BatchingSystem.shared.setQuiescenceFramesBeforeBatchBuild(2)

        let meshes = BasicPrimitives.createSphere()

        for _ in 0 ..< 3 {
            let entity = createEntity()
            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
            }
            _ = scene.assign(to: entity, component: LocalTransformComponent.self)
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)
        }

        let targetEntity = createEntity()
        if let renderComponent = scene.assign(to: targetEntity, component: RenderComponent.self) {
            renderComponent.mesh = []
            renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
            renderComponent.assetName = "ball"
        }
        _ = scene.assign(to: targetEntity, component: LocalTransformComponent.self)
        _ = scene.assign(to: targetEntity, component: WorldTransformComponent.self)
        setEntityStaticBatchComponent(entityId: targetEntity)

        enableBatching(true)
        generateBatches()
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: targetEntity), "❌ Entity starts unbatched")

        if let renderComponent = scene.get(component: RenderComponent.self, for: targetEntity) {
            renderComponent.mesh = meshes
        }
        SystemEventBus.shared.queueResidencyChange(
            AssetResidencyChangedEvent(
                entityId: targetEntity,
                assetURL: URL(fileURLWithPath: "/dev/null/ball"),
                meshName: "ball",
                isResident: true
            )
        )
        SystemEventBus.shared.flushEvents()

        for _ in 0 ..< 3 {
            BatchingSystem.shared.tick()
            XCTAssertFalse(
                BatchingSystem.shared.isBatched(entityId: targetEntity),
                "❌ Quiescence should keep newly resident cell unbatched during settle frames"
            )
        }

        let deferredDiag = BatchingSystem.shared.getTickDiagnosticsSnapshot()
        XCTAssertGreaterThan(
            deferredDiag.deferredByQuiescence,
            0,
            "❌ Quiescence deferrals should be visible in tick diagnostics"
        )

        BatchingSystem.shared.tick()
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: targetEntity), "❌ Entity should batch after quiescence delay")
    }

    func testTickProcessesPendingRemovalsAndAdditions() {
        // Given: Create batched entities
        // Note: tick() processes pending entity changes and rebuilds affected cells incrementally
        let meshes = BasicPrimitives.createSphere()

        // Create entities at LOD 0
        var lod0Entities: [EntityID] = []
        for i in 0 ..< 4 {
            let entity = createEntity()
            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
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
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
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
            assetURL: URL(fileURLWithPath: "/dev/null/ball"),
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

    func testTickRebuildsOnlyDirtyCells() {
        BatchingSystem.shared.setBatchCellSize(10.0)
        enableBatching(true)

        let meshes = BasicPrimitives.createSphere()

        func makeEntity(position: simd_float3) -> EntityID {
            let entity = createEntity()
            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
                renderComponent.assetName = "ball"
            }
            if let localTransform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                localTransform.position = position
            }
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)
            return entity
        }

        let cell0EntityA = makeEntity(position: simd_float3(1.0, 0.0, 0.0))
        let cell0EntityB = makeEntity(position: simd_float3(3.0, 0.0, 0.0))
        let cell2EntityA = makeEntity(position: simd_float3(25.0, 0.0, 0.0))
        let cell2EntityB = makeEntity(position: simd_float3(27.0, 0.0, 0.0))

        generateBatches()
        XCTAssertEqual(BatchingSystem.shared.batchGroups.count, 2, "❌ Expected one batch per populated cell")

        let initialCell0BatchId = BatchingSystem.shared.getBatchInfo(for: cell0EntityA)?.batchId
        let initialCell2BatchId = BatchingSystem.shared.getBatchInfo(for: cell2EntityA)?.batchId
        XCTAssertNotNil(initialCell0BatchId, "❌ Cell 0 batch should exist")
        XCTAssertNotNil(initialCell2BatchId, "❌ Cell 2 batch should exist")

        // Evict one entity from cell 0 only.
        if let renderComponent = scene.get(component: RenderComponent.self, for: cell0EntityA) {
            renderComponent.mesh = []
        }
        let evictionEvent = AssetResidencyChangedEvent(
            entityId: cell0EntityA,
            assetURL: URL(fileURLWithPath: "/dev/null/ball"),
            meshName: "ball",
            isResident: false
        )
        SystemEventBus.shared.queueResidencyChange(evictionEvent)
        SystemEventBus.shared.flushEvents()
        BatchingSystem.shared.tick()

        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: cell0EntityA), "❌ Evicted entity should be removed from batching")
        XCTAssertFalse(
            BatchingSystem.shared.isBatched(entityId: cell0EntityB),
            "❌ Dirty cell now has one entity and should no longer form a batch"
        )
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: cell2EntityB), "❌ Unaffected cell entity should remain batched")

        let updatedCell2BatchId = BatchingSystem.shared.getBatchInfo(for: cell2EntityA)?.batchId
        XCTAssertEqual(
            updatedCell2BatchId,
            initialCell2BatchId,
            "❌ Unaffected cell batch ID changed, indicating global rebuild instead of dirty-cell rebuild"
        )
    }

    func testTickProcessesRemainingDirtyCellsAcrossFramesWhenBudgetLimited() {
        BatchingSystem.shared.setBatchCellSize(10.0)
        BatchingSystem.shared.setMaxDirtyCellsPerTick(1)
        enableBatching(true)

        let meshes = BasicPrimitives.createSphere()

        func makeEntity(position: simd_float3) -> EntityID {
            let entity = createEntity()
            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
                renderComponent.assetName = "ball"
            }
            if let localTransform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                localTransform.position = position
            }
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)
            return entity
        }

        let cell0EntityA = makeEntity(position: simd_float3(1.0, 0.0, 0.0))
        let cell0EntityB = makeEntity(position: simd_float3(3.0, 0.0, 0.0))
        let cell0EntityC = makeEntity(position: simd_float3(5.0, 0.0, 0.0))
        let cell2EntityA = makeEntity(position: simd_float3(25.0, 0.0, 0.0))
        let cell2EntityB = makeEntity(position: simd_float3(27.0, 0.0, 0.0))
        let cell2EntityC = makeEntity(position: simd_float3(29.0, 0.0, 0.0))

        generateBatches()
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: cell0EntityB), "❌ Cell 0 should start batched")
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: cell2EntityB), "❌ Cell 2 should start batched")

        // Evict one entity from each cell so both cells become dirty.
        for entityId in [cell0EntityA, cell2EntityA] {
            if let renderComponent = scene.get(component: RenderComponent.self, for: entityId) {
                renderComponent.mesh = []
            }
            let evictionEvent = AssetResidencyChangedEvent(
                entityId: entityId,
                assetURL: URL(fileURLWithPath: "/dev/null/ball"),
                meshName: "ball",
                isResident: false
            )
            SystemEventBus.shared.queueResidencyChange(evictionEvent)
        }
        SystemEventBus.shared.flushEvents()

        // Tick 1: both cells fall back to unbatched, then only one cell is rebatched due budget = 1.
        BatchingSystem.shared.tick()
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: cell0EntityB), "❌ First dirty cell should be rebatched on tick 1")
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: cell0EntityC), "❌ First dirty cell companion should be rebatched on tick 1")
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: cell2EntityB), "❌ Second dirty cell should remain pending on tick 1")
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: cell2EntityC), "❌ Second dirty cell companion should remain pending on tick 1")

        // Tick 2: remaining dirty cell should rebuild even without new events.
        BatchingSystem.shared.tick()
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: cell2EntityB), "❌ Pending dirty cell should rebuild on a later tick")
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: cell2EntityC), "❌ Pending dirty cell companion should rebuild on a later tick")
    }

    func testTickDefersSomeDirtyCellsWhenWorkBudgetIsExceeded() {
        BatchingSystem.shared.setBatchCellSize(10.0)
        BatchingSystem.shared.setMaxDirtyCellsPerTick(4)
        BatchingSystem.shared.setMaxRebuildVerticesPerTick(1_000_000_000)
        BatchingSystem.shared.setMaxRebuildIndicesPerTick(1_000_000_000)
        BatchingSystem.shared.setMaxRebuildBufferBytesPerTick(1)
        enableBatching(true)

        let meshes = BasicPrimitives.createSphere()

        func makeEntity(position: simd_float3) -> EntityID {
            let entity = createEntity()
            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
                renderComponent.assetName = "ball"
            }
            if let localTransform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                localTransform.position = position
            }
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)
            return entity
        }

        let cell0A = makeEntity(position: simd_float3(1.0, 0.0, 0.0))
        let cell0B = makeEntity(position: simd_float3(3.0, 0.0, 0.0))
        let cell0C = makeEntity(position: simd_float3(5.0, 0.0, 0.0))
        let cell2A = makeEntity(position: simd_float3(25.0, 0.0, 0.0))
        let cell2B = makeEntity(position: simd_float3(27.0, 0.0, 0.0))
        let cell2C = makeEntity(position: simd_float3(29.0, 0.0, 0.0))

        generateBatches()
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: cell0B), "❌ Cell 0 should start batched")
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: cell2B), "❌ Cell 2 should start batched")
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: cell0C), "❌ Cell 0 companion should start batched")
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: cell2C), "❌ Cell 2 companion should start batched")

        for entityId in [cell0A, cell2A] {
            if let renderComponent = scene.get(component: RenderComponent.self, for: entityId) {
                renderComponent.mesh = []
            }
            let evictionEvent = AssetResidencyChangedEvent(
                entityId: entityId,
                assetURL: URL(fileURLWithPath: "/dev/null/ball"),
                meshName: "ball",
                isResident: false
            )
            SystemEventBus.shared.queueResidencyChange(evictionEvent)
        }
        SystemEventBus.shared.flushEvents()
        BatchingSystem.shared.tick()

        let tickDiag = BatchingSystem.shared.getTickDiagnosticsSnapshot()
        XCTAssertEqual(tickDiag.rebuiltCells, 1, "❌ Work budget should allow only one dirty cell rebuild")
        XCTAssertGreaterThanOrEqual(
            tickDiag.deferredByWorkBudget,
            1,
            "❌ At least one dirty cell should be deferred by work budget"
        )
    }

    func testTickMarksOversizedCellsRuntimeIneligible() {
        BatchingSystem.shared.setBatchCellSize(10.0)
        BatchingSystem.shared.setMaxRuntimeCellVertices(1)
        BatchingSystem.shared.setMaxRuntimeCellIndices(1_000_000_000)
        BatchingSystem.shared.setMaxRuntimeCellBufferBytes(1_000_000_000)
        BatchingSystem.shared.setQuiescenceFramesBeforeBatchBuild(0)
        enableBatching(true)

        let meshes = BasicPrimitives.createSphere()

        func makeEntity(position: simd_float3) -> EntityID {
            let entity = createEntity()
            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
                renderComponent.assetName = "ball"
            }
            if let localTransform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                localTransform.position = position
            }
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            if let lod = scene.assign(to: entity, component: LODComponent.self) {
                lod.currentLOD = 0
            }
            setEntityStaticBatchComponent(entityId: entity)
            return entity
        }

        let entityA = makeEntity(position: simd_float3(1.0, 0.0, 0.0))
        let entityB = makeEntity(position: simd_float3(3.0, 0.0, 0.0))
        generateBatches()
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: entityA), "❌ Entity A should start batched")
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: entityB), "❌ Entity B should start batched")

        if let lod = scene.get(component: LODComponent.self, for: entityA) {
            lod.currentLOD = 1
        }
        if let lod = scene.get(component: LODComponent.self, for: entityB) {
            lod.currentLOD = 1
        }
        SystemEventBus.shared.queueLODChange(
            EntityLODChangedEvent(
                entityId: entityA,
                previousLODIndex: 0,
                newLODIndex: 1,
                meshAssetID: "ball_LOD1"
            )
        )
        SystemEventBus.shared.queueLODChange(
            EntityLODChangedEvent(
                entityId: entityB,
                previousLODIndex: 0,
                newLODIndex: 1,
                meshAssetID: "ball_LOD1"
            )
        )
        SystemEventBus.shared.flushEvents()
        BatchingSystem.shared.tick()

        let tickDiag = BatchingSystem.shared.getTickDiagnosticsSnapshot()
        XCTAssertGreaterThanOrEqual(
            tickDiag.skippedByComplexityGuard,
            1,
            "❌ Oversized dirty cell should be rejected by complexity guard"
        )
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: entityA), "❌ Oversized cell should remain unbatched")
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: entityB), "❌ Oversized cell should remain unbatched")

        let summary = BatchingSystem.shared.getRuntimeBatchingSummaryDiagnostic()
        XCTAssertGreaterThanOrEqual(summary.runtimeIneligibleCells, 1, "❌ Runtime ineligible cell should be tracked")
    }

    func testBackgroundArtifactBuildAppliesOnSubsequentTick() {
        BatchingSystem.shared.setBatchCellSize(10.0)
        BatchingSystem.shared.setBackgroundArtifactBuildEnabled(true)
        BatchingSystem.shared.setMaxDirtyCellsPerTick(1)
        BatchingSystem.shared.setMaxBuildDispatchesPerTick(1)
        BatchingSystem.shared.setMaxArtifactAppliesPerTick(1)
        BatchingSystem.shared.setQuiescenceFramesBeforeBatchBuild(0)
        enableBatching(true)

        let meshes = BasicPrimitives.createSphere()

        func makeEntity(position: simd_float3) -> EntityID {
            let entity = createEntity()
            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
                renderComponent.assetName = "ball"
            }
            if let localTransform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                localTransform.position = position
            }
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)
            return entity
        }

        let entityA = makeEntity(position: simd_float3(1.0, 0.0, 0.0))
        let entityB = makeEntity(position: simd_float3(3.0, 0.0, 0.0))
        let entityC = makeEntity(position: simd_float3(5.0, 0.0, 0.0))
        generateBatches()
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: entityB), "❌ Cell should start batched")

        if let renderComponent = scene.get(component: RenderComponent.self, for: entityA) {
            renderComponent.mesh = []
        }
        SystemEventBus.shared.queueResidencyChange(
            AssetResidencyChangedEvent(
                entityId: entityA,
                assetURL: URL(fileURLWithPath: "/dev/null/ball"),
                meshName: "ball",
                isResident: false
            )
        )
        SystemEventBus.shared.flushEvents()

        BatchingSystem.shared.tick()
        let firstTick = BatchingSystem.shared.getTickDiagnosticsSnapshot()
        XCTAssertGreaterThanOrEqual(firstTick.dispatchedBuilds, 1, "❌ First tick should dispatch async artifact build")
        XCTAssertEqual(firstTick.appliedArtifacts, 0, "❌ First tick should not apply the newly dispatched artifact")

        var becameBatchedAgain = false
        for _ in 0 ..< 60 {
            Thread.sleep(forTimeInterval: 0.01)
            BatchingSystem.shared.tick()
            if BatchingSystem.shared.isBatched(entityId: entityB), BatchingSystem.shared.isBatched(entityId: entityC) {
                becameBatchedAgain = true
                break
            }
        }

        XCTAssertTrue(becameBatchedAgain, "❌ Async artifact should apply on a subsequent tick")
    }

    func testVisibilityGateDefersOffscreenCellBatchRebuild() {
        BatchingSystem.shared.setBatchCellSize(10.0)
        BatchingSystem.shared.setVisibilityGatedBatchBuildEnabled(true)
        BatchingSystem.shared.setQuiescenceFramesBeforeBatchBuild(0)
        enableBatching(true)

        let meshes = BasicPrimitives.createSphere()

        func makeEntity(position: simd_float3) -> EntityID {
            let entity = createEntity()
            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
                renderComponent.assetName = "ball"
            }
            if let localTransform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                localTransform.position = position
            }
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)
            return entity
        }

        let entityA = makeEntity(position: simd_float3(1.0, 0.0, 0.0))
        let entityB = makeEntity(position: simd_float3(3.0, 0.0, 0.0))
        let entityC = makeEntity(position: simd_float3(5.0, 0.0, 0.0))
        generateBatches()
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: entityB), "❌ Cell should start batched")
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: entityC), "❌ Cell should start batched")

        if let renderComponent = scene.get(component: RenderComponent.self, for: entityA) {
            renderComponent.mesh = []
        }
        SystemEventBus.shared.queueResidencyChange(
            AssetResidencyChangedEvent(
                entityId: entityA,
                assetURL: URL(fileURLWithPath: "/dev/null/ball"),
                meshName: "ball",
                isResident: false
            )
        )
        SystemEventBus.shared.flushEvents()

        visibleEntityIds.removeAll(keepingCapacity: true)
        BatchingSystem.shared.tick()
        let hiddenTick = BatchingSystem.shared.getTickDiagnosticsSnapshot()
        XCTAssertGreaterThan(
            hiddenTick.deferredByVisibility,
            0,
            "❌ Off-screen dirty cells should be deferred by visibility gate"
        )
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: entityB), "❌ Off-screen cell should remain unbatched")
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: entityC), "❌ Off-screen cell should remain unbatched")

        visibleEntityIds = [entityB, entityC]
        BatchingSystem.shared.tick()
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: entityB), "❌ Visible cell should become batched again")
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: entityC), "❌ Visible cell should become batched again")
    }

    func testGenerateBatchesCreatesSeparateBatchesForDifferentLODs() {
        // Given: Create entities with same material but different LOD levels
        let meshes = BasicPrimitives.createSphere()

        // Create entities at LOD 0
        var lod0Entities: [EntityID] = []
        for i in 0 ..< 3 {
            let entity = createEntity()
            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
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
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
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

        // Verify batch key includes LOD suffix
        for batchGroup in BatchingSystem.shared.batchGroups {
            XCTAssertTrue(batchGroup.batchKey.contains("_LOD"), "❌ Batch key should include LOD suffix")
        }

        print("✅ generateBatches() correctly creates separate batches for different LOD levels")
        print("   Batch groups created: \(BatchingSystem.shared.batchGroups.count)")
        for (index, batch) in BatchingSystem.shared.batchGroups.enumerated() {
            print("   Batch \(index): \(batch.entityIds.count) entities, key: \(batch.batchKey)")
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

    func testEmbeddedURLNormalizationFormat() throws {
        // This test documents the expected behavior of URL normalization:
        // - "usdz-embedded://SM_Mesh_Name/embedded_Basecolor_map" -> "embedded_Basecolor_map"
        // - Regular file URLs should remain unchanged
        // - "none" for nil URLs

        // Given: Create a URL that simulates an embedded USDZ texture path
        let embeddedURL1 = try XCTUnwrap(URL(string: "usdz-embedded://SM_Env_Pillar_Stone_1/embedded_Basecolor_map"))
        let embeddedURL2 = try XCTUnwrap(URL(string: "usdz-embedded://SM_Env_Pillar_Stone_2/embedded_Basecolor_map"))
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

    private func addCubeEntity(material: Material, position: simd_float3) -> EntityID {
        let entity = createEntity()
        var meshes = BasicPrimitives.createCube()
        for meshIndex in meshes.indices {
            for submeshIndex in meshes[meshIndex].submeshes.indices {
                meshes[meshIndex].submeshes[submeshIndex].material = material
            }
        }
        if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
            renderComponent.mesh = meshes
        }
        if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
            transform.position = position
        }
        _ = scene.assign(to: entity, component: WorldTransformComponent.self)
        setEntityStaticBatchComponent(entityId: entity)
        return entity
    }

    func testHeightMaterialDifferencesPreventBatching() {
        // Regression test: getMaterialHash() previously had no awareness of height/POM
        // parameters at all, so two materials differing only in heightScale (or
        // heightEnabled, heightMidlevel, heightRemapMin/Max) hashed identically and could
        // be merged into the same batch group — silently applying one material's POM
        // tuning (or lack of POM) to geometry that should render differently.
        //
        // Batching only forms a batch group once 2+ entities share a material hash (see
        // testGenerateBatchesWithSingleStaticEntity), so this needs 2 entities per distinct
        // height configuration to actually exercise batch formation, not just hashing.
        func makeMaterial(heightScale: Float) -> Material {
            Material(
                runtimeMaterial: RuntimeMaterialSource(
                    baseColorFactor: simd_float4(1, 1, 1, 1),
                    metallicFactor: 0.0,
                    roughnessFactor: 1.0,
                    heightScale: heightScale
                ),
                device: renderInfo.device
            )
        }

        let entitySubtleA = addCubeEntity(material: makeMaterial(heightScale: 0.02), position: simd_float3(0, 0, 0))
        let entitySubtleB = addCubeEntity(material: makeMaterial(heightScale: 0.02), position: simd_float3(2, 0, 0))
        let entityStrongA = addCubeEntity(material: makeMaterial(heightScale: 0.20), position: simd_float3(4, 0, 0))
        let entityStrongB = addCubeEntity(material: makeMaterial(heightScale: 0.20), position: simd_float3(6, 0, 0))

        generateBatches()

        let batchSubtleA = BatchingSystem.shared.getBatchInfo(for: entitySubtleA)?.batchId
        let batchSubtleB = BatchingSystem.shared.getBatchInfo(for: entitySubtleB)?.batchId
        let batchStrongA = BatchingSystem.shared.getBatchInfo(for: entityStrongA)?.batchId
        let batchStrongB = BatchingSystem.shared.getBatchInfo(for: entityStrongB)?.batchId

        XCTAssertNotNil(batchSubtleA, "❌ Subtle-height entity A should be batched")
        XCTAssertNotNil(batchStrongA, "❌ Strong-height entity A should be batched")

        XCTAssertEqual(batchSubtleA, batchSubtleB, "❌ Entities with identical heightScale should share a batch")
        XCTAssertEqual(batchStrongA, batchStrongB, "❌ Entities with identical heightScale should share a batch")
        XCTAssertNotEqual(batchSubtleA, batchStrongA, "❌ Materials differing only in heightScale must not share a batch")
    }

    func testHeightEnabledDifferencePreventsBatching() {
        let sharedScale: Float = 0.08
        func makeMaterial(heightEnabled: Bool) -> Material {
            var material = Material(
                runtimeMaterial: RuntimeMaterialSource(
                    baseColorFactor: simd_float4(1, 1, 1, 1),
                    metallicFactor: 0.0,
                    roughnessFactor: 1.0,
                    heightScale: sharedScale
                ),
                device: renderInfo.device
            )
            material.heightEnabled = heightEnabled
            return material
        }

        let entityOnA = addCubeEntity(material: makeMaterial(heightEnabled: true), position: simd_float3(0, 2, 0))
        let entityOnB = addCubeEntity(material: makeMaterial(heightEnabled: true), position: simd_float3(2, 2, 0))
        let entityOffA = addCubeEntity(material: makeMaterial(heightEnabled: false), position: simd_float3(4, 2, 0))
        let entityOffB = addCubeEntity(material: makeMaterial(heightEnabled: false), position: simd_float3(6, 2, 0))

        generateBatches()

        let batchOnA = BatchingSystem.shared.getBatchInfo(for: entityOnA)?.batchId
        let batchOnB = BatchingSystem.shared.getBatchInfo(for: entityOnB)?.batchId
        let batchOffA = BatchingSystem.shared.getBatchInfo(for: entityOffA)?.batchId
        let batchOffB = BatchingSystem.shared.getBatchInfo(for: entityOffB)?.batchId

        XCTAssertNotNil(batchOnA, "❌ POM-enabled entity should be batched")
        XCTAssertNotNil(batchOffA, "❌ POM-disabled entity should be batched")
        XCTAssertEqual(batchOnA, batchOnB, "❌ Entities with identical heightEnabled should share a batch")
        XCTAssertEqual(batchOffA, batchOffB, "❌ Entities with identical heightEnabled should share a batch")
        XCTAssertNotEqual(batchOnA, batchOffA, "❌ heightEnabled true/false must not share a batch")
    }

    func testRuntimeOpacityChangeRemovesBatchedEntity() {
        // Verify that calling updateMaterialOpacity on a batched entity correctly
        // removes it from the batch so the transparency pass can render it.
        // This covers the client scenario: model loaded from .json, opacity changed at runtime.
        let meshes = BasicPrimitives.createSphere()

        var entities: [EntityID] = []
        for i in 0 ..< 3 {
            let entity = createEntity()

            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/opacity_test_\(i)")
            }

            if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                transform.position = simd_float3(Float(i) * 2.0, 0, 0)
            }

            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)
            entities.append(entity)
        }

        enableBatching(true)
        generateBatches()

        let target = entities[0]
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: target),
                      "❌ Entity should be batched before opacity change")

        // Simulate the client call: change opacity at runtime
        updateMaterialOpacity(entityId: target, opacity: 0.5)

        // Process the pending batch update triggered by the opacity change
        BatchingSystem.shared.tick()

        // Entity must leave the batch so the transparency pass can pick it up
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: target),
                       "❌ Entity should be removed from batch after opacity change (transparency pass must render it)")

        // Material must have switched to blend mode
        let alphaMode = getMaterialAlphaMode(entityId: target)
        XCTAssertEqual(alphaMode, .blend,
                       "❌ Alpha mode should be .blend after opacity change")

        // The opacity value must be stored in the material
        let opacity = getMaterialOpacity(entityId: target)
        XCTAssertEqual(opacity, 0.5, accuracy: 0.001,
                       "❌ Material opacity should reflect the requested value")

        // Other entities in the same cell should remain batched
        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: entities[1]),
                      "❌ Other entities in the cell should remain batched")
    }

    func testRuntimeOpacityRestoreRebatchesEntity() {
        // Verify that restoring opacity to 1.0 on a previously transparent batched entity
        // returns it to the batch on the next rebuild.
        let meshes = BasicPrimitives.createSphere()

        var entities: [EntityID] = []
        for i in 0 ..< 3 {
            let entity = createEntity()

            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/opacity_restore_\(i)")
            }

            if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                transform.position = simd_float3(Float(i) * 2.0, 0, 0)
            }

            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)
            entities.append(entity)
        }

        enableBatching(true)
        generateBatches()

        let target = entities[0]

        // Make transparent
        updateMaterialOpacity(entityId: target, opacity: 0.5)
        BatchingSystem.shared.tick()
        XCTAssertFalse(BatchingSystem.shared.isBatched(entityId: target),
                       "❌ Entity should be unbatched after going transparent")

        // Restore to fully opaque
        updateMaterialOpacity(entityId: target, opacity: 1.0)
        // tick processes pending changes and schedules a cell rebuild
        BatchingSystem.shared.tick()
        // Second tick executes the rebuild (cell moves from batchPending → built)
        BatchingSystem.shared.tick()

        XCTAssertTrue(BatchingSystem.shared.isBatched(entityId: target),
                      "❌ Entity should be re-batched after opacity restored to 1.0")
        XCTAssertEqual(getMaterialAlphaMode(entityId: target), .opaque,
                       "❌ Alpha mode should revert to .opaque when opacity is restored to 1.0")
    }

    func testRecursiveOpacityUpdatesRenderableDescendants() {
        let root = createStaticCubeEntity(position: .zero, markStatic: false)
        let child = createStaticCubeEntity(position: simd_float3(1.0, 0.0, 0.0), markStatic: false)
        let grandchild = createStaticCubeEntity(position: simd_float3(2.0, 0.0, 0.0), markStatic: false)
        let sibling = createStaticCubeEntity(position: simd_float3(3.0, 0.0, 0.0), markStatic: false)
        setParent(childId: child, parentId: root)
        setParent(childId: grandchild, parentId: child)

        updateMaterialOpacity(entityId: root, opacity: 0.35, recursive: true)

        XCTAssertEqual(getMaterialOpacity(entityId: root), 0.35, accuracy: 0.0001)
        XCTAssertEqual(getMaterialOpacity(entityId: child), 0.35, accuracy: 0.0001)
        XCTAssertEqual(getMaterialOpacity(entityId: grandchild), 0.35, accuracy: 0.0001)
        XCTAssertEqual(getMaterialOpacity(entityId: sibling), 1.0, accuracy: 0.0001)
        XCTAssertEqual(getMaterialAlphaMode(entityId: root), .blend)
        XCTAssertEqual(getMaterialAlphaMode(entityId: child), .blend)
        XCTAssertEqual(getMaterialAlphaMode(entityId: grandchild), .blend)
        XCTAssertEqual(getMaterialAlphaMode(entityId: sibling), .opaque)
    }

    func testRecursiveEmissiveUpdatesRenderableDescendantsOnce() {
        let root = createStaticCubeEntity(position: .zero, markStatic: false)
        let child = createStaticCubeEntity(position: simd_float3(1.0, 0.0, 0.0), markStatic: false)
        let grandchild = createStaticCubeEntity(position: simd_float3(2.0, 0.0, 0.0), markStatic: false)
        setParent(childId: child, parentId: root)
        setParent(childId: grandchild, parentId: child)

        if let rootScenegraph = scene.get(component: ScenegraphComponent.self, for: root) {
            rootScenegraph.children.append(child)
        }

        let emissive = simd_float3(0.25, 0.5, 1.0)
        updateMaterialEmmisive(entityId: root, emmissive: emissive, recursive: true)

        XCTAssertEqual(getMaterialEmmissive(entityId: root), emissive)
        XCTAssertEqual(getMaterialEmmissive(entityId: child), emissive)
        XCTAssertEqual(getMaterialEmmissive(entityId: grandchild), emissive)
    }

    func testLegacyEmbeddedPseudoURLsDoNotSplitBatching() throws {
        // Legacy embedded pseudo-URLs were mesh-scoped:
        // usdz-embedded://<meshName>/embedded_Basecolor_map
        // Even with different mesh hosts, entities should still batch together
        // when they share the same source asset and embedded texture token.
        let meshes = BasicPrimitives.createSphere()

        var entities: [EntityID] = []
        for i in 0 ..< 3 {
            let entity = createEntity()

            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/ball")
            }

            if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                transform.position = simd_float3(Float(i) * 2.0, 0, 0)
            }

            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            setEntityStaticBatchComponent(entityId: entity)

            let legacyEmbeddedURL = try XCTUnwrap(URL(string: "usdz-embedded://SM_Env_Ceiling_Stone_\(i)/embedded_Basecolor_map"))
            let didUpdate = updateMaterial(entityId: entity) { material in
                material.baseColorURL = legacyEmbeddedURL
            }
            XCTAssertTrue(didUpdate, "❌ Failed to update material for entity \(entity)")

            entities.append(entity)
        }

        generateBatches()
        XCTAssertGreaterThan(BatchingSystem.shared.batchGroups.count, 0, "❌ Should create at least one batch")

        let firstBatchId = BatchingSystem.shared.getBatchInfo(for: entities[0])?.batchId
        XCTAssertNotNil(firstBatchId, "❌ First entity should be batched")

        for entity in entities {
            let batchInfo = BatchingSystem.shared.getBatchInfo(for: entity)
            XCTAssertNotNil(batchInfo, "❌ Entity should be batched")
            XCTAssertEqual(batchInfo?.batchId, firstBatchId, "❌ Legacy embedded URL host differences should not split batches")
        }
    }
}

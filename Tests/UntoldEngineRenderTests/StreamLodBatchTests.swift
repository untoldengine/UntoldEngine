//
//  StreamLodBatchTests.swift
//  UntoldEngine
//
//  Tests for the Streaming-LOD-Batching integration architecture.
//  Verifies event bus, LOD fallback logic, batch key generation, and system coordination.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

// MARK: - Event Bus Tests

final class StreamLodBatchEventBusTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Clear the event bus before each test
        SystemEventBus.shared.reset()
    }

    override func tearDown() {
        SystemEventBus.shared.reset()
        super.tearDown()
    }

    func testEventBusDeliversResidencyEvents() {
        // Given
        var receivedEvents: [AssetResidencyChangedEvent] = []
        let testURL = URL(fileURLWithPath: "/test/mesh.usdz")

        SystemEventBus.shared.subscribeToResidencyChanges { event in
            receivedEvents.append(event)
        }

        // When
        let event = AssetResidencyChangedEvent(
            entityId: 1,
            assetURL: testURL,
            meshName: "test_mesh_LOD0",
            isResident: true
        )
        SystemEventBus.shared.queueResidencyChange(event)
        SystemEventBus.shared.flushEvents()

        // Then
        XCTAssertEqual(receivedEvents.count, 1)
        XCTAssertEqual(receivedEvents.first?.meshName, "test_mesh_LOD0")
        XCTAssertTrue(receivedEvents.first?.isResident ?? false)
    }

    func testEventBusDeliversLODChangedEvents() {
        // Given
        var receivedEvents: [EntityLODChangedEvent] = []

        SystemEventBus.shared.subscribeToLODChanges { event in
            receivedEvents.append(event)
        }

        // When
        let event = EntityLODChangedEvent(
            entityId: 42,
            previousLODIndex: 0,
            newLODIndex: 1,
            meshAssetID: "entity_42_LOD1"
        )
        SystemEventBus.shared.queueLODChange(event)
        SystemEventBus.shared.flushEvents()

        // Then
        XCTAssertEqual(receivedEvents.count, 1)
        XCTAssertEqual(receivedEvents.first?.entityId, 42)
        XCTAssertEqual(receivedEvents.first?.previousLODIndex, 0)
        XCTAssertEqual(receivedEvents.first?.newLODIndex, 1)
    }

    func testEventBusQueuesMultipleEvents() {
        // Given
        var eventCount = 0
        let testURL = URL(fileURLWithPath: "/test/mesh.usdz")

        SystemEventBus.shared.subscribeToResidencyChanges { _ in
            eventCount += 1
        }

        // When - queue multiple events before flushing
        SystemEventBus.shared.queueResidencyChange(AssetResidencyChangedEvent(entityId: 1, assetURL: testURL, meshName: "mesh1", isResident: true))
        SystemEventBus.shared.queueResidencyChange(AssetResidencyChangedEvent(entityId: 2, assetURL: testURL, meshName: "mesh2", isResident: true))
        SystemEventBus.shared.queueResidencyChange(AssetResidencyChangedEvent(entityId: 3, assetURL: testURL, meshName: "mesh3", isResident: false))

        // Events should be queued, not delivered yet
        XCTAssertEqual(eventCount, 0)

        // When - flush
        SystemEventBus.shared.flushEvents()

        // Then - all events delivered
        XCTAssertEqual(eventCount, 3)
    }

    func testEventBusSupportsMultipleSubscribers() {
        // Given
        var subscriber1Count = 0
        var subscriber2Count = 0
        let testURL = URL(fileURLWithPath: "/test/mesh.usdz")

        SystemEventBus.shared.subscribeToResidencyChanges { _ in
            subscriber1Count += 1
        }
        SystemEventBus.shared.subscribeToResidencyChanges { _ in
            subscriber2Count += 1
        }

        // When
        SystemEventBus.shared.queueResidencyChange(AssetResidencyChangedEvent(entityId: 1, assetURL: testURL, meshName: "test", isResident: true))
        SystemEventBus.shared.flushEvents()

        // Then - both subscribers receive the event
        XCTAssertEqual(subscriber1Count, 1)
        XCTAssertEqual(subscriber2Count, 1)
    }
}

// MARK: - LOD Fallback Tests (with real meshes)

final class StreamLodBatchFallbackTests: BaseRenderSetup {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testIsLODResident_WithMesh_ReturnsTrue() {
        // Given - create a real mesh using BasicPrimitives
        let cubeMesh = BasicPrimitives.createCube()

        let lodComponent = LODComponent()
        lodComponent.lodLevels = [
            LODLevel(mesh: cubeMesh, maxDistance: 50),
        ]

        // Then - mesh array is non-empty, so it's resident
        XCTAssertTrue(lodComponent.isLODResident(0))
    }

    func testIsLODResident_WithEmptyMesh_ReturnsFalse() {
        // Given
        let lodComponent = LODComponent()
        lodComponent.lodLevels = [
            LODLevel(mesh: [], maxDistance: 50),
        ]

        // Then
        XCTAssertFalse(lodComponent.isLODResident(0))
    }

    func testIsLODResident_OutOfBounds_ReturnsFalse() {
        // Given
        let cubeMesh = BasicPrimitives.createCube()
        let lodComponent = LODComponent()
        lodComponent.lodLevels = [
            LODLevel(mesh: cubeMesh, maxDistance: 50),
        ]

        // Then
        XCTAssertFalse(lodComponent.isLODResident(-1))
        XCTAssertFalse(lodComponent.isLODResident(5))
    }

    func testFindFallbackLOD_PrefersCoarser() {
        // Given - LOD0 resident, LOD1 NOT resident, LOD2 resident
        let cubeMesh = BasicPrimitives.createCube()
        let sphereMesh = BasicPrimitives.createSphere()

        let lodComponent = LODComponent()
        lodComponent.lodLevels = [
            LODLevel(mesh: cubeMesh, maxDistance: 50), // LOD0 - resident
            LODLevel(mesh: [], maxDistance: 100), // LOD1 - NOT resident
            LODLevel(mesh: sphereMesh, maxDistance: 200), // LOD2 - resident
        ]

        // When - looking for fallback from LOD1 (desired but not resident)
        let fallback = lodComponent.findFallbackLOD(from: 1)

        // Then - should prefer coarser LOD2 over finer LOD0
        XCTAssertEqual(fallback, 2)
    }

    func testFindFallbackLOD_FallsToFinerWhenNoCoarser() {
        // Given - only LOD0 is resident
        let cubeMesh = BasicPrimitives.createCube()

        let lodComponent = LODComponent()
        lodComponent.lodLevels = [
            LODLevel(mesh: cubeMesh, maxDistance: 50), // LOD0 - resident
            LODLevel(mesh: [], maxDistance: 100), // LOD1 - NOT resident
            LODLevel(mesh: [], maxDistance: 200), // LOD2 - NOT resident
        ]

        // When - looking for fallback from LOD1
        let fallback = lodComponent.findFallbackLOD(from: 1)

        // Then - falls back to LOD0 (only option)
        XCTAssertEqual(fallback, 0)
    }

    func testFindFallbackLOD_ReturnsNilWhenNoneAvailable() {
        // Given - no LODs are resident
        let lodComponent = LODComponent()
        lodComponent.lodLevels = [
            LODLevel(mesh: [], maxDistance: 50),
            LODLevel(mesh: [], maxDistance: 100),
            LODLevel(mesh: [], maxDistance: 200),
        ]

        // When
        let fallback = lodComponent.findFallbackLOD(from: 1)

        // Then
        XCTAssertNil(fallback)
    }

    func testLODComponentTracksDesiredVsCurrent() {
        // Given
        let lodComponent = LODComponent()
        lodComponent.desiredLOD = 0
        lodComponent.currentLOD = 2
        lodComponent.isUsingFallback = true

        // Then
        XCTAssertEqual(lodComponent.desiredLOD, 0)
        XCTAssertEqual(lodComponent.currentLOD, 2)
        XCTAssertTrue(lodComponent.isUsingFallback)
    }
}

// MARK: - Batch Key Tests

final class StreamLodBatchKeyTests: XCTestCase {
    func testEntityBatchInfoIncludesLODIndex() {
        // Given
        let batchId = UUID()
        let batchInfo = EntityBatchInfo(
            batchId: batchId,
            lodIndex: 2,
            materialHash: "material_standard"
        )

        // Then
        XCTAssertEqual(batchInfo.batchId, batchId)
        XCTAssertEqual(batchInfo.lodIndex, 2)
        XCTAssertEqual(batchInfo.materialHash, "material_standard")
    }

    func testDifferentLODsProduceDifferentBatchInfo() {
        // Given - same material but different LODs
        let batchId1 = UUID()
        let batchId2 = UUID()
        let entity1Info = EntityBatchInfo(batchId: batchId1, lodIndex: 0, materialHash: "material_A")
        let entity2Info = EntityBatchInfo(batchId: batchId2, lodIndex: 1, materialHash: "material_A")

        // Then - LOD indices should be different
        XCTAssertNotEqual(entity1Info.lodIndex, entity2Info.lodIndex)
        // Same material hash
        XCTAssertEqual(entity1Info.materialHash, entity2Info.materialHash)
    }
}

// MARK: - Integration Monitor Tests

final class StreamLodBatchMonitorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Reset stats by calling tick after enough time (or just verify recording works)
    }

    func testMonitorTracksStreamingLoads() {
        // Given
        let initialCount = SystemIntegrationMonitor.shared.stats.streamingLoadsThisSecond

        // When
        SystemIntegrationMonitor.shared.recordStreamingLoad()
        SystemIntegrationMonitor.shared.recordStreamingLoad()

        // Then
        XCTAssertEqual(
            SystemIntegrationMonitor.shared.stats.streamingLoadsThisSecond,
            initialCount + 2
        )
    }

    func testMonitorTracksLODSwitches() {
        // Given
        let initialCount = SystemIntegrationMonitor.shared.stats.lodSwitchesThisSecond

        // When
        SystemIntegrationMonitor.shared.recordLODSwitch()

        // Then
        XCTAssertEqual(
            SystemIntegrationMonitor.shared.stats.lodSwitchesThisSecond,
            initialCount + 1
        )
    }

    func testMonitorTracksBatchRebuilds() {
        // Given
        let initialCount = SystemIntegrationMonitor.shared.stats.batchRebuildsThisSecond

        // When
        SystemIntegrationMonitor.shared.recordBatchRebuild()
        SystemIntegrationMonitor.shared.recordBatchRebuild()
        SystemIntegrationMonitor.shared.recordBatchRebuild()

        // Then
        XCTAssertEqual(
            SystemIntegrationMonitor.shared.stats.batchRebuildsThisSecond,
            initialCount + 3
        )
    }

    func testMonitorTracksLODFallbacks() {
        // Given
        let initialCount = SystemIntegrationMonitor.shared.stats.lodFallbacksThisSecond

        // When
        SystemIntegrationMonitor.shared.recordLODFallback()

        // Then
        XCTAssertEqual(
            SystemIntegrationMonitor.shared.stats.lodFallbacksThisSecond,
            initialCount + 1
        )
    }
}

// MARK: - LOD Residency State Tests

final class StreamLodBatchResidencyStateTests: XCTestCase {
    func testLODResidencyStateEnum() {
        // Verify all states exist and are distinct
        let unknown: LODResidencyState = .unknown
        let resident: LODResidencyState = .resident
        let notResident: LODResidencyState = .notResident
        let loading: LODResidencyState = .loading

        // All states should be different
        XCTAssertTrue(unknown != resident)
        XCTAssertTrue(resident != notResident)
        XCTAssertTrue(notResident != loading)
        XCTAssertTrue(loading != unknown)
    }

    func testLODLevelResidencyStateCanBeModified() {
        // Given
        var level = LODLevel(mesh: [], maxDistance: 50)
        XCTAssertEqual(level.residencyState, LODResidencyState.notResident)

        // When
        level.residencyState = .loading

        // Then
        XCTAssertEqual(level.residencyState, LODResidencyState.loading)

        // When
        level.residencyState = .resident

        // Then
        XCTAssertEqual(level.residencyState, LODResidencyState.resident)
    }
}

// MARK: - LOD with Real Mesh Residency Tests

final class StreamLodBatchMeshResidencyTests: BaseRenderSetup {
    func testLODLevelWithMeshIsResident() {
        // Given - LOD level with real mesh
        let cubeMesh = BasicPrimitives.createCube()
        let levelWithMesh = LODLevel(mesh: cubeMesh, maxDistance: 50)

        // Then - should be resident (mesh array non-empty)
        XCTAssertEqual(levelWithMesh.residencyState, LODResidencyState.resident)
    }

    func testLODLevelWithoutMeshIsNotResident() {
        // Given - LOD level without mesh
        let levelWithoutMesh = LODLevel(mesh: [], maxDistance: 100)

        // Then - should not be resident
        XCTAssertEqual(levelWithoutMesh.residencyState, LODResidencyState.notResident)
    }

    func testMultipleLODLevelsWithMixedResidency() {
        // Given - create LOD chain with mixed residency
        let highDetailMesh = BasicPrimitives.createSphere(segments: [32, 16])
        let lowDetailMesh = BasicPrimitives.createSphere(segments: [8, 4])

        let lodComponent = LODComponent()
        lodComponent.lodLevels = [
            LODLevel(mesh: highDetailMesh, maxDistance: 25), // LOD0 - resident
            LODLevel(mesh: [], maxDistance: 50), // LOD1 - not resident (loading)
            LODLevel(mesh: lowDetailMesh, maxDistance: 100), // LOD2 - resident
        ]

        // Then - verify residency states
        XCTAssertTrue(lodComponent.isLODResident(0))
        XCTAssertFalse(lodComponent.isLODResident(1))
        XCTAssertTrue(lodComponent.isLODResident(2))

        // Fallback from LOD1 should go to LOD2 (coarser)
        XCTAssertEqual(lodComponent.findFallbackLOD(from: 1), 2)
    }
}

// MARK: - LOD-Aware Streaming Tests

final class StreamLodBatchLODAwareStreamingTests: BaseRenderSetup {
    override func setUp() {
        super.setUp()
        GeometryStreamingSystem.shared.enabled = false
        GeometryStreamingSystem.shared.reset()
    }

    override func tearDown() {
        GeometryStreamingSystem.shared.enabled = false
        GeometryStreamingSystem.shared.reset()
        super.tearDown()
    }

    func testUnloadClearsAllLODLevelMeshes() {
        // Given: An entity with LODComponent and multiple LOD levels
        let entity = createEntity()
        _ = scene.assign(to: entity, component: LocalTransformComponent.self)
        _ = scene.assign(to: entity, component: WorldTransformComponent.self)

        // Create meshes for LOD levels
        let cubeMesh = BasicPrimitives.createCube()
        let sphereMesh = BasicPrimitives.createSphere()

        if let lodComponent = scene.assign(to: entity, component: LODComponent.self) {
            lodComponent.lodLevels = [
                LODLevel(mesh: cubeMesh, maxDistance: 50, url: URL(fileURLWithPath: "/test/lod0.usdz"), assetName: "lod0"),
                LODLevel(mesh: sphereMesh, maxDistance: 100, url: URL(fileURLWithPath: "/test/lod1.usdz"), assetName: "lod1"),
            ]
        }

        // Verify LOD levels have meshes
        let lodComponent = scene.get(component: LODComponent.self, for: entity)
        XCTAssertTrue(lodComponent?.isLODResident(0) ?? false, "LOD0 should be resident initially")
        XCTAssertTrue(lodComponent?.isLODResident(1) ?? false, "LOD1 should be resident initially")

        // When: Clear all LOD meshes (simulating what unloadMesh does for LOD entities)
        if let lod = scene.get(component: LODComponent.self, for: entity) {
            for i in lod.lodLevels.indices {
                lod.lodLevels[i].mesh = []
                lod.lodLevels[i].residencyState = .notResident
            }
        }

        // Then: All LOD levels should be non-resident
        XCTAssertFalse(lodComponent?.isLODResident(0) ?? true, "LOD0 should not be resident after clear")
        XCTAssertFalse(lodComponent?.isLODResident(1) ?? true, "LOD1 should not be resident after clear")
        XCTAssertEqual(lodComponent?.lodLevels[0].residencyState, .notResident, "LOD0 state should be notResident")
        XCTAssertEqual(lodComponent?.lodLevels[1].residencyState, .notResident, "LOD1 state should be notResident")
    }

    func testLODLevelURLAndAssetNamePreservedAfterMeshClear() {
        // Given: An entity with LOD levels that have URLs and asset names
        let entity = createEntity()
        let testURL0 = URL(fileURLWithPath: "/test/model_LOD0.usdz")
        let testURL1 = URL(fileURLWithPath: "/test/model_LOD1.usdz")

        if let lodComponent = scene.assign(to: entity, component: LODComponent.self) {
            lodComponent.lodLevels = [
                LODLevel(mesh: BasicPrimitives.createCube(), maxDistance: 50, url: testURL0, assetName: "model_LOD0"),
                LODLevel(mesh: BasicPrimitives.createSphere(), maxDistance: 100, url: testURL1, assetName: "model_LOD1"),
            ]
        }

        // When: Clear meshes (simulating streaming unload)
        if let lod = scene.get(component: LODComponent.self, for: entity) {
            for i in lod.lodLevels.indices {
                lod.lodLevels[i].mesh = []
                lod.lodLevels[i].residencyState = .notResident
            }
        }

        // Then: URL and assetName should still be preserved for reload
        let lodComponent = scene.get(component: LODComponent.self, for: entity)
        XCTAssertEqual(lodComponent?.lodLevels[0].url, testURL0, "LOD0 URL should be preserved")
        XCTAssertEqual(lodComponent?.lodLevels[1].url, testURL1, "LOD1 URL should be preserved")
        XCTAssertEqual(lodComponent?.lodLevels[0].assetName, "model_LOD0", "LOD0 assetName should be preserved")
        XCTAssertEqual(lodComponent?.lodLevels[1].assetName, "model_LOD1", "LOD1 assetName should be preserved")
    }

    func testStreamingDetectsLODComponent() {
        // Given: An entity with both StreamingComponent and LODComponent
        let entity = createEntity()
        _ = scene.assign(to: entity, component: LocalTransformComponent.self)
        _ = scene.assign(to: entity, component: WorldTransformComponent.self)
        _ = scene.assign(to: entity, component: StreamingComponent.self)
        _ = scene.assign(to: entity, component: LODComponent.self)

        // Then: Both components should be present
        let hasStreaming = scene.get(component: StreamingComponent.self, for: entity) != nil
        let hasLOD = scene.get(component: LODComponent.self, for: entity) != nil

        XCTAssertTrue(hasStreaming, "Entity should have StreamingComponent")
        XCTAssertTrue(hasLOD, "Entity should have LODComponent")
    }

    func testMultipleEntitiesWithSharedCachedMeshesHaveUniqueUniformBuffers() {
        // This test verifies the fix for a bug where multiple entities sharing cached meshes
        // would also share the same spaceUniform MTLBuffers, causing one entity to overwrite
        // another's transform data during rendering (making entities disappear).
        //
        // The fix uses Mesh.copyWithNewUniformBuffers() when assigning cached meshes to entities.

        // Given: Create a shared mesh (simulating cached mesh from MeshResourceManager)
        let sharedMesh = BasicPrimitives.createCube()

        // Create two entities that will use the same "cached" mesh
        let entity1 = createEntity()
        let entity2 = createEntity()

        _ = scene.assign(to: entity1, component: LocalTransformComponent.self)
        _ = scene.assign(to: entity1, component: WorldTransformComponent.self)
        _ = scene.assign(to: entity2, component: LocalTransformComponent.self)
        _ = scene.assign(to: entity2, component: WorldTransformComponent.self)

        // When: Assign meshes using copyWithNewUniformBuffers (what the streaming system does)
        let entity1Meshes = sharedMesh.map { $0.copyWithNewUniformBuffers() }
        let entity2Meshes = sharedMesh.map { $0.copyWithNewUniformBuffers() }

        if let render1 = scene.assign(to: entity1, component: RenderComponent.self) {
            render1.mesh = entity1Meshes
        }
        if let render2 = scene.assign(to: entity2, component: RenderComponent.self) {
            render2.mesh = entity2Meshes
        }

        // Then: Each entity's mesh should have unique uniform buffers
        let render1 = scene.get(component: RenderComponent.self, for: entity1)
        let render2 = scene.get(component: RenderComponent.self, for: entity2)

        XCTAssertNotNil(render1, "Entity 1 should have RenderComponent")
        XCTAssertNotNil(render2, "Entity 2 should have RenderComponent")
        XCTAssertFalse(render1!.mesh.isEmpty, "Entity 1 should have meshes")
        XCTAssertFalse(render2!.mesh.isEmpty, "Entity 2 should have meshes")

        // Verify uniform buffers are different (not shared)
        for i in 0 ..< min(render1!.mesh.count, render2!.mesh.count) {
            let buffer1 = render1!.mesh[i].spaceUniform
            let buffer2 = render2!.mesh[i].spaceUniform

            // Each buffer slot should be unique between entities
            for j in 0 ..< min(buffer1.count, buffer2.count) {
                if let b1 = buffer1[j], let b2 = buffer2[j] {
                    // Compare buffer pointers - they should be different objects
                    XCTAssertFalse(
                        b1 === b2,
                        "Entity 1 and Entity 2 should have different uniform buffers at mesh[\(i)].spaceUniform[\(j)]"
                    )
                }
            }
        }

        print("✅ Multiple entities with shared cached meshes have unique uniform buffers")
    }
}

// MARK: - Region Streaming Event Tests

final class StreamLodBatchRegionEventTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SystemEventBus.shared.reset()
    }

    override func tearDown() {
        SystemEventBus.shared.reset()
        super.tearDown()
    }

    func testRegionStreamingEventStructure() {
        // Given
        let regionId = UUID()
        let event = RegionStreamingEvent(
            regionId: regionId,
            isLoaded: true,
            entityCount: 5
        )

        // Then
        XCTAssertEqual(event.regionId, regionId)
        XCTAssertTrue(event.isLoaded)
        XCTAssertEqual(event.entityCount, 5)
    }

    func testMonitorTracksRegionLoads() {
        // Given
        let initialCount = SystemIntegrationMonitor.shared.stats.regionLoadsThisSecond

        // When
        SystemIntegrationMonitor.shared.recordRegionLoad()

        // Then
        XCTAssertEqual(
            SystemIntegrationMonitor.shared.stats.regionLoadsThisSecond,
            initialCount + 1
        )
    }

    func testMonitorTracksRegionUnloads() {
        // Given
        let initialCount = SystemIntegrationMonitor.shared.stats.regionUnloadsThisSecond

        // When
        SystemIntegrationMonitor.shared.recordRegionUnload()

        // Then
        XCTAssertEqual(
            SystemIntegrationMonitor.shared.stats.regionUnloadsThisSecond,
            initialCount + 1
        )
    }

    func testMonitorTracksLoadedRegionCount() {
        // When
        SystemIntegrationMonitor.shared.setLoadedRegionCount(3)

        // Then
        XCTAssertEqual(SystemIntegrationMonitor.shared.stats.loadedRegionCount, 3)
    }
}

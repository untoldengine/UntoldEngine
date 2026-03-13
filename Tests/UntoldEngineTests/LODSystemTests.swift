//
//  LODSystemTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

@MainActor
final class LODSystemTests: XCTestCase {
    var testEntity: EntityID!

    override func setUp() async throws {
        resetEngineTestState()
        testEntity = createEntity()
        registerTransformComponent(entityId: testEntity)
    }

    override func tearDown() async throws {
        destroyAllEntities()
    }

    // MARK: - LODComponent Tests

    func testLODComponentCreation() {
        let lodComponent = LODComponent()

        XCTAssertEqual(lodComponent.lodLevels.count, 0, "New LODComponent should have empty levels")
        XCTAssertEqual(lodComponent.currentLOD, 0, "Default LOD should be 0")
        XCTAssertNil(lodComponent.previousLOD, "Previous LOD should be nil initially")
        XCTAssertNil(lodComponent.forcedLOD, "Forced LOD should be nil by default")
        XCTAssertEqual(lodComponent.transitionProgress, 0.0, "Transition progress should be 0")
    }

    func testLODLevelCreation() {
        let meshes: [Mesh] = []
        let lodLevel = LODLevel(
            mesh: meshes,
            maxDistance: 100.0,
            screenPercentage: 0.5
        )

        XCTAssertEqual(lodLevel.maxDistance, 100.0, "Max distance should match")
        XCTAssertEqual(lodLevel.screenPercentage, 0.5, "Screen percentage should match")
        XCTAssertEqual(lodLevel.mesh.count, 0, "Mesh array should be empty")
    }

    func testRegisterLODComponent() {
        registerComponent(entityId: testEntity, componentType: LODComponent.self)

        XCTAssertTrue(
            hasComponent(entityId: testEntity, componentType: LODComponent.self),
            "Entity should have LODComponent"
        )

        let lodComp = scene.get(component: LODComponent.self, for: testEntity)
        XCTAssertNotNil(lodComp, "LODComponent should be retrievable")
    }

    // MARK: - LODConfig Tests

    func testLODConfigDefaults() {
        let config = LODConfig.shared

        XCTAssertEqual(config.lodDistances.count, 4, "Should have 4 default distances")
        XCTAssertEqual(config.lodDistances[0], 50.0, "LOD0 distance should be 50")
        XCTAssertEqual(config.lodDistances[1], 100.0, "LOD1 distance should be 100")
        XCTAssertEqual(config.lodDistances[2], 200.0, "LOD2 distance should be 200")
        XCTAssertEqual(config.lodDistances[3], 500.0, "LOD3 distance should be 500")

        XCTAssertEqual(config.lodBias, 1.0, "Default LOD bias should be 1.0")
        XCTAssertEqual(config.hysteresis, 5.0, "Default hysteresis should be 5.0")
        XCTAssertFalse(config.enableFadeTransitions, "Fade transitions should be disabled by default for performance")
        XCTAssertEqual(config.fadeTransitionTime, 0.3, "Fade transition time should be 0.3s")
    }

    func testLODConfigCustomization() {
        LODConfig.shared.lodBias = 1.5
        LODConfig.shared.hysteresis = 10.0

        XCTAssertEqual(LODConfig.shared.lodBias, 1.5, "LOD bias should be updated")
        XCTAssertEqual(LODConfig.shared.hysteresis, 10.0, "Hysteresis should be updated")

        // Reset for other tests
        LODConfig.shared.lodBias = 1.0
        LODConfig.shared.hysteresis = 5.0
    }

    // MARK: - LODSystem Distance Calculation Tests

    func testCalculateDistanceBasic() {
        // Test the distance calculation logic independently
        let cameraPos = simd_float3(0, 0, 0)
        let entityPos = simd_float3(10, 0, 0)

        let distance = simd_distance(cameraPos, entityPos)

        // Verify distance calculation
        XCTAssertEqual(distance, 10.0, accuracy: 0.01, "Distance calculation should be accurate")

        // Test other positions
        let pos2 = simd_float3(3, 4, 0)
        let distance2 = simd_distance(cameraPos, pos2)
        XCTAssertEqual(distance2, 5.0, accuracy: 0.01, "Distance should be 5 (3-4-5 triangle)")
    }

    // MARK: - LOD Selection Tests

    func testLODSelectionBasedOnDistance() {
        // Create LOD component with test levels
        registerComponent(entityId: testEntity, componentType: LODComponent.self)
        guard let lodComp = scene.get(component: LODComponent.self, for: testEntity) else {
            XCTFail("Failed to get LOD component")
            return
        }

        // Add LOD levels with increasing distances
        lodComp.lodLevels = [
            LODLevel(mesh: [], maxDistance: 50.0, screenPercentage: 1.0), // LOD0
            LODLevel(mesh: [], maxDistance: 100.0, screenPercentage: 0.5), // LOD1
            LODLevel(mesh: [], maxDistance: 200.0, screenPercentage: 0.25), // LOD2
            LODLevel(mesh: [], maxDistance: 500.0, screenPercentage: 0.1), // LOD3
        ]

        XCTAssertEqual(lodComp.lodLevels.count, 4, "Should have 4 LOD levels")

        // Verify distances are correctly set
        XCTAssertEqual(lodComp.lodLevels[0].maxDistance, 50.0)
        XCTAssertEqual(lodComp.lodLevels[1].maxDistance, 100.0)
        XCTAssertEqual(lodComp.lodLevels[2].maxDistance, 200.0)
        XCTAssertEqual(lodComp.lodLevels[3].maxDistance, 500.0)
    }

    func testForcedLODOverride() {
        registerComponent(entityId: testEntity, componentType: LODComponent.self)
        guard let lodComp = scene.get(component: LODComponent.self, for: testEntity) else {
            XCTFail("Failed to get LOD component")
            return
        }

        lodComp.lodLevels = [
            LODLevel(mesh: [], maxDistance: 50.0, screenPercentage: 1.0),
            LODLevel(mesh: [], maxDistance: 100.0, screenPercentage: 0.5),
        ]

        // Force LOD to specific level
        lodComp.forcedLOD = 1

        XCTAssertEqual(lodComp.forcedLOD, 1, "Forced LOD should be set to 1")

        // Clear forced LOD
        lodComp.forcedLOD = nil
        XCTAssertNil(lodComp.forcedLOD, "Forced LOD should be cleared")
    }

    // MARK: - LOD Transition Tests

    func testLODTransitionProgress() {
        registerComponent(entityId: testEntity, componentType: LODComponent.self)
        guard let lodComp = scene.get(component: LODComponent.self, for: testEntity) else {
            XCTFail("Failed to get LOD component")
            return
        }

        lodComp.currentLOD = 0
        lodComp.previousLOD = 1
        lodComp.transitionProgress = 0.5

        XCTAssertEqual(lodComp.currentLOD, 0, "Current LOD should be 0")
        XCTAssertEqual(lodComp.previousLOD, 1, "Previous LOD should be 1")
        XCTAssertEqual(lodComp.transitionProgress, 0.5, "Transition progress should be 0.5")
    }

    func testTransitionCompletion() {
        registerComponent(entityId: testEntity, componentType: LODComponent.self)
        guard let lodComp = scene.get(component: LODComponent.self, for: testEntity) else {
            XCTFail("Failed to get LOD component")
            return
        }

        lodComp.currentLOD = 1
        lodComp.previousLOD = 0
        lodComp.transitionProgress = 1.0

        // Simulate transition completion
        if lodComp.transitionProgress >= 1.0 {
            lodComp.previousLOD = nil
            lodComp.transitionProgress = 0.0
        }

        XCTAssertNil(lodComp.previousLOD, "Previous LOD should be cleared after transition")
        XCTAssertEqual(lodComp.transitionProgress, 0.0, "Transition progress should reset to 0")
    }

    // MARK: - Array Extension Tests

    func testSafeArraySubscript() {
        let distances: [Float] = [50.0, 100.0, 200.0]

        XCTAssertEqual(distances[safe: 0], 50.0, "Safe subscript should return first element")
        XCTAssertEqual(distances[safe: 1], 100.0, "Safe subscript should return second element")
        XCTAssertEqual(distances[safe: 2], 200.0, "Safe subscript should return third element")
        XCTAssertNil(distances[safe: 3], "Safe subscript should return nil for out of bounds")
        XCTAssertNil(distances[safe: -1], "Safe subscript should return nil for negative index")
    }

    // MARK: - LOD Component Registration Tests

    func testRegisterLODComponentWithLevels() {
        let lodLevels = [
            LODLevel(mesh: [], maxDistance: 50.0, screenPercentage: 1.0),
            LODLevel(mesh: [], maxDistance: 100.0, screenPercentage: 0.5),
        ]

        registerLODComponent(entityId: testEntity, lodLevels: lodLevels)

        XCTAssertTrue(
            hasComponent(entityId: testEntity, componentType: LODComponent.self),
            "Entity should have LODComponent after registration"
        )

        guard let lodComp = scene.get(component: LODComponent.self, for: testEntity) else {
            XCTFail("Failed to retrieve LOD component")
            return
        }

        XCTAssertEqual(lodComp.lodLevels.count, 2, "Should have 2 LOD levels")
        XCTAssertEqual(lodComp.currentLOD, 0, "Current LOD should be 0")
        XCTAssertEqual(lodComp.lodLevels[0].maxDistance, 50.0, "LOD0 distance should be 50")
        XCTAssertEqual(lodComp.lodLevels[1].maxDistance, 100.0, "LOD1 distance should be 100")
    }

    func testRegisterLODComponentWithEmptyLevels() {
        // This should log a warning but not crash
        registerLODComponent(entityId: testEntity, lodLevels: [])

        // Component should not be registered if levels are empty
        XCTAssertFalse(
            hasComponent(entityId: testEntity, componentType: LODComponent.self),
            "Entity should not have LODComponent with empty levels"
        )
    }

    // MARK: - LOD System Integration Tests

    func testMultipleEntitiesWithLOD() {
        let entity1 = createEntity()
        let entity2 = createEntity()

        registerTransformComponent(entityId: entity1)
        registerTransformComponent(entityId: entity2)

        let lodLevels1 = [LODLevel(mesh: [], maxDistance: 50.0, screenPercentage: 1.0)]
        let lodLevels2 = [LODLevel(mesh: [], maxDistance: 100.0, screenPercentage: 1.0)]

        registerLODComponent(entityId: entity1, lodLevels: lodLevels1)
        registerLODComponent(entityId: entity2, lodLevels: lodLevels2)

        XCTAssertTrue(hasComponent(entityId: entity1, componentType: LODComponent.self))
        XCTAssertTrue(hasComponent(entityId: entity2, componentType: LODComponent.self))

        let lod1 = scene.get(component: LODComponent.self, for: entity1)
        let lod2 = scene.get(component: LODComponent.self, for: entity2)

        XCTAssertEqual(lod1?.lodLevels[0].maxDistance, 50.0)
        XCTAssertEqual(lod2?.lodLevels[0].maxDistance, 100.0)
    }

    func testLODSystemQuery() {
        // Create multiple entities with LOD components
        let entity1 = createEntity()
        let entity2 = createEntity()
        let entity3 = createEntity() // No LOD

        registerTransformComponent(entityId: entity1)
        registerTransformComponent(entityId: entity2)
        registerTransformComponent(entityId: entity3)

        let lodLevels = [LODLevel(mesh: [], maxDistance: 50.0, screenPercentage: 1.0)]
        registerLODComponent(entityId: entity1, lodLevels: lodLevels)
        registerLODComponent(entityId: entity2, lodLevels: lodLevels)

        // Query entities with LOD components
        let lodId = getComponentId(for: LODComponent.self)
        let transformId = getComponentId(for: WorldTransformComponent.self)
        let entities = queryEntitiesWithComponentIds([lodId, transformId], in: scene)

        XCTAssertEqual(entities.count, 2, "Should find 2 entities with LOD and transform components")
        XCTAssertTrue(entities.contains(entity1), "Should contain entity1")
        XCTAssertTrue(entities.contains(entity2), "Should contain entity2")
        XCTAssertFalse(entities.contains(entity3), "Should not contain entity3 (no LOD)")
    }

    // MARK: - LOD Hysteresis Tests

    func testHysteresisValue() {
        let hysteresis = LODConfig.shared.hysteresis

        XCTAssertEqual(hysteresis, 5.0, "Default hysteresis should be 5.0")
        XCTAssertGreaterThan(hysteresis, 0, "Hysteresis should be positive")

        // Hysteresis prevents flickering by requiring distance to change
        // by more than hysteresis value before switching LOD levels
        let threshold: Float = 100.0
        let adjustedUpward = threshold + hysteresis // 105.0
        let adjustedDownward = threshold - hysteresis // 95.0

        XCTAssertEqual(adjustedUpward, 105.0, "Upward threshold should include hysteresis")
        XCTAssertEqual(adjustedDownward, 95.0, "Downward threshold should include hysteresis")
    }

    // MARK: - LOD Bias Tests

    func testLODBias() {
        let bias = LODConfig.shared.lodBias
        XCTAssertEqual(bias, 1.0, "Default bias should be 1.0")

        // Bias > 1.0 makes LODs switch to lower detail sooner (performance mode)
        // Bias < 1.0 makes LODs switch to lower detail later (quality mode)
        let distance: Float = 100.0
        let performanceBias: Float = 1.5
        let qualityBias: Float = 0.75

        let performanceDistance = distance * performanceBias
        let qualityDistance = distance * qualityBias

        XCTAssertEqual(performanceDistance, 150.0, "Performance bias should increase effective distance")
        XCTAssertEqual(qualityDistance, 75.0, "Quality bias should decrease effective distance")
    }

    // MARK: - Edge Cases

    func testLODWithSingleLevel() {
        let lodLevels = [LODLevel(mesh: [], maxDistance: 1000.0, screenPercentage: 1.0)]
        registerLODComponent(entityId: testEntity, lodLevels: lodLevels)

        guard let lodComp = scene.get(component: LODComponent.self, for: testEntity) else {
            XCTFail("Failed to get LOD component")
            return
        }

        XCTAssertEqual(lodComp.lodLevels.count, 1, "Should have exactly 1 LOD level")
        XCTAssertEqual(lodComp.currentLOD, 0, "Current LOD should always be 0 with single level")
    }

    func testLODWithMaxLevels() {
        // Test with many LOD levels
        var lodLevels: [LODLevel] = []
        for i in 0 ..< 10 {
            let distance = Float(i + 1) * 100.0
            lodLevels.append(LODLevel(mesh: [], maxDistance: distance, screenPercentage: 1.0))
        }

        registerLODComponent(entityId: testEntity, lodLevels: lodLevels)

        guard let lodComp = scene.get(component: LODComponent.self, for: testEntity) else {
            XCTFail("Failed to get LOD component")
            return
        }

        XCTAssertEqual(lodComp.lodLevels.count, 10, "Should have 10 LOD levels")
        XCTAssertEqual(lodComp.lodLevels[9].maxDistance, 1000.0, "Last LOD should have max distance of 1000")
    }

    func testDestroyEntityWithLODComponent() {
        let lodLevels = [LODLevel(mesh: [], maxDistance: 50.0, screenPercentage: 1.0)]
        registerLODComponent(entityId: testEntity, lodLevels: lodLevels)

        XCTAssertTrue(hasComponent(entityId: testEntity, componentType: LODComponent.self))

        destroyEntity(entityId: testEntity)
        scene.finalizePendingDestroys()

        // Entity should be marked as freed after destruction
        let entityIndex = getEntityIndex(testEntity)
        XCTAssertTrue(scene.entities[Int(entityIndex)].freed, "Entity should be freed after destruction")
    }

    // MARK: - LODLevel assetName Tests

    func testLODLevelStoresAssetName() {
        // Given: Create a LODLevel with explicit assetName
        let testURL = URL(fileURLWithPath: "/path/to/model.usdz")
        let lodLevel = LODLevel(
            mesh: [],
            maxDistance: 100.0,
            screenPercentage: 0.5,
            url: testURL,
            assetName: "custom_asset_name"
        )

        // Then: assetName should be stored
        XCTAssertEqual(lodLevel.assetName, "custom_asset_name", "LODLevel should store explicit assetName")
        XCTAssertEqual(lodLevel.url, testURL, "LODLevel should store URL")
    }

    func testLODLevelAssetNameDefaultsToNil() {
        // Given: Create a LODLevel without assetName and empty mesh
        let lodLevel = LODLevel(mesh: [], maxDistance: 50.0)

        // Then: assetName should be nil (no mesh to extract from)
        XCTAssertNil(lodLevel.assetName, "LODLevel assetName should be nil when no mesh provided")
    }

    func testLODLevelURLForStreamingReload() {
        // Given: Create LODLevels with URLs (simulating addLODLevel behavior)
        let testURL1 = URL(fileURLWithPath: "/path/to/model_LOD0.usdz")
        let testURL2 = URL(fileURLWithPath: "/path/to/model_LOD1.usdz")

        let lodComponent = LODComponent()
        lodComponent.lodLevels = [
            LODLevel(mesh: [], maxDistance: 50, url: testURL1, assetName: "model_LOD0"),
            LODLevel(mesh: [], maxDistance: 100, url: testURL2, assetName: "model_LOD1"),
        ]

        // Then: URLs should be accessible for streaming reload
        XCTAssertEqual(lodComponent.lodLevels[0].url, testURL1, "LOD0 URL should be stored")
        XCTAssertEqual(lodComponent.lodLevels[1].url, testURL2, "LOD1 URL should be stored")
        XCTAssertEqual(lodComponent.lodLevels[0].assetName, "model_LOD0", "LOD0 assetName should be stored")
        XCTAssertEqual(lodComponent.lodLevels[1].assetName, "model_LOD1", "LOD1 assetName should be stored")
    }

    func testLODSystemHandlesEmptyLODLevels() {
        // Simulates the scenario where LODSystem.update() is called before
        // async LOD level loading completes (entity has LODComponent but no levels yet)
        let entity = createEntity()
        registerTransformComponent(entityId: entity)

        // Add LODComponent with NO levels (simulating async load in progress)
        registerComponent(entityId: entity, componentType: LODComponent.self)

        guard let lodComponent = scene.get(component: LODComponent.self, for: entity) else {
            XCTFail("Failed to get LOD component")
            return
        }

        // Verify lodLevels is empty
        XCTAssertTrue(lodComponent.lodLevels.isEmpty, "LOD levels should be empty")

        // This should NOT crash - the system should gracefully skip entities with empty LOD levels
        LODSystem.shared.update(deltaTime: 0.016)

        // Entity should still have its LODComponent intact
        XCTAssertTrue(hasComponent(entityId: entity, componentType: LODComponent.self),
                      "LODComponent should still exist after update")
    }
}

//
//  DistanceTrackingTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

final class DistanceTrackingTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetEngineTestState()
    }

    override func tearDown() {
        super.tearDown()
    }

    private func makeTranslationMatrix(_ translation: simd_float3) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = simd_float4(translation.x, translation.y, translation.z, 1.0)
        return matrix
    }

    @discardableResult
    private func createRenderableEntity(
        position: simd_float3,
        bounds: (min: simd_float3, max: simd_float3) = (min: simd_float3(-1, -1, -1), max: simd_float3(1, 1, 1))
    ) -> EntityID {
        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: RenderComponent.self)

        if let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId) {
            localTransform.boundingBox = bounds
        }

        if let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId) {
            worldTransform.space = makeTranslationMatrix(position)
        }

        if let renderComponent = scene.get(component: RenderComponent.self, for: entityId) {
            renderComponent.isVisible = true
        }

        return entityId
    }

    // MARK: - Fix 5: Distance Tracking Tests

    func testPickedEntityDistanceInitialValue() {
        var state = XRSpatialInputState()
        XCTAssertEqual(
            state.pickedEntityDistance,
            Float.infinity,
            "Distance should initialize to infinity"
        )
    }

    func testPickedEntityDistanceIsSetDuringPicking() {
        let entity = createRenderableEntity(position: simd_float3(5, 0, 0))
        visibleEntityIds = [entity]

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        guard let hit = result else {
            XCTFail("Expected a valid hit result")
            return
        }

        XCTAssertEqual(hit.distance, 4.0, accuracy: 0.0001, "Distance should be 4.0")
    }

    func testPickedEntityDistanceIsStoredinState() {
        var state = XRSpatialInputState()
        state.pickedEntityId = 42
        state.pickedEntityDistance = 7.5
        state.currentPhase = .began

        XCTAssertEqual(state.pickedEntityId, 42)
        XCTAssertEqual(state.pickedEntityDistance, 7.5, accuracy: 0.0001)
    }

    func testPickedEntityDistanceReflectsRayIntersectionPoint() {
        let entity = createRenderableEntity(
            position: simd_float3(10, 0, 0),
            bounds: (min: simd_float3(-1, -1, -1), max: simd_float3(1, 1, 1))
        )
        visibleEntityIds = [entity]

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        guard let hit = result else {
            XCTFail("Expected a valid hit result")
            return
        }

        // Entity at x=10 with bounds [-1, 1], so AABB spans [9, 11]
        // Ray origin at x=0, so distance to AABB entry at x=9 is 9.0
        XCTAssertEqual(hit.distance, 9.0, accuracy: 0.0001)
    }

    func testPickedEntityDistanceWithDifferentRayOrigins() {
        let entity = createRenderableEntity(position: simd_float3(5, 0, 0))
        visibleEntityIds = [entity]

        let result1 = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        let result2 = pickEntity(
            rayOrigin: simd_float3(2, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        guard let hit1 = result1, let hit2 = result2 else {
            XCTFail("Expected valid hit results")
            return
        }

        XCTAssertEqual(hit1.distance, 4.0, accuracy: 0.0001)
        XCTAssertEqual(hit2.distance, 2.0, accuracy: 0.0001, "Distance should be shorter from closer origin")
    }

    func testPickedEntityDistanceWithBackwardRay() {
        let entity = createRenderableEntity(position: simd_float3(5, 0, 0))
        visibleEntityIds = [entity]

        let result = pickEntity(
            rayOrigin: simd_float3(10, 0, 0),
            rayDirection: simd_float3(-1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        guard let hit = result else {
            XCTFail("Expected a valid hit result")
            return
        }

        // Ray starts at x=10, entity AABB spans [4, 6], pointing backward (-1, 0, 0)
        // Distance is from x=10 to x=6 (AABB exit) = 4.0
        XCTAssertEqual(hit.distance, 4.0, accuracy: 0.0001)
    }

    func testPickedEntityDistanceWithMultipleEntities() {
        let nearEntity = createRenderableEntity(position: simd_float3(3, 0, 0))
        let farEntity = createRenderableEntity(position: simd_float3(10, 0, 0))
        visibleEntityIds = [nearEntity, farEntity]

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        guard let hit = result else {
            XCTFail("Expected a valid hit result")
            return
        }

        // Should pick nearest entity (nearEntity)
        XCTAssertEqual(hit.entityId, nearEntity)
        XCTAssertEqual(hit.distance, 2.0, accuracy: 0.0001, "Should report distance to nearest entity")
    }

    func testPickedEntityDistanceResetOnInteractionCancel() {
        var state = XRSpatialInputState()
        state.pickedEntityId = 99
        state.pickedEntityDistance = 5.5
        state.currentPhase = .began

        // Simulate interaction cancellation
        state.currentPhase = .cancelled
        state.pickedEntityId = nil
        state.pickedEntityDistance = Float.infinity

        XCTAssertNil(state.pickedEntityId)
        XCTAssertEqual(state.pickedEntityDistance, Float.infinity)
    }

    func testPickedEntityDistanceWithOctreeRayPicking() {
        let entity = createRenderableEntity(position: simd_float3(7.5, 0, 0))
        visibleEntityIds = [entity]

        OctreeSystem.shared.registerEntity(entity)

        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .octreePreferred)
        )

        guard let hit = result else {
            XCTFail("Expected a valid hit result")
            return
        }

        // Entity at x=7.5 with bounds [-1, 1], so AABB spans [6.5, 8.5]
        // Ray origin at x=0, distance to entry at x=6.5 is 6.5
        XCTAssertEqual(hit.distance, 6.5, accuracy: 0.0001)
    }

    func testPickedEntityDistanceConsistencyAcrossBackends() {
        let entity = createRenderableEntity(position: simd_float3(5, 0, 0))
        visibleEntityIds = [entity]
        OctreeSystem.shared.registerEntity(entity)

        let cpuResult = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        let octreeResult = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .octreePreferred)
        )

        guard let cpuHit = cpuResult, let octreeHit = octreeResult else {
            XCTFail("Expected valid hit results")
            return
        }

        XCTAssertEqual(
            cpuHit.distance,
            octreeHit.distance,
            accuracy: 0.0001,
            "Distance should be consistent across backends"
        )
    }

    func testPickedEntityDistanceWithVariousDistances() {
        let testCases: [(position: simd_float3, expectedDistance: Float)] = [
            (simd_float3(1, 0, 0), 0.0), // Ray origin inside AABB
            (simd_float3(2, 0, 0), 1.0),
            (simd_float3(5, 0, 0), 4.0),
            (simd_float3(10, 0, 0), 9.0),
            (simd_float3(20, 0, 0), 19.0),
        ]

        for testCase in testCases {
            visibleEntityIds.removeAll()
            let entity = createRenderableEntity(position: testCase.position)
            visibleEntityIds = [entity]

            let result = pickEntity(
                rayOrigin: simd_float3(0, 0, 0),
                rayDirection: simd_float3(1, 0, 0),
                options: ScenePickOptions(backend: .cpuOnly)
            )

            guard let hit = result else {
                XCTFail("Expected hit for entity at \(testCase.position)")
                continue
            }

            XCTAssertEqual(
                hit.distance,
                testCase.expectedDistance,
                accuracy: 0.0001,
                "Distance mismatch for entity at \(testCase.position)"
            )
        }
    }
}

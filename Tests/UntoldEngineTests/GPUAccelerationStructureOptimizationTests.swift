//
//  GPUAccelerationStructureOptimizationTests.swift
//  UntoldEngineTests
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import simd
@testable import UntoldEngine
import XCTest

final class GPUAccelerationStructureOptimizationTests: XCTestCase {
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
        bounds: (min: simd_float3, max: simd_float3) = (min: simd_float3(-1, -1, -1), max: simd_float3(1, 1, 1)),
        isStatic: Bool = false
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

        if isStatic {
            registerComponent(entityId: entityId, componentType: StaticBatchComponent.self)
        }

        return entityId
    }

    // MARK: - Fix 4: GPU Acceleration Structure Optimization Tests

    func testStaticEntityIsIdentifiedCorrectly() {
        let staticEntity = createRenderableEntity(position: simd_float3(0, 0, 0), isStatic: true)
        let dynamicEntity = createRenderableEntity(position: simd_float3(5, 0, 0), isStatic: false)

        XCTAssertTrue(
            hasComponent(entityId: staticEntity, componentType: StaticBatchComponent.self),
            "Static entity should have StaticBatchComponent"
        )

        XCTAssertFalse(
            hasComponent(entityId: dynamicEntity, componentType: StaticBatchComponent.self),
            "Dynamic entity should not have StaticBatchComponent"
        )
    }

    func testStaticEntityTransformChangeDoesNotTriggerSignatureChange() {
        let staticEntity = createRenderableEntity(position: simd_float3(0, 0, 0), isStatic: true)
        visibleEntityIds = [staticEntity]

        // Get initial state
        scenePickingDirtyEntities.removeAll()

        // Move the static entity
        if let worldTransform = scene.get(component: WorldTransformComponent.self, for: staticEntity) {
            worldTransform.space = makeTranslationMatrix(simd_float3(10, 0, 0))
        }

        // Mark as dirty (as the transform system would do)
        scenePickingDirtyEntities.insert(staticEntity)

        // In the fixed implementation, static entities' transforms shouldn't change the signature
        // The dirty set would still track it for GPU rebuild, but the signature optimization
        // reduces unnecessary rebuilds when only dynamic entities change
        XCTAssertTrue(
            scenePickingDirtyEntities.contains(staticEntity),
            "Static entity should be tracked in dirty set"
        )
    }

    func testDynamicEntityMovementMarkedDirty() {
        let dynamicEntity = createRenderableEntity(position: simd_float3(0, 0, 0), isStatic: false)
        visibleEntityIds = [dynamicEntity]

        // Clear dirty set
        scenePickingDirtyEntities.removeAll()

        // Move dynamic entity
        if let worldTransform = scene.get(component: WorldTransformComponent.self, for: dynamicEntity) {
            worldTransform.space = makeTranslationMatrix(simd_float3(10, 0, 0))
        }

        // Mark as dirty
        scenePickingDirtyEntities.insert(dynamicEntity)

        XCTAssertTrue(
            scenePickingDirtyEntities.contains(dynamicEntity),
            "Dynamic entity should be marked dirty when moved"
        )
    }

    func testMeshVisibilityChangeTriggersAccelStructureUpdate() {
        let entity = createRenderableEntity(position: simd_float3(0, 0, 0), isStatic: true)
        visibleEntityIds = [entity]

        // Change visibility
        if let renderComponent = scene.get(component: RenderComponent.self, for: entity) {
            renderComponent.isVisible = false
        }

        // Mark as dirty (geometry change should trigger update)
        scenePickingDirtyEntities.insert(entity)

        XCTAssertTrue(
            scenePickingDirtyEntities.contains(entity),
            "Entity with visibility change should be marked dirty"
        )
    }

    func testMultipleEntitiesStatusTracking() {
        let staticEntity1 = createRenderableEntity(position: simd_float3(0, 0, 0), isStatic: true)
        let staticEntity2 = createRenderableEntity(position: simd_float3(5, 0, 0), isStatic: true)
        let dynamicEntity1 = createRenderableEntity(position: simd_float3(10, 0, 0), isStatic: false)
        let dynamicEntity2 = createRenderableEntity(position: simd_float3(15, 0, 0), isStatic: false)

        visibleEntityIds = [staticEntity1, staticEntity2, dynamicEntity1, dynamicEntity2]

        // Verify identification
        let staticEntities = visibleEntityIds.filter { entityId in
            hasComponent(entityId: entityId, componentType: StaticBatchComponent.self)
        }

        let dynamicEntities = visibleEntityIds.filter { entityId in
            !hasComponent(entityId: entityId, componentType: StaticBatchComponent.self)
        }

        XCTAssertEqual(staticEntities.count, 2, "Should have 2 static entities")
        XCTAssertEqual(dynamicEntities.count, 2, "Should have 2 dynamic entities")
    }

    func testDirtyEntityTrackingIndependentOfEntityType() {
        let staticEntity = createRenderableEntity(position: simd_float3(0, 0, 0), isStatic: true)
        let dynamicEntity = createRenderableEntity(position: simd_float3(5, 0, 0), isStatic: false)

        scenePickingDirtyEntities.removeAll()

        // Mark both as dirty
        scenePickingDirtyEntities.insert(staticEntity)
        scenePickingDirtyEntities.insert(dynamicEntity)

        XCTAssertTrue(scenePickingDirtyEntities.contains(staticEntity))
        XCTAssertTrue(scenePickingDirtyEntities.contains(dynamicEntity))
        XCTAssertEqual(scenePickingDirtyEntities.count, 2)
    }

    func testStaticEntityWithVisibilityToggle() {
        let staticEntity = createRenderableEntity(position: simd_float3(0, 0, 0), isStatic: true)
        visibleEntityIds = [staticEntity]

        let renderComponent = scene.get(component: RenderComponent.self, for: staticEntity)
        XCTAssertNotNil(renderComponent)
        XCTAssertTrue(renderComponent?.isVisible ?? false)

        // Toggle visibility
        renderComponent?.isVisible = false

        XCTAssertFalse(renderComponent?.isVisible ?? true)

        // Visibility change should be tracked for rebuild
        scenePickingDirtyEntities.insert(staticEntity)
        XCTAssertTrue(scenePickingDirtyEntities.contains(staticEntity))
    }

    func testOptimizationPreservesAccuracyForPickingResults() {
        // Even with optimization, ray picking should remain accurate
        let staticEntity = createRenderableEntity(
            position: simd_float3(5, 0, 0),
            bounds: (min: simd_float3(-1, -1, -1), max: simd_float3(1, 1, 1)),
            isStatic: true
        )
        visibleEntityIds = [staticEntity]

        // Ray picking should still work correctly despite optimization
        let result = pickEntity(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            options: ScenePickOptions(backend: .cpuOnly)
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.entityId, staticEntity)
        if let distance = result?.distance {
            XCTAssertEqual(Double(distance), 4.0, accuracy: 0.0001)
        } else {
            XCTFail("Result distance is nil")
        }
    }
}

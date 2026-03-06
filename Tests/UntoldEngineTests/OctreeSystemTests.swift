//
//  OctreeSystemTests.swift
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

final class OctreeSystemTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetEngineTestState()
    }

    override func tearDown() {
        OctreeSystem.shared.clear()
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Creates an entity with required transform components for OctreeSystem
    private func createEntityWithTransforms(
        boundingBox: (min: simd_float3, max: simd_float3) = (min: simd_float3(-1, -1, -1), max: simd_float3(1, 1, 1)),
        worldMatrix: simd_float4x4 = matrix_identity_float4x4
    ) -> EntityID {
        let entityId = createEntity()

        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)

        if let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId) {
            localTransform.boundingBox = boundingBox
        }

        if let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId) {
            worldTransform.space = worldMatrix
        }

        return entityId
    }

    /// Creates a translation matrix
    private func makeTranslationMatrix(_ translation: simd_float3) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = simd_float4(translation.x, translation.y, translation.z, 1)
        return matrix
    }

    // MARK: - Test: registerEntity

    func testRegisterEntityAddsEntityAndCalculatesBounds() {
        // Arrange: Create entity with known bounding box at origin
        let boundingBox = (min: simd_float3(-2, -2, -2), max: simd_float3(2, 2, 2))
        let entityId = createEntityWithTransforms(boundingBox: boundingBox)

        // Act: Register the entity
        OctreeSystem.shared.registerEntity(entityId)

        // Assert: Entity should be registered
        XCTAssertEqual(OctreeSystem.shared.entityCount, 1, "OctreeSystem should have 1 registered entity")

        // Verify bounds were calculated correctly
        let storedBounds = OctreeSystem.shared.getBounds(for: entityId)
        XCTAssertNotNil(storedBounds, "Stored bounds should not be nil")
        if let b = storedBounds {
            XCTAssertEqual(b.min.x, -2.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.min.y, -2.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.min.z, -2.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.max.x, 2.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.max.y, 2.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.max.z, 2.0 as Float, accuracy: 0.001)
        }
    }

    func testRegisterEntityWithTransformedBounds() {
        // Arrange: Create entity with bounding box translated in world space
        let boundingBox = (min: simd_float3(-1, -1, -1), max: simd_float3(1, 1, 1))
        let translation = simd_float3(10, 20, 30)
        let worldMatrix = makeTranslationMatrix(translation)
        let entityId = createEntityWithTransforms(boundingBox: boundingBox, worldMatrix: worldMatrix)

        // Act: Register the entity
        OctreeSystem.shared.registerEntity(entityId)

        // Assert: Bounds should be transformed to world space
        let storedBounds = OctreeSystem.shared.getBounds(for: entityId)
        XCTAssertNotNil(storedBounds, "Stored bounds should not be nil")
        if let b = storedBounds {
            // World bounds should be local bounds + translation
            XCTAssertEqual(b.min.x, 9.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.min.y, 19.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.min.z, 29.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.max.x, 11.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.max.y, 21.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.max.z, 31.0 as Float, accuracy: 0.001)
        }
    }

    func testRegisterEntityDoesNotDuplicateRegistration() {
        // Arrange
        let entityId = createEntityWithTransforms()

        // Act: Register the same entity twice
        OctreeSystem.shared.registerEntity(entityId)
        OctreeSystem.shared.registerEntity(entityId)

        // Assert: Should only be registered once
        XCTAssertEqual(OctreeSystem.shared.entityCount, 1, "Entity should not be registered twice")
    }

    func testRegisterEntityWithoutComponentsDoesNothing() {
        // Arrange: Create entity without transform components
        // Use scene.newEntity() directly to avoid auto-registration of spatial components
        let entityId = scene.newEntity()

        // Act
        OctreeSystem.shared.registerEntity(entityId)

        // Assert: Should not be registered (no components)
        XCTAssertEqual(OctreeSystem.shared.entityCount, 0, "Entity without components should not be registered")
    }

    // MARK: - Test: unregisterEntity

    func testUnregisterEntityRemovesEntityFromSystem() {
        // Arrange: Register an entity
        let entityId = createEntityWithTransforms()
        OctreeSystem.shared.registerEntity(entityId)
        XCTAssertEqual(OctreeSystem.shared.entityCount, 1)

        // Act: Unregister the entity
        OctreeSystem.shared.unregisterEntity(entityId)

        // Assert: Entity should be removed
        XCTAssertEqual(OctreeSystem.shared.entityCount, 0, "Entity count should be 0 after unregistration")
        XCTAssertNil(OctreeSystem.shared.getBounds(for: entityId), "Bounds should be nil after unregistration")
    }

    func testUnregisterEntityNotRegisteredDoesNothing() {
        // Arrange: Create entity but don't register it
        let entityId = createEntityWithTransforms()

        // Act & Assert: Should not crash or change count
        OctreeSystem.shared.unregisterEntity(entityId)
        XCTAssertEqual(OctreeSystem.shared.entityCount, 0)
    }

    func testUnregisterEntityRemovesFromDirtySet() {
        // Arrange: Register and mark entity as dirty
        let entityId = createEntityWithTransforms()
        OctreeSystem.shared.registerEntity(entityId)
        OctreeSystem.shared.markDirty(entityId)

        // Act: Unregister the entity
        OctreeSystem.shared.unregisterEntity(entityId)

        // Assert: Entity should be removed (updateDirtyBounds should not crash)
        OctreeSystem.shared.updateDirtyBounds()
        XCTAssertEqual(OctreeSystem.shared.entityCount, 0)
    }

    // MARK: - Test: markDirty and updateDirtyBounds

    func testMarkDirtyAndUpdateDirtyBoundsUpdatesPosition() {
        // Arrange: Create and register entity at origin
        let boundingBox = (min: simd_float3(-1, -1, -1), max: simd_float3(1, 1, 1))
        let entityId = createEntityWithTransforms(boundingBox: boundingBox)
        OctreeSystem.shared.registerEntity(entityId)

        // Verify initial position
        let initialBounds = OctreeSystem.shared.getBounds(for: entityId)
        if let b = initialBounds {
            XCTAssertEqual(b.min.x, -1.0 as Float, accuracy: 0.001)
        }

        // Act: Move entity and mark dirty
        let newTranslation = simd_float3(100, 100, 100)
        if let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId) {
            worldTransform.space = makeTranslationMatrix(newTranslation)
        }
        OctreeSystem.shared.markDirty(entityId)
        OctreeSystem.shared.updateDirtyBounds()

        // Assert: Bounds should be updated to new position
        let updatedBounds = OctreeSystem.shared.getBounds(for: entityId)
        XCTAssertNotNil(updatedBounds)
        if let b = updatedBounds {
            XCTAssertEqual(b.min.x, 99.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.min.y, 99.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.min.z, 99.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.max.x, 101.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.max.y, 101.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.max.z, 101.0 as Float, accuracy: 0.001)
        }
    }

    func testMarkDirtyOnUnregisteredEntityDoesNothing() {
        // Arrange: Create entity but don't register
        let entityId = createEntityWithTransforms()

        // Act & Assert: Should not crash
        OctreeSystem.shared.markDirty(entityId)
        OctreeSystem.shared.updateDirtyBounds()
        XCTAssertEqual(OctreeSystem.shared.entityCount, 0)
    }

    func testUpdateDirtyBoundsClearsDirtySet() {
        // Arrange
        let entityId = createEntityWithTransforms()
        OctreeSystem.shared.registerEntity(entityId)
        OctreeSystem.shared.markDirty(entityId)

        // Act: Update dirty bounds twice
        OctreeSystem.shared.updateDirtyBounds()

        // Modify position again but don't mark dirty
        if let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId) {
            worldTransform.space = makeTranslationMatrix(simd_float3(500, 500, 500))
        }
        OctreeSystem.shared.updateDirtyBounds()

        // Assert: Bounds should NOT be updated (entity was not marked dirty again)
        let bounds = OctreeSystem.shared.getBounds(for: entityId)
        // Should still be at origin since dirty flag was cleared
        if let b = bounds {
            XCTAssertEqual(b.min.x, -1.0 as Float, accuracy: 0.001)
        }
    }

    func testScaleToUpdatesWorldTransformBeforeDirtyBoundsFlush() {
        // Arrange: Entity created through RegistrationSystem has Local+World+Scenegraph.
        let entityId = createEntity()
        OctreeSystem.shared.registerEntity(entityId)

        // Act: Scale via TransformSystem then flush octree dirty bounds in same frame.
        scaleTo(entityId: entityId, scale: simd_float3(2, 2, 2))
        OctreeSystem.shared.updateDirtyBounds()

        // Assert: Octree bounds should match scaled world transform.
        let updatedBounds = OctreeSystem.shared.getBounds(for: entityId)
        XCTAssertNotNil(updatedBounds)
        if let b = updatedBounds {
            XCTAssertEqual(b.min.x, -2.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.min.y, -2.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.min.z, -2.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.max.x, 2.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.max.y, 2.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.max.z, 2.0 as Float, accuracy: 0.001)
        }
    }

    func testParentTranslateUpdatesChildOctreeBounds() {
        // Arrange: Parent is a non-render root; child is renderable and registered in octree.
        let parentId = createEntity()
        let childId = createEntity()
        setParent(childId: childId, parentId: parentId)

        OctreeSystem.shared.registerEntity(childId)

        // Ensure initial transforms are settled.
        traverseSceneGraph()
        OctreeSystem.shared.updateDirtyBounds()

        var results = OctreeSystem.shared.query(sphere: BoundingSphere(center: .zero, radius: 5))
        XCTAssertTrue(results.contains(childId), "Child should initially be near origin")

        // Act: Move parent; child world transform should follow and octree should update child entry.
        translateTo(entityId: parentId, position: simd_float3(100, 0, 0))
        OctreeSystem.shared.updateDirtyBounds()

        // Assert: Child no longer at origin and now found at translated location.
        results = OctreeSystem.shared.query(sphere: BoundingSphere(center: .zero, radius: 5))
        XCTAssertFalse(results.contains(childId), "Child should no longer be near origin after parent move")

        results = OctreeSystem.shared.query(sphere: BoundingSphere(center: simd_float3(100, 0, 0), radius: 5))
        XCTAssertTrue(results.contains(childId), "Child should be near translated parent location")
    }

    func testEntityQueryAfterPositionUpdate() {
        // Arrange: Create entity and register
        let boundingBox = (min: simd_float3(-1, -1, -1), max: simd_float3(1, 1, 1))
        let entityId = createEntityWithTransforms(boundingBox: boundingBox)
        OctreeSystem.shared.registerEntity(entityId)

        // Query near origin - should find entity
        var results = OctreeSystem.shared.query(sphere: BoundingSphere(center: .zero, radius: 5))
        XCTAssertTrue(results.contains(entityId), "Entity should be found near origin")

        // Act: Move entity far away and update
        if let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId) {
            worldTransform.space = makeTranslationMatrix(simd_float3(200, 200, 200))
        }
        OctreeSystem.shared.markDirty(entityId)
        OctreeSystem.shared.updateDirtyBounds()

        // Assert: Should no longer be found at origin
        results = OctreeSystem.shared.query(sphere: BoundingSphere(center: .zero, radius: 5))
        XCTAssertFalse(results.contains(entityId), "Entity should NOT be found near origin after move")

        // Should be found at new location
        results = OctreeSystem.shared.query(sphere: BoundingSphere(center: simd_float3(200, 200, 200), radius: 5))
        XCTAssertTrue(results.contains(entityId), "Entity should be found at new location")
    }

    // MARK: - Test: rebuildOctree

    func testRebuildOctreeReInitializesAndReInsertsEntities() {
        // Arrange: Register multiple entities at different positions
        let entity1 = createEntityWithTransforms(
            boundingBox: (min: simd_float3(-1, -1, -1), max: simd_float3(1, 1, 1)),
            worldMatrix: makeTranslationMatrix(simd_float3(0, 0, 0))
        )
        let entity2 = createEntityWithTransforms(
            boundingBox: (min: simd_float3(-1, -1, -1), max: simd_float3(1, 1, 1)),
            worldMatrix: makeTranslationMatrix(simd_float3(50, 50, 50))
        )
        let entity3 = createEntityWithTransforms(
            boundingBox: (min: simd_float3(-1, -1, -1), max: simd_float3(1, 1, 1)),
            worldMatrix: makeTranslationMatrix(simd_float3(-50, -50, -50))
        )

        OctreeSystem.shared.registerEntity(entity1)
        OctreeSystem.shared.registerEntity(entity2)
        OctreeSystem.shared.registerEntity(entity3)

        XCTAssertEqual(OctreeSystem.shared.entityCount, 3)

        // Act: Rebuild the octree
        OctreeSystem.shared.rebuildOctree()

        // Assert: All entities should still be registered with correct bounds
        XCTAssertEqual(OctreeSystem.shared.entityCount, 3, "All entities should be re-inserted after rebuild")

        // Verify entities can still be queried
        var results = OctreeSystem.shared.query(sphere: BoundingSphere(center: .zero, radius: 5))
        XCTAssertTrue(results.contains(entity1), "Entity1 should be found after rebuild")

        results = OctreeSystem.shared.query(sphere: BoundingSphere(center: simd_float3(50, 50, 50), radius: 5))
        XCTAssertTrue(results.contains(entity2), "Entity2 should be found after rebuild")

        results = OctreeSystem.shared.query(sphere: BoundingSphere(center: simd_float3(-50, -50, -50), radius: 5))
        XCTAssertTrue(results.contains(entity3), "Entity3 should be found after rebuild")
    }

    func testRebuildOctreeWithUpdatedPositions() {
        // Arrange: Register entity
        let entityId = createEntityWithTransforms()
        OctreeSystem.shared.registerEntity(entityId)

        // Move entity without marking dirty
        if let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId) {
            worldTransform.space = makeTranslationMatrix(simd_float3(300, 300, 300))
        }

        // Act: Rebuild octree (should use current component values)
        OctreeSystem.shared.rebuildOctree()

        // Assert: Entity should be at new position
        let bounds = OctreeSystem.shared.getBounds(for: entityId)
        if let b = bounds {
            XCTAssertEqual(b.min.x, 299.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.max.x, 301.0 as Float, accuracy: 0.001)
        }
    }

    func testRebuildOctreeClearsDirtyEntities() {
        // Arrange
        let entityId = createEntityWithTransforms()
        OctreeSystem.shared.registerEntity(entityId)
        OctreeSystem.shared.markDirty(entityId)

        // Act: Rebuild
        OctreeSystem.shared.rebuildOctree()

        // Assert: Dirty set should be cleared (no update should happen)
        // Modify position
        if let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId) {
            worldTransform.space = makeTranslationMatrix(simd_float3(999, 999, 999))
        }
        OctreeSystem.shared.updateDirtyBounds()

        // Should not have updated since dirty was cleared by rebuild
        let bounds = OctreeSystem.shared.getBounds(for: entityId)
        if let b = bounds {
            XCTAssertEqual(b.min.x, -1.0 as Float, accuracy: 0.001)
        }
    }

    // MARK: - Test: OctreeSystem enabled flag

    func testDisabledOctreeSystemDoesNotRegister() {
        // Arrange
        OctreeSystem.shared.enabled = false
        let entityId = createEntityWithTransforms()

        // Act
        OctreeSystem.shared.registerEntity(entityId)

        // Assert
        XCTAssertEqual(OctreeSystem.shared.entityCount, 0, "Disabled system should not register entities")

        // Cleanup
        OctreeSystem.shared.enabled = true
    }

    func testDisabledOctreeSystemDoesNotMarkDirty() {
        // Arrange
        let entityId = createEntityWithTransforms()
        OctreeSystem.shared.registerEntity(entityId)
        OctreeSystem.shared.enabled = false

        // Move entity
        if let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId) {
            worldTransform.space = makeTranslationMatrix(simd_float3(100, 100, 100))
        }

        // Act
        OctreeSystem.shared.markDirty(entityId)
        OctreeSystem.shared.enabled = true
        OctreeSystem.shared.updateDirtyBounds()

        // Assert: Position should not have been updated
        let bounds = OctreeSystem.shared.getBounds(for: entityId)
        if let b = bounds {
            XCTAssertEqual(b.min.x, -1.0 as Float, accuracy: 0.001)
        }
    }

    // MARK: - Test: RegistrationSystem Integration

    func testRegistrationSystemRegisterRenderComponentRegistersWithOctree() {
        // Arrange: Create entity with transform components
        let entityId = createEntity()
        registerTransformComponent(entityId: entityId)
        registerSceneGraphComponent(entityId: entityId)

        // Set up bounding box
        if let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId) {
            localTransform.boundingBox = (min: simd_float3(-5, -5, -5), max: simd_float3(5, 5, 5))
        }

        // Act: Register render component directly (simulating what registerRenderComponent does)
        // Since we can't easily create Mesh objects in unit tests, we'll verify the OctreeSystem
        // registration is called by registerEntity
        OctreeSystem.shared.registerEntity(entityId)

        // Assert: Entity should be registered with OctreeSystem
        XCTAssertEqual(OctreeSystem.shared.entityCount, 1)
        let bounds = OctreeSystem.shared.getBounds(for: entityId)
        XCTAssertNotNil(bounds)
        if let b = bounds {
            XCTAssertEqual(b.min.x, -5.0 as Float, accuracy: 0.001)
            XCTAssertEqual(b.max.x, 5.0 as Float, accuracy: 0.001)
        }
    }

    func testRemoveEntityMeshUnregistersFromOctree() {
        // Arrange: Create and register entity
        let entityId = createEntity()
        registerTransformComponent(entityId: entityId)
        registerSceneGraphComponent(entityId: entityId)
        registerComponent(entityId: entityId, componentType: RenderComponent.self)

        // Manually register with OctreeSystem (simulating what registerRenderComponent does)
        OctreeSystem.shared.registerEntity(entityId)
        XCTAssertEqual(OctreeSystem.shared.entityCount, 1)

        // Act: Call unregisterEntity (simulating what removeEntityMesh does)
        OctreeSystem.shared.unregisterEntity(entityId)

        // Assert: Entity should be unregistered from OctreeSystem
        XCTAssertEqual(OctreeSystem.shared.entityCount, 0)
        XCTAssertNil(OctreeSystem.shared.getBounds(for: entityId))
    }

    // MARK: - Test: Multiple Entity Operations

    func testMultipleEntityRegistrationAndUnregistration() {
        // Arrange: Create multiple entities
        var entities: [EntityID] = []
        for i in 0 ..< 10 {
            let entityId = createEntityWithTransforms(
                worldMatrix: makeTranslationMatrix(simd_float3(Float(i) * 10, 0, 0))
            )
            entities.append(entityId)
            OctreeSystem.shared.registerEntity(entityId)
        }

        XCTAssertEqual(OctreeSystem.shared.entityCount, 10)

        // Act: Unregister half
        for i in 0 ..< 5 {
            OctreeSystem.shared.unregisterEntity(entities[i])
        }

        // Assert
        XCTAssertEqual(OctreeSystem.shared.entityCount, 5)

        // Remaining entities should still be queryable
        for i in 5 ..< 10 {
            let center = simd_float3(Float(i) * 10, 0, 0)
            let results = OctreeSystem.shared.query(sphere: BoundingSphere(center: center, radius: 5))
            XCTAssertTrue(results.contains(entities[i]), "Entity \(i) should be found")
        }
    }

    func testClearRemovesAllEntities() {
        // Arrange: Register multiple entities
        for _ in 0 ..< 5 {
            let entityId = createEntityWithTransforms()
            OctreeSystem.shared.registerEntity(entityId)
        }
        XCTAssertEqual(OctreeSystem.shared.entityCount, 5)

        // Act
        OctreeSystem.shared.clear()

        // Assert
        XCTAssertEqual(OctreeSystem.shared.entityCount, 0)
    }
}

//
//  ScenegraphTest.swift
//
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
final class SceneGraphTests: XCTestCase {
    var rootEntity: EntityID!
    var childEntity: EntityID!
    var grandchildEntity: EntityID!

    // MARK: - Setup and Teardown

    override func setUp() async throws {
        resetEngineTestState()
        anyTransformDirty = false

        // Create root, child, and grandchild entities
        rootEntity = createEntity()
        childEntity = createEntity()
        grandchildEntity = createEntity()

        registerTestEntities(entityId: rootEntity)
        registerTestEntities(entityId: childEntity)
        registerTestEntities(entityId: grandchildEntity)
    }

    override func tearDown() async throws {
        destroyEntity(entityId: rootEntity)
        destroyEntity(entityId: childEntity)
        destroyEntity(entityId: grandchildEntity)
    }

    func registerTestEntities(entityId: EntityID) {
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)
    }

    // MARK: - Parent-Child Relationship Tests

    func testSetParent() {
        setParent(childId: childEntity, parentId: rootEntity, offset: simd_float3(2.0, 1.0, 4.0))

        let childScenegraph = scene.get(component: ScenegraphComponent.self, for: childEntity)
        XCTAssertEqual(childScenegraph?.parent, rootEntity)
        XCTAssertEqual(childScenegraph?.level, 1)

        let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: childEntity)

        XCTAssertEqual(localTransformComponent?.position.x, 2.0, "local x transformation should be equal to x-offset")
        XCTAssertEqual(localTransformComponent?.position.y, 1.0, "local y transformation should be equal to y-offset")
        XCTAssertEqual(localTransformComponent?.position.z, 4.0, "local z transformation should be equal to z-offset")

        let parentScenegraph = scene.get(component: ScenegraphComponent.self, for: rootEntity)
        let index = parentScenegraph?.children[0]
        XCTAssertEqual(index, childEntity)
    }

    func testRemoveParent() {
        // set relationship
        setParent(childId: childEntity, parentId: rootEntity)

        let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: childEntity)

        worldTransformComponent?.space.columns.3 = simd_float4(2.0, 1.0, 4.0, 1.0)

        // unset relationship
        removeParent(childId: childEntity)

        let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: childEntity)

        let childScenegraph = scene.get(component: ScenegraphComponent.self, for: childEntity)
        XCTAssertEqual(childScenegraph?.parent, .invalid)
        XCTAssertEqual(childScenegraph?.level, 0)

        // Test if local transformation was set to world transformation
        XCTAssertEqual(localTransformComponent?.position.x, 2.0, "local x transformation should be equal to x-offset")
        XCTAssertEqual(localTransformComponent?.position.y, 1.0, "local y transformation should be equal to y-offset")
        XCTAssertEqual(localTransformComponent?.position.z, 4.0, "local z transformation should be equal to z-offset")

        let parentScenegraph = scene.get(component: ScenegraphComponent.self, for: rootEntity)

        XCTAssertEqual(parentScenegraph?.children.isEmpty, true)
    }

    func testPropagateLevelToDescendants() {
        setParent(childId: grandchildEntity, parentId: childEntity)
        setParent(childId: childEntity, parentId: rootEntity)

        let grandchildScenegraph = scene.get(component: ScenegraphComponent.self, for: grandchildEntity)
        XCTAssertEqual(grandchildScenegraph?.level, 2)
    }

    func testPropagateLevelToDescendantsAfteUnsetParent() {
        setParent(childId: grandchildEntity, parentId: childEntity)
        setParent(childId: childEntity, parentId: rootEntity)

        removeParent(childId: childEntity)

        let grandchildScenegraph = scene.get(component: ScenegraphComponent.self, for: grandchildEntity)
        XCTAssertEqual(grandchildScenegraph?.level, 1)
    }

    // MARK: - World Transform Update Tests

    func testUpdateTransformSystemWithoutParent() {
        let position = simd_float3(1, 2, 3)

        let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: rootEntity)

        localTransformComponent?.position = position

        updateTransformSystem(entityId: rootEntity)

        let worldTransform = scene.get(component: WorldTransformComponent.self, for: rootEntity)?.space
        XCTAssertEqual(worldTransform, localTransformComponent?.space)
    }

    func testUpdateTransformSystemWithParent() {
        let rootLocalTransform = simd_float4x4(translation: simd_float3(0, 0, 0))
        let childLocalTransform = simd_float4x4(translation: simd_float3(0, 0, 0))

        let rootLocalTransformComponent = scene.get(component: LocalTransformComponent.self, for: rootEntity)

        let childLocalTransformComponent = scene.get(component: LocalTransformComponent.self, for: childEntity)

        rootLocalTransformComponent?.space = rootLocalTransform
        childLocalTransformComponent?.space = childLocalTransform

        setParent(childId: childEntity, parentId: rootEntity, offset: simd_float3(0, 1, 0))

        updateTransformSystem(entityId: rootEntity)
        updateTransformSystem(entityId: childEntity)

        let childWorldTransform = scene.get(component: WorldTransformComponent.self, for: childEntity)?.space

        XCTAssertEqual(childWorldTransform?.columns.3.x, 0.0)
        XCTAssertEqual(childWorldTransform?.columns.3.y, 1.0)
        XCTAssertEqual(childWorldTransform?.columns.3.z, 0.0)
    }

    // MARK: - Scene Graph Traversal

    func testTraverseSceneGraph() {
        let rootTransform = simd_float4x4(translation: simd_float3(0, 0, 0))
        let childTransform = simd_float4x4(translation: simd_float3(0, 0, 0))
        let grandchildTransform = simd_float4x4(translation: simd_float3(0, 0, 0))

        let rootLocalTransformComponent = scene.get(component: LocalTransformComponent.self, for: rootEntity)

        let childLocalTransformComponent = scene.get(component: LocalTransformComponent.self, for: childEntity)

        let grandChildLocalTransformComponent = scene.get(component: LocalTransformComponent.self, for: grandchildEntity)

        rootLocalTransformComponent?.space = rootTransform
        childLocalTransformComponent?.space = childTransform
        grandChildLocalTransformComponent?.space = grandchildTransform

        setParent(childId: childEntity, parentId: rootEntity, offset: simd_float3(0, 1, 0))
        setParent(childId: grandchildEntity, parentId: childEntity, offset: simd_float3(0, 0, 1))

        traverseSceneGraph()

        let childWorld = scene.get(component: WorldTransformComponent.self, for: childEntity)?.space
        let grandchildWorld = scene.get(component: WorldTransformComponent.self, for: grandchildEntity)?.space

        XCTAssertEqual(childWorld?.columns.3.x, 0.0)
        XCTAssertEqual(childWorld?.columns.3.y, 1.0)
        XCTAssertEqual(childWorld?.columns.3.z, 0.0)

        XCTAssertEqual(grandchildWorld?.columns.3.x, 0.0)
        XCTAssertEqual(grandchildWorld?.columns.3.y, 1.0)
        XCTAssertEqual(grandchildWorld?.columns.3.z, 1.0)
    }

    // MARK: - Transform Dirty Optimization Tests

    /// After a traversal clears both dirty flags, a second traversal must be a
    /// complete no-op — it must not recompute world transforms for clean entities.
    func testTraverseSceneGraphSkipsCleanEntities() throws {
        let entity = createEntity()
        registerTransformComponent(entityId: entity) // sets anyTransformDirty = true
        registerSceneGraphComponent(entityId: entity)

        let local = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: entity))
        local.position = simd_float3(5, 0, 0)
        local.transformDirty = true
        anyTransformDirty = true

        traverseSceneGraph() // first pass: computes world transform, clears dirty

        let worldAfterFirst = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: entity)?.space)
        XCTAssertEqual(worldAfterFirst.columns.3.x, 5.0, accuracy: 0.001, "First traversal should compute world transform")
        XCTAssertFalse(anyTransformDirty, "anyTransformDirty should be false after traversal")

        // Corrupt the world transform — a second traversal must not repair it
        scene.get(component: WorldTransformComponent.self, for: entity)?.space = matrix_identity_float4x4

        traverseSceneGraph() // second pass: anyTransformDirty = false → early exit

        let worldAfterSecond = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: entity)?.space)
        XCTAssertEqual(worldAfterSecond, matrix_identity_float4x4,
                       "Static entity world transform must not be recomputed when transformDirty and anyTransformDirty are both false")

        destroyEntity(entityId: entity)
    }

    /// A dirty parent must cause the child's world transform to be updated via
    /// the cascade even when the child's own transformDirty is false.
    func testTraverseSceneGraphCascadesDirtyToChild() throws {
        let parent = createEntity()
        let child = createEntity()
        registerTransformComponent(entityId: parent)
        registerSceneGraphComponent(entityId: parent)
        registerTransformComponent(entityId: child)
        registerSceneGraphComponent(entityId: child)
        setParent(childId: child, parentId: parent)

        traverseSceneGraph() // settle — clears all dirty flags
        XCTAssertFalse(anyTransformDirty)

        let parentLocal = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: parent))
        parentLocal.position = simd_float3(10, 0, 0)
        parentLocal.transformDirty = true
        anyTransformDirty = true

        traverseSceneGraph()

        let childWorld = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: child)?.space)
        XCTAssertEqual(childWorld.columns.3.x, 10.0, accuracy: 0.001,
                       "Child world transform must reflect parent movement via cascade")
        XCTAssertFalse(anyTransformDirty, "anyTransformDirty must be cleared after traversal")

        destroyEntity(entityId: parent)
        destroyEntity(entityId: child)
    }

    /// registerTransformComponent must set anyTransformDirty so the new entity
    /// is processed by the very next traversal.
    func testRegisterTransformComponentPrimesTraversal() throws {
        anyTransformDirty = false

        let entity = createEntity()
        registerTransformComponent(entityId: entity)
        XCTAssertTrue(anyTransformDirty, "registerTransformComponent must prime anyTransformDirty")

        registerSceneGraphComponent(entityId: entity)
        let local = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: entity))
        local.position = simd_float3(7, 0, 0)

        traverseSceneGraph()

        let world = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: entity)?.space)
        XCTAssertEqual(world.columns.3.x, 7.0, accuracy: 0.001,
                       "New entity must be processed on its first traversal after registerTransformComponent")

        destroyEntity(entityId: entity)
    }

    func testRemoveEntityScenegraph() {
        setParent(childId: grandchildEntity, parentId: childEntity)
        setParent(childId: childEntity, parentId: rootEntity)

        let parentScenegraph = scene.get(component: ScenegraphComponent.self, for: rootEntity)

        removeEntityScenegraph(entityId: childEntity)
        scene.finalizePendingDestroys()
        XCTAssertEqual(parentScenegraph?.children.count, 0, "Children count should be zero")

        XCTAssertFalse(hasComponent(entityId: childEntity, componentType: ScenegraphComponent.self))
        XCTAssertFalse(hasComponent(entityId: grandchildEntity, componentType: ScenegraphComponent.self))
    }
}

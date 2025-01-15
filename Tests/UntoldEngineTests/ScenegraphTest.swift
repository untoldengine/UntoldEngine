//
//  ScenegraphTest.swift
//
//
//  Created by Harold Serrano on 12/17/24.
//  UntoldEngine

import simd
@testable import UntoldEngine
import XCTest

final class SceneGraphTests: XCTestCase {
    var rootEntity: EntityID!
    var childEntity: EntityID!
    var grandchildEntity: EntityID!

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()

        // Create root, child, and grandchild entities
        rootEntity = createEntity()
        childEntity = createEntity()
        grandchildEntity = createEntity()

        registerTestEntities(entityId: rootEntity)
        registerTestEntities(entityId: childEntity)
        registerTestEntities(entityId: grandchildEntity)
    }

    override func tearDown() {
        destroyEntity(entityId: rootEntity)
        destroyEntity(entityId: childEntity)
        destroyEntity(entityId: grandchildEntity)
        super.tearDown()
    }

    func registerTestEntities(entityId: EntityID) {
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)
    }

    // MARK: - Parent-Child Relationship Tests

    func testSetParent() {
        setParent(childId: childEntity, parentId: rootEntity)

        let childScenegraph = scene.get(component: ScenegraphComponent.self, for: childEntity)
        XCTAssertEqual(childScenegraph?.parent, rootEntity)
        XCTAssertEqual(childScenegraph?.level, 1)

        let parentScenegraph = scene.get(component: ScenegraphComponent.self, for: rootEntity)
        let index = parentScenegraph?.children[0]
        XCTAssertEqual(index, childEntity)
    }

    func testUnsetParent() {
        // set relationship
        setParent(childId: childEntity, parentId: rootEntity)

        // unset relationship
        removeParent(childId: childEntity)

        let childScenegraph = scene.get(component: ScenegraphComponent.self, for: childEntity)
        XCTAssertEqual(childScenegraph?.parent, .invalid)
        XCTAssertEqual(childScenegraph?.level, 0)

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
        let localTransform = simd_float4x4(translation: simd_float3(1, 2, 3))

        let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: rootEntity)

        localTransformComponent?.space = localTransform

        updateTransformSystem(entityId: rootEntity)

        let worldTransform = scene.get(component: WorldTransformComponent.self, for: rootEntity)?.space
        XCTAssertEqual(worldTransform, localTransform)
    }

    func testUpdateTransformSystemWithParent() {
        let rootLocalTransform = simd_float4x4(translation: simd_float3(1, 0, 0))
        let childLocalTransform = simd_float4x4(translation: simd_float3(0, 1, 0))

        let rootLocalTransformComponent = scene.get(component: LocalTransformComponent.self, for: rootEntity)

        let childLocalTransformComponent = scene.get(component: LocalTransformComponent.self, for: childEntity)

        rootLocalTransformComponent?.space = rootLocalTransform
        childLocalTransformComponent?.space = childLocalTransform

        setParent(childId: childEntity, parentId: rootEntity)

        updateTransformSystem(entityId: rootEntity)
        updateTransformSystem(entityId: childEntity)

        let expectedWorldTransform = simd_mul(rootLocalTransform, childLocalTransform)

        let childWorldTransform = scene.get(component: WorldTransformComponent.self, for: childEntity)?.space

        XCTAssertEqual(childWorldTransform, expectedWorldTransform)
    }

    // MARK: - Scene Graph Traversal

    func testTraverseSceneGraph() {
        let rootTransform = simd_float4x4(translation: simd_float3(1, 0, 0))
        let childTransform = simd_float4x4(translation: simd_float3(0, 1, 0))
        let grandchildTransform = simd_float4x4(translation: simd_float3(0, 0, 1))

        let rootLocalTransformComponent = scene.get(component: LocalTransformComponent.self, for: rootEntity)

        let childLocalTransformComponent = scene.get(component: LocalTransformComponent.self, for: childEntity)

        let grandChildLocalTransformComponent = scene.get(component: LocalTransformComponent.self, for: grandchildEntity)

        rootLocalTransformComponent?.space = rootTransform
        childLocalTransformComponent?.space = childTransform
        grandChildLocalTransformComponent?.space = grandchildTransform

        setParent(childId: childEntity, parentId: rootEntity)
        setParent(childId: grandchildEntity, parentId: childEntity)

        traverseSceneGraph()

        let expectedChildWorld = simd_mul(rootTransform, childTransform)
        let expectedGrandchildWorld = simd_mul(expectedChildWorld, grandchildTransform)

        let childWorld = scene.get(component: WorldTransformComponent.self, for: childEntity)?.space
        let grandchildWorld = scene.get(component: WorldTransformComponent.self, for: grandchildEntity)?.space

        XCTAssertEqual(childWorld, expectedChildWorld)
        XCTAssertEqual(grandchildWorld, expectedGrandchildWorld)
    }

    func testRemoveEntity() {
        setParent(childId: grandchildEntity, parentId: childEntity)
        setParent(childId: childEntity, parentId: rootEntity)

        let childEntityIndex = getEntityIndex(childEntity)
        let grandChildEntityIndex = getEntityIndex(grandchildEntity)

        let childScenegraph = scene.get(component: ScenegraphComponent.self, for: childEntity)
        let grandChildScenegraph = scene.get(component: ScenegraphComponent.self, for: grandchildEntity)
        let parentScenegraph = scene.get(component: ScenegraphComponent.self, for: rootEntity)

        removeEntity(entityId: childEntity, containsResources: false)

        XCTAssertEqual(parentScenegraph?.children.count, 0, "Children count should be zero")

        var componentId: Int = getComponentId(for: ScenegraphComponent.self)

        let childComponentMask = scene.entities[Int(childEntityIndex)].mask

        XCTAssertFalse(childComponentMask.test(componentId), "Component should be set to false for child")

        let grandChildComponentMask = scene.entities[Int(grandChildEntityIndex)].mask

        XCTAssertFalse(grandChildComponentMask.test(componentId), "Component should be set to false for grand child")
    }
}

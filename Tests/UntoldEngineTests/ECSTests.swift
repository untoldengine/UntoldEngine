@testable import UntoldEngine
import XCTest

final class ECSTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testCreateEntity() throws {
        // Create a new entity
        let entityId = createEntity()

        // Ensure the entity ID is valid
        XCTAssertNotNil(entityId, "Entity ID should not be nil")

        // Check that the entity exists in the entities array
        let index = Int(getEntityIndex(entityId))
        XCTAssertLessThan(index, scene.entities.count, "Entity index should be within bounds")
        XCTAssertEqual(scene.entities[Int(index)].entityId, entityId, "Entity ID should match the created entity")
    }

    func testCreateEntityReusesFreedEntityIndex() throws {
        // Create and destroy an entity

        let entityId = createEntity()
        destroyEntity(entityId: entityId)

        scene.finalizePendingDestroys()

        // Create a new entity and verify that it reuses the freed index
        let freedCountBefore = scene.freeEntities.count
        let newEntityId = createEntity()
        let newIndex = getEntityIndex(newEntityId)
        XCTAssertEqual(scene.freeEntities.count, freedCountBefore - 1, "Free entities should be empty after reuse")
        XCTAssertEqual(newIndex, getEntityIndex(entityId), "Entity index should be reused")
    }

    func testDestroyEntityMarksEntityAsFreed() throws {
        // Create an entity
        let entityId = createEntity()
        let entityIndex = getEntityIndex(entityId)

        // Destroy the entity
        destroyEntity(entityId: entityId)
        scene.finalizePendingDestroys()

        // Verify that the entity is marked as freed
        XCTAssertTrue(scene.entities[Int(entityIndex)].freed, "Entity should be marked as freed")
        XCTAssertEqual(scene.freeEntities.last, entityIndex, "Freed entity index should be added to freeEntities")
    }

    func testDestroyEntityIncrementsEntityIDVersion() throws {
        // Create an entity
        let entityId = createEntity()
        let entityIndex = getEntityIndex(entityId)
        let initialVersion = getEntityVersion(entityId)

        // Destroy the entity
        destroyEntity(entityId: entityId)
        scene.finalizePendingDestroys()
        // Verify that the entity ID version is incremented
        let newEntityId = scene.entities[Int(entityIndex)].entityId
        let newVersion = getEntityVersion(newEntityId)
        XCTAssertEqual(newVersion, initialVersion + 1, "Entity version should be incremented")
    }

    func testHasComponent() {
        let entityId = createEntity()

        _ = scene.assign(to: entityId, component: RenderComponent.self)

        XCTAssertTrue(hasComponent(entityId: entityId, componentType: RenderComponent.self), "Should have component")

        // remove component
        scene.remove(component: RenderComponent.self, from: entityId)

        XCTAssertFalse(hasComponent(entityId: entityId, componentType: RenderComponent.self), "Should not have component")
    }

    func testSetGetName() {
        let _ = createEntity()
        let entityId2 = createEntity()

        setEntityName(entityId: entityId2, name: "untold")
        let result = getEntityName(entityId: entityId2)

        XCTAssertEqual("untold", result, "Strings do not match")
    }

    func testRemoveEntityName() {
        entityNameMap.removeAll()

        let entityId = createEntity()

        setEntityName(entityId: entityId, name: "untold2")

        XCTAssertEqual(entityNameMap.count, 1, "map should contain one item")

        removeEntityName(entityId: entityId)

        XCTAssertEqual(entityNameMap.count, 0, "map should contain no items")
    }

    func testFindEntity() {
        let _ = createEntity()
        let entityId = createEntity()

        setEntityName(entityId: entityId, name: "untold")

        let resultId = findEntity(name: "untold")
        let wrongId = findEntity(name: "untold2")

        XCTAssertEqual(entityId, resultId, "entities should match")
        XCTAssertNotEqual(entityId, wrongId, "entities should not match")
    }

    func testGetAllEntityComponentTypes() {
        // Arrange
        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)

        // Act
        let components = getAllEntityComponentsTypes(entityId: entityId)

        // Assert
        XCTAssertEqual(components.count, 2, "Expected entity to have 2 components")

        let expectedTypes: Set<ObjectIdentifier> = [
            ObjectIdentifier(RenderComponent.self),
            ObjectIdentifier(LocalTransformComponent.self),
        ]

        let actualTypes = Set(components.map { ObjectIdentifier($0) })

        XCTAssertEqual(actualTypes, expectedTypes, "Returned component types do not match expected types")
    }

    func testGetAllEntityComponentIds() {
        let entityId = createEntity()

        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)

        var componentIds: [Int] = []

        componentIds = getAllEntityComponentsIds(entityId: entityId)

        XCTAssertTrue(componentIds.contains(getComponentId(for: LocalTransformComponent.self)), "Does not contain component")

        XCTAssertTrue(componentIds.contains(getComponentId(for: RenderComponent.self)), "Does not contain component")
    }

    func testDestroyAllEntities() {
        let _ = createEntity()
        let _ = createEntity()

        destroyAllEntities()

        XCTAssertEqual(scene.getAllEntities().count, 0, "Scene should have no entities")
    }
}

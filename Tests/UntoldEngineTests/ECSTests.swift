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

        // Create a new entity and verify that it reuses the freed index
        let newEntityId = createEntity()
        let newIndex = getEntityIndex(newEntityId)
        XCTAssertEqual(scene.freeEntities.last, nil, "Free entities should be empty after reuse")
        XCTAssertEqual(newIndex, getEntityIndex(entityId), "Entity index should be reused")
    }

    func testDestroyEntityMarksEntityAsFreed() throws {
        // Create an entity
        let entityId = createEntity()
        let entityIndex = getEntityIndex(entityId)

        // Destroy the entity
        destroyEntity(entityId: entityId)

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
}

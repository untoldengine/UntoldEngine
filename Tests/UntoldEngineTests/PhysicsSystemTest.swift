//
//  PhysicsSystemTest.swift
//
//
//  Created by Harold Serrano on 12/19/24.
//

import simd
@testable import UntoldEngine
import XCTest

final class PhysicsSystemTests: XCTestCase {
    var entityId: EntityID!

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()

        entityId = createEntity()
        registerComponent(entityId: entityId, componentType: PhysicsComponents.self)
        registerComponent(entityId: entityId, componentType: KineticComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)
    }

    override func tearDown() {
        destroyEntity(entityId: entityId)
        super.tearDown()
    }

    // MARK: - Mass Tests

    func testSetAndGetMass() {
        let mass: Float = 5.0
        setMass(entityId: entityId, mass: mass)
        let retrievedMass = getMass(entityId: entityId)
        XCTAssertEqual(retrievedMass, mass, "Mass should be correctly set and retrieved.")
    }

    // MARK: - Force Application Tests

    func testApplyForce() {
        let force = simd_float3(10, 0, 0)
        applyForce(entityId: entityId, force: force)

        let kineticComponent = scene.get(component: KineticComponent.self, for: entityId)

        XCTAssertEqual(kineticComponent?.forces.first, force, "Force should be correctly applied.")
    }

    func testClearForces() {
        applyForce(entityId: entityId, force: simd_float3(10, 0, 0))
        clearForces(entityId: entityId)

        let kineticComponent = scene.get(component: KineticComponent.self, for: entityId)

        XCTAssertTrue(kineticComponent?.forces.isEmpty ?? false, "Forces should be cleared.")
    }

    // MARK: - Velocity Tests

    func testGetVelocity() {
        let velocity = simd_float3(5, 0, 0)

        let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId)

        physicsComponent?.velocity = velocity

        let retrievedVelocity = getVelocity(entityId: entityId)
        XCTAssertEqual(retrievedVelocity, velocity, "Velocity should be correctly retrieved.")
    }

    func testVelocityUpdateWithForces() {
        setMass(entityId: entityId, mass: 2.0)

        applyForce(entityId: entityId, force: simd_float3(10, 0, 0))

        updatePhysicsSystem(deltaTime: 1.0)

        let velocity = scene.get(component: PhysicsComponents.self, for: entityId)?.velocity
        XCTAssertEqual(velocity!.x, 5.0, accuracy: 0.01, "z Velocity should be updated correctly.")
        XCTAssertEqual(velocity!.y, 0.0, accuracy: 0.01, "y Velocity should be updated correctly.")
        XCTAssertEqual(velocity!.z, 0.0, accuracy: 0.01, "z Velocity should be updated correctly.")
    }

    func testAccelerationUpdateWithForces() {
        setMass(entityId: entityId, mass: 2.0)

        applyForce(entityId: entityId, force: simd_float3(10, 0, 0))

        updatePhysicsSystem(deltaTime: 1.0)

        let acceleration = scene.get(component: PhysicsComponents.self, for: entityId)?.acceleration
        XCTAssertEqual(acceleration, simd_float3(5, 0, 0), "Acceleration should be correctly calculated.")
    }

    func testPositionnUpdateWithForces() {
        setMass(entityId: entityId, mass: 1.0)
        setGravityScale(entityId: entityId, gravityScale: 1.0)
        updatePhysicsSystem(deltaTime: 1.0)

        let transformComponent = scene.get(component: LocalTransformComponent.self, for: entityId)

        let position = simd_float3(transformComponent!.space.columns.3.x,
                                   transformComponent!.space.columns.3.y,
                                   transformComponent!.space.columns.3.z)

        let expectedPosition = simd_float3(0, -9.8, 0) // Gravity: -9.8, dt = 1.0, initial velocity = 0

        XCTAssertEqual(position.x, expectedPosition.x, accuracy: 0.1, "x Position should be correctly calculated.")
        XCTAssertEqual(position.y, expectedPosition.y, accuracy: 0.1, "y Position should be correctly calculated.")
        XCTAssertEqual(position.z, expectedPosition.z, accuracy: 0.1, "z Position should be correctly calculated.")
    }

    // MARK: - Pause Physics Tests

    func testPausePhysicsComponent() {
        pausePhysicsComponent(entityId: entityId, isPaused: true)
        XCTAssertTrue(isPhysicsComponentPaused(entityId: entityId), "Physics component should be paused.")

        pausePhysicsComponent(entityId: entityId, isPaused: false)
        XCTAssertFalse(isPhysicsComponentPaused(entityId: entityId), "Physics component should be unpaused.")
    }
}

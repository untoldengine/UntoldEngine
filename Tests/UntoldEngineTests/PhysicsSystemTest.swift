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

        var t: Float = 0.1
        while t < 1.0 {
            applyForce(entityId: entityId, force: simd_float3(10, 0, 0))
            updatePhysicsSystem(deltaTime: 0.1)
            t += 0.1
        }

        let velocity = scene.get(component: PhysicsComponents.self, for: entityId)?.velocity
        XCTAssertEqual(velocity!.x, 5.0, accuracy: 0.3, "x Velocity should be updated correctly.")
        XCTAssertEqual(velocity!.y, 0.0, accuracy: 0.3, "y Velocity should be updated correctly.")
        XCTAssertEqual(velocity!.z, 0.0, accuracy: 0.3, "z Velocity should be updated correctly.")
    }

    func testAccelerationUpdateWithForces() {
        setMass(entityId: entityId, mass: 2.0)

        applyForce(entityId: entityId, force: simd_float3(10, 0, 0))

        updatePhysicsSystem(deltaTime: 1.0)

        let acceleration = scene.get(component: PhysicsComponents.self, for: entityId)?.acceleration
        XCTAssertEqual(acceleration, simd_float3(5, 0, 0), "Acceleration should be correctly calculated.")
    }

    func testPositionUpdateWithForces() {
        setMass(entityId: entityId, mass: 2.0)

        var t: Float = 0.1
        while t < 1.0 {
            applyForce(entityId: entityId, force: simd_float3(10, 0, 0))
            updatePhysicsSystem(deltaTime: 0.1)
            t += 0.1
        }

        let transformComponent = scene.get(component: LocalTransformComponent.self, for: entityId)

        let position = simd_float3(transformComponent!.space.columns.3.x,
                                   transformComponent!.space.columns.3.y,
                                   transformComponent!.space.columns.3.z)

        let expectedPosition = simd_float3(2.5, 0.0, 0)

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

    func testSphereMomentInertia() {
        guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
            handleError(.noPhysicsComponent, entityId)
            return
        }

        guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
            handleError(.noLocalTransformComponent, entityId)
            return
        }

        physicsComponent.mass = 1.0

        localTransformComponent.boundingBox = (min: simd_float3(-1.0, -1.0, -1.0), max: simd_float3(1.0, 1.0, 1.0))

        computeInertiaTensor(entityId: entityId)

        XCTAssertEqual(physicsComponent.momentOfInertiaTensor.columns.0.x, 2.0 / 5.0, accuracy: 0.001, "x tensor component should match")
        XCTAssertEqual(physicsComponent.momentOfInertiaTensor.columns.1.y, 2.0 / 5.0, accuracy: 0.001, "y tensor component should match")
        XCTAssertEqual(physicsComponent.momentOfInertiaTensor.columns.2.z, 2.0 / 5.0, accuracy: 0.001, "z tensor component should match")
    }

    func testCylinderMomentInertia() {
        guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
            handleError(.noPhysicsComponent, entityId)
            return
        }

        guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
            handleError(.noLocalTransformComponent, entityId)
            return
        }

        physicsComponent.inertiaTensorType = .cylindrical

        physicsComponent.mass = 1.0

        localTransformComponent.boundingBox = (min: simd_float3(-1.0, -2.0, -1.0), max: simd_float3(1.0, 2.0, 1.0))

        computeInertiaTensor(entityId: entityId)

        XCTAssertEqual(physicsComponent.momentOfInertiaTensor.columns.0.x, 19.0 / 12.0, accuracy: 0.001, "x tensor component should match")
        XCTAssertEqual(physicsComponent.momentOfInertiaTensor.columns.1.y, 19.0 / 12.0, accuracy: 0.001, "y tensor component should match")
        XCTAssertEqual(physicsComponent.momentOfInertiaTensor.columns.2.z, 0.5, accuracy: 0.001, "z tensor component should match")
    }

    func testCubicMomentInertia() {
        guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
            handleError(.noPhysicsComponent, entityId)
            return
        }

        guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
            handleError(.noLocalTransformComponent, entityId)
            return
        }

        physicsComponent.inertiaTensorType = .cubic

        physicsComponent.mass = 1.0

        localTransformComponent.boundingBox = (min: simd_float3(-1.0, -1.0, -1.0), max: simd_float3(1.0, 1.0, 1.0))

        computeInertiaTensor(entityId: entityId)

        XCTAssertEqual(physicsComponent.momentOfInertiaTensor.columns.0.x, 8.0 / 12.0, accuracy: 0.001, "x tensor component should match")
        XCTAssertEqual(physicsComponent.momentOfInertiaTensor.columns.1.y, 8.0 / 12.0, accuracy: 0.001, "y tensor component should match")
        XCTAssertEqual(physicsComponent.momentOfInertiaTensor.columns.2.z, 8.0 / 12.0, accuracy: 0.001, "z tensor component should match")
    }

//    func testAngularAcceleration(){
//
//        guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
//            handleError(.noPhysicsComponent, entityId)
//            return
//        }
//
//        guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
//            handleError(.noLocalTransformComponent, entityId)
//            return
//        }
//
//        physicsComponent.mass = 2.0
//
//        localTransformComponent.boundingBox = (min: simd_float3(-2.0, -2.0, -2.0), max: simd_float3(2.0, 2.0, 2.0))
//
//        computeInertiaTensor(entityId: entityId)
//
//        XCTAssertEqual(physicsComponent.momentOfInertiaTensor.columns.0.x, 3.2, accuracy: 0.001, "x tensor component should match")
//        XCTAssertEqual(physicsComponent.momentOfInertiaTensor.columns.1.y, 3.2, accuracy: 0.001, "y tensor component should match")
//        XCTAssertEqual(physicsComponent.momentOfInertiaTensor.columns.2.z, 3.2, accuracy: 0.001, "z tensor component should match")
//
//        applyMoment(entityId: entityId, force: simd_float3(1.0,0.0,0.0), at: simd_float3(0.0,2.0,0.0))
//
//        accumulateMoment(deltaTime: 0.1)
//
//        XCTAssertEqual(physicsComponent.angularAcceleration.x, 0.0, accuracy: 0.001, "x acceleration component should match")
//        XCTAssertEqual(physicsComponent.angularAcceleration.y, 0.0, accuracy: 0.001, "y acceleration component should match")
//        XCTAssertEqual(physicsComponent.angularAcceleration.z, -0.625, accuracy: 0.001, "z acceleration component should match")
//
//    }

    func testAngularVelocityUpdate() {
        guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
            handleError(.noPhysicsComponent, entityId)
            return
        }

        guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
            handleError(.noLocalTransformComponent, entityId)
            return
        }

        physicsComponent.mass = 2.0

        localTransformComponent.boundingBox = (min: simd_float3(-2.0, -2.0, -2.0), max: simd_float3(2.0, 2.0, 2.0))

        var t: Float = 0.1
        while t < 1.0 {
            applyMoment(entityId: entityId, force: simd_float3(1.0, 0.0, 0.0), at: simd_float3(0.0, 2.0, 0.0))
            updatePhysicsSystem(deltaTime: 0.1)
            t += 0.1
        }

        XCTAssertEqual(physicsComponent.angularVelocity.x, 0.0, accuracy: 0.3, "x velocity component should match")
        XCTAssertEqual(physicsComponent.angularVelocity.y, 0.0, accuracy: 0.3, "y velocity component should match")
        XCTAssertEqual(physicsComponent.angularVelocity.z, -0.625, accuracy: 0.3, "z velocity component should match")
    }

    func testOrientationUpdate() {
        guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
            handleError(.noPhysicsComponent, entityId)
            return
        }

        guard let transform = scene.get(component: LocalTransformComponent.self, for: entityId) else {
            handleError(.noLocalTransformComponent, entityId)
            return
        }

        physicsComponent.mass = 2.0

        transform.boundingBox = (min: simd_float3(-2.0, -2.0, -2.0), max: simd_float3(2.0, 2.0, 2.0))

        var t: Float = 0.1
        while t < 1.0 {
            applyMoment(entityId: entityId, force: simd_float3(1.0, 0.0, 0.0), at: simd_float3(0.0, 2.0, 0.0))
            updatePhysicsSystem(deltaTime: 0.1)
            t += 0.1
        }

        XCTAssertEqual(transform.space.columns.0.x, 0.9878, accuracy: 0.3, "component should match")
        XCTAssertEqual(transform.space.columns.0.y, 0.1556, accuracy: 0.3, "component should match")
        XCTAssertEqual(transform.space.columns.0.z, 0.0, accuracy: 0.3, "component should match")

        XCTAssertEqual(transform.space.columns.1.x, -0.1556, accuracy: 0.3, "component should match")
        XCTAssertEqual(transform.space.columns.1.y, 0.9878, accuracy: 0.3, "component should match")
        XCTAssertEqual(transform.space.columns.1.z, 0.0, accuracy: 0.3, "component should match")

        XCTAssertEqual(transform.space.columns.2.x, 0.0, accuracy: 0.3, "component should match")
        XCTAssertEqual(transform.space.columns.2.y, 0.0, accuracy: 0.3, "component should match")
        XCTAssertEqual(transform.space.columns.2.z, 1.0, accuracy: 0.3, "component should match")
    }
}

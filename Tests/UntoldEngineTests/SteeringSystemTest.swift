//
//  SteeringSystemTest.swift
//
//
//  Created by Harold Serrano on 12/17/24.
//

import simd
@testable import UntoldEngine
import XCTest

final class SteeringSystemTests: XCTestCase {
    var entityId: EntityID!
    var targetEntityId: EntityID!

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()

        entityId = createEntity()
        targetEntityId = createEntity()

        registerTestEntity(entity: entityId)
        registerTestEntity(entity: targetEntityId)

        gameMode = true
    }

    override func tearDown() {
        destroyEntity(entityId: entityId)
        destroyEntity(entityId: targetEntityId)
        super.tearDown()
    }

    func registerTestEntity(entity: EntityID) {
        registerComponent(entityId: entity, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entity, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entity, componentType: ScenegraphComponent.self)
        setEntityKinetics(entityId: entity)
    }

    // MARK: - Seek Test

    func testSeek() {
        let targetPosition = simd_float3(10, 0, 0)
        let maxSpeed: Float = 5.0

        updateTransformSystem(entityId: entityId)
        updateTransformSystem(entityId: targetEntityId)

        let steering = seek(entityId: entityId, targetPosition: targetPosition, maxSpeed: maxSpeed)

        let expectedVelocity = simd_float3(5, 0, 0) // Moving towards the target
        XCTAssertEqual(steering, expectedVelocity)
    }

    // MARK: - Flee Test

    func testFlee() {
        let threatPosition = simd_float3(5, 0, 0)
        let maxSpeed: Float = 5.0

        updateTransformSystem(entityId: entityId)
        updateTransformSystem(entityId: targetEntityId)

        let steering = flee(entityId: entityId, threatPosition: threatPosition, maxSpeed: maxSpeed)

        let expectedVelocity = simd_float3(-5, 0, 0) // Moving away from the threat
        XCTAssertEqual(steering, expectedVelocity)
    }

    // MARK: - Arrive Test

    func testArrive() {
        let targetPosition = simd_float3(3, 0, 0)
        let maxSpeed: Float = 10.0
        let slowingRadius: Float = 5.0

        translateTo(entityId: entityId, position: simd_float3(7, 0, 0))

        updateTransformSystem(entityId: entityId)
        updateTransformSystem(entityId: targetEntityId)

        let steering = arrive(entityId: entityId, targetPosition: targetPosition, maxSpeed: maxSpeed, slowingRadius: slowingRadius)

        let toTarget = targetPosition - getPosition(entityId: entityId)

        // Calculate the expected speed
        let speed = min(maxSpeed, maxSpeed * (length(toTarget) / slowingRadius))

        // Calculate the expected velocity
        let expectedVelocity = normalize(toTarget) * speed

        XCTAssertEqual(steering, expectedVelocity)
    }

    // MARK: - Pursuit Test

    func testPursuit() {
        let maxSpeed: Float = 5.0

        translateTo(entityId: targetEntityId, position: simd_float3(5, 0, 0))

        let physicsComponent = scene.get(component: PhysicsComponents.self, for: targetEntityId)

        physicsComponent?.velocity = simd_float3(2, 0, 0)

        updateTransformSystem(entityId: entityId)
        updateTransformSystem(entityId: targetEntityId)

        let steering = pursuit(entityId: entityId, targetEntity: targetEntityId, maxSpeed: maxSpeed)
        let expectedPrediction = simd_float3(6, 0, 0)
        let expectedSteering = simd_float3(5, 0, 0) // Target future position

        XCTAssertEqual(steering, expectedSteering)
    }

    // MARK: - Evade Test

    func testEvade() {
        let maxSpeed: Float = 5.0

        translateTo(entityId: targetEntityId, position: simd_float3(5, 0, 0))

        let physicsComponent = scene.get(component: PhysicsComponents.self, for: targetEntityId)

        physicsComponent?.velocity = simd_float3(2, 0, 0)
        updateTransformSystem(entityId: entityId)
        updateTransformSystem(entityId: targetEntityId)
        let steering = evade(entityId: entityId, threatEntity: targetEntityId, maxSpeed: maxSpeed)
        let expectedSteering = simd_float3(-5, 0, 0) // Away from predicted threat position

        XCTAssertEqual(steering, expectedSteering)
    }

    // MARK: - Align Orientation Test

    func testAlignOrientation() {
        let direction = simd_float3(1, 0, 0)
        let deltaTime: Float = 2.0
        let turnSpeed: Float = 0.5

        let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId)

        physicsComponent?.velocity = direction

        updateTransformSystem(entityId: entityId)

        alignOrientation(entityId: entityId, targetDirection: direction, deltaTime: deltaTime, turnSpeed: turnSpeed)

        updateTransformSystem(entityId: entityId)
        let orientation = getOrientation(entityId: entityId)
        let expectedForward = simd_float3(1, 0, 0)

        XCTAssertEqual(orientation.columns.2, expectedForward)
    }

    // MARK: - Orbit Test

    func testOrbit() {
        let center = simd_float3(0, 0, 0)
        let radius: Float = 5.0
        let maxSpeed: Float = 2.0
        let deltaTime: Float = 1.0

        translateTo(entityId: entityId, position: simd_float3(radius, 0, 0))

        updateTransformSystem(entityId: entityId)

        orbit(entityId: entityId, centerPosition: center, radius: radius, maxSpeed: maxSpeed, deltaTime: deltaTime)

        updateTransformSystem(entityId: entityId)
        let newPosition = getPosition(entityId: entityId)
        XCTAssertNotEqual(newPosition, simd_float3(radius, 0, 0)) // Position changes around the orbit
    }
}

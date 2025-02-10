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
    let maxSpeed: Float = 5.0

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
        registerComponent(entityId: entity, componentType: PhysicsComponents.self)
        registerComponent(entityId: entity, componentType: KineticComponent.self)
        registerComponent(entityId: entity, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entity, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entity, componentType: ScenegraphComponent.self)
        setEntityKinetics(entityId: entity)

        setMass(entityId: entity, mass: 2.0)
    }

    // MARK: - Seek Test

    func testSeek() {
        let targetPosition = simd_float3(10, 0, 0)

        updatePhysicsSystem(deltaTime: 0.01)

        let steering = seek(entityId: entityId, targetPosition: targetPosition, maxSpeed: maxSpeed)

        let expectedVelocity = simd_float3(5, 0, 0) // Moving towards the target
        XCTAssertEqual(steering, expectedVelocity)
    }

    // MARK: - Flee Test

    func testFlee() {
        let threatPosition = simd_float3(5, 0, 0)

        updatePhysicsSystem(deltaTime: 0.01)

        let steering = flee(entityId: entityId, threatPosition: threatPosition, maxSpeed: maxSpeed)

        let expectedVelocity = simd_float3(-5, 0, 0) // Moving away from the threat
        XCTAssertEqual(steering, expectedVelocity)
    }

    // MARK: - Arrive Test

    func testArrive() {
        let targetPosition = simd_float3(10, 0, 0)
        let slowingRadius: Float = 0.1

        translateTo(entityId: entityId, position: simd_float3(0, 0, 0))

        updatePhysicsSystem(deltaTime: 0.01)

        let steering = arrive(entityId: entityId, targetPosition: targetPosition, maxSpeed: maxSpeed, slowingRadius: slowingRadius)

        let toTarget = targetPosition - getLocalPosition(entityId: entityId)

        // Calculate the expected speed
        let speed = min(maxSpeed, maxSpeed * (length(toTarget) / slowingRadius))

        // Calculate the expected velocity
        let expectedVelocity = normalize(toTarget) * speed

        XCTAssertEqual(steering, expectedVelocity)
    }

    // MARK: - Pursuit Test

    func testPursuit() {
        translateTo(entityId: targetEntityId, position: simd_float3(5, 0, 0))

        let physicsComponent = scene.get(component: PhysicsComponents.self, for: targetEntityId)

        physicsComponent?.velocity = simd_float3(2, 0, 0)

        updatePhysicsSystem(deltaTime: 0.01)

        let steering = pursuit(entityId: entityId, targetEntity: targetEntityId, maxSpeed: maxSpeed)

        let expectedSteering = simd_float3(5, 0, 0) // Target future position

        XCTAssertEqual(steering, expectedSteering)
    }

    // MARK: - Evade Test

    func testEvade() {
        translateTo(entityId: targetEntityId, position: simd_float3(5, 0, 0))

        let physicsComponent = scene.get(component: PhysicsComponents.self, for: targetEntityId)

        physicsComponent?.velocity = simd_float3(2, 0, 0)
        updatePhysicsSystem(deltaTime: 0.01)
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

        updatePhysicsSystem(deltaTime: 0.01)

        alignOrientation(entityId: entityId, targetDirection: direction, deltaTime: deltaTime, turnSpeed: turnSpeed)

        updateTransformSystem(entityId: entityId)
        let orientation = getOrientation(entityId: entityId)
        let expectedForward = simd_float3(1, 0, 0)

        XCTAssertEqual(orientation.columns.2.x, expectedForward.x, accuracy: 0.001)
        XCTAssertEqual(orientation.columns.2.y, expectedForward.y, accuracy: 0.001)
        XCTAssertEqual(orientation.columns.2.z, expectedForward.z, accuracy: 0.001)
    }

    // MARK: - Orbit Test

    func testOrbit() {
        let center = simd_float3(0, 0, 0)
        let radius: Float = 5.0
        let maxSpeed: Float = 2.0
        let deltaTime: Float = 1.0

        translateTo(entityId: entityId, position: simd_float3(radius, 0, 0))

        updatePhysicsSystem(deltaTime: 0.01)

        orbit(entityId: entityId, centerPosition: center, radius: radius, maxSpeed: maxSpeed, deltaTime: deltaTime)

        updateTransformSystem(entityId: entityId)
        let newPosition = getPosition(entityId: entityId)
        XCTAssertNotEqual(newPosition, simd_float3(radius, 0, 0)) // Position changes around the orbit
    }

    func testGetDistanceFromPath() {
        // Mock EntityID and its position
        let entityId: EntityID = 1
        let mockPosition = simd_float3(2, 0, 0)

        // Mock path
        let path: [simd_float3] = [
            simd_float3(0, 0, 0), // Waypoint 1
            simd_float3(5, 0, 0), // Waypoint 2
        ]

        // Mock functions
        func getWaypointIndex(for _: EntityID) -> Int {
            1 // Simulate that the entity is closest to the first waypoint
        }

        func getPosition(entityId _: EntityID) -> simd_float3 {
            mockPosition
        }

        // Run the function
        let distance = getDistanceFromPath(for: entityId, path: path)

        // Expected result: perpendicular distance from (2,0,0) to the line segment (0,0,0) -> (5,0,0) is 0
        let expectedDistance: Float = 0.0

        // Assert the results
        XCTAssertNotNil(distance, "Distance should not be nil for a valid path.")
        XCTAssertEqual(distance, expectedDistance, "Distance should be accurately calculated.")
    }

    func testEmptyPathReturnsNil() {
        let entityId: EntityID = 1
        let path: [simd_float3] = []

        // Run the function
        let distance = getDistanceFromPath(for: entityId, path: path)

        // Assert the results
        XCTAssertNil(distance, "Distance should be nil for an empty path.")
    }

    func testInvalidWaypointIndexHandledGracefully() {
        // Mock EntityID and its position
        let entityId: EntityID = 1
        let mockPosition = simd_float3(2, 0, 0)

        // Mock path
        let path: [simd_float3] = [
            simd_float3(0, 0, 0), // Waypoint 1
            simd_float3(5, 0, 0), // Waypoint 2
        ]

        // Mock functions
        func getWaypointIndex(for _: EntityID) -> Int {
            -10 // Simulate an invalid negative waypoint index
        }

        func getPosition(entityId _: EntityID) -> simd_float3 {
            mockPosition
        }

        // Run the function
        let distance = getDistanceFromPath(for: entityId, path: path)

        // Expected result: Still calculates distance properly from clamped waypoint index
        let expectedDistance: Float = 0.0

        // Assert the results
        XCTAssertNotNil(distance, "Distance should not be nil for a valid path.")
        XCTAssertEqual(distance, expectedDistance, "Distance should be accurately calculated.")
    }

    func testSteerSeek() {
        translateTo(entityId: entityId, position: simd_float3(0.0, 0.0, 0.0))

        clearVelocity(entityId: entityId)

        let targetPosition = simd_float3(10.0, 0.0, 0.0)

        let transformComponent = scene.get(component: LocalTransformComponent.self, for: entityId)

        let deltaTime: Float = 0.01

        var t: Float = 0.0

        let maxSimulationTime: Float = 10.0

        while t < maxSimulationTime {
            steerSeek(entityId: entityId, targetPosition: targetPosition, maxSpeed: maxSpeed, deltaTime: 0.01)

            updatePhysicsSystem(deltaTime: deltaTime)

            t += deltaTime

            // check if the entity is close enough to the target
            let position = getLocalPosition(entityId: entityId)
            if distance(position, targetPosition) < 0.1 {
                break
            }
        }

        let finalPosition = getLocalPosition(entityId: entityId)

        XCTAssertEqual(finalPosition.x, targetPosition.x, accuracy: 0.1, "x Position should be correctly calculated.")
        XCTAssertEqual(finalPosition.y, targetPosition.y, accuracy: 0.1, "y Position should be correctly calculated.")
        XCTAssertEqual(finalPosition.z, targetPosition.z, accuracy: 0.1, "z Position should be correctly calculated.")
    }

    func testSteerArrive() {
        translateTo(entityId: entityId, position: simd_float3(0.0, 0.0, 0.0))

        clearVelocity(entityId: entityId)

        let targetPosition = simd_float3(10.0, 0.0, 0.0)

        let transformComponent = scene.get(component: LocalTransformComponent.self, for: entityId)

        let deltaTime: Float = 0.01

        var t: Float = 0.0

        let maxSimulationTime: Float = 10.0

        while t < maxSimulationTime {
            steerArrive(entityId: entityId, targetPosition: targetPosition, maxSpeed: maxSpeed, slowingRadius: 0.2, deltaTime: 0.01)

            updatePhysicsSystem(deltaTime: deltaTime)

            t += deltaTime

            // check if the entity is close enough to the target
            let position = getLocalPosition(entityId: entityId)
            if distance(position, targetPosition) < 0.1 {
                break
            }
        }

        let finalPosition = getLocalPosition(entityId: entityId)

        XCTAssertEqual(finalPosition.x, targetPosition.x, accuracy: 0.1, "x Position should be correctly calculated.")
        XCTAssertEqual(finalPosition.y, targetPosition.y, accuracy: 0.1, "y Position should be correctly calculated.")
        XCTAssertEqual(finalPosition.z, targetPosition.z, accuracy: 0.1, "z Position should be correctly calculated.")
    }

    func testSteerFlee() {
        translateTo(entityId: entityId, position: simd_float3(0.0, 0.0, 0.0))

        clearVelocity(entityId: entityId)

        let threatPosition = simd_float3(5.0, 0.0, 0.0)

        let deltaTime: Float = 0.01

        var t: Float = 0.0

        let maxSimulationTime: Float = 10.0

        while t < maxSimulationTime {
            steerFlee(entityId: entityId, threatPosition: threatPosition, maxSpeed: maxSpeed, deltaTime: 0.01)

            updatePhysicsSystem(deltaTime: deltaTime)

            t += deltaTime

            // check if the entity is close enough to the target
            let position = getLocalPosition(entityId: entityId)
            if distance(position, threatPosition) > 10.0 {
                break
            }
        }

        let finalPosition = getLocalPosition(entityId: entityId)

        XCTAssertEqual(-finalPosition.x, threatPosition.x, accuracy: 0.1, "x Position should be correctly calculated.")
        XCTAssertEqual(-finalPosition.y, threatPosition.y, accuracy: 0.1, "y Position should be correctly calculated.")
        XCTAssertEqual(-finalPosition.z, threatPosition.z, accuracy: 0.1, "z Position should be correctly calculated.")
    }

    func testSteerPursuit() {
        translateTo(entityId: entityId, position: simd_float3(0.0, 0.0, 1.0))
        translateTo(entityId: targetEntityId, position: simd_float3(0.0, 0.0, -5.0))

        clearVelocity(entityId: entityId)
        clearVelocity(entityId: targetEntityId)

        let targetPosition = simd_float3(20.0, 0.0, 0.0)

        let deltaTime: Float = 0.01

        var t: Float = 0.0

        let maxSimulationTime: Float = 10.0

        while t < maxSimulationTime {
            steerSeek(entityId: targetEntityId, targetPosition: targetPosition, maxSpeed: 1.0, deltaTime: 0.01)

            steerPursuit(entityId: entityId, targetEntity: targetEntityId, maxSpeed: maxSpeed * 10.0, deltaTime: 0.01)

            updatePhysicsSystem(deltaTime: deltaTime)

            t += deltaTime

            // check if the entity is close enough to the target
            let position = getLocalPosition(entityId: entityId)
            let targetEntityPosition = getLocalPosition(entityId: targetEntityId)
            if distance(position, targetEntityPosition) < 0.1 {
                break
            }
        }

        let finalPosition = getLocalPosition(entityId: entityId)
        let finalTargetEntityPosition = getLocalPosition(entityId: targetEntityId)

        XCTAssertEqual(distance(finalPosition, finalTargetEntityPosition), 0.0, accuracy: 0.1, "distances between entities is not close enough")
    }

    func testSteerFollowPath() {
        let path: [simd_float3] = [
            simd_float3(1.0, 0.0, 0.0),
            simd_float3(5.0, 0.0, 0.0),
            simd_float3(10.0, 0.0, 5.0),
            simd_float3(15.0, 0.0, 0.0),
        ]

        var reachedWaypoints: [Bool] = Array(repeating: false, count: path.count)

        translateTo(entityId: entityId, position: simd_float3(0.0, 0.0, 0.0))

        clearVelocity(entityId: entityId)

        let deltaTime: Float = 0.01

        var t: Float = 0.0

        let maxSimulationTime: Float = 10.0

        while t < maxSimulationTime {
            steerFollowPath(entityId: entityId, path: path, maxSpeed: maxSpeed, deltaTime: 0.01)

            updatePhysicsSystem(deltaTime: deltaTime)

            t += deltaTime

            // check if the entity is close enough to any waypoint
            let position = getLocalPosition(entityId: entityId)
            for (i, waypoint) in path.enumerated() {
                if distance(position, waypoint) < 0.5 {
                    reachedWaypoints[i] = true
                }
            }

            // Stop early if all waypoints have been reached
            if reachedWaypoints.allSatisfy({ $0 }) {
                break
            }
        }

        let finalPosition = getLocalPosition(entityId: entityId)
        let lastWayPoint = path.last!

        XCTAssertLessThanOrEqual(distance(finalPosition, lastWayPoint), 0.5, "Entity should have reached last waypoint")

        // Ensure all waypoints were reached
        for (index, reached) in reachedWaypoints.enumerated() {
            XCTAssertTrue(reached, "Waypoint \(index) was not reached")
        }
    }

    func testSteerAvoidObstacles() {
        translateTo(entityId: entityId, position: simd_float3(0.0, 0.0, 0.0))

        clearVelocity(entityId: entityId)

        translateTo(entityId: targetEntityId, position: simd_float3(3.0, 0.0, 0.0))

        clearVelocity(entityId: targetEntityId)

        let obstacles: [EntityID] = [targetEntityId]
        let avoidanceRadius: Float = 1.0
        var avoided = false
        let deltaTime: Float = 0.01

        var t: Float = 0.0

        let maxSimulationTime: Float = 10.0

        while t < maxSimulationTime {
            steerAvoidObstacles(entityId: entityId, obstacles: obstacles, avoidanceRadius: avoidanceRadius, maxSpeed: maxSpeed, deltaTime: deltaTime)

            updatePhysicsSystem(deltaTime: deltaTime)

            t += deltaTime

            // check if the entity is close enough to any waypoint
            let position = getLocalPosition(entityId: entityId)
            let obstaclePosition = getLocalPosition(entityId: targetEntityId)

            if distance(position, obstaclePosition) > avoidanceRadius {
                avoided = true
                break
            }
        }

        XCTAssertTrue(avoided, "Entity should have moved away from the obstacle")

        let finalPosition = getLocalPosition(entityId: entityId)
        let finalDistanceToObstacle = distance(finalPosition, getLocalPosition(entityId: targetEntityId))

        XCTAssertGreaterThan(finalDistanceToObstacle, avoidanceRadius, "Entity should be outside the avoidance radius")
    }

    func testSteerWASD() {
        translateTo(entityId: entityId, position: simd_float3(0.0, 0.0, 0.0))

        clearVelocity(entityId: entityId)

        let targetPosition = simd_float3(1.0, 0.0, 0.0)

        let deltaTime: Float = 0.01

        var t: Float = 0.0

        let maxSimulationTime: Float = 10.0

        inputSystem.keyState.dPressed = true

        while t < maxSimulationTime {
            steerWithWASD(entityId: entityId, maxSpeed: maxSpeed, deltaTime: deltaTime)
            updatePhysicsSystem(deltaTime: deltaTime)

            t += deltaTime

            // check if the entity is close enough to the target
            let position = getLocalPosition(entityId: entityId)
            if distance(position, targetPosition) < 0.1 {
                break
            }
        }

        let finalPosition = getLocalPosition(entityId: entityId)

        XCTAssertEqual(finalPosition.x, targetPosition.x, accuracy: 0.1, "x Position should be correctly calculated.")
        XCTAssertEqual(finalPosition.y, targetPosition.y, accuracy: 0.1, "y Position should be correctly calculated.")
        XCTAssertEqual(finalPosition.z, targetPosition.z, accuracy: 0.1, "z Position should be correctly calculated.")
    }
}

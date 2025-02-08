//
//  SteeringSystem.swift
//
//
//  Created by Harold Serrano on 11/9/24.
//

import Foundation
import simd

var entityWaypointIndices: [EntityID: Int] = [:]

func getWaypointIndex(for entityId: EntityID) -> Int {
    entityWaypointIndices[entityId] ?? 0 // Default to the first waypoint
}

func setWaypointIndex(for entityId: EntityID, index: Int) {
    entityWaypointIndices[entityId] = index
}

public func getDistanceFromPath(for entityId: EntityID, path: [simd_float3]) -> Float? {
    // Return nil if the path is empty
    guard !path.isEmpty else {
        return nil
    }

    // Ensure the current waypoint index is valid
    let currentWaypointIndex = max(0, getWaypointIndex(for: entityId) - 1)
    let nextWaypointIndex = (currentWaypointIndex + 1) % path.count

    // Extract relevant points
    let entityPosition = getPosition(entityId: entityId)
    let startPoint = path[currentWaypointIndex]
    let endPoint = path[nextWaypointIndex]

    // Compute the direction vector and normalize it
    let direction = simd_normalize(endPoint - startPoint)

    // Project the entity's position onto the line segment
    let offset = entityPosition - startPoint
    let projection = dot(offset, direction)
    let closestPointOnPath = startPoint + projection * direction

    // Compute the distance from the entity's position to the closest point
    return distance(entityPosition, closestPointOnPath)
}

// Low-Level Steering Behaviors

func seek(entityId: EntityID, targetPosition: simd_float3, maxSpeed: Float) -> simd_float3 {
    if gameMode == false {
        return simd_float3(0.0, 0.0, 0.0)
    }

    if isPhysicsComponentPaused(entityId: entityId) {
        return simd_float3(0.0, 0.0, 0.0)
    }

    let position = getPosition(entityId: entityId)

    // calculate the desired velocity towards the target
    let desiredVelocity = normalize(targetPosition - position) * maxSpeed

    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    // Compute the final velocity by subtracting the desired velocity minus the current velocity
    return desiredVelocity - physicsComponent.velocity
}

public func flee(entityId: EntityID, threatPosition: simd_float3, maxSpeed: Float) -> simd_float3 {
    if gameMode == false {
        return simd_float3(0.0, 0.0, 0.0)
    }

    if isPhysicsComponentPaused(entityId: entityId) {
        return simd_float3(0.0, 0.0, 0.0)
    }

    let position = getPosition(entityId: entityId)

    // Calculate the desired velocity away from the threat
    let desiredVelocity = normalize(position - threatPosition) * maxSpeed

    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    // Compute the final velocity by subtracting the desired velocity minus the current velocity
    return desiredVelocity - physicsComponent.velocity
}

public func arrive(entityId: EntityID, targetPosition: simd_float3, maxSpeed: Float, slowingRadius: Float) -> simd_float3 {
    if gameMode == false {
        return simd_float3(0.0, 0.0, 0.0)
    }

    if isPhysicsComponentPaused(entityId: entityId) {
        return simd_float3(0.0, 0.0, 0.0)
    }

    let position = getPosition(entityId: entityId)
    let toTarget = targetPosition - position
    let distance = length(toTarget)

    // Adjust speed based on distance to target
    let speed = min(maxSpeed, maxSpeed * (distance / slowingRadius))

    // Calculate the desired velocity
    let desiredVelocity = normalize(toTarget) * speed

    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    // Compute the final velocity by subtracting the desired velocity minus the current velocity
    return desiredVelocity - physicsComponent.velocity
}

public func pursuit(entityId: EntityID, targetEntity: EntityID, maxSpeed: Float) -> simd_float3 {
    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    guard let physicsTargetComponent = scene.get(component: PhysicsComponents.self, for: targetEntity) else {
        handleError(.noPhysicsComponent, targetEntity)
        return simd_float3(0.0, 0.0, 0.0)
    }

    if gameMode == false {
        return simd_float3(0.0, 0.0, 0.0)
    }

    if isPhysicsComponentPaused(entityId: entityId) {
        return simd_float3(0.0, 0.0, 0.0)
    }

    let position = getPosition(entityId: entityId)
    let targetPosition = getPosition(entityId: targetEntity)

    // Estimate where the target entity will be based on its current velocity
    let toTarget = targetPosition - position
    let relativeHeading = dot(normalize(physicsTargetComponent.velocity), normalize(physicsComponent.velocity))

    let predictionTime = (relativeHeading > 0.95) ? (length(toTarget) / maxSpeed) : 0.5
    let futurePosition = targetPosition + physicsTargetComponent.velocity * predictionTime

    // Seek towards the predicted future position of target entity
    return seek(entityId: entityId, targetPosition: futurePosition, maxSpeed: maxSpeed)
}

public func evade(entityId: EntityID, threatEntity: EntityID, maxSpeed: Float) -> simd_float3 {
    guard let physicsThreatComponent = scene.get(component: PhysicsComponents.self, for: threatEntity) else {
        handleError(.noPhysicsComponent, threatEntity)
        return simd_float3(0.0, 0.0, 0.0)
    }

    if gameMode == false {
        return simd_float3(0.0, 0.0, 0.0)
    }

    if isPhysicsComponentPaused(entityId: entityId) {
        return simd_float3(0.0, 0.0, 0.0)
    }

    let position = getPosition(entityId: entityId)
    let threatPosition = getPosition(entityId: threatEntity)

    // Estimate where the threat will be based on its velocity
    let toThreat = threatPosition - position
    let predictionTime = length(toThreat) / maxSpeed
    let futureThreatPosition = threatPosition + physicsThreatComponent.velocity * predictionTime

    // Flee from the predicted future position of the threat
    return flee(entityId: entityId, threatPosition: futureThreatPosition, maxSpeed: maxSpeed)
}

public func alignOrientation(entityId: EntityID, targetDirection _: simd_float3, deltaTime: Float, turnSpeed: Float) {
    if gameMode == false {
        return
    }

    if isPhysicsComponentPaused(entityId: entityId) {
        return
    }

    // Retrieve the entity's current velocity
    let velocity = getVelocity(entityId: entityId)

    // Align the entity's orientation to its movement direction
    if length(velocity) > 0.001 { // Avoid division by zero for stationary entities
        let forwardDirection = normalize(velocity) // Forward direction based on movement
        let upVector = simd_float3(0, 1, 0) // Assuming Y-up coordinate system

        // Calculate the right vector using cross product
        let rightVector = normalize(cross(upVector, forwardDirection))

        // Recalculate the true up vector for orthogonality
        let correctedUpVector = cross(forwardDirection, rightVector)

        // Create the target orientation matrix
        let targetOrientation = simd_float3x3(columns: (
            rightVector, // X-axis (right)
            correctedUpVector, // Y-axis (up)
            forwardDirection // Z-axis (forward)
        ))

        // Retrieve the current orientation matrix
        var currentOrientation = getOrientation(entityId: entityId) // simd_float3x3

        // Smoothly interpolate each column of the orientation matrix
        currentOrientation.columns.0 = mix(currentOrientation.columns.0, targetOrientation.columns.0, t: turnSpeed * deltaTime)
        currentOrientation.columns.1 = mix(currentOrientation.columns.1, targetOrientation.columns.1, t: turnSpeed * deltaTime)
        currentOrientation.columns.2 = mix(currentOrientation.columns.2, targetOrientation.columns.2, t: turnSpeed * deltaTime)

        // Re-orthogonalize the matrix to avoid numerical drift
        let reorthogonalizedRight = normalize(currentOrientation.columns.0)
        let reorthogonalizedForward = normalize(cross(reorthogonalizedRight, currentOrientation.columns.1))
        let reorthogonalizedUp = cross(reorthogonalizedForward, reorthogonalizedRight)

        let finalCurrentOrientation = simd_float4x4(columns: (
            simd_float4(reorthogonalizedRight, 0.0),
            simd_float4(reorthogonalizedUp, 0.0),
            simd_float4(reorthogonalizedForward, 0.0),
            simd_float4(0.0, 0.0, 0.0, 1.0)
        ))

        // Set the new smoothed orientation
        rotateTo(entityId: entityId, rotation: finalCurrentOrientation)
    }
}

public func orbit(entityId: EntityID, centerPosition: simd_float3, radius: Float, maxSpeed: Float, deltaTime: Float, turnSpeed: Float = 1.0) {
    if gameMode == false {
        return
    }

    if isPhysicsComponentPaused(entityId: entityId) {
        return
    }

    guard scene.get(component: LocalTransformComponent.self, for: entityId) != nil else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    // Retrieve the entity's current position and compute relative position to the center
    let currentPosition = getPosition(entityId: entityId)
    let relativePosition = currentPosition - centerPosition

    // Calculate angular velocity (speed around the orbit)
    let angularVelocity = maxSpeed / radius // radians per second

    // Increment angle based on angular velocity and deltaTime
    var currentAngle = atan2(relativePosition.z, relativePosition.x) // Angle in 2D (XZ plane)
    currentAngle += angularVelocity * deltaTime

    // Calculate new position on the orbit (XZ plane)
    let newX = cos(currentAngle) * radius
    let newZ = sin(currentAngle) * radius
    let newPosition = simd_float3(newX, currentPosition.y, newZ) + centerPosition

    // Update the entity's position
    translateTo(entityId: entityId, position: newPosition)

    // Align the entity's orientation to face its tangential direction
    let tangentialDirection = normalize(simd_float3(-sin(currentAngle), 0.0, cos(currentAngle)))
    alignOrientation(entityId: entityId, targetDirection: tangentialDirection, deltaTime: deltaTime, turnSpeed: turnSpeed)
}

// High Level Steering Behaviors

// movement helper functions

/// Moves an entity towards a target position at a specified speed.
/// - Parameters:
///   - entityId: The ID of the entity to move.
///   - targetPosition: The position to move towards.
///   - maxSpeed: The maximum speed of the entity.
///   - deltaTime: The elapsed time for the current frame.
public func steerTo(entityId: EntityID, targetPosition: simd_float3, maxSpeed: Float, deltaTime: Float, turnSpeed: Float = 1.0, weight: Float = 1.0) {
    if gameMode == false {
        return
    }

    if isPhysicsComponentPaused(entityId: entityId) {
        return
    }

    // Check for invalid deltaTime

    guard deltaTime > 0 else {
        print("Warning: deltaTime is zero or negative, skipping movement for entity \(entityId).")
        return
    }

    // Use the seek behavior to calculate the steering velocity adjustment
    let steeringAdjustment = seek(entityId: entityId, targetPosition: targetPosition, maxSpeed: maxSpeed) * weight

    // Convert the velocity adjustment into a force for the physics system
    if let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) {
        let steeringForce = (steeringAdjustment * physicsComponent.mass) / deltaTime
        applyForce(entityId: entityId, force: steeringForce)
    } else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    // Align orientation to face the target
    let currentPosition = getPosition(entityId: entityId)
    let targetDirection = normalize(targetPosition - currentPosition)

    let velocity = getVelocity(entityId: entityId)
    if length(velocity) > 0.001 { // Avoid division by zero for stationary entities
        alignOrientation(entityId: entityId, targetDirection: targetDirection, deltaTime: deltaTime, turnSpeed: turnSpeed)
    }
}

/// Moves an entity towards a target position at a specified speed, slowing down as it approaches the target.
/// - Parameters:
///   - entityId: The ID of the entity to move.
///   - targetPosition: The position to move towards.
///   - maxSpeed: The maximum speed of the entity.
///   - slowingRadius: The radius within which the entity slows down as it approaches the target.
///   - deltaTime: The elapsed time for the current frame.
public func steerTo(entityId: EntityID, targetPosition: simd_float3, maxSpeed: Float, slowingRadius: Float, deltaTime: Float, turnSpeed: Float = 1.0) {
    if gameMode == false {
        return
    }

    if isPhysicsComponentPaused(entityId: entityId) {
        return
    }

    // Check for invalid deltaTime
    guard deltaTime > 0 else {
        print("Warning: deltaTime is zero or negative, skipping movement for entity \(entityId).")
        return
    }

    // Use the arrive behavior to calculate the steering velocity adjustment
    let steeringAdjustment = arrive(entityId: entityId, targetPosition: targetPosition, maxSpeed: maxSpeed, slowingRadius: slowingRadius)

    // Convert the velocity adjustment into a force for the physics system
    if let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) {
        let steeringForce = (steeringAdjustment * physicsComponent.mass) / deltaTime
        applyForce(entityId: entityId, force: steeringForce)
    } else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    // Align orientation to face the target
    let currentPosition = getPosition(entityId: entityId)
    let targetDirection = normalize(targetPosition - currentPosition)

    let velocity = getVelocity(entityId: entityId)
    if length(velocity) > 0.001 { // Avoid division by zero for stationary entities
        alignOrientation(entityId: entityId, targetDirection: targetDirection, deltaTime: deltaTime, turnSpeed: turnSpeed)
    }
}

public func steerWithWASD(entityId: EntityID, maxSpeed: Float, deltaTime: Float, turnSpeed: Float = 1.0, weight: Float = 1.0) {
    if gameMode == false {
        return
    }

    if isPhysicsComponentPaused(entityId: entityId) {
        return
    }

    // Check for invalid deltaTime
    guard deltaTime > 0 else {
        print("Warning: deltaTime is zero or negative, skipping movement for entity \(entityId).")
        return
    }

    let currentPosition = getPosition(entityId: entityId)
    var targetPosition = currentPosition

    if inputSystem.keyState.wPressed {
        targetPosition.z += 1.0
    }

    if inputSystem.keyState.sPressed {
        targetPosition.z -= 1.0
    }

    if inputSystem.keyState.aPressed {
        targetPosition.x -= 1.0
    }

    if inputSystem.keyState.dPressed {
        targetPosition.x += 1.0
    }

    // Use the seek behavior to calculate the steering velocity adjustment
    let finalVelocity = seek(entityId: entityId, targetPosition: targetPosition, maxSpeed: maxSpeed) * weight

    // Convert the velocity adjustment into a force for the physics system
    if let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) {
        let steeringForce = (finalVelocity * physicsComponent.mass) / deltaTime
        applyForce(entityId: entityId, force: steeringForce)
    } else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    // Align orientation to face the target

    let targetDirection = normalize(targetPosition - currentPosition)

    let velocity = getVelocity(entityId: entityId)
    if length(velocity) > 0.001 { // Avoid division by zero for stationary entities
        alignOrientation(entityId: entityId, targetDirection: targetDirection, deltaTime: deltaTime, turnSpeed: turnSpeed)
    }
}

public func steerAway(entityId: EntityID, threatPosition: simd_float3, maxSpeed: Float, deltaTime: Float, turnSpeed: Float = 1.0) {
    if gameMode == false {
        return
    }

    if isPhysicsComponentPaused(entityId: entityId) {
        return
    }

    // Check for invalid deltaTime
    guard deltaTime > 0 else {
        print("Warning: deltaTime is zero or negative, skipping movement for entity \(entityId).")
        return
    }

    // Use the flee behavior to calculate the steering velocity adjustment
    let steeringAdjustment = flee(entityId: entityId, threatPosition: threatPosition, maxSpeed: maxSpeed)

    // Convert the velocity adjustment into a force for the physics system
    if let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) {
        let steeringForce = (steeringAdjustment * physicsComponent.mass) / deltaTime
        applyForce(entityId: entityId, force: steeringForce)
    } else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    // Align orientation to face away from the threat
    let currentPosition = getPosition(entityId: entityId)
    let threatDirection = normalize(threatPosition - currentPosition)
    let fleeDirection = -threatDirection

    let velocity = getVelocity(entityId: entityId)
    if length(velocity) > 0.001 { // Avoid division by zero for stationary entities
        alignOrientation(entityId: entityId, targetDirection: fleeDirection, deltaTime: deltaTime, turnSpeed: turnSpeed)
    }
}

public func steerPursuit(entityId: EntityID, targetEntity: EntityID, maxSpeed: Float, deltaTime: Float, turnSpeed: Float = 1.0) {
    if gameMode == false {
        return
    }

    if isPhysicsComponentPaused(entityId: entityId) {
        return
    }

    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    guard let physicsTargetComponent = scene.get(component: PhysicsComponents.self, for: targetEntity) else {
        handleError(.noPhysicsComponent, targetEntity)
        return
    }

    // Check for invalid deltaTime
    guard deltaTime > 0 else {
        print("Warning: deltaTime is zero or negative, skipping movement for entity \(entityId).")
        return
    }

    // Use the pursuit behavior to calculate the steering velocity adjustment
    let steeringAdjustment = pursuit(entityId: entityId, targetEntity: targetEntity, maxSpeed: maxSpeed)

    // Convert the velocity adjustment into a force for the physics system
    if let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) {
        let steeringForce = (steeringAdjustment * physicsComponent.mass) / deltaTime
        applyForce(entityId: entityId, force: steeringForce)
    } else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    // Align orientation to face the predicted target position
    let position = getPosition(entityId: entityId)
    let targetPosition = getPosition(entityId: targetEntity)

    // Estimate where the target entity will be based on its current velocity
    let toTarget = targetPosition - position
    let relativeHeading = dot(normalize(physicsTargetComponent.velocity), normalize(physicsComponent.velocity))

    let predictionTime = (relativeHeading > 0.95) ? (length(toTarget) / maxSpeed) : 0.5
    let futurePosition = targetPosition + physicsTargetComponent.velocity * predictionTime

    let velocity = getVelocity(entityId: entityId)
    if length(velocity) > 0.001 { // Avoid division by zero for stationary entities
        alignOrientation(entityId: entityId, targetDirection: futurePosition, deltaTime: deltaTime, turnSpeed: turnSpeed)
    }
}

public func followPath(entityId: EntityID, path: [simd_float3], maxSpeed: Float, deltaTime: Float, turnSpeed: Float = 1.0, waypointThreshold: Float = 0.5, weight: Float = 1.0) {
    if gameMode == false {
        return
    }

    if isPhysicsComponentPaused(entityId: entityId) {
        return
    }

    guard !path.isEmpty else {
        print("Path is empty. Nothing to follow.")
        return
    }

    // Retrieve the entity's current position
    let currentPosition = getPosition(entityId: entityId)

    // Keep track of the current waypoint index
    var waypointIndex = getWaypointIndex(for: entityId)

    // Target the current waypoint
    let targetWaypoint = path[waypointIndex]
    let distanceToWaypoint = length(targetWaypoint - currentPosition)

    // Check if the entity has reached the current waypoint
    if distanceToWaypoint <= waypointThreshold {
        waypointIndex += 1 // Move to the next waypoint
        if waypointIndex >= path.count {
            waypointIndex = 0 // Loop back to the first waypoint (or stop if needed)
        }
        setWaypointIndex(for: entityId, index: waypointIndex)
    }

    // Seek toward the current waypoint
    let seekForce = seek(entityId: entityId, targetPosition: targetWaypoint, maxSpeed: maxSpeed) * weight

    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    // Apply the force for movement
    applyForce(entityId: entityId, force: (seekForce * physicsComponent.mass) / deltaTime)

    // Retrieve the entity's current velocity
    let velocity = getVelocity(entityId: entityId)

    // Align the entity's orientation to its movement direction
    if length(velocity) > 0.001 { // Avoid division by zero for stationary entities
        alignOrientation(entityId: entityId, targetDirection: targetWaypoint, deltaTime: deltaTime, turnSpeed: turnSpeed)
    }
}

public func avoidObstacles(entityId: EntityID, obstacles: [EntityID], avoidanceRadius: Float, maxSpeed: Float, deltaTime: Float, turnSpeed: Float = 1.0) {
    if gameMode == false {
        return
    }

    if isPhysicsComponentPaused(entityId: entityId) {
        return
    }

    guard scene.get(component: LocalTransformComponent.self, for: entityId) != nil else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    var avoidanceForce = simd_float3(0.0, 0.0, 0.0)
    let currentPosition = getPosition(entityId: entityId)

    for obstacleId in obstacles {
        guard scene.get(component: LocalTransformComponent.self, for: obstacleId) != nil else {
            handleError(.noLocalTransformComponent, obstacleId)
            continue
        }

        let obstaclePosition = getPosition(entityId: obstacleId)
        let directionToObstacle = obstaclePosition - currentPosition
        let distanceToObstacle = length(directionToObstacle)

        // Only consider obstacles within the avoidance radius
        if distanceToObstacle < avoidanceRadius, distanceToObstacle > 0.01 {
            // Calculate avoidance force proportional to the distance (closer obstacles have stronger repulsion)
            let normalizedDirection = normalize(directionToObstacle)
            let forceMagnitude = (avoidanceRadius - distanceToObstacle) / avoidanceRadius
            let repulsionForce = -normalizedDirection * forceMagnitude * maxSpeed
            avoidanceForce += repulsionForce
        }
    }

    // Limit the magnitude of the avoidance force
    if length(avoidanceForce) > maxSpeed {
        avoidanceForce = normalize(avoidanceForce) * maxSpeed
    }

    // Apply the avoidance force to the entity
    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    applyForce(entityId: entityId, force: (avoidanceForce * physicsComponent.mass) / deltaTime)

    // Align the entity's orientation to its movement direction
    let velocity = getVelocity(entityId: entityId)
    if length(velocity) > 0 {
        alignOrientation(entityId: entityId, targetDirection: normalize(velocity), deltaTime: deltaTime, turnSpeed: turnSpeed)
    }
}

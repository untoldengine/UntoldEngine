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
    return entityWaypointIndices[entityId] ?? 0 // Default to the first waypoint
}

func setWaypointIndex(for entityId: EntityID, index: Int) {
    entityWaypointIndices[entityId] = index
}

public func seek(entityId: EntityID, targetPosition: simd_float3, maxSpeed: Float) -> simd_float3 {

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

    let position = getPosition(entityId: entityId)

    // Calculate the desired velocity away from the threat
    let desiredVelocity = normalize(threatPosition - position) * maxSpeed

    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent,entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    // Compute the final velocity by subtracting the desired velocity minus the current velocity
    return desiredVelocity - physicsComponent.velocity
}

public func arrive(entityId: EntityID, targetPosition: simd_float3, maxSpeed: Float, slowingRadius: Float) -> simd_float3 {

    let position = getPosition(entityId: entityId)
    let toTarget = targetPosition - position
    let distance = length(toTarget)

    // Adjust speed based on distance to target
    let speed = min(maxSpeed, maxSpeed * (distance / slowingRadius))

    // Calculate the desired velocity
    let desiredVelocity = normalize(toTarget) * speed

    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent,entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    // Compute the final velocity by subtracting the desired velocity minus the current velocity
    return desiredVelocity - physicsComponent.velocity
}

public func pursuit(entityId: EntityID, targetEntity: EntityID, maxSpeed: Float) -> simd_float3 {

    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent,entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    guard let physicsTargetComponent = scene.get(component: PhysicsComponents.self, for: targetEntity) else {
        handleError(.noPhysicsComponent,targetEntity)
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

    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent,entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    guard let physicsThreatComponent = scene.get(component: PhysicsComponents.self, for: threatEntity) else {
        handleError(.noPhysicsComponent,threatEntity)
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

public func alignOrientation(entityId: EntityID, targetDirection: simd_float3, deltaTime: Float, turnSpeed: Float) {
    guard let transformComponent = scene.get(component: TransformComponent.self, for: entityId) else {
        handleError(.noTransformComponent, entityId)
        return
    }

    // Get the current forward direction of the entity (model's actual forward vector in local space)
    let modelForward = simd_float3(0, 0, 1) // Assuming the default forward vector for the model is +Z
    let currentForward = normalize(simd_float3(transformComponent.localSpace.columns.2.x,
                                               transformComponent.localSpace.columns.2.y,
                                               transformComponent.localSpace.columns.2.z))

    // User-defined forward vector (e.g., from the model's metadata)
    let userDefinedForward = transformComponent.forwardVector
    let rotationOffset = simd_quatf(from: modelForward, to: userDefinedForward)

    // Adjust the current forward vector based on the user-defined forward
    let adjustedCurrentForward = rotationOffset.act(currentForward)

    // Normalize the target direction
    let normalizedTargetDirection = normalize(targetDirection)

    // Calculate the rotation axis and angle
    let rotationAxis = cross(adjustedCurrentForward, normalizedTargetDirection)
    let dotProduct = dot(adjustedCurrentForward, normalizedTargetDirection)
    let rotationAngle = acos(simd_clamp(dotProduct, -1.0, 1.0)) // Angle between adjusted current and target direction

    // Check if alignment is needed
    if length(rotationAxis) < 0.0001 || rotationAngle < 0.001 {
        // Already aligned or very close, no need to rotate
        return
    }

    // Smoothly rotate towards the target direction based on turnSpeed
    let interpolatedAngle = min(rotationAngle, turnSpeed * deltaTime)
    let rotationMatrix = matrix4x4Rotation(radians: interpolatedAngle, axis: normalize(rotationAxis))

    // Apply the rotation
    let currentTransform = transformComponent.localSpace
    let updatedRotation = simd_mul(currentTransform, rotationMatrix)
    transformComponent.localSpace = updatedRotation
}


// movement helper functions

/// Moves an entity towards a target position at a specified speed.
/// - Parameters:
///   - entityId: The ID of the entity to move.
///   - targetPosition: The position to move towards.
///   - maxSpeed: The maximum speed of the entity.
///   - deltaTime: The elapsed time for the current frame.
public func moveTo(entityId: EntityID, targetPosition: simd_float3, maxSpeed: Float, deltaTime: Float, turnSpeed: Float = 1.0) {

    if gameMode == false {
        return
    }

    // Check for invalid deltaTime

    guard deltaTime > 0 else {
        print("Warning: deltaTime is zero or negative, skipping movement for entity \(entityId).")
        return
    }

    // Use the seek behavior to calculate the steering velocity adjustment
    let steeringAdjustment = seek(entityId: entityId, targetPosition: targetPosition, maxSpeed: maxSpeed)

    // Convert the velocity adjustment into a force for the physics system
    if let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) {
        let steeringForce = (steeringAdjustment * physicsComponent.mass) / deltaTime
        applyForce(entityId: entityId, force: steeringForce)
    } else {
        handleError(.noPhysicsComponent,entityId)
        return
    }

    // Align orientation to face the target
    let currentPosition = getPosition(entityId: entityId)
    let targetDirection = normalize(targetPosition - currentPosition)
    alignOrientation(entityId: entityId, targetDirection: targetDirection, deltaTime: deltaTime, turnSpeed: turnSpeed)
}

/// Moves an entity towards a target position at a specified speed, slowing down as it approaches the target.
/// - Parameters:
///   - entityId: The ID of the entity to move.
///   - targetPosition: The position to move towards.
///   - maxSpeed: The maximum speed of the entity.
///   - slowingRadius: The radius within which the entity slows down as it approaches the target.
///   - deltaTime: The elapsed time for the current frame.
public func moveTo(entityId: EntityID, targetPosition: simd_float3, maxSpeed: Float, slowingRadius: Float, deltaTime: Float, turnSpeed: Float = 1.0) {

    if gameMode == false {
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
        handleError(.noPhysicsComponent,entityId)
        return
    }

    // Align orientation to face the target
    let currentPosition = getPosition(entityId: entityId)
    let targetDirection = normalize(targetPosition - currentPosition)
    alignOrientation(entityId: entityId, targetDirection: targetDirection, deltaTime: deltaTime, turnSpeed: turnSpeed)
}

public func orbit(entityId: EntityID, centerPosition: simd_float3, radius: Float, maxSpeed: Float, deltaTime: Float, turnSpeed: Float = 1.0) {

    if gameMode == false {
        return
    }

    guard scene.get(component: TransformComponent.self, for: entityId) != nil else {
        handleError(.noTransformComponent, entityId)
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

public func followPath(entityId: EntityID, path: [simd_float3], maxSpeed: Float, deltaTime: Float, turnSpeed: Float = 1.0) {

    if gameMode == false {
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
    let waypointThreshold: Float = 0.1 // Threshold to determine when a waypoint is "reached"

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
    let seekForce = seek(entityId: entityId, targetPosition: targetWaypoint, maxSpeed: maxSpeed)
    
    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId)else{
        handleError(.noPhysicsComponent,entityId)
        return
    }
    
    applyForce(entityId: entityId, force: (seekForce * physicsComponent.mass) / deltaTime)

    // Align the entity's orientation to its movement direction
    let velocity = getVelocity(entityId: entityId)
    if length(velocity) > 0 {
        alignOrientation(entityId: entityId, targetDirection: normalize(velocity), deltaTime: deltaTime, turnSpeed: turnSpeed)
    }
}

public func avoidObstacles(entityId: EntityID, obstacles: [EntityID], avoidanceRadius: Float, maxSpeed: Float, deltaTime: Float, turnSpeed: Float = 1.0) {

    if gameMode == false {
        return
    }

    guard scene.get(component: TransformComponent.self, for: entityId) != nil else {
        handleError(.noTransformComponent, entityId)
        return
    }

    var avoidanceForce = simd_float3(0.0, 0.0, 0.0)
    let currentPosition = getPosition(entityId: entityId)

    for obstacleId in obstacles {
        guard scene.get(component: TransformComponent.self, for: obstacleId) != nil else {
            handleError(.noTransformComponent, obstacleId)
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
    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else{
        handleError(.noPhysicsComponent,entityId)
        return
    }
    
    applyForce(entityId: entityId, force: (avoidanceForce * physicsComponent.mass) / deltaTime)

    // Align the entity's orientation to its movement direction
    let velocity = getVelocity(entityId: entityId)
    if length(velocity) > 0 {
        alignOrientation(entityId: entityId, targetDirection: normalize(velocity), deltaTime: deltaTime, turnSpeed: turnSpeed)
    }
}

//
//  File.swift
//
//
//  Created by Harold Serrano on 11/9/24.
//

import Foundation
import simd

public func seek(entityId: EntityID, targetPosition: simd_float3, maxSpeed: Float)->simd_float3 {
    guard let transform = scene.get(component: Transform.self, for: entityId) else {
        print("entity with id: \(entityId) not found")
        return simd_float3(0.0, 0.0, 0.0)
    }
    
    var position = getPosition(entityId: entityId)
    
    // calculate the desired velocity towards the target
    let desiredVelocity = normalize(targetPosition - position) * maxSpeed
    
    guard let physics = scene.get(component: Physics.self, for: entityId) else {
        print("entity with id: \(entityId) not found")
        return simd_float3(0.0, 0.0, 0.0)
    }
    
    // Compute the final velocity by subtracting the desired velocity minus the current velocity
    return desiredVelocity - physics.velocity
}

public func flee(entityId: EntityID, threatPosition: simd_float3, maxSpeed: Float)->simd_float3 {
    guard let transform = scene.get(component: Transform.self, for: entityId) else {
        print("entity with id: \(entityId) not found")
        return simd_float3(0.0, 0.0, 0.0)
    }
    
    var position = getPosition(entityId: entityId)
    
    // Calculate the desired velocity away from the threat
    let desiredVelocity = normalize(threatPosition - position) * maxSpeed
    
    guard let physics = scene.get(component: Physics.self, for: entityId) else {
        print("entity with id: \(entityId) not found")
        return simd_float3(0.0, 0.0, 0.0)
    }
    
    // Compute the final velocity by subtracting the desired velocity minus the current velocity
    return desiredVelocity - physics.velocity
}

public func arrive(entityId: EntityID, targetPosition: simd_float3, maxSpeed: Float, slowingRadius: Float)->simd_float3 {
    guard let transform = scene.get(component: Transform.self, for: entityId) else {
        print("entity with id: \(entityId) not found")
        return simd_float3(0.0, 0.0, 0.0)
    }
    
    let position = getPosition(entityId: entityId)
    let toTarget = targetPosition - position
    let distance = length(toTarget)
    
    // Adjust speed based on distance to target
    let speed = min(maxSpeed, maxSpeed * (distance/slowingRadius))
    
    // Calculate the desired velocity
    let desiredVelocity = normalize(toTarget) * speed
    
    guard let physics = scene.get(component: Physics.self, for: entityId) else {
        print("entity with id: \(entityId) not found")
        return simd_float3(0.0, 0.0, 0.0)
    }
    
    // Compute the final velocity by subtracting the desired velocity minus the current velocity
    return desiredVelocity - physics.velocity
}

public func pursuit(entityId: EntityID, targetEntity: EntityID, maxSpeed: Float)->simd_float3 {
    guard let transformEntity = scene.get(component: Transform.self, for: entityId) else {
        print("entity with id: \(entityId) not found")
        return simd_float3(0.0, 0.0, 0.0)
    }
    
    guard let physicsEntity = scene.get(component: Physics.self, for: entityId) else {
        print("entity with id: \(entityId) not found")
        return simd_float3(0.0, 0.0, 0.0)
    }
    
    guard let transformTargetEntity = scene.get(component: Transform.self, for: targetEntity) else {
        print("entity with id: \(entityId) not found")
        return simd_float3(0.0, 0.0, 0.0)
    }
    
    guard let physicsTargetEntity = scene.get(component: Physics.self, for: targetEntity) else {
        print("entity with id: \(entityId) not found")
        return simd_float3(0.0, 0.0, 0.0)
    }
    
    var position = getPosition(entityId: entityId)
    var targetPosition = getPosition(entityId: targetEntity)
    
    // Estimate where the target entity will be based on its current velocity
    let toTarget = targetPosition - position
    let relativeHeading = dot(normalize(physicsTargetEntity.velocity), normalize(physicsEntity.velocity))
    
    let predictionTime = (relativeHeading > 0.95) ? (length(toTarget)/maxSpeed) : 0.5
    let futurePosition = targetPosition + physicsTargetEntity.velocity * predictionTime
    
    // Seek towards the predicted future position of target entity
    return seek(entityId: entityId, targetPosition: futurePosition, maxSpeed: maxSpeed)
}

public func evade(entityId: EntityID, threatEntity: EntityID, maxSpeed: Float)->simd_float3 {
    guard let transformEntity = scene.get(component: Transform.self, for: entityId) else {
        print("entity with id: \(entityId) not found")
        return simd_float3(0.0, 0.0, 0.0)
    }
    
    guard let physicsEntity = scene.get(component: Physics.self, for: entityId) else {
        print("entity with id: \(entityId) not found")
        return simd_float3(0.0, 0.0, 0.0)
    }
    
    guard let transformThreatEntity = scene.get(component: Transform.self, for: threatEntity) else {
        print("entity with id: \(entityId) not found")
        return simd_float3(0.0, 0.0, 0.0)
    }
    
    guard let physicsThreatEntity = scene.get(component: Physics.self, for: threatEntity) else {
        print("entity with id: \(entityId) not found")
        return simd_float3(0.0, 0.0, 0.0)
    }
    
    var position = getPosition(entityId: entityId)
    var threatPosition = getPosition(entityId: threatEntity)
    
    // Estimate where the threat will be based on its velocity
    let toThreat = threatPosition - position
    let predictionTime = length(toThreat)/maxSpeed
    let futureThreatPosition = threatPosition + physicsThreatEntity.velocity * predictionTime
    
    // Flee from the predicted future position of the threat
    return flee(entityId: entityId, threatPosition: futureThreatPosition, maxSpeed: maxSpeed)
}

//
//  PhysicsSystem.swift
//
//
//  Created by Harold Serrano on 11/9/24.
//

import Foundation
import simd

public func setMass(entityId: EntityID, mass: Float) {
    // retrieve physics component
    guard let physics = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    physics.mass = mass
}

public func setGravityScale(entityId: EntityID, gravityScale: Float) {
    guard let kinetic = scene.get(component: KineticComponent.self, for: entityId) else {
        handleError(.noKineticComponent, entityId)
        return
    }

    kinetic.gravityScale = gravityScale
}

public func updatePhysicsSystem(deltaTime: Float) {
    addGravity(gravity: simd_float3(0.0, -9.0, 0.0)) // add gravity
    accumulateForces(deltaTime: deltaTime) // Apply accumulated forces to acceleration
    eulerIntegration(deltaTime: deltaTime) // Update velocity and position
}

public func addGravity(gravity: simd_float3) {
    let kineticId = getComponentId(for: KineticComponent.self)
    let entities = queryEntitiesWithComponentIds([kineticId], in: scene)

    for entity in entities {
        guard let kinetic = scene.get(component: KineticComponent.self, for: entity) else {
            handleError(.noKineticComponent, entity)
            continue
        }

        // add gravity
        kinetic.addForce(gravity * kinetic.gravityScale)
    }
}

public func accumulateForces(deltaTime _: Float) {
    let kineticId = getComponentId(for: KineticComponent.self)
    let physicsId = getComponentId(for: PhysicsComponents.self)
    let entities = queryEntitiesWithComponentIds([kineticId, physicsId], in: scene)

    for entity in entities {
        guard let physics = scene.get(component: PhysicsComponents.self, for: entity) else {
            continue
        }

        guard let kinetic = scene.get(component: KineticComponent.self, for: entity) else {
            continue
        }

        // sum up all forces
        var totalForce = simd_float3(0.0, 0.0, 0.0)
        for force in kinetic.forces {
            totalForce += force
        }

        // Calculate acceleration based on accumulated forces
        physics.acceleration = totalForce / physics.mass

        // clear forces after applying them
        kinetic.clearForces()
    }
}

public func applyForce(entityId: EntityID, force: simd_float3) {
    guard let kinetic = scene.get(component: KineticComponent.self, for: entityId) else {
        handleError(.noKineticComponent, entityId)
        return
    }

    kinetic.addForce(force)
}

public func eulerIntegration(deltaTime: Float) {
    // all all the forces for the entity
    let kineticId = getComponentId(for: KineticComponent.self)
    let physicsId = getComponentId(for: PhysicsComponents.self)
    let transformId = getComponentId(for: TransformComponent.self)

    let entities = queryEntitiesWithComponentIds([kineticId, physicsId, transformId], in: scene)

    for entity in entities {
        guard let physics = scene.get(component: PhysicsComponents.self, for: entity) else {
            continue
        }

        guard let transform = scene.get(component: TransformComponent.self, for: entity) else {
            continue
        }

        // update velocity based on acceleration
        physics.velocity += physics.acceleration * deltaTime

        // update position based on velocity
        var position = getPosition(entityId: entity)
        position += physics.velocity * deltaTime

        transform.localSpace.columns.3.x = position.x
        transform.localSpace.columns.3.y = position.y
        transform.localSpace.columns.3.z = position.z
    }
}

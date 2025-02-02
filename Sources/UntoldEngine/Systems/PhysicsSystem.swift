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

public func getMass(entityId: EntityID) -> Float {
    // retrieve physics component
    guard let physics = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return 0.0
    }

    return physics.mass
}

public func setDragCoefficient(entityId: EntityID, coefficients: simd_float2) {
    guard let physics = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    physics.dragCoefficients = coefficients
}

public func getDragCoefficient(entityId: EntityID) -> simd_float2 {
    guard let physics = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return simd_float2(0.0, 0.0)
    }

    return physics.dragCoefficients
}

public func setGravityScale(entityId: EntityID, gravityScale: Float) {
    guard let kinetic = scene.get(component: KineticComponent.self, for: entityId) else {
        handleError(.noKineticComponent, entityId)
        return
    }

    kinetic.gravityScale = gravityScale
}

public func getVelocity(entityId: EntityID) -> simd_float3 {
    guard let physics = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    return physics.velocity
}

public func updatePhysicsSystem(deltaTime: Float) {
    addGravity(gravity: simd_float3(0.0, -9.8, 0.0)) // add gravity
    accumulateDrag(deltaTime: deltaTime)
    accumulateForces(deltaTime: deltaTime) // Apply accumulated forces to acceleration
    accumulateMoment(deltaTime: deltaTime)
    rungeKuttaIntegration(deltaTime: deltaTime) // Update velocity and position
}

private func addGravity(gravity: simd_float3) {
    let kineticId = getComponentId(for: KineticComponent.self)
    let physicsId = getComponentId(for: PhysicsComponents.self)

    let entities = queryEntitiesWithComponentIds([kineticId, physicsId], in: scene)

    for entity in entities {
        guard let kinetic = scene.get(component: KineticComponent.self, for: entity) else {
            handleError(.noKineticComponent, entity)
            continue
        }

        if isPhysicsComponentPaused(entityId: entity) {
            continue
        }

        guard isValid(gravity) else {
            handleError(.valueisNaN, "Gravity", entity)
            return
        }

        // add gravity
        kinetic.addForce(gravity * kinetic.gravityScale)
    }
}

private func accumulateForces(deltaTime _: Float) {
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

        if isPhysicsComponentPaused(entityId: entity) {
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

private func accumulateMoment(deltaTime _: Float) {
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

        if isPhysicsComponentPaused(entityId: entity) {
            continue
        }

        computeInertiaTensor(entityId: entity)

        // sum up all moments
        var totalMoment = simd_float3(0.0, 0.0, 0.0)
        for moment in kinetic.moments {
            totalMoment += moment
        }

        // Calculate angular acceleration based on accumulated forces
        physics.angularAcceleration = physics.inverseMomentOfInertiaTensor * (totalMoment - cross(physics.angularVelocity, physics.momentOfInertiaTensor * physics.angularVelocity))

        // clear moments after applying them
        kinetic.clearMoments()
    }
}

func accumulateDrag(deltaTime _: Float) {
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

        if isPhysicsComponentPaused(entityId: entity) {
            continue
        }

        let dragCoeff = physics.dragCoefficients
        let k1: Float = dragCoeff.x
        let k2: Float = dragCoeff.y

        var linearDrag: simd_float3
        var forceDragCoeff: Float

        linearDrag = physics.velocity
        forceDragCoeff = simd.length(linearDrag)

        forceDragCoeff = k1 * forceDragCoeff + k2 * forceDragCoeff * forceDragCoeff

        linearDrag = safeNormalize(linearDrag)
        linearDrag *= -forceDragCoeff

        kinetic.addForce(linearDrag)

        // moment
        var angularDrag: simd_float3
        var momentDragCoeff: Float

        angularDrag = physics.angularVelocity
        momentDragCoeff = simd.length(angularDrag)

        momentDragCoeff = k1 * momentDragCoeff + k2 * momentDragCoeff * momentDragCoeff

        angularDrag = safeNormalize(angularDrag)
        angularDrag *= -momentDragCoeff

        kinetic.addMoment(angularDrag)
    }
}

public func applyForce(entityId: EntityID, force: simd_float3) {
    guard let kinetic = scene.get(component: KineticComponent.self, for: entityId) else {
        handleError(.noKineticComponent, entityId)
        return
    }

    guard isValid(force) else {
        handleError(.valueisNaN, "Force", entityId)
        return
    }

    kinetic.addForce(force)
}

public func applyMoment(entityId: EntityID, force: simd_float3, at point: simd_float3) {
    guard let kinetic = scene.get(component: KineticComponent.self, for: entityId) else {
        handleError(.noKineticComponent, entityId)
        return
    }

    guard let physics = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    guard isValid(force) else {
        handleError(.valueisNaN, "Force", entityId)
        return
    }

    // calculate lever arm
    let r = point - physics.centerOfMass

    // calculate torque
    let torque = simd_cross(r, force)

    kinetic.addMoment(torque)
}

public func clearForces(entityId: EntityID) {
    guard let kinetic = scene.get(component: KineticComponent.self, for: entityId) else {
        handleError(.noKineticComponent, entityId)
        return
    }

    kinetic.clearForces()
}

public func clearMoment(entityId: EntityID) {
    guard let kinetic = scene.get(component: KineticComponent.self, for: entityId) else {
        handleError(.noKineticComponent, entityId)
        return
    }

    kinetic.clearMoments()
}

/// pause physics component for entity
public func pausePhysicsComponent(entityId: EntityID, isPaused: Bool) {
    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    physicsComponent.pause = isPaused
}

/// Is physics component paused for a particular entity
public func isPhysicsComponentPaused(entityId: EntityID) -> Bool {
    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return false
    }

    return physicsComponent.pause
}

private func rungeKuttaIntegration(deltaTime: Float) {
    // all all the forces for the entity
    let kineticId = getComponentId(for: KineticComponent.self)
    let physicsId = getComponentId(for: PhysicsComponents.self)
    let transformId = getComponentId(for: LocalTransformComponent.self)

    let entities = queryEntitiesWithComponentIds([kineticId, physicsId, transformId], in: scene)

    for entity in entities {
        guard let physics = scene.get(component: PhysicsComponents.self, for: entity) else {
            continue
        }

        guard let transform = scene.get(component: LocalTransformComponent.self, for: entity) else {
            continue
        }

        if isPhysicsComponentPaused(entityId: entity) {
            continue
        }

        let rungeFactor: Float = 1.0 / 6.0

        // update velocity based on acceleration
        let k1v: simd_float3 = (physics.acceleration) * deltaTime
        let k2v: simd_float3 = (physics.acceleration + k1v * 0.5) * deltaTime
        let k3v: simd_float3 = (physics.acceleration + k2v * 0.5) * deltaTime
        let k4v: simd_float3 = (physics.acceleration + k3v) * deltaTime

        let velocityDelta = (k1v + 2.0 * k2v + 2.0 * k3v + k4v) * rungeFactor

        physics.velocity = physics.velocity + velocityDelta

        // update position based on velocity
        var position = getLocalPosition(entityId: entity)

        let k1x: simd_float3 = (physics.velocity) * deltaTime
        let k2x: simd_float3 = (physics.velocity + k1x * 0.5) * deltaTime
        let k3x: simd_float3 = (physics.velocity + k2x * 0.5) * deltaTime
        let k4x: simd_float3 = (physics.velocity + k3x) * deltaTime

        let positionDelta = (k1x + 2.0 * k2x + 2.0 * k3x + k4x) * rungeFactor
        position = position + positionDelta

        transform.space.columns.3 = simd_float4(position.x, position.y, position.z, 1.0)

        // update angular velocity and orientation
        let k1av: simd_float3 = (physics.angularAcceleration) * deltaTime
        let k2av: simd_float3 = (physics.angularAcceleration + k1av * 0.5) * deltaTime
        let k3av: simd_float3 = (physics.angularAcceleration + k2av * 0.5) * deltaTime
        let k4av: simd_float3 = (physics.angularAcceleration + k3av) * deltaTime

        let angularVelocityDelta = (k1av + 2.0 * k2av + 2.0 * k3av + k4av) * rungeFactor

        // update angular velocity
        physics.angularVelocity = physics.angularVelocity + angularVelocityDelta

        // update orientation
        var orientationMatrix: simd_float3x3 = getLocalOrientation(entityId: entity)
        var orientationQuaternion = transformMatrix3nToQuaternion(m: orientationMatrix)
        let eulerAngles = transformQuaternionToEulerAngles(q: orientationQuaternion)

        var orientation = simd_float3(eulerAngles.pitch, eulerAngles.yaw, eulerAngles.roll)

        let k1ax: simd_float3 = (physics.angularVelocity) * deltaTime
        let k2ax: simd_float3 = (physics.angularVelocity + k1ax * 0.5) * deltaTime
        let k3ax: simd_float3 = (physics.angularVelocity + k2ax * 0.5) * deltaTime
        let k4ax: simd_float3 = (physics.angularVelocity + k3ax) * deltaTime

        let orientationDelta = (k1ax + 2.0 * k2ax + 2.0 * k3ax + k4ax) * rungeFactor
        orientation = orientation + orientationDelta

        orientationQuaternion = transformEulerAnglesToQuaternion(pitch: orientation.x, yaw: orientation.y, roll: orientation.z)

        orientationMatrix = transformQuaternionToMatrix3x3(q: orientationQuaternion)

        transform.space.columns.0 = simd_float4(orientationMatrix.columns.0, 0.0)
        transform.space.columns.1 = simd_float4(orientationMatrix.columns.1, 0.0)
        transform.space.columns.2 = simd_float4(orientationMatrix.columns.2, 0.0)
    }
}

private func eulerIntegration(deltaTime: Float) {
    // all all the forces for the entity
    let kineticId = getComponentId(for: KineticComponent.self)
    let physicsId = getComponentId(for: PhysicsComponents.self)
    let transformId = getComponentId(for: LocalTransformComponent.self)

    let entities = queryEntitiesWithComponentIds([kineticId, physicsId, transformId], in: scene)

    for entity in entities {
        guard let physics = scene.get(component: PhysicsComponents.self, for: entity) else {
            continue
        }

        guard let transform = scene.get(component: LocalTransformComponent.self, for: entity) else {
            continue
        }

        if isPhysicsComponentPaused(entityId: entity) {
            continue
        }

        // update velocity based on acceleration
        physics.velocity += physics.acceleration * deltaTime

        // update position based on velocity
        var position = getPosition(entityId: entity)
        position += physics.velocity * deltaTime

        transform.space.columns.3.x = position.x
        transform.space.columns.3.y = position.y
        transform.space.columns.3.z = position.z
    }
}

func computeInertiaTensor(entityId: EntityID) {
    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    if physicsComponent.inertiaTensorComputed {
        return
    }

    var tensor: simd_float3x3 = .init(diagonal: simd_float3(1.0, 1.0, 1.0))

    var Ixx: Float = 0.0
    var Iyy: Float = 0.0
    var Izz: Float = 0.0

    var Ixy: Float = 0.0
    var Ixz: Float = 0.0
    var Iyz: Float = 0.0

    // get body dimensions
    var uX: Float = abs(localTransformComponent.boundingBox.1.x - localTransformComponent.boundingBox.0.x)
    var uY: Float = abs(localTransformComponent.boundingBox.1.y - localTransformComponent.boundingBox.0.y)
    var uZ: Float = abs(localTransformComponent.boundingBox.1.z - localTransformComponent.boundingBox.0.z)

    if physicsComponent.inertiaTensorType == .spherical {
        uX = uX / 2.0
        uY = uY / 2.0
        uZ = uZ / 2.0

        // Inertia Tensor for spherical bodies
        Ixx = (2 * uX * uX) * physicsComponent.mass / 5.0
        Iyy = (2 * uX * uX) * physicsComponent.mass / 5.0
        Izz = (2 * uX * uX) * physicsComponent.mass / 5.0

        Ixy = physicsComponent.mass * (physicsComponent.centerOfMass.x * physicsComponent.centerOfMass.y)
        Ixz = physicsComponent.mass * (physicsComponent.centerOfMass.x * physicsComponent.centerOfMass.z)
        Iyz = physicsComponent.mass * (physicsComponent.centerOfMass.y * physicsComponent.centerOfMass.z)

    } else if physicsComponent.inertiaTensorType == .cylindrical {
        uX = uX / 2.0

        Ixx = (3 * uX * uX + uY * uY) * physicsComponent.mass / 12.0
        Iyy = (3 * uX * uX + uY * uY) * physicsComponent.mass / 12.0
        Izz = (uX * uX) * physicsComponent.mass / 2.0

        Ixy = physicsComponent.mass * (physicsComponent.centerOfMass.x * physicsComponent.centerOfMass.y)
        Ixz = physicsComponent.mass * (physicsComponent.centerOfMass.x * physicsComponent.centerOfMass.z)
        Iyz = physicsComponent.mass * (physicsComponent.centerOfMass.y * physicsComponent.centerOfMass.z)

    } else {
        // Inertia Tensor for cubic bodies
        Ixx = (uY * uY + uZ * uZ) * physicsComponent.mass / 12.0
        Iyy = (uX * uX + uZ * uZ) * physicsComponent.mass / 12.0
        Izz = (uX * uX + uY * uY) * physicsComponent.mass / 12.0

        Ixy = physicsComponent.mass * (physicsComponent.centerOfMass.x * physicsComponent.centerOfMass.y)
        Ixz = physicsComponent.mass * (physicsComponent.centerOfMass.x * physicsComponent.centerOfMass.z)
        Iyz = physicsComponent.mass * (physicsComponent.centerOfMass.y * physicsComponent.centerOfMass.z)
    }

    tensor.columns.0.x = Ixx
    tensor.columns.1.y = Iyy
    tensor.columns.2.z = Izz

    tensor.columns.1.x = -Ixy
    tensor.columns.2.x = -Ixz
    tensor.columns.2.y = Iyz

    tensor.columns.0.y = -Ixy
    tensor.columns.0.z = -Ixz
    tensor.columns.1.z = -Iyz

    physicsComponent.momentOfInertiaTensor = tensor
    physicsComponent.inverseMomentOfInertiaTensor = tensor.inverse

    physicsComponent.inertiaTensorComputed = true
}

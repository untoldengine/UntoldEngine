//
//  PhysicsSystem.swift
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
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

public func setLinearDragCoefficient(entityId: EntityID, coefficients: simd_float2) {
    guard let physics = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    physics.linearDragCoefficients = coefficients
}

public func getLinearDragCoefficient(entityId: EntityID) -> simd_float2 {
    guard let physics = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return simd_float2(0.0, 0.0)
    }

    return physics.linearDragCoefficients
}

public func setAngularDragCoefficient(entityId: EntityID, coefficients: simd_float2) {
    guard let physics = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    physics.angularDragCoefficients = coefficients
}

public func getAngularDragCoefficient(entityId: EntityID) -> simd_float2 {
    guard let physics = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return simd_float2(0.0, 0.0)
    }

    return physics.angularDragCoefficients
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

public func setVelocity(entityId: EntityID, velocity: simd_float3) {
    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    physicsComponent.velocity = velocity
}

public func updatePhysicsSystem(deltaTime: Float) {
    let kineticId = getComponentId(for: KineticComponent.self)
    let physicsId = getComponentId(for: PhysicsComponents.self)
    let transformId = getComponentId(for: LocalTransformComponent.self)
    let entities = queryEntitiesWithComponentIds([kineticId, physicsId, transformId], in: scene)

    for entity in entities {
        if isPhysicsComponentPaused(entityId: entity) {
            continue
        }

        addGravity(entityId: entity, gravity: simd_float3(0.0, -9.8, 0.0)) // add gravity
        addDrag(entityId: entity, deltaTime: deltaTime)
        accumulateForces(entityId: entity, deltaTime: deltaTime) // Apply accumulated forces to acceleration
        accumulateMoment(entityId: entity, deltaTime: deltaTime)
        rungeKuttaIntegration(entityId: entity, deltaTime: deltaTime) // Update velocity and position
        clearAllAccumulateForces(entityId: entity)
    }
}

private func addGravity(entityId: EntityID, gravity: simd_float3) {
    guard isValid(gravity) else {
        handleError(.valueisNaN, "Gravity", entityId)
        return
    }

    guard let kinetic = scene.get(component: KineticComponent.self, for: entityId) else {
        handleError(.noKineticComponent, entityId)
        return
    }

    // add gravity
    kinetic.addForce(gravity * kinetic.gravityScale)
}

private func accumulateForces(entityId: EntityID, deltaTime _: Float) {
    guard let physics = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    guard let kinetic = scene.get(component: KineticComponent.self, for: entityId) else {
        handleError(.noKineticComponent, entityId)
        return
    }

    // sum up all forces
    var totalForce = simd_float3(0.0, 0.0, 0.0)
    for force in kinetic.forces {
        totalForce += force
    }

    // Calculate acceleration based on accumulated forces
    physics.acceleration = totalForce / physics.mass
}

private func accumulateMoment(entityId: EntityID, deltaTime _: Float) {
    guard let physics = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    guard let kinetic = scene.get(component: KineticComponent.self, for: entityId) else {
        handleError(.noKineticComponent, entityId)
        return
    }

    computeInertiaTensor(entityId: entityId)

    // sum up all moments
    var totalMoment = simd_float3(0.0, 0.0, 0.0)
    for moment in kinetic.moments {
        totalMoment += moment
    }

    // Calculate angular acceleration based on accumulated forces
    physics.angularAcceleration = physics.inverseMomentOfInertiaTensor * (totalMoment - cross(physics.angularVelocity, physics.momentOfInertiaTensor * physics.angularVelocity))
}

func addDrag(entityId: EntityID, deltaTime _: Float) {
    guard let kinetic = scene.get(component: KineticComponent.self, for: entityId) else {
        handleError(.noKineticComponent, entityId)
        return
    }

    guard let physics = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    let linearDragCoeff = physics.linearDragCoefficients
    let k1: Float = linearDragCoeff.x
    let k2: Float = linearDragCoeff.y

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
    let angularDragCoeff = physics.angularDragCoefficients
    let k1Theta: Float = angularDragCoeff.x
    let k2Theta: Float = angularDragCoeff.y
    angularDrag = physics.angularVelocity
    momentDragCoeff = simd.length(angularDrag)

    momentDragCoeff = k1Theta * momentDragCoeff + k2Theta * momentDragCoeff * momentDragCoeff

    angularDrag = safeNormalize(angularDrag)
    angularDrag *= -momentDragCoeff

    kinetic.addMoment(angularDrag)
}

func clearAllAccumulateForces(entityId: EntityID) {
    guard let kinetic = scene.get(component: KineticComponent.self, for: entityId) else {
        handleError(.noKineticComponent, entityId)
        return
    }

    kinetic.clearForces()

    kinetic.clearMoments()
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
    let torque = getOrientation(entityId: entityId).inverse * simd_cross(r, force)

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

public func clearAngularVelocity(entityId: EntityID) {
    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    physicsComponent.angularVelocity = .zero
}

public func clearVelocity(entityId: EntityID) {
    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    physicsComponent.velocity = .zero
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

private func rungeKuttaIntegration(entityId: EntityID, deltaTime: Float) {
    guard let physics = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
        return
    }

    guard let transform = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    let rungeFactor: Float = 1.0 / 6.0

    // update velocity based on acceleration
    let k1v: simd_float3 = (physics.acceleration) * deltaTime
    let k2v: simd_float3 = (physics.acceleration + k1v * 0.5) * deltaTime
    let k3v: simd_float3 = (physics.acceleration + k2v * 0.5) * deltaTime
    let k4v: simd_float3 = (physics.acceleration + k3v) * deltaTime

    let accelerationDelta = (k1v + 2.0 * k2v + 2.0 * k3v + k4v) * rungeFactor

    physics.velocity = physics.velocity + accelerationDelta

    // update position based on velocity

    let k1x: simd_float3 = (physics.velocity) * deltaTime
    let k2x: simd_float3 = (physics.velocity + k1x * 0.5) * deltaTime
    let k3x: simd_float3 = (physics.velocity + k2x * 0.5) * deltaTime
    let k4x: simd_float3 = (physics.velocity + k3x) * deltaTime

    let velocityDelta = (k1x + 2.0 * k2x + 2.0 * k3x + k4x) * rungeFactor
    var position = getLocalPosition(entityId: entityId)
    position = position + velocityDelta

    transform.position = simd_float3(position.x, position.y, position.z)

    // update angular velocity and orientation
    let k1av: simd_float3 = (physics.angularAcceleration) * deltaTime
    let k2av: simd_float3 = (physics.angularAcceleration + k1av * 0.5) * deltaTime
    let k3av: simd_float3 = (physics.angularAcceleration + k2av * 0.5) * deltaTime
    let k4av: simd_float3 = (physics.angularAcceleration + k3av) * deltaTime

    let angularAccelerationDelta = (k1av + 2.0 * k2av + 2.0 * k3av + k4av) * rungeFactor

    // update angular velocity
    physics.angularVelocity = physics.angularVelocity + angularAccelerationDelta

    var mQuat: simd_quatf = transform.rotation

    let k1q = quaternionDerivative(q: mQuat, omega: physics.angularVelocity) * deltaTime
    let k2q = quaternionDerivative(q: mQuat + k1q * 0.5, omega: physics.angularVelocity) * deltaTime
    let k3q = quaternionDerivative(q: mQuat + k2q * 0.5, omega: physics.angularVelocity) * deltaTime
    let k4q = quaternionDerivative(q: mQuat + k3q, omega: physics.angularVelocity) * deltaTime

    mQuat += (k1q + 2.0 * k2q + 2.0 * k3q + k4q) * rungeFactor

    mQuat = simd_normalize(mQuat)

    transform.rotation = mQuat
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

        transform.position = simd_float3(position.x, position.y, position.z)
    }
}

func computeInertiaTensor(entityId: EntityID) {
    guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
        handleError(.noPhysicsComponent, entityId)
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
    var (uX, uY, uZ) = getDimension(entityId: entityId)

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

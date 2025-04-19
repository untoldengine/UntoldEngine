
//
//  TransformSystem.swift
//  Untold Engine
//  Created by Harold Serrano on 2/8/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import Foundation
import simd

public func getLocalPosition(entityId: EntityID) -> simd_float3 {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    let x: Float = localTransformComponent.space.columns.3.x
    let y: Float = localTransformComponent.space.columns.3.y
    let z: Float = localTransformComponent.space.columns.3.z

    return simd_float3(x, y, z)
}

/// Retrives world position for entity id
public func getPosition(entityId: EntityID) -> simd_float3 {
    guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
        handleError(.noWorldTransformComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    let x: Float = worldTransformComponent.space.columns.3.x
    let y: Float = worldTransformComponent.space.columns.3.y
    let z: Float = worldTransformComponent.space.columns.3.z

    return simd_float3(x, y, z)
}

public func getLocalOrientation(entityId: EntityID) -> simd_float3x3 {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return simd_float3x3()
    }

    return matrix3x3_upper_left(localTransformComponent.space)
}

/// Retrieves world orientation for entity id
public func getOrientation(entityId: EntityID) -> simd_float3x3 {
    guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
        handleError(.noWorldTransformComponent, entityId)
        return simd_float3x3()
    }

    return matrix3x3_upper_left(worldTransformComponent.space)
}

public func getLocalOrientationEuler(entityId: EntityID) -> (pitch: Float, yaw: Float, roll: Float) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return (0.0, 0.0, 0.0)
    }

    let m = matrix3x3_upper_left(localTransformComponent.space)
    let q = transformMatrix3nToQuaternion(m: m)

    let euler = transformQuaternionToEulerAngles(q: q)

    return (euler.pitch, euler.yaw, euler.roll)
}

public func getOrientationEuler(entityId: EntityID) -> (pitch: Float, yaw: Float, roll: Float) {
    guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
        handleError(.noWorldTransformComponent, entityId)
        return (0.0, 0.0, 0.0)
    }

    let m = matrix3x3_upper_left(worldTransformComponent.space)
    let q = transformMatrix3nToQuaternion(m: m)

    let euler = transformQuaternionToEulerAngles(q: q)

    return (euler.pitch, euler.yaw, euler.roll)
}

public func getForwardAxisVector(entityId: EntityID) -> simd_float3 {
    // get the transform for the entity
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    var forward = simd_float3(
        localTransformComponent.space.columns.2.x,
        localTransformComponent.space.columns.2.y,
        localTransformComponent.space.columns.2.z
    )

    forward = normalize(forward)

    return forward
}

public func getRightAxisVector(entityId: EntityID) -> simd_float3 {
    // get the transform for the entity
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    var right = simd_float3(
        localTransformComponent.space.columns.0.x,
        localTransformComponent.space.columns.0.y,
        localTransformComponent.space.columns.0.z
    )

    right = normalize(right)

    return right
}

public func getUpAxisVector(entityId: EntityID) -> simd_float3 {
    // get the transform for the entity
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    var up = simd_float3(
        localTransformComponent.space.columns.1.x,
        localTransformComponent.space.columns.1.y,
        localTransformComponent.space.columns.1.z
    )

    up = normalize(up)

    return up
}

public func translateTo(entityId: EntityID, position: simd_float3) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    guard isValid(position) else {
        handleError(.valueisNaN, "Position", entityId)
        return
    }

    localTransformComponent.space.columns.3 = simd_float4(position, 1.0)
}

public func translateBy(entityId: EntityID, position: simd_float3) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    guard isValid(position) else {
        handleError(.valueisNaN, "Position", entityId)
        return
    }

    localTransformComponent.space.columns.3.x += position.x
    localTransformComponent.space.columns.3.y += position.y
    localTransformComponent.space.columns.3.z += position.z
}

public func rotateTo(entityId: EntityID, angle: Float, axis: simd_float3) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    guard isValid(axis) else {
        handleError(.valueisNaN, "Axis", entityId)
        return
    }

    guard isValid(angle) else {
        handleError(.valueisNaN, "Angle", entityId)
        return
    }

    let q = simd_quatf(angle: degreesToRadians(degrees: angle), axis: axis)
    let m: simd_float3x3 = transformQuaternionToMatrix3x3(q: q)

    localTransformComponent.space.columns.0 = simd_float4(m.columns.0, 0.0)
    localTransformComponent.space.columns.1 = simd_float4(m.columns.1, 0.0)
    localTransformComponent.space.columns.2 = simd_float4(m.columns.2, 0.0)

    if localTransformComponent.flipCoord == true {
        localTransformComponent.space.columns.2 = simd_float4(m.columns.1, 0.0)
        localTransformComponent.space.columns.1 = simd_float4(m.columns.2, 0.0)
    }
}

public func rotateBy(entityId: EntityID, angle: Float, axis: simd_float3) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    guard isValid(axis) else {
        handleError(.valueisNaN, "Axis", entityId)
        return
    }

    guard isValid(angle) else {
        handleError(.valueisNaN, "Angle", entityId)
        return
    }

    // previous matrix
    let previusM: simd_float3x3 = matrix3x3_upper_left(localTransformComponent.space)

    // transform to quat
    let pq: simd_quatf = transformMatrix3nToQuaternion(m: previusM)

    // new desired rotation
    let q = simd_quatf.init(angle: degreesToRadians(degrees: angle), axis: axis)

    // new rotation
    let newQ = simd_mul(q, pq)

    // update matrix
    let m: simd_float3x3 = transformQuaternionToMatrix3x3(q: newQ)

    localTransformComponent.space.columns.0 = simd_float4(m.columns.0, localTransformComponent.space.columns.0.w)
    localTransformComponent.space.columns.1 = simd_float4(m.columns.1, localTransformComponent.space.columns.1.w)
    localTransformComponent.space.columns.2 = simd_float4(m.columns.2, localTransformComponent.space.columns.2.w)
}

public func rotateTo(entityId: EntityID, rotation: simd_float4x4) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    let rotUpperLeft = matrix3x3_upper_left(rotation)
    let q = simd_quatf(rotUpperLeft)
    let m: simd_float3x3 = transformQuaternionToMatrix3x3(q: q)

    localTransformComponent.space.columns.0 = simd_float4(m.columns.0, 0.0)
    localTransformComponent.space.columns.1 = simd_float4(m.columns.1, 0.0)
    localTransformComponent.space.columns.2 = simd_float4(m.columns.2, 0.0)
}

public func rotateTo(entityId: EntityID, pitch: Float, yaw: Float, roll: Float) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    let q = transformEulerAnglesToQuaternion(pitch: pitch, yaw: yaw, roll: roll)

    let m: simd_float3x3 = transformQuaternionToMatrix3x3(q: q)

    localTransformComponent.space.columns.0 = simd_float4(m.columns.0, 0.0)
    localTransformComponent.space.columns.1 = simd_float4(m.columns.1, 0.0)
    localTransformComponent.space.columns.2 = simd_float4(m.columns.2, 0.0)
}

public func setAxisRotations(entityId: EntityID, rotX: Float, rotY: Float, rotZ: Float) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    localTransformComponent.rotationX = rotX
    localTransformComponent.rotationY = rotY
    localTransformComponent.rotationZ = rotZ
}

public func getAxisRotations(entityId: EntityID) -> simd_float3 {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return .zero
    }

    return simd_float3(localTransformComponent.rotationX, localTransformComponent.rotationY, localTransformComponent.rotationZ)
}

public func applyAxisRotations(entityId: EntityID) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    // Generate Rotation
    let rotXMatrix: simd_float4x4 = matrix4x4Rotation(
        radians: degreesToRadians(degrees: localTransformComponent.rotationX), axis: simd_float3(1.0, 0.0, 0.0)
    )
    let rotYMatrix: simd_float4x4 = matrix4x4Rotation(
        radians: degreesToRadians(degrees: localTransformComponent.rotationY), axis: simd_float3(0.0, 1.0, 0.0)
    )
    let rotZMatrix: simd_float4x4 = matrix4x4Rotation(
        radians: degreesToRadians(degrees: localTransformComponent.rotationZ), axis: simd_float3(0.0, 0.0, 1.0)
    )

    // combine the rotations
    let combinedRotation: simd_float4x4 = rotZMatrix * rotYMatrix * rotXMatrix

    rotateTo(entityId: entityId, rotation: combinedRotation)
}

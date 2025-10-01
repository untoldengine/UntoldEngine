
//
//  TransformSystem.swift
//  Untold Engine
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import Foundation
import simd

public func getLocalPosition(entityId: EntityID) -> simd_float3 {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    let x: Float = localTransformComponent.position.x
    let y: Float = localTransformComponent.position.y
    let z: Float = localTransformComponent.position.z

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

    return transformQuaternionToMatrix3x3(q: localTransformComponent.rotation)
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

    let m = transformQuaternionToMatrix3x3(q: localTransformComponent.rotation)
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

    let m: simd_float3x3 = transformQuaternionToMatrix3x3(q: localTransformComponent.rotation)

    var forward = simd_float3(
        m.columns.2.x,
        m.columns.2.y,
        m.columns.2.z
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

    let m: simd_float3x3 = transformQuaternionToMatrix3x3(q: localTransformComponent.rotation)

    var right = simd_float3(
        m.columns.0.x,
        m.columns.0.y,
        m.columns.0.z
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
    let m: simd_float3x3 = transformQuaternionToMatrix3x3(q: localTransformComponent.rotation)

    var up = simd_float3(
        m.columns.1.x,
        m.columns.1.y,
        m.columns.1.z
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

    localTransformComponent.position = position
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

    localTransformComponent.position.x += position.x
    localTransformComponent.position.y += position.y
    localTransformComponent.position.z += position.z
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

    let q = simd_normalize(simd_quatf(angle: degreesToRadians(degrees: angle), axis: axis))
    let m: simd_float3x3 = transformQuaternionToMatrix3x3(q: q)

    var n: simd_float3x3 = .init(diagonal: simd_float3(repeating: 1.0))

    n.columns.0 = m.columns.0
    n.columns.1 = m.columns.1
    n.columns.2 = m.columns.2

    if localTransformComponent.flipCoord == true {
        n.columns.2 = m.columns.1
        n.columns.1 = m.columns.2
    }

    localTransformComponent.rotation = transformMatrix3nToQuaternion(m: n)
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
    let previusM: simd_float3x3 = transformQuaternionToMatrix3x3(q: localTransformComponent.rotation)

    // transform to quat
    let pq: simd_quatf = transformMatrix3nToQuaternion(m: previusM)

    // new desired rotation
    let q = simd_quatf.init(angle: degreesToRadians(degrees: angle), axis: axis)

    // new rotation
    let newQ = simd_normalize(simd_mul(q, pq))

    localTransformComponent.rotation = newQ
}

public func rotateTo(entityId: EntityID, rotation: simd_float4x4) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    let rotUpperLeft = matrix3x3_upper_left(rotation)
    let q = simd_normalize(simd_quatf(rotUpperLeft))

    localTransformComponent.rotation = q
}

public func rotateTo(entityId: EntityID, pitch: Float, yaw: Float, roll: Float) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    let q = simd_normalize(transformEulerAnglesToQuaternion(pitch: pitch, yaw: yaw, roll: roll))

    localTransformComponent.rotation = q
}

public func scaleTo(entityId: EntityID, scale: simd_float3) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    localTransformComponent.scale.x = scale.x
    localTransformComponent.scale.y = scale.y
    localTransformComponent.scale.z = scale.z
}

public func getScale(entityId: EntityID) -> simd_float3 {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return .zero
    }

    return localTransformComponent.scale
}

public func getAxisRotations(entityId: EntityID) -> simd_float3 {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return .zero
    }

    return simd_float3(localTransformComponent.rotationX, localTransformComponent.rotationY, localTransformComponent.rotationZ)
}

public func applyAxisRotations(entityId: EntityID, axis: simd_float3) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    localTransformComponent.rotationX = axis.x
    localTransformComponent.rotationY = axis.y
    localTransformComponent.rotationZ = axis.z

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

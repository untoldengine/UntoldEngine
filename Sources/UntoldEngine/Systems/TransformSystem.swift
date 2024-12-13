
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
        handleError(.noTransformComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    let x: Float = localTransformComponent.space.columns.3.x
    let y: Float = localTransformComponent.space.columns.3.y
    let z: Float = localTransformComponent.space.columns.3.z

    return simd_float3(x, y, z)
}

//public func getWorldPosition(entityId: EntityID) -> simd_float3 {
//    
//}

public func getLocalOrientation(entityId: EntityID) -> simd_float3x3 {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noTransformComponent, entityId)
        return simd_float3x3()
    }

    return matrix3x3_upper_left(localTransformComponent.space)
}

//public func getWorldOrientation(entityId: EntityID) -> simd_float3x3 {
//    
//}

public func getForwardAxisVector(entityId: EntityID) -> simd_float3 {
    // get the transform for the entity
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noTransformComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    var forward = simd_float3(
        localTransformComponent.space.columns.2.x,
        localTransformComponent.space.columns.2.z,
        -localTransformComponent.space.columns.2.y
    )

    forward = normalize(forward)

    return forward
}

public func getRightAxisVector(entityId: EntityID) -> simd_float3 {
    // get the transform for the entity
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noTransformComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    var right = simd_float3(
        localTransformComponent.space.columns.0.x,
        localTransformComponent.space.columns.0.z,
        -localTransformComponent.space.columns.0.y
    )

    right = normalize(right)

    return right
}

public func getUpAxisVector(entityId: EntityID) -> simd_float3 {
    // get the transform for the entity
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noTransformComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    var up = simd_float3(
        localTransformComponent.space.columns.1.x,
        localTransformComponent.space.columns.1.z,
        -localTransformComponent.space.columns.1.y
    )

    up = normalize(up)

    return up
}

public func translateTo(entityId: EntityID, position: simd_float3) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noTransformComponent, entityId)
        return
    }

    guard isValid(position)else{
        handleError(.valueisNaN,"Position", entityId)
        return
    }
    
    localTransformComponent.space.columns.3 = simd_float4(position, 1.0)
}

public func translateBy(entityId: EntityID, position: simd_float3) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noTransformComponent, entityId)
        return
    }

    guard isValid(position)else{
        handleError(.valueisNaN, "Position", entityId)
        return
    }
    
    localTransformComponent.space.columns.3.x += position.x
    localTransformComponent.space.columns.3.y += position.y
    localTransformComponent.space.columns.3.z += position.z
}


public func rotateTo(entityId: EntityID, angle: Float, axis: simd_float3) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noTransformComponent, entityId)
        return
    }

    guard isValid(axis)else{
        handleError(.valueisNaN,"Axis", entityId)
        return
    }
    
    guard isValid(angle)else{
        handleError(.valueisNaN,"Angle",entityId)
        return
    }
    
    let m: simd_float4x4 = matrix4x4Rotation(radians: degreesToRadians(degrees: angle), axis: axis)

    localTransformComponent.space.columns.0 = m.columns.0
    localTransformComponent.space.columns.1 = m.columns.1
    localTransformComponent.space.columns.2 = m.columns.2
    
    if localTransformComponent.flipCoord == true{
        localTransformComponent.space.columns.2 = m.columns.1
        localTransformComponent.space.columns.1 = m.columns.2
    }
    
}

public func rotateBy(entityId: EntityID, angle: Float, axis: simd_float3) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noTransformComponent, entityId)
        return
    }

    guard isValid(axis)else{
        handleError(.valueisNaN,"Axis", entityId)
        return
    }
    
    guard isValid(angle)else{
        handleError(.valueisNaN,"Angle",entityId)
        return
    }
    
    // new matrix
    var m: simd_float3x3 = matrix3x3_upper_left(
        matrix4x4Rotation(radians: degreesToRadians(degrees: angle), axis: axis))

    // previous matrix
    let p = matrix3x3_upper_left(localTransformComponent.space)

    m = matrix_multiply(m, p)

    localTransformComponent.space.columns.0 = simd_float4(m.columns.0, localTransformComponent.space.columns.0.w)
    localTransformComponent.space.columns.1 = simd_float4(m.columns.1, localTransformComponent.space.columns.1.w)
    localTransformComponent.space.columns.2 = simd_float4(m.columns.2, localTransformComponent.space.columns.2.w)
}

public func rotateTo(entityId: EntityID, rotation: simd_float4x4) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noTransformComponent, entityId)
        return
    }

    localTransformComponent.space.columns.0 = rotation.columns.0
    localTransformComponent.space.columns.1 = rotation.columns.1
    localTransformComponent.space.columns.2 = rotation.columns.2
}

//public func combineRotations(entityId: EntityID) {
//    guard let t = scene.get(component: localTransformComponent.self, for: entityId) else {
//        handleError(.noTransformComponent, entityId)
//        return
//    }
//
//    // Generate Rotation
//    let rotXMatrix: simd_float4x4 = matrix4x4Rotation(
//        radians: degreesToRadians(degrees: t.xRot), axis: simd_float3(1.0, 0.0, 0.0)
//    )
//    let rotYMatrix: simd_float4x4 = matrix4x4Rotation(
//        radians: degreesToRadians(degrees: t.yRot), axis: simd_float3(0.0, 1.0, 0.0)
//    )
//    let rotZMatrix: simd_float4x4 = matrix4x4Rotation(
//        radians: degreesToRadians(degrees: t.zRot), axis: simd_float3(0.0, 0.0, 1.0)
//    )
//
//    // combine the rotations
//    let combinedRotation: simd_float4x4 = rotZMatrix * rotYMatrix * rotXMatrix
//
//    rotateTo(entityId: entityId, rotation: combinedRotation)
//}

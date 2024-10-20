
//
//  TransformSystem.swift
//  Untold Engine
//  Created by Harold Serrano on 2/8/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import Foundation
import simd

public func translateTo(_ entityId: EntityID, _ position: simd_float3) {
  let t = scene.get(component: Transform.self, for: entityId)
  t?.localSpace.columns.3 = simd_float4(position, 1.0)
}

public func translateEntityBy(_ entityId: EntityID, _ position: simd_float3) {

  let t = scene.get(component: Transform.self, for: entityId)
  t?.localSpace.columns.3.x += position.x
  t?.localSpace.columns.3.y += position.y
  t?.localSpace.columns.3.z += position.z
}

public func rotateTo(_ entityId: EntityID, _ angle: Float, _ axis: simd_float3) {
  let t = scene.get(component: Transform.self, for: entityId)

  let m: simd_float4x4 = matrix4x4Rotation(radians: degreesToRadians(degrees: angle), axis: axis)

  t?.localSpace.columns.0 = m.columns.0
  t?.localSpace.columns.1 = m.columns.1
  t?.localSpace.columns.2 = m.columns.2
}

public func rotateBy(_ entityId: EntityID, _ angle: Float, _ axis: simd_float3) {
  let t = scene.get(component: Transform.self, for: entityId)

  //new matrix
  var m: simd_float3x3 = matrix3x3_upper_left(
    matrix4x4Rotation(radians: degreesToRadians(degrees: angle), axis: axis))

  //previous matrix
  let p = matrix3x3_upper_left(t!.localSpace)

  m = matrix_multiply(m, p)

  t?.localSpace.columns.0 = simd_float4(m.columns.0, (t?.localSpace.columns.0.w)!)
  t?.localSpace.columns.1 = simd_float4(m.columns.1, (t?.localSpace.columns.1.w)!)
  t?.localSpace.columns.2 = simd_float4(m.columns.2, (t?.localSpace.columns.2.w)!)

}
//
//func rotateTo(_ entityId:EntityID, pitch: Float, yaw: Float, roll: Float){
//    let t=scene.get(component: Transform.self, for: entityId)
//
//    let m:simd_float4x4=matrix4x4Rotation(pitch: pitch, yaw: yaw, roll: roll)
//
//    t?.localSpace.columns.0=m.columns.0
//    t?.localSpace.columns.1=m.columns.1
//    t?.localSpace.columns.2=m.columns.2
//
//}
//
//func rotateBy(_ entityId:EntityID, pitch: Float, yaw: Float, roll: Float){
//
//    let t=scene.get(component: Transform.self, for: entityId)
//
//    //new matrix
//    var m:simd_float3x3=matrix3x3_upper_left(matrix4x4Rotation(pitch: pitch, yaw: yaw, roll: roll))
//
//    //previous matrix
//    let p=matrix3x3_upper_left(t!.localSpace)
//
//    m=matrix_multiply(m, p)
//
//    t?.localSpace.columns.0=simd_float4(m.columns.0,(t?.localSpace.columns.0.w)!)
//    t?.localSpace.columns.1=simd_float4(m.columns.1,(t?.localSpace.columns.1.w)!)
//    t?.localSpace.columns.2=simd_float4(m.columns.2,(t?.localSpace.columns.2.w)!)
//
//
//}

public func rotateTo(_ entityId: EntityID, _ rotation: simd_float4x4) {

  let t = scene.get(component: Transform.self, for: entityId)

  t?.localSpace.columns.0 = rotation.columns.0
  t?.localSpace.columns.1 = rotation.columns.1
  t?.localSpace.columns.2 = rotation.columns.2

}

public func combineRotations(_ entityId: EntityID) {

  let t = scene.get(component: Transform.self, for: entityId)

  //Generate Rotation
  let rotXMatrix: simd_float4x4 = matrix4x4Rotation(
    radians: degreesToRadians(degrees: t!.xRot), axis: simd_float3(1.0, 0.0, 0.0))
  let rotYMatrix: simd_float4x4 = matrix4x4Rotation(
    radians: degreesToRadians(degrees: t!.yRot), axis: simd_float3(0.0, 1.0, 0.0))
  let rotZMatrix: simd_float4x4 = matrix4x4Rotation(
    radians: degreesToRadians(degrees: t!.zRot), axis: simd_float3(0.0, 0.0, 1.0))

  //combine the rotations
  let combinedRotation: simd_float4x4 = rotZMatrix * rotYMatrix * rotXMatrix

  rotateTo(entityId, combinedRotation)

}

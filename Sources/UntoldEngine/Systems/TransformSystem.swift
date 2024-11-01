
//
//  TransformSystem.swift
//  Untold Engine
//  Created by Harold Serrano on 2/8/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import Foundation
import simd

public func getPosition(entityId: EntityID)->simd_float3{

    guard let t = scene.get(component: Transform.self, for: entityId)else{

        return simd_float3(0.0,0.0,0.0)
    }

    let x:Float=t.localSpace.columns.3.x 
    let y:Float=t.localSpace.columns.3.y 
    let z:Float=t.localSpace.columns.3.z 

    return simd_float3(x,y,z)
}

public func getForwardVector(entityId:EntityID)->simd_float3{

    //get the transform for the entity
    guard let t = scene.get(component: Transform.self, for: entityId) else {

      return simd_float3(0.0,0.0,0.0)
    }

    var forward: simd_float3 = simd_float3(
      t.localSpace.columns.2.x,
      t.localSpace.columns.2.z,
      -t.localSpace.columns.2.y)
    

    forward = normalize(forward)

    return forward
}

public func translateTo(entityId: EntityID, position: simd_float3) {

    guard let t = scene.get(component: Transform.self, for: entityId)else{
        print("entity with id: \(entityId) not found")
        return 
    }
  
    t.localSpace.columns.3 = simd_float4(position, 1.0)
}

public func translateEntityBy(entityId: EntityID, position: simd_float3) {

    guard let t = scene.get(component: Transform.self, for: entityId)else{
        print("entity with id: \(entityId) not found")
        return 
    }

   t.localSpace.columns.3.x += position.x
   t.localSpace.columns.3.y += position.y
   t.localSpace.columns.3.z += position.z

}

public func rotateTo(entityId: EntityID, angle: Float, axis: simd_float3) {

    guard let t = scene.get(component: Transform.self, for: entityId)else{
        print("entity with id: \(entityId) not found")
        return 
    }


  let m: simd_float4x4 = matrix4x4Rotation(radians: degreesToRadians(degrees: angle), axis: axis)

  t.localSpace.columns.0 = m.columns.0
  t.localSpace.columns.1 = m.columns.1
  t.localSpace.columns.2 = m.columns.2
}

public func rotateBy(entityId: EntityID, angle: Float, axis: simd_float3) {

    guard let t = scene.get(component: Transform.self, for: entityId)else{
        print("entity with id: \(entityId) not found")
        return 
    }


  //new matrix
  var m: simd_float3x3 = matrix3x3_upper_left(
    matrix4x4Rotation(radians: degreesToRadians(degrees: angle), axis: axis))

  //previous matrix
  let p = matrix3x3_upper_left(t.localSpace)

  m = matrix_multiply(m, p)

  t.localSpace.columns.0 = simd_float4(m.columns.0, (t.localSpace.columns.0.w))
  t.localSpace.columns.1 = simd_float4(m.columns.1, (t.localSpace.columns.1.w))
  t.localSpace.columns.2 = simd_float4(m.columns.2, (t.localSpace.columns.2.w))

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

public func rotateTo(entityId: EntityID, rotation: simd_float4x4) {

    guard let t = scene.get(component: Transform.self, for: entityId)else{
        print("entity with id: \(entityId) not found")
        return 
    }

  t.localSpace.columns.0 = rotation.columns.0
  t.localSpace.columns.1 = rotation.columns.1
  t.localSpace.columns.2 = rotation.columns.2

}

public func combineRotations(entityId: EntityID) {

    guard let t = scene.get(component: Transform.self, for: entityId)else{
        print("entity with id: \(entityId) not found")
        return 
    }

  //Generate Rotation
  let rotXMatrix: simd_float4x4 = matrix4x4Rotation(
    radians: degreesToRadians(degrees: t.xRot), axis: simd_float3(1.0, 0.0, 0.0))
  let rotYMatrix: simd_float4x4 = matrix4x4Rotation(
    radians: degreesToRadians(degrees: t.yRot), axis: simd_float3(0.0, 1.0, 0.0))
  let rotZMatrix: simd_float4x4 = matrix4x4Rotation(
    radians: degreesToRadians(degrees: t.zRot), axis: simd_float3(0.0, 0.0, 1.0))

  //combine the rotations
  let combinedRotation: simd_float4x4 = rotZMatrix * rotYMatrix * rotXMatrix

  rotateTo(entityId: entityId, rotation: combinedRotation)

}

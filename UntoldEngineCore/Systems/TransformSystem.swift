//
//  TransformSystem.swift
//  Mac_Untold
//
//  Created by Harold Serrano on 2/8/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import Foundation
import simd

func translateTo(_ entityId:EntityID,_ position:simd_float3){
    let t=scene.get(component: Transform.self, for: entityId)
    t?.localTransform.columns.3=simd_float4(position,1.0)
}

func translateEntityBy(_ entityId:EntityID,_ position:simd_float3){
    
    let t=scene.get(component: Transform.self, for: entityId)
    t?.localTransform.columns.3.x+=position.x
    t?.localTransform.columns.3.y+=position.y
    t?.localTransform.columns.3.z+=position.z
}

func rotateTo(_ entityId:EntityID,_ angle:Float, _ axis:simd_float3){
    let t=scene.get(component: Transform.self, for: entityId)
    
    
    let m:simd_float4x4=matrix4x4Rotation(radians: degreesToRadians(degrees: angle), axis: axis)
    
    t?.localTransform.columns.0=m.columns.0
    t?.localTransform.columns.1=m.columns.1
    t?.localTransform.columns.2=m.columns.2
}

func rotateBy(_ entityId:EntityID,_ angle:Float, _ axis:simd_float3){
    let t=scene.get(component: Transform.self, for: entityId)
    
    //new matrix
    var m:simd_float3x3=matrix3x3_upper_left(matrix4x4Rotation(radians: degreesToRadians(degrees: angle), axis: axis))
    
    //previous matrix
    let p=matrix3x3_upper_left(t!.localTransform)
    
    m=matrix_multiply(m, p)
    
    t?.localTransform.columns.0=simd_float4(m.columns.0,(t?.localTransform.columns.0.w)!)
    t?.localTransform.columns.1=simd_float4(m.columns.1,(t?.localTransform.columns.1.w)!)
    t?.localTransform.columns.2=simd_float4(m.columns.2,(t?.localTransform.columns.2.w)!)
    
}

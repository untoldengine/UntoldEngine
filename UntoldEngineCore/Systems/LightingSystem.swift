//
//  Lights.swift
//  UntoldEngine3D
//
//  Created by Harold Serrano on 5/29/23.
//

import Foundation
import simd

struct DirectionalLight{
    
    mutating func updateLightSpace(){
        
        //Scene's center
        let targetPoint:simd_float3=simd_float3(0.0,0.0,0.0)
                
        let lightPosition=targetPoint + normalize(direction)*100

        viewMatrix=matrix_look_at_right_hand(lightPosition, simd_float3(0.0,0.0,0.0), simd_float3(0.0,1.0,0.0))

        orthoViewMatrix=simd_mul(orthoMatrix, viewMatrix)
    }
    
    var orthoViewMatrix:simd_float4x4!
    var orthoMatrix:simd_float4x4!
    var viewMatrix:simd_float4x4!
    var direction:simd_float3=simd_float3(1.0,1.0,1.0)
};

struct PointLight{    
    var position:simd_float4=simd_float4(0.0,0.0,0.0,0.0)
    var color:simd_float4=simd_float4(0.0,0.0,0.0,0.0)
    var attenuation:simd_float4=simd_float4(0.0,0.0,0.0,0.0) //constant, linera, quadratic -> (x, y, z, max range)
    var intensity: simd_float4=simd_float4(0.0,0.0,0.0,0.0) //ambient intensity diffuse intensity, specular intensity ->(x,y,z)
}

struct LightingSystem{
    
    var dirLight:DirectionalLight=DirectionalLight()
    var pointLight:[PointLight]=[]
    var currentPointLightCount:Int = 0
    
}


//
//  Components.swift
//  ECSinSwift
//
//  Created by Harold Serrano on 1/14/24.
//

import Foundation
import Metal
import MetalKit
import simd

public class Transform: Component {
    var localSpace: simd_float4x4
    var xRot: Float
    var yRot: Float
    var zRot: Float

    var minBox: simd_float3!
    var maxBox: simd_float3!

    var scale: simd_float3!

    public required init() {
        // Initialize default values
        localSpace = matrix4x4Identity()
        xRot = 0.0
        yRot = 0.0
        zRot = 0.0
    }
}

public class Render: Component {
    var spaceUniform: MTLBuffer!
    var mesh: Mesh!

    public required init() {}
}

public class Physics: Component{
    
    var mass:Float
    var velocity:simd_float3
    var acceleration:simd_float3
    
    public required init() {
        
        mass=1.0
        velocity=simd_float3(0.0,0.0,0.0)
        acceleration=simd_float3(0.0,0.0,0.0)
        
    }
}

public class LightComponent: Component {
    enum LightType {
        case point(PointLight)
        case directional(DirectionalLight)
        case area(AreaLight)
    }

    var lightType: LightType?

    public required init() {}
}
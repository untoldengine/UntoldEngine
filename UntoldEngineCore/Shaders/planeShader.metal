//
//  planeShader.metal
//  UntoldEngine3D
//
//  Created by Harold Serrano on 6/19/23.
//

#include <metal_stdlib>
using namespace metal;
#include <simd/simd.h>
#import "ShaderTypes.h"
#include "ShaderStructs.h"


vertex VertexOutPlane vertexPlaneShader(VertexPlane in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(voxelUniform) ]]){
    VertexOutPlane out;
    
    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    
    return out;
}

fragment float4 fragmentPlaneShader(VertexOutPlane in [[stage_in]],  constant Uniforms & uniforms [[ buffer(voxelUniform) ]]){
    
    
    return float4(1.0,1.0,1.0,1.0);
}


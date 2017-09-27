//
//  lightShader.metal
//  MetalRendering
//
//  Created by Harold Serrano on 7/11/17.
//  Copyright © 2017 Harold Serrano. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include <simd/simd.h>
#include "U4DShaderProtocols.h"

struct VertexInput {
    
    float4    position [[ attribute(0) ]];
    
};

struct VertexOutput{
    
    float4 position [[position]];
    
};

vertex VertexOutput vertexLightShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    return vertexOut;
}

fragment float4 fragmentLightShader(VertexOutput vertexOut [[stage_in]]){
    
    return float4(1.0,1.0,1.0,1.0);
    
}

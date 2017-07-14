//
//  shadowShader.metal
//  MetalRendering
//
//  Created by Harold Serrano on 7/6/17.
//  Copyright © 2017 Harold Serrano. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include <simd/simd.h>
#include "U4DShaderProtocols.h"

struct VertexInput {
    
    float4    position [[ attribute(0) ]];
    float4    normal   [[ attribute(1) ]];
    float2    uv       [[ attribute(2) ]];
    
};

struct VertexOutput{
    
    float4 position [[position]];
    float4 color;
    float2 uvCoords;
    
};

vertex VertexOutput vertexShadowShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    float4 position=uniformSpace.lightShadowProjectionSpace*(uniformSpace.modelSpace*float4(vert.position));
    
    vertexOut.position=position;
    
    return vertexOut;
}

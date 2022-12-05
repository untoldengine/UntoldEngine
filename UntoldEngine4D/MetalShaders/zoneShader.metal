//
//  zoneShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 11/27/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
#include "U4DShaderProtocols.h"
#include "U4DShaderHelperFunctions.h"

struct VertexInput {
    
    float4    position [[ attribute(0) ]];
    float2    uv       [[ attribute(1) ]];
    
};

struct VertexOutput{
    
    float4 position [[position]];
    float4 color;
    float2 uvCoords;
    
};

vertex VertexOutput vertexZoneShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(viSpaceBuffer)]], constant UniformGlobalData &uniformGlobalData [[buffer(viGlobalDataBuffer)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    vertexOut.uvCoords=vert.uv;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    return vertexOut;
}

fragment float4 fragmentZoneShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(fiGlobalDataBuffer)]], constant UniformShaderEntityProperty &uniformShaderEntityProperty [[buffer(fiShaderEntityPropertyBuffer)]], texture2d<float> texture[[texture(fiTexture0)]], sampler sam [[sampler(fiSampler0)]]){
    
    
    return float4(1.0,0.0,0.0,1.0);
    
}





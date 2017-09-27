//
//  skyboxShader.metal
//  MetalRendering
//
//  Created by Harold Serrano on 7/13/17.
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
    float3 uvCoords;
    
};

vertex VertexOutput vertexSkyboxShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    vertexOut.uvCoords=float3(vert.position);
    
    return vertexOut;
}

fragment float4 fragmentSkyboxShader(VertexOutput vertexOut [[stage_in]], texturecube<float> skyboxTexture[[texture(0)]], sampler skyboxSampler [[sampler(0)]]){
    
    float3 texCoords = float3(vertexOut.uvCoords.x, vertexOut.uvCoords.y, -vertexOut.uvCoords.z);
    
    return skyboxTexture.sample(skyboxSampler, texCoords);
    
    
}


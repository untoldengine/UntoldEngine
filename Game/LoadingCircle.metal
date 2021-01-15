//
//  LoadingScreen.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 7/7/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
#include "../UntoldEngine4D/MetalShaders/U4DShaderProtocols.h"
#include "../UntoldEngine4D/MetalShaders/U4DShaderHelperFunctions.h"

#define M_PI 3.1415926535897932384626433832795

struct VertexInput {
    
    float4    position [[ attribute(0) ]];
    float2    uv       [[ attribute(1) ]];
    
};

struct VertexOutput{
    
    float4 position [[position]];
    float4 color;
    float2 uvCoords;
    
};

vertex VertexOutput vertexLoadingCircleShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(viSpaceBuffer)]], constant UniformGlobalData &uniformGlobalData [[buffer(viGlobalDataBuffer)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    vertexOut.uvCoords=vert.uv;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    return vertexOut;
}

fragment float4 fragmentLoadingCircleShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(fiGlobalDataBuffer)]], texture2d<float> texture[[texture(fiTexture0)]], sampler sam [[sampler(fiSampler0)]]){
    
    float2 st=vertexOut.uvCoords;
    
    float3 color =float3(1.0);
    
    float2 pos=float2(0.5,0.6)-st;
    
    float r=5.0*sqrt(dot(pos,pos));
    
    pos=normalize(pos);
    
    float a=-atan2(pos.y,pos.x);
    
    a=mod(uniformGlobalData.time+0.5*(1.0+a/M_PI),1.0);
    
    float c=a*(smoothstep(0.3,0.35,r)-smoothstep(0.4,0.45,r));
    
    color=float3(c);
    
    return float4(color,0.5);
    
}

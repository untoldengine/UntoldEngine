//
//  sliderUIShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 9/21/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
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

vertex VertexOutput vertexUISliderShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(viSpaceBuffer)]], constant UniformGlobalData &uniformGlobalData [[buffer(viGlobalDataBuffer)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    vertexOut.uvCoords=vert.uv;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    return vertexOut;
}

fragment float4 fragmentUISliderShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(fiGlobalDataBuffer)]], constant UniformShaderEntityProperty &uniformShaderEntityProperty [[buffer(fiShaderEntityPropertyBuffer)]], texture2d<float> texture[[texture(fiTexture0)]], sampler sam [[sampler(fiSampler0)]]){
    
    float2 st=-1.0+2.0*vertexOut.uvCoords;
    
    float3 color =float3(0.0);
    
    float b=sdfBox(st,float2(1.0,0.2));
    
    b=sharpen(b,0.01,uniformGlobalData.resolution);
    
    color=float3(b)*backgroundColor;
    
    float s=sdfBox(st-float2(uniformShaderEntityProperty.shaderParameter[0].x,0.0),float2(0.05,1.0));
    
    s=sharpen(s,0.01,uniformGlobalData.resolution);
    
    color=max(color,float3(s)*foregroundColor);
    
    return float4(color,1.0);
    
}



//
//  checkboxUIShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 9/23/20.
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

vertex VertexOutput vertexUICheckboxShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], constant UniformGlobalData &uniformGlobalData [[buffer(2)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    vertexOut.uvCoords=vert.uv;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    return vertexOut;
}

fragment float4 fragmentUICheckboxShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(0)]], constant UniformShaderEntityProperty &uniformShaderEntityProperty [[buffer(1)]], texture2d<float> texture[[texture(0)]], sampler sam [[sampler(0)]]){
    
    float2 st=-1.0+2.0*vertexOut.uvCoords;
    
    float3 color =float3(0.0);
    
    float b=sdfBox(st,float2(1.0,1.0));
    
    b=abs(b)-0.1;
    
    b=sharpen(b,0.01,uniformGlobalData.resolution);
    
    color=float3(b)*backgroundColor;
    
    if(uniformShaderEntityProperty.shaderParameter[0].x==1){
        
        float s=sdfBox(st,float2(0.8,0.8));
        
        s=sharpen(s,0.01,uniformGlobalData.resolution);
        
        color=max(color,float3(s)*foregroundColor);

    }
    
    return float4(color,1.0);
    
}



//
//  RadarLocation.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 7/9/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
#include "../UntoldEngine4D/MetalShaders/U4DShaderProtocols.h"
#include "../UntoldEngine4D/MetalShaders/U4DShaderHelperFunctions.h"

struct VertexInput {
    
    float4    position [[ attribute(0) ]];
    float2    uv       [[ attribute(1) ]];
    
};

struct VertexOutput{
    
    float4 position [[position]];
    float4 color;
    float2 uvCoords;
    
};

float sdBox( float2 p, float2 b ){
    float2 d = abs(p)-b;
    return length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
}

float sdRoundedX( float2 p, float w, float r )
{
    p = abs(p);
    return length(p-min(p.x+p.y,w)*0.5) - r;
}

vertex VertexOutput vertexRadarShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], constant UniformGlobalData &uniformGlobalData [[buffer(2)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    vertexOut.uvCoords=vert.uv;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    return vertexOut;
}

fragment float4 fragmentRadarShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(0)]], constant UniformShaderEntityProperty &uniformShaderEntityProperty [[buffer(1)]], texture2d<float> texture[[texture(0)]], sampler sam [[sampler(0)]]){
    
    float2 st=-1. + 2. * vertexOut.uvCoords;
    
    //sample the texture color
    float4 fieldTexture=texture.sample(sam,vertexOut.uvCoords.xy);
    
    float3 color =float3(0.0);
    
    float2 playerDim=float2(0.02,0.05);
    
    for(int i=1;i<=3;i++){
        
        float playerPos=sdBox(st-float2(uniformShaderEntityProperty.shaderParameter[i].x,-uniformShaderEntityProperty.shaderParameter[i].y),playerDim);
        
        playerPos=step(0.01,playerPos)-step(0.03,playerPos);
        
        float3 playerColor=float3(playerPos)*float3(1.0,0.0,0.0)*50.0;
        
        color+=playerColor;
        
    }
    
    
    
    float ballPos=length(st-float2(uniformShaderEntityProperty.shaderParameter[0].x,-uniformShaderEntityProperty.shaderParameter[0].y));
                         
    ballPos=step(0.0,ballPos)-step(0.05,ballPos);


    float3 ballColor=float3(ballPos)*50.0;
    
    color+=ballColor;
    
    float4 finalColor=mix(float4(color,1.0),fieldTexture,0.3);
    
    return finalColor;
    
}



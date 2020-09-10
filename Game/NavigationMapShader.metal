//
//  NavigationMapShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 7/28/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include <simd/simd.h>
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

float sdCircle(float2 p, float2 c, float r)
{
    return abs(r - length(p - c));
}

float sdLine( float2 p, float2 a, float2 b)
{
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa,ba) / dot(ba,ba), 0., 1.);
    return length(pa - ba * h);
}




vertex VertexOutput vertexNavigationShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], constant UniformGlobalData &uniformGlobalData [[buffer(2)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    vertexOut.uvCoords=vert.uv;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    return vertexOut;
}

fragment float4 fragmentNavigationShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(0)]], constant UniformShaderEntityProperty &uniformShaderEntityProperty [[buffer(1)]], texture2d<float> texture[[texture(0)]], sampler sam [[sampler(0)]]){
    
    float2 st=-1. + 2. * vertexOut.uvCoords;
    
    //sample the texture color
    float4 fieldTexture=texture.sample(sam,vertexOut.uvCoords.xy);
    
    float3 color =float3(0.0);
    
    int navPathSize=(int)uniformShaderEntityProperty.shaderParameter[0].x;
    
    for(int i=1;i<navPathSize;i++){
        
        float2 pointA=float2(uniformShaderEntityProperty.shaderParameter[i].x,-uniformShaderEntityProperty.shaderParameter[i].y);
        float2 pointB=float2(uniformShaderEntityProperty.shaderParameter[i].z,-uniformShaderEntityProperty.shaderParameter[i].w);
        
        float c=sdCircle(st,pointA,0.02);
        c=sharpen(c,0.01*0.8,uniformGlobalData.resolution);
        
        color+=float3(c);
        
        c=sdCircle(st,pointB,0.02);
        c=sharpen(c,0.01*0.8,uniformGlobalData.resolution);
        
        color+=float3(c);
        
        float l=sdLine(st,pointA,pointB);
        
        l=sharpen(l,0.01*0.8,uniformGlobalData.resolution);
    
        color+=float3(l);
        
    }
    
    
//    //divide the field into spaces
//    st*=5.0;
//
//    float2 fid=fract(st);
//
//    float2 iid=floor(st);
//
//
//    //draw the lines separating the spaces
//    if(fid.x<0.05 || fid.x>0.95 || fid.y<0.05 || fid.y>0.95){
//
//        //color+=float3(0.0,0.0,0.9);
//
//    }

    float4 finalColor=mix(float4(color,1.0),fieldTexture,0.3);
    
    return finalColor;
    
}


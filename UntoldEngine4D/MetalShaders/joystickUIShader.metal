//
//  joystickUIShader.metal
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

vertex VertexOutput vertexUIJoystickShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(viSpaceBuffer)]], constant UniformGlobalData &uniformGlobalData [[buffer(viGlobalDataBuffer)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    vertexOut.uvCoords=vert.uv;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    return vertexOut;
}

fragment float4 fragmentUIJoystickShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(fiGlobalDataBuffer)]], constant UniformShaderEntityProperty &uniformShaderEntityProperty [[buffer(fiShaderEntityPropertyBuffer)]], texture2d<float> texture[[texture(fiTexture0)]], sampler sam [[sampler(fiSampler0)]], texture2d<float> texture2[[texture(fiTexture1)]], sampler sam2 [[sampler(fiSampler1)]]){
    
    float2 st=-1.0+2.0*vertexOut.uvCoords;
    float3 color =float3(0.0);
    float4 finalColor=float4(0.0);
    
    if(uniformShaderEntityProperty.hasTexture==true){
        
        //sample the texture color
        finalColor=texture.sample(sam,vertexOut.uvCoords.xy);
        
        //st+=float2(-uniformShaderEntityProperty.shaderParameter[0].x,uniformShaderEntityProperty.shaderParameter[0].y);
        
        float4 js=texture2.sample(sam2,st/0.5-float2(uniformShaderEntityProperty.shaderParameter[0].x,-uniformShaderEntityProperty.shaderParameter[0].y)+float2(0.5));
        
        finalColor=max(finalColor, js);
        
        //discard the fragment if the alpha value less than 0.15
        if(finalColor.a<0.15){
    
            //discard_fragment();
    
        }
        
    }else{
        
        float b=sdfRing(st,float2(0.0,0.0),0.8);
        
        b=sharpen(b,0.03,uniformGlobalData.resolution);
        
        color=float3(b)*float3(0.8,0.8,0.8);
        
        float s=sdfRing(st/0.5-float2(uniformShaderEntityProperty.shaderParameter[0].x,-uniformShaderEntityProperty.shaderParameter[0].y),float2(0.0,0.0),0.5);
        
        s=sharpen(s,0.03,uniformGlobalData.resolution);
        
        color=max(color,float3(s)*float3(0.96,0.18,0.25));
        
        finalColor=float4(color,1.0);
        
    }
    

    return finalColor;
    
}



//
//  buttonUIShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 9/20/20.
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

float3 lerp(float3 a, float3 b, float t){
    
    return (1.0f-t)*a+b*t;
    
}

vertex VertexOutput vertexUIButtonShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], constant UniformGlobalData &uniformGlobalData [[buffer(2)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    vertexOut.uvCoords=vert.uv;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    return vertexOut;
}

fragment float4 fragmentUIButtonShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(0)]], constant UniformShaderEntityProperty &uniformShaderEntityProperty [[buffer(1)]], texture2d<float> texture[[texture(0)]], sampler sam [[sampler(0)]]){
    
    float2 st=-1.0+2.0*vertexOut.uvCoords;
    float4 finalColor;
    
    //sample the texture color
    if(uniformShaderEntityProperty.hasTexture==true){
        
        finalColor=texture.sample(sam,vertexOut.uvCoords.xy);
    
        //discard the fragment if the alpha value less than 0.15
        if(finalColor.a<0.15){
    
            discard_fragment();
    
        }
        
    }else{
        
        float3 color=float3(0.0);
        
        float b=sdfBox(st,float2(1.0,1.0));
        
        b=abs(b)-0.1;
        
        b=sharpen(b,0.01,uniformGlobalData.resolution);
        
        color=float3(b)*backgroundColor;
        
        finalColor=float4(color,1.0);
        
    }

    
    float a=uniformShaderEntityProperty.shaderParameter[0].x;
    
    if(a==1.0){
    
        finalColor.rgb*=0.5;
        
    }
    
    return finalColor;
    
}


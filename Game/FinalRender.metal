//
//  FinalRender.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 12/20/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
#include "../UntoldEngine4D/MetalShaders/U4DShaderProtocols.h"
#include "../UntoldEngine4D/MetalShaders/U4DShaderHelperFunctions.h"

struct VertexInput {
    
    float4    position [[ attribute(0) ]];
    float4    uv       [[ attribute(2) ]];
    
};

struct VertexOutput{
    
    float4 position [[position]];
    float2 uvCoords;
    float4 color;
};


vertex VertexOutput vertexFinalRenderShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], constant UniformGlobalData &uniformGlobalData [[buffer(5)]], uint vid [[vertex_id]]){ 
    
    VertexOutput vertexOut;
    
    float4 position;
    
    //1. transform the vertices by the mvp transformation
    //position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    position.x=(float)(vid/2)*4.0-1.0;
    position.y=(float)(vid%2)*4.0-1.0;
    position.z=0.0;
    position.w=1.0;
    
    float2 tex;
    tex.x=(float)(vid/2)*2.0;
    tex.y=1.0-(float)(vid%2)*2.0;
    
    vertexOut.position=position;
    vertexOut.uvCoords=tex;
    
    
    return vertexOut;
    
}


fragment float4 fragmentFinalRenderShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(5)]], texture2d<float> offscreenTexture[[texture(4)]], sampler sam [[sampler(0)]]){
    

    float4 sampledTexture0Color=offscreenTexture.sample(sam,vertexOut.uvCoords);
    
    return sampledTexture0Color;

    
}



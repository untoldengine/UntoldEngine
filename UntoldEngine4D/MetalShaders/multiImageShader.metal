//
//  multiImageShader.metal
//  MetalRendering
//
//  Created by Harold Serrano on 7/12/17.
//  Copyright © 2017 Harold Serrano. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include <simd/simd.h>
#include "U4DShaderProtocols.h"

struct VertexInput {
    
    float4    position [[ attribute(0) ]];
    float2    uv       [[ attribute(1) ]];
    
};

struct VertexOutput{
    
    float4 position [[position]];
    float4 color;
    float2 uvCoords;
    
};

vertex VertexOutput vertexMultiImageShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    vertexOut.uvCoords=vert.uv;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    return vertexOut;
}

fragment float4 fragmentMultiImageShader(VertexOutput vertexOut [[stage_in]], constant UniformMultiImageState &uniformMultiImageState [[buffer(1)]], texture2d<float> mainTexture[[texture(0)]], sampler sam [[sampler(0)]], texture2d<float> secondaryTexture[[texture(1)]]){
    
    float4 sampledColor;
    
    if(uniformMultiImageState.changeImage==true){
        
        sampledColor=secondaryTexture.sample(sam,vertexOut.uvCoords);
        
    }else{
        
        sampledColor=mainTexture.sample(sam,vertexOut.uvCoords);
        
    }
    
    
    return sampledColor;
    
}


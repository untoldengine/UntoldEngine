//
//  OffscreenRender.metal
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

vertex VertexOutput vertexOffscreenShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], constant UniformGlobalData &uniformGlobalData [[buffer(5)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut; 
    
    float4 position;
    
    //1. transform the vertices by the mvp transformation
    position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
        
    vertexOut.uvCoords=vert.uv.xy;
    vertexOut.position=position;
    
    
    return vertexOut;
    
}


fragment float4 fragmentOffscreenShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(5)]], texture2d<float> texture[[texture(0)]], sampler sam [[sampler(0)]]){
    
    
    float4 sampledTextureColor=texture.sample(sam,vertexOut.uvCoords.xy);
    
    
    return sampledTextureColor;

}

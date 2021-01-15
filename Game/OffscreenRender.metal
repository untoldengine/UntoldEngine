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

vertex VertexOutput vertexOffscreenShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(viSpaceBuffer)]], constant UniformGlobalData &uniformGlobalData [[buffer(viGlobalDataBuffer)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut; 
    
    float4 position;
    
    //1. transform the vertices by the mvp transformation
    position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
        
    vertexOut.uvCoords=vert.uv.xy;
    vertexOut.position=position;
    
    
    return vertexOut;
    
}


fragment float4 fragmentOffscreenShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(fiGlobalDataBuffer)]], texture2d<float> texture[[texture(fiTexture0)]], sampler sam [[sampler(fiSampler0)]]){
    
    
    float4 sampledTextureColor=texture.sample(sam,vertexOut.uvCoords.xy);
    
    
    return sampledTextureColor;

}

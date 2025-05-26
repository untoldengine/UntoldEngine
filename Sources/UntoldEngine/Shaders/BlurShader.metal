//
//  BlurShader.metal
//  
//
//  Created by Harold Serrano on 5/23/25.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
using namespace metal;

vertex VertexCompositeOutput vertexBlurShader(VertexCompositeIn in [[stage_in]]){

    VertexCompositeOutput vertexOut;
    vertexOut.position=float4(float3(in.position),1.0);
    vertexOut.uvCoords=in.uvCoords;

    return vertexOut;
}

fragment float4 fragmentBlurShader(VertexCompositeOutput vertexOut [[stage_in]],
                                        texture2d<float> finalTexture[[texture(0)]],
                                        constant float2 &direction[[buffer(0)]],
                                        constant float2 &resolution[[buffer(1)]]){

    constexpr sampler s(min_filter::linear,mag_filter::linear);
    
    float3 color = finalTexture.sample(s, vertexOut.uvCoords).rgb;
    
    return float4(color,1.0);
    
}



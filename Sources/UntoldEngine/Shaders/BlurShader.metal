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

constant float4 blurSamples[9] = {
    float4(-1.0, -1.0, 0.0, 1.0 / 16.0),
    float4(-1.0,  1.0, 0.0, 1.0 / 16.0),
    float4( 1.0, -1.0, 0.0, 1.0 / 16.0),
    float4( 1.0,  1.0, 0.0, 1.0 / 16.0),
    float4( 0.0, -1.0, 0.0, 2.0 / 16.0),
    float4(-1.0,  0.0, 0.0, 2.0 / 16.0),
    float4( 1.0,  0.0, 0.0, 2.0 / 16.0),
    float4( 0.0,  1.0, 0.0, 2.0 / 16.0),
    float4( 0.0,  0.0, 0.0, 4.0 / 16.0)
};

vertex VertexCompositeOutput vertexBlurShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput vertexOut;
    vertexOut.position = float4(float3(in.position), 1.0);
    vertexOut.uvCoords = in.uvCoords;
    return vertexOut;
}

fragment float4 fragmentBlurShader(VertexCompositeOutput vertexOut [[stage_in]],
                                   texture2d<float> finalTexture [[texture(0)]])
{
    constexpr sampler s(address::clamp_to_edge, min_filter::linear, mag_filter::linear);

    uint width = finalTexture.get_width();
    uint height = finalTexture.get_height();
    float2 texelSize = 1.0 / float2(width, height);

    float3 color = float3(0.0);
    for (int i = 0; i < 9; i++) {
        float2 offset = blurSamples[i].xy * texelSize;
        color += blurSamples[i].w * finalTexture.sample(s, vertexOut.uvCoords + offset).rgb;
    }

    return float4(color, 1.0);
}

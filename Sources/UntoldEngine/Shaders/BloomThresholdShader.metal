//
//  BloomThresholdShader.metal
//  
//
//  Created by Harold Serrano on 5/27/25.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
using namespace metal;

vertex VertexCompositeOutput vertexBloomThresholdShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput vertexOut;
    vertexOut.position = float4(float3(in.position), 1.0);
    vertexOut.uvCoords = in.uvCoords;
    return vertexOut;
}

fragment float4 fragmentBloomThresholdShader(VertexCompositeOutput vertexOut [[stage_in]],
                                   texture2d<float> finalTexture [[texture(0)]],
                                    constant float &threshold[[buffer(bloomThresholdPassCutoffIndex)]],
                                    constant float &intensity[[buffer(bloomThresholdPassIntensityIndex)]])
{
    constexpr sampler s(address::clamp_to_edge, min_filter::linear, mag_filter::linear);

    float3 color = finalTexture.sample(s, vertexOut.uvCoords).rgb;

    // Compute luminance (can use different weights, these are common)
    float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));

    // Apply threshold
    float bloomFactor = max((luminance - threshold), 0.0);

    // Optional: boost the bloom brightness
    float3 bloomColor = color * bloomFactor * intensity;

    return float4(bloomColor, 1.0);
}



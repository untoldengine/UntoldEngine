//
//  VignetteShader.metal
//  
//
//  Created by Harold Serrano on 5/28/25.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
using namespace metal;

vertex VertexCompositeOutput vertexVignetteShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput vertexOut;
    vertexOut.position = float4(float3(in.position), 1.0);
    vertexOut.uvCoords = in.uvCoords;
    return vertexOut;
}

fragment float4 fragmentVignetteShader(VertexCompositeOutput vertexOut [[stage_in]],
                                   texture2d<float> finalTexture [[texture(0)]],
                                   constant float &intensity[[buffer(vignettePassIntensityIndex)]],
                                   constant float &radius[[buffer(vignettePassRadiusIndex)]],
                                   constant float &softness[[buffer(vignettePassSoftnessIndex)]],
                                   constant simd_float2 &center[[buffer(vignettePassCenterIndex)]])
{
    constexpr sampler s(address::clamp_to_edge, min_filter::linear, mag_filter::linear);

    float3 color = finalTexture.sample(s, vertexOut.uvCoords).rgb;
    
    float2 toCenter = vertexOut.uvCoords - center;
    float dist = length(toCenter);

    // Define fade start and fade end
    float fadeStart = radius;
    float fadeEnd = fadeStart + softness;

    // Compute vignette falloff
    float vignette = smoothstep(fadeStart, fadeEnd, dist);
    vignette = clamp(1.0 - vignette * intensity, 0.0, 1.0);

    // Apply
    color *= vignette;

    return float4(color, 1.0);
}




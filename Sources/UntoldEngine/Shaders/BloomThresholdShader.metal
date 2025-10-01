//
//  BloomThresholdShader.metal
//  
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
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
                                    texture2d<float> emissiveTexture [[texture(1)]],
                                    constant float &threshold[[buffer(bloomThresholdPassCutoffIndex)]],
                                    constant float &intensity[[buffer(bloomThresholdPassIntensityIndex)]],
                                    constant bool &enabled[[buffer(bloomThresholdPassEnabledIndex)]])
{
    constexpr sampler s(address::clamp_to_edge, min_filter::linear, mag_filter::linear);

    float3 color = emissiveTexture.sample(s, vertexOut.uvCoords).rgb;
    
    if(!enabled){
        return float4(0.0,0.0,0.0, 1.0);
    }

    // Compute luminance (can use different weights, these are common)
    float luminance = getLuminance(color);
    // Apply threshold
    float bloomFactor = max((luminance - threshold), 0.0);

    // Optional: boost the bloom brightness
    float3 bloomColor = color * bloomFactor * intensity;

    return float4(bloomColor, 1.0);
}



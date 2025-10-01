//
//  BloomCompositeShader.metal
//  
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
using namespace metal;

vertex VertexCompositeOutput vertexBloomCompositeShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput vertexOut;
    vertexOut.position = float4(float3(in.position), 1.0);
    vertexOut.uvCoords = in.uvCoords;
    return vertexOut;
}

fragment float4 fragmentBloomCompositeShader(VertexCompositeOutput vertexOut [[stage_in]],
                                   texture2d<float> finalTexture [[texture(1)]],
                                    texture2d<float> bloomTexture [[texture(0)]],
                                    constant float &intensity [[buffer(bloomCompositePassIntensityIndex)]],
                                             constant bool &enabled[[buffer(bloomCompositePassEnabledIndex)]])
{
    constexpr sampler s(address::clamp_to_edge, min_filter::linear, mag_filter::linear);

    float3 originalColor = finalTexture.sample(s, vertexOut.uvCoords).rgb;
    
    if(!enabled){
        return float4(originalColor,1.0);
    }

    float3 bloom = bloomTexture.sample(s, vertexOut.uvCoords).rgb;

    float3 finalColor = originalColor + bloom * intensity;

    return float4(finalColor, 1.0);

}

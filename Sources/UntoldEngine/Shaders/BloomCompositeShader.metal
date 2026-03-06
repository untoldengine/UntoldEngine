//
//  BloomCompositeShader.metal
//  
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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

    float4 originalSample = finalTexture.sample(s, vertexOut.uvCoords);
    float3 originalColor = originalSample.rgb;
    float originalAlpha = originalSample.a;
    
    if(!enabled){
        return float4(originalColor, originalAlpha);
    }

    float3 bloom = bloomTexture.sample(s, vertexOut.uvCoords).rgb;

    float3 finalColor = originalColor + bloom * intensity;

    return float4(finalColor, originalAlpha);

}

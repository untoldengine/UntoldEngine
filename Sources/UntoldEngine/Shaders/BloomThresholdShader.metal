//
//  BloomThresholdShader.metal
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

vertex VertexCompositeOutput vertexBloomThresholdShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput vertexOut;
    vertexOut.position = float4(float3(in.position), 1.0);
    vertexOut.uvCoords = in.uvCoords;
    return vertexOut;
}

fragment float4 fragmentBloomThresholdShader(VertexCompositeOutput vertexOut [[stage_in]],
                                   texture2d<float> finalTexture [[texture(0)]],
                                   constant float &threshold[[buffer(bloomThresholdPassCutoffIndex)]],
                                   constant float &intensity[[buffer(bloomThresholdPassIntensityIndex)]],
                                   constant bool &enabled[[buffer(bloomThresholdPassEnabledIndex)]])
{
    constexpr sampler s(address::clamp_to_edge, min_filter::linear, mag_filter::linear);

    if(!enabled){
        return float4(0.0, 0.0, 0.0, 1.0);
    }

    // Sample the full HDR scene color (includes emissive, specular highlights, etc.)
    float3 color = finalTexture.sample(s, vertexOut.uvCoords).rgb;

    float luminance = getLuminance(color);
    float bloomFactor = max(luminance - threshold, 0.0);
    float3 bloomColor = color * bloomFactor * intensity;

    return float4(bloomColor, 1.0);
}



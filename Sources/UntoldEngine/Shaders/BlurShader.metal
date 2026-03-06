//
//  BlurShader.metal
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

constant float2 blurSamples[5] = {
    float2(-2.0, 0.12),
    float2(-1.0, 0.24),
    float2( 0.0, 0.28),
    float2( 1.0, 0.24),
    float2( 2.0, 0.12)
};

vertex VertexCompositeOutput vertexBlurShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput vertexOut;
    vertexOut.position = float4(float3(in.position), 1.0);
    vertexOut.uvCoords = in.uvCoords;
    return vertexOut;
}

fragment float4 fragmentBlurShader(VertexCompositeOutput vertexOut [[stage_in]],
                                   texture2d<float> finalTexture [[texture(0)]],
                                   constant float2 &direction [[buffer(blurPassDirectionIndex)]],
                                   constant float &blurRadius [[buffer(blurPassRadiusIndex)]],
                                   constant bool &enabled[[buffer(blurPassEnabledIndex)]])
{
    constexpr sampler s(address::clamp_to_edge, min_filter::linear, mag_filter::linear);

    if (!enabled){
        return finalTexture.sample(s, vertexOut.uvCoords);
    }
    
    uint width = finalTexture.get_width();
    uint height = finalTexture.get_height();
    float2 texelSize = 1.0 / float2(width, height);

    float4 color = float4(0.0);
    for (int i = 0; i < 5; i++) {
        float offset = blurSamples[i].x;
        float weight = blurSamples[i].y;

        float2 sampleOffset = direction * offset * texelSize*blurRadius;
        color += weight * finalTexture.sample(s, vertexOut.uvCoords + sampleOffset);
    }

    return color;
    
}

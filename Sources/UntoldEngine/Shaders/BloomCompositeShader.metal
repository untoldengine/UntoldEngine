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
                                   texture2d<float> bloomTexture  [[texture(0)]],
                                   texture2d<float> sceneTexture  [[texture(1)]],
                                   constant float &intensity      [[buffer(bloomCompositePassIntensityIndex)]],
                                   constant bool  &enabled        [[buffer(bloomCompositePassEnabledIndex)]])
{
    constexpr sampler s(address::clamp_to_edge, min_filter::linear, mag_filter::linear);

    float4 sceneSample = sceneTexture.sample(s, vertexOut.uvCoords);

    if (!enabled) {
        return sceneSample;
    }

    float3 bloom = bloomTexture.sample(s, vertexOut.uvCoords).rgb;

    return float4(sceneSample.rgb + bloom * intensity, sceneSample.a);
}

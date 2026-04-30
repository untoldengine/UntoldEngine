//
//  ColorCorrectionShader.metal
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

vertex VertexCompositeOutput vertexColorCorrectionShader(VertexCompositeIn in [[stage_in]]){

    VertexCompositeOutput vertexOut;
    vertexOut.position=float4(float3(in.position),1.0);
    vertexOut.uvCoords=in.uvCoords;

    return vertexOut;
}

fragment float4 fragmentColorCorrectionShader(VertexCompositeOutput vertexOut [[stage_in]],
                                        texture2d<float>      finalTexture [[texture(0)]],
                                        constant simd_float3 &lift         [[buffer(colorCorrectionPassLiftIndex)]],
                                        constant simd_float3 &gamma        [[buffer(colorCorrectionPassGammaIndex)]],
                                        constant simd_float3 &gain         [[buffer(colorCorrectionPassGainIndex)]],
                                        constant bool        &enabled      [[buffer(colorCorrectionPassEnabledIndex)]])
{
    constexpr sampler s(min_filter::linear, mag_filter::linear, address::clamp_to_edge);

    float4 sample = finalTexture.sample(s, vertexOut.uvCoords);

    if (!enabled) {
        return sample;
    }

    float3 color = sample.rgb;

    color = color + lift;
    color = pow(max(color, 0.0), gamma);
    color *= gain;

    return float4(clamp(color, 0.0, 1.0), sample.a);
}


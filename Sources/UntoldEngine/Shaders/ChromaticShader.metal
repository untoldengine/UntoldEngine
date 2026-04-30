//
//  ChromaticShader.metal
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

vertex VertexCompositeOutput vertexChromaticAberrationShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput vertexOut;
    vertexOut.position = float4(float3(in.position), 1.0);
    vertexOut.uvCoords = in.uvCoords;
    return vertexOut;
}

fragment float4 fragmentChromaticAberrationShader(VertexCompositeOutput vertexOut [[stage_in]],
                                   texture2d<float> finalTexture [[texture(0)]],
                                    constant float &intensity [[buffer(chromaticAberrationPassIntensityIndex)]],
                                    constant simd_float2 &center[[buffer(chromaticAberrationPassCenterIndex)]],
                                                  constant bool &enabled[[buffer(chromaticAberrationPassEnabledIndex)]])
{
    constexpr sampler s(address::clamp_to_edge, min_filter::linear, mag_filter::linear);
    
    float2 uv = vertexOut.uvCoords;
   
    if (!enabled){
        return finalTexture.sample(s, uv);
    }
    
    // Normalize the direction in aspect-corrected space so the aberration
    // magnitude is uniform regardless of direction from center on any
    // non-square framebuffer, then convert the offset back to UV space.
    float aspectRatio = float(finalTexture.get_width()) / float(finalTexture.get_height());
    float2 offset = normalize((uv - center) * float2(aspectRatio, 1.0)) * intensity;
    offset.x /= aspectRatio;

    float4 centerSample = finalTexture.sample(s, uv);
    float red   = finalTexture.sample(s, uv + offset).r;
    float blue  = finalTexture.sample(s, uv - offset).b;

    return float4(red, centerSample.g, blue, centerSample.a);
}




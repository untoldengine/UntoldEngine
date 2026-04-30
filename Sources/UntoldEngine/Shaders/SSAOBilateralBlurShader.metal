//
//  SSAOBilateralBlurShader.metal
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
#include "ShadersUtils.h"
using namespace metal;

vertex VertexCompositeOutput vertexSSAOBilateralBlurShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput vertexOut;
    vertexOut.position = float4(float3(in.position), 1.0);
    vertexOut.uvCoords = in.uvCoords;
    return vertexOut;
}

// Separable bilateral blur for SSAO
// This is much faster than the box blur (2 passes of 5 taps vs 1 pass of 16 taps)
fragment float4 fragmentSSAOBilateralBlurShader(VertexCompositeOutput vertexOut [[stage_in]],
                                                texture2d<float> ssaoTexture    [[texture(0)]],
                                                texture2d<float> depthTexture   [[texture(1)]],
                                                constant float2 &blurDirection  [[buffer(0)]],
                                                constant bool   &enabled        [[buffer(1)]],
                                                constant float2 &frustumPlanes  [[buffer(2)]],
                                                constant bool   &reverseZ       [[buffer(3)]])
{
    if (!enabled) {
        return float4(1.0);
    }

    constexpr sampler s(min_filter::nearest, mag_filter::nearest,
                        s_address::clamp_to_edge, t_address::clamp_to_edge);

    uint width = ssaoTexture.get_width();
    uint height = ssaoTexture.get_height();
    float2 texelSize = 1.0 / float2(width, height);

    // Linearize raw depth so the sigma is in consistent world-space units
    // regardless of depth convention (reverse-Z on Vision Pro, standard elsewhere).
    float centerLinear = linearizeDepth(depthTexture.sample(s, vertexOut.uvCoords).r,
                                        frustumPlanes.x, frustumPlanes.y, reverseZ);

    // Bilateral blur parameters
    const int   kernelRadius  = 2;
    const float depthSigma    = 0.5; // world-space units; ~0.5 m edge threshold
    const float spatialSigma  = 2.0;

    float totalWeight = 1.0;
    float result = ssaoTexture.sample(s, vertexOut.uvCoords).r;

    for (int i = 1; i <= kernelRadius; ++i) {
        float2 offset  = blurDirection * texelSize * float(i);
        float2 uvPlus  = vertexOut.uvCoords + offset;
        float2 uvMinus = vertexOut.uvCoords - offset;

        float aoPlus  = ssaoTexture.sample(s, uvPlus).r;
        float aoMinus = ssaoTexture.sample(s, uvMinus).r;

        float linearPlus  = linearizeDepth(depthTexture.sample(s, uvPlus).r,
                                           frustumPlanes.x, frustumPlanes.y, reverseZ);
        float linearMinus = linearizeDepth(depthTexture.sample(s, uvMinus).r,
                                           frustumPlanes.x, frustumPlanes.y, reverseZ);

        float weightPlus  = exp(-abs(centerLinear - linearPlus)  / depthSigma)
                          * exp(-float(i * i) / spatialSigma);
        float weightMinus = exp(-abs(centerLinear - linearMinus) / depthSigma)
                          * exp(-float(i * i) / spatialSigma);

        result       += aoPlus  * weightPlus + aoMinus * weightMinus;
        totalWeight  += weightPlus + weightMinus;
    }

    result /= totalWeight;
    return float4(result, result, result, 1.0);
}

//
//  DoFShader.metal
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

vertex VertexCompositeOutput vertexDepthOfFieldShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput vertexOut;
    vertexOut.position = float4(float3(in.position), 1.0);
    vertexOut.uvCoords = in.uvCoords;
    return vertexOut;
}

float computeBlurAmount(float linearDepth, float focusDistance, float focusRange) {
    float halfRange = focusRange * 0.5;
    float distanceFromFocus = abs(linearDepth - focusDistance);

    // Fully in focus if inside band
    if (distanceFromFocus <= halfRange) {
        return 0.0;
    }

    // Linearly increase blur beyond focus band
    return saturate((distanceFromFocus - halfRange) / halfRange);
}


fragment float4 fragmentDepthOfFieldShader(VertexCompositeOutput vertexOut [[stage_in]],
                                   texture2d<float> finalTexture [[texture(0)]],
                                   depth2d<float> depthTexture [[texture(1)]],
                                   constant float &focusDistance[[buffer(depthOfFieldPassFocusDistanceIndex)]],
                                   constant float &focusRange[[buffer(depthOfFieldPassFocusRangeIndex)]],
                                   constant float &maxBlur[[buffer(depthOfFieldPassMaxBlurIndex)]],
                                   constant float2 &frustumPlanes[[buffer(depthOfFieldPassFrustumIndex)]],
                                   constant bool &enabled[[buffer(depthOfFieldPassEnabledIndex)]],
                                   constant bool &reverseZ[[buffer(depthOfFieldPassReverseZIndex)]])
{
    constexpr sampler s(address::clamp_to_edge, min_filter::linear, mag_filter::linear);

    if (!enabled){
        return finalTexture.sample(s, vertexOut.uvCoords);
    }

    // Get scene depth at this pixel
    float rawDepth = depthTexture.sample(s, vertexOut.uvCoords);
    float linearDepth = linearizeDepth(rawDepth, frustumPlanes.x, frustumPlanes.y, reverseZ);
    
    // Compute blur factor
    float blurFactor = computeBlurAmount(linearDepth, focusDistance, focusRange);

    // Convert radius from pixels to UV space so the bokeh disc is circular
    // regardless of framebuffer aspect ratio.
    float2 texelSize = float2(1.0 / float(finalTexture.get_width()),
                              1.0 / float(finalTexture.get_height()));
    float radius = blurFactor * maxBlur;

    float4 color = float4(0.0);
    int samples = 8;

    for (int i = 0; i < samples; ++i) {
        float angle = float(i) / float(samples) * 2.0 * M_PI_F;
        float2 offset = float2(cos(angle), sin(angle)) * radius * texelSize;
        color += finalTexture.sample(s, vertexOut.uvCoords + offset);
    }

    color /= float(samples);
    return color;
}


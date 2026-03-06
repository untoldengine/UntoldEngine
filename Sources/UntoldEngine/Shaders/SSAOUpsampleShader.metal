//
//  SSAOUpsampleShader.metal
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

vertex VertexCompositeOutput vertexSSAOUpsampleShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput vertexOut;
    vertexOut.position = float4(float3(in.position), 1.0);
    vertexOut.uvCoords = in.uvCoords;
    return vertexOut;
}

// Depth-aware bilateral upsample from half-res to full-res
// Uses depth buffer to prevent edge bleeding
fragment float4 fragmentSSAOUpsampleShader(VertexCompositeOutput vertexOut [[stage_in]],
                                          texture2d<float> ssaoLowRes [[texture(0)]],
                                          texture2d<float> depthFullRes [[texture(1)]],
                                          constant bool &useDepthAware [[buffer(0)]])
{
    constexpr sampler linearSampler(min_filter::linear, mag_filter::linear,
                                    s_address::clamp_to_edge, t_address::clamp_to_edge);
    
    constexpr sampler pointSampler(min_filter::nearest, mag_filter::nearest,
                                   s_address::clamp_to_edge, t_address::clamp_to_edge);
    
    // Simple bilinear upsample (fast path)
    if (!useDepthAware) {
        float ao = ssaoLowRes.sample(linearSampler, vertexOut.uvCoords).r;
        return float4(ao, ao, ao, 1.0);
    }
    
    // Depth-aware bilateral upsample (quality path)
    uint2 fullResCoord = uint2(vertexOut.uvCoords * float2(depthFullRes.get_width(), depthFullRes.get_height()));
    float centerDepth = depthFullRes.read(fullResCoord).r;
    
    uint lowResWidth = ssaoLowRes.get_width();
    uint lowResHeight = ssaoLowRes.get_height();
    float2 lowResTexelSize = 1.0 / float2(lowResWidth, lowResHeight);
    
    // Sample 4 nearest low-res texels
    float2 lowResUV = vertexOut.uvCoords;
    float2 texelCenter = floor(lowResUV / lowResTexelSize) * lowResTexelSize + lowResTexelSize * 0.5;
    
    // Offsets to 2x2 neighborhood
    float2 offsets[4] = {
        float2(-0.5, -0.5) * lowResTexelSize,
        float2( 0.5, -0.5) * lowResTexelSize,
        float2(-0.5,  0.5) * lowResTexelSize,
        float2( 0.5,  0.5) * lowResTexelSize
    };
    
    float totalAO = 0.0;
    float totalWeight = 0.0;
    
    const float depthThreshold = 0.02; // Adjust based on scene depth range
    
    for (int i = 0; i < 4; ++i) {
        float2 sampleUV = texelCenter + offsets[i];
        float ao = ssaoLowRes.sample(pointSampler, sampleUV).r;
        
        // Get corresponding depth in full-res
        float2 depthUV = sampleUV;
        float sampleDepth = depthFullRes.sample(pointSampler, depthUV).r;
        
        // Depth-based weight
        float depthDiff = abs(centerDepth - sampleDepth);
        float weight = exp(-depthDiff / depthThreshold);
        
        totalAO += ao * weight;
        totalWeight += weight;
    }
    
    float result = (totalWeight > 0.0001) ? (totalAO / totalWeight) : ssaoLowRes.sample(linearSampler, vertexOut.uvCoords).r;
    
    return float4(result, result, result, 1.0);
}

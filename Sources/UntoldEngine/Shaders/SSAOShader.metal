//
//  SSAOShader.metal
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
using namespace metal;

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
using namespace metal;

vertex VertexCompositeOutput vertexSSAOShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput vertexOut;
    vertexOut.position = float4(float3(in.position), 1.0);
    vertexOut.uvCoords = in.uvCoords;
    return vertexOut;
}

fragment float4 fragmentSSAOShader(VertexCompositeOutput vertexOut [[stage_in]],
                                   depth2d<float> depthTexture [[texture(ssaoDepthTextureIndex)]],
                                   constant float &radius    [[buffer(ssaoPassRadiusIndex)]],
                                   constant float &bias      [[buffer(ssaoPassBiasIndex)]],
                                   constant float &intensity [[buffer(ssaoPassIntensityIndex)]],
                                   constant bool  &enabled   [[buffer(ssaoPassEnabledIndex)]],
                                   constant float2 &viewPort [[buffer(ssaoPassViewPortIndex)]],
                                   constant float2 &frustumPlanes [[buffer(ssaoPassFrustumIndex)]],
                                   constant bool &reverseZ [[buffer(ssaoPassReverseZIndex)]]
                                   )
{
    if (!enabled){
        return float4(1.0,1.0,1.0, 1.0);
    }

    constexpr sampler s(min_filter::linear, mag_filter::linear, mip_filter::none,
                        s_address::clamp_to_edge, t_address::clamp_to_edge);

    float rawDepth = depthTexture.sample(s, vertexOut.uvCoords);
    if ((reverseZ && rawDepth <= 0.00001) || (!reverseZ && rawDepth >= 0.99999)) {
        return float4(1.0);
    }

    float centerDepth = linearizeDepth(rawDepth, frustumPlanes.x, frustumPlanes.y, reverseZ);
    float2 texelSize = 1.0 / max(viewPort, float2(1.0));
    float pixelRadius = clamp(radius * 220.0 / max(centerDepth, 0.001), 2.0, 48.0);

    const int sampleCount = 16;
    const float goldenAngle = 2.399963;
    float occlusion = 0.0;

    for (int i = 0; i < sampleCount; ++i) {
        float r = sqrt((float(i) + 0.5) / float(sampleCount));
        float angle = float(i) * goldenAngle;
        float2 offset = float2(cos(angle), sin(angle)) * r * pixelRadius * texelSize;

        float sampleRawDepth = depthTexture.sample(s, vertexOut.uvCoords + offset);
        if ((reverseZ && sampleRawDepth <= 0.00001) || (!reverseZ && sampleRawDepth >= 0.99999)) {
            continue;
        }

        float sampleDepth = linearizeDepth(sampleRawDepth, frustumPlanes.x, frustumPlanes.y, reverseZ);
        float depthDelta = centerDepth - sampleDepth;
        float rangeCheck = 1.0 - smoothstep(0.0, radius, abs(depthDelta));
        occlusion += (depthDelta > bias ? 1.0 : 0.0) * rangeCheck;
    }

    // Blend between no-occlusion (1.0) and full AO using intensity.
    // intensity=0 → effect invisible, intensity=1 → full computed AO.
    float ao = mix(1.0, 1.0 - (occlusion / float(sampleCount)), intensity);

    return float4(ao, ao, ao, 1.0);
}

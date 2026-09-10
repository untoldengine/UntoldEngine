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

// Reconstructs a view-space position from a UV + linear view-space depth using the
// projection's perspective scale terms (proj[0][0], proj[1][1]). Only relative
// positions/distances between reconstructions of this same function are meaningful —
// the absolute axis orientation is arbitrary but self-consistent, which is all the
// occlusion test below needs.
static float3 reconstructViewPos(float2 uv, float linearDepth, float2 projScale) {
    float2 ndc = (uv - 0.5) * 2.0;
    float2 xy = ndc * linearDepth / projScale;
    return float3(xy, linearDepth);
}

fragment float4 fragmentSSAOShader(VertexCompositeOutput vertexOut [[stage_in]],
                                   depth2d<float> depthTexture [[texture(ssaoDepthTextureIndex)]],
                                   constant float &radius    [[buffer(ssaoPassRadiusIndex)]],
                                   constant float &bias      [[buffer(ssaoPassBiasIndex)]],
                                   constant float &intensity [[buffer(ssaoPassIntensityIndex)]],
                                   constant bool  &enabled   [[buffer(ssaoPassEnabledIndex)]],
                                   constant float2 &viewPort [[buffer(ssaoPassViewPortIndex)]],
                                   constant float2 &frustumPlanes [[buffer(ssaoPassFrustumIndex)]],
                                   constant bool &reverseZ [[buffer(ssaoPassReverseZIndex)]],
                                   constant float2 &projScale [[buffer(ssaoPassProjScaleIndex)]]
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

    float3 centerPosition = reconstructViewPos(vertexOut.uvCoords, centerDepth, projScale);
    // No normal G-buffer is available here — normalMap/positionMap are memoryless
    // (TBDR tile-only) in normal rendering and can't be bound to a later, separate
    // pass. Derive the surface normal from the depth buffer itself via screen-space
    // derivatives of the reconstructed position.
    float3 centerNormal = normalize(cross(dfdx(centerPosition), dfdy(centerPosition)));
    // dfdx/dfdy winding is arbitrary (depends on Metal's screen-space handedness), so
    // the cross product can come out facing either way. centerPosition is the vector
    // from the camera (at this reconstruction's origin) to the surface, so a normal
    // that actually faces the camera must point opposite it — flip if it doesn't.
    // Without this, every genuine occluder reads as a negative dot product and gets
    // clamped to zero, silently discarding real corner/crease occlusion everywhere.
    if (dot(centerNormal, centerPosition) > 0.0) {
        centerNormal = -centerNormal;
    }

    const int sampleCount = 16;
    const float goldenAngle = 2.399963;
    float occlusion = 0.0;

    for (int i = 0; i < sampleCount; ++i) {
        float r = sqrt((float(i) + 0.5) / float(sampleCount));
        float angle = float(i) * goldenAngle;
        float2 offset = float2(cos(angle), sin(angle)) * r * pixelRadius * texelSize;
        float2 sampleUV = vertexOut.uvCoords + offset;

        float sampleRawDepth = depthTexture.sample(s, sampleUV);
        if ((reverseZ && sampleRawDepth <= 0.00001) || (!reverseZ && sampleRawDepth >= 0.99999)) {
            continue;
        }

        float sampleLinearDepth = linearizeDepth(sampleRawDepth, frustumPlanes.x, frustumPlanes.y, reverseZ);
        float3 samplePosition = reconstructViewPos(sampleUV, sampleLinearDepth, projScale);
        float3 toSample = samplePosition - centerPosition;
        float sampleDistance = length(toSample);
        if (sampleDistance < 1e-5) {
            continue;
        }

        // Occlusion relative to the surface normal, not raw screen-space depth,
        // so a sample on the same tangent plane (a sloped floor/wall) contributes
        // ~0 regardless of view angle instead of drifting with camera movement.
        float NdotS = dot(centerNormal, toSample / sampleDistance);
        float rangeCheck = 1.0 - smoothstep(0.0, radius, sampleDistance);
        occlusion += max(0.0, NdotS - bias) * rangeCheck;
    }

    // Blend between no-occlusion (1.0) and full AO using intensity.
    // intensity=0 → effect invisible, intensity=1 → full computed AO.
    float ao = mix(1.0, 1.0 - saturate(occlusion / float(sampleCount)), intensity);

    return float4(ao, ao, ao, 1.0);
}

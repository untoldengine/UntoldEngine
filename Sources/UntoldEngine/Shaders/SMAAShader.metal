//
//  SMAAShader.metal
//  UntoldEngine
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

inline float smaaLumaFromLinear(float3 c) {
    return dot(sqrt(max(c, 0.0)), float3(0.299, 0.587, 0.114));
}

inline float smaaGuardedLuma(float4 neighbor, float centerLuma, float alphaThreshold) {
    return neighbor.a > alphaThreshold ? smaaLumaFromLinear(neighbor.rgb) : centerLuma;
}

vertex VertexCompositeOutput vertexSMAAShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput out;
    out.position = float4(float3(in.position), 1.0);
    out.uvCoords = in.uvCoords;
    return out;
}

fragment float4 fragmentSMAAEdgeDetectionShader(
    VertexCompositeOutput in          [[stage_in]],
    texture2d<float>      colorTexture[[texture(0)]],
    constant float2      &texelSize   [[buffer(smaaPassTexelSizeIndex)]],
    constant float       &threshold   [[buffer(smaaPassEdgeThresholdIndex)]]
) {
    constexpr sampler s(min_filter::linear, mag_filter::linear, address::clamp_to_edge);

    const float kAlpha = 0.1;
    float2 uv = in.uvCoords;

    float4 center = colorTexture.sample(s, uv);
    if (center.a <= kAlpha) {
        return float4(0.0);
    }

    float lumaM = smaaLumaFromLinear(center.rgb);
    float lumaL = smaaGuardedLuma(colorTexture.sample(s, uv + float2(-1.0, 0.0) * texelSize), lumaM, kAlpha);
    float lumaT = smaaGuardedLuma(colorTexture.sample(s, uv + float2(0.0, -1.0) * texelSize), lumaM, kAlpha);

    float2 delta = abs(float2(lumaM - lumaL, lumaM - lumaT));
    float2 edges = step(float2(threshold), delta);

    if (dot(edges, float2(1.0)) == 0.0) {
        discard_fragment();
    }

    float lumaR = smaaGuardedLuma(colorTexture.sample(s, uv + float2(1.0, 0.0) * texelSize), lumaM, kAlpha);
    float lumaB = smaaGuardedLuma(colorTexture.sample(s, uv + float2(0.0, 1.0) * texelSize), lumaM, kAlpha);

    float2 maxDelta = max(delta, abs(float2(lumaM - lumaR, lumaM - lumaB)));

    float lumaL2 = smaaGuardedLuma(colorTexture.sample(s, uv + float2(-2.0, 0.0) * texelSize), lumaM, kAlpha);
    float lumaT2 = smaaGuardedLuma(colorTexture.sample(s, uv + float2(0.0, -2.0) * texelSize), lumaM, kAlpha);
    maxDelta = max(maxDelta, abs(float2(lumaL - lumaL2, lumaT - lumaT2)));

    float finalDelta = max(maxDelta.x, maxDelta.y);
    edges *= step(float2(finalDelta), 2.0 * delta);

    if (dot(edges, float2(1.0)) == 0.0) {
        discard_fragment();
    }

    return float4(edges, 0.0, 1.0);
}

constant int SMAA_MAX_SEARCH_STEPS = 8;
constant float SMAA_AREATEX_MAX_DISTANCE = 16.0;
constant float2 SMAA_AREATEX_PIXEL_SIZE = float2(1.0 / 160.0, 1.0 / 560.0);
constant float SMAA_AREATEX_SUBTEX_SIZE = 1.0 / 7.0;
constant float2 SMAA_SEARCHTEX_SIZE = float2(66.0, 33.0);
constant float2 SMAA_SEARCHTEX_PACKED_SIZE = float2(64.0, 16.0);

inline float2 smaaSampleEdges(texture2d<float> edgesTexture, sampler s, float2 uv) {
    return edgesTexture.sample(s, uv).rg;
}

inline float2 smaaSampleEdgesOffset(texture2d<float> edgesTexture, sampler s, float2 uv, int2 offset, float2 texelSize) {
    return edgesTexture.sample(s, uv + float2(offset) * texelSize).rg;
}

float smaaSearchLength(texture2d<float> searchTexture, sampler s, float2 e, float bias) {
    float2 searchScale = SMAA_SEARCHTEX_SIZE * float2(0.5, -1.0);
    float2 searchBias = SMAA_SEARCHTEX_SIZE * float2(bias, 1.0);

    searchScale += float2(-1.0, 1.0);
    searchBias += float2(0.5, -0.5);

    searchScale /= SMAA_SEARCHTEX_PACKED_SIZE;
    searchBias /= SMAA_SEARCHTEX_PACKED_SIZE;

    return searchTexture.sample(s, searchScale * e + searchBias).r;
}

float smaaSearchXLeft(
    texture2d<float> edgesTexture,
    texture2d<float> searchTexture,
    sampler edgesSampler,
    sampler searchSampler,
    float2 texcoord,
    float end,
    float2 texelSize
) {
    float2 e = float2(0.0, 1.0);
    for (int i = 0; i < SMAA_MAX_SEARCH_STEPS; i++) {
        e = smaaSampleEdges(edgesTexture, edgesSampler, texcoord);
        texcoord -= float2(2.0, 0.0) * texelSize;
        if (!(texcoord.x > end && e.y > 0.8281 && e.x == 0.0)) {
            break;
        }
    }

    float offset = 3.25 - (255.0 / 127.0) * smaaSearchLength(searchTexture, searchSampler, e, 0.0);
    return texcoord.x + offset * texelSize.x;
}

float smaaSearchXRight(
    texture2d<float> edgesTexture,
    texture2d<float> searchTexture,
    sampler edgesSampler,
    sampler searchSampler,
    float2 texcoord,
    float end,
    float2 texelSize
) {
    float2 e = float2(0.0, 1.0);
    for (int i = 0; i < SMAA_MAX_SEARCH_STEPS; i++) {
        e = smaaSampleEdges(edgesTexture, edgesSampler, texcoord);
        texcoord += float2(2.0, 0.0) * texelSize;
        if (!(texcoord.x < end && e.y > 0.8281 && e.x == 0.0)) {
            break;
        }
    }

    float offset = 3.25 - (255.0 / 127.0) * smaaSearchLength(searchTexture, searchSampler, e, 0.5);
    return texcoord.x - offset * texelSize.x;
}

float smaaSearchYUp(
    texture2d<float> edgesTexture,
    texture2d<float> searchTexture,
    sampler edgesSampler,
    sampler searchSampler,
    float2 texcoord,
    float end,
    float2 texelSize
) {
    float2 e = float2(1.0, 0.0);
    for (int i = 0; i < SMAA_MAX_SEARCH_STEPS; i++) {
        e = smaaSampleEdges(edgesTexture, edgesSampler, texcoord);
        texcoord -= float2(0.0, 2.0) * texelSize;
        if (!(texcoord.y > end && e.x > 0.8281 && e.y == 0.0)) {
            break;
        }
    }

    float offset = 3.25 - (255.0 / 127.0) * smaaSearchLength(searchTexture, searchSampler, e.yx, 0.0);
    return texcoord.y + offset * texelSize.y;
}

float smaaSearchYDown(
    texture2d<float> edgesTexture,
    texture2d<float> searchTexture,
    sampler edgesSampler,
    sampler searchSampler,
    float2 texcoord,
    float end,
    float2 texelSize
) {
    float2 e = float2(1.0, 0.0);
    for (int i = 0; i < SMAA_MAX_SEARCH_STEPS; i++) {
        e = smaaSampleEdges(edgesTexture, edgesSampler, texcoord);
        texcoord += float2(0.0, 2.0) * texelSize;
        if (!(texcoord.y < end && e.x > 0.8281 && e.y == 0.0)) {
            break;
        }
    }

    float offset = 3.25 - (255.0 / 127.0) * smaaSearchLength(searchTexture, searchSampler, e.yx, 0.5);
    return texcoord.y - offset * texelSize.y;
}

float2 smaaArea(texture2d<float> areaTexture, sampler s, float2 dist, float e1, float e2, float offset) {
    float2 texcoord = SMAA_AREATEX_MAX_DISTANCE * round(4.0 * float2(e1, e2)) + dist;
    texcoord = SMAA_AREATEX_PIXEL_SIZE * texcoord + 0.5 * SMAA_AREATEX_PIXEL_SIZE;
    texcoord.y += SMAA_AREATEX_SUBTEX_SIZE * offset;
    return areaTexture.sample(s, texcoord).rg;
}

fragment float4 fragmentSMAABlendWeightShader(
    VertexCompositeOutput in             [[stage_in]],
    texture2d<float>      edgesTexture   [[texture(0)]],
    texture2d<float>      areaTexture    [[texture(1)]],
    texture2d<float>      searchTexture  [[texture(2)]],
    constant float2      &texelSize      [[buffer(smaaPassTexelSizeIndex)]]
) {
    constexpr sampler edgesSampler(min_filter::linear, mag_filter::linear, address::clamp_to_edge);
    constexpr sampler areaSampler(min_filter::linear, mag_filter::linear, address::clamp_to_edge);
    constexpr sampler searchSampler(min_filter::nearest, mag_filter::nearest, address::clamp_to_edge);

    float2 texcoord = in.uvCoords;
    float2 pixcoord = texcoord / texelSize;
    float4 weights = float4(0.0);
    float2 e = smaaSampleEdges(edgesTexture, edgesSampler, texcoord);

    float4 offset0 = texcoord.xyxy + texelSize.xyxy * float4(-0.25, -0.125, 1.25, -0.125);
    float4 offset1 = texcoord.xyxy + texelSize.xyxy * float4(-0.125, -0.25, -0.125, 1.25);
    float4 offset2 = float4(offset0.xz, offset1.yw)
        + float4(-2.0, 2.0, -2.0, 2.0) * texelSize.xxyy * float(SMAA_MAX_SEARCH_STEPS);

    if (e.y > 0.0) {
        float2 d;
        float2 coords;

        coords.x = smaaSearchXLeft(edgesTexture, searchTexture, edgesSampler, searchSampler, offset0.xy, offset2.x, texelSize);
        coords.y = offset1.y;
        d.x = coords.x;

        float e1 = edgesTexture.sample(edgesSampler, coords).r;

        coords.x = smaaSearchXRight(edgesTexture, searchTexture, edgesSampler, searchSampler, offset0.zw, offset2.y, texelSize);
        d.y = coords.x;

        d = abs(round(d / texelSize.x - pixcoord.x));
        float2 sqrtD = sqrt(d);

        coords.y += texelSize.y;
        float e2 = smaaSampleEdgesOffset(edgesTexture, edgesSampler, coords, int2(1, 0), texelSize).r;

        weights.rg = smaaArea(areaTexture, areaSampler, sqrtD, e1, e2, 0.0);
    }

    if (e.x > 0.0) {
        float2 d;
        float2 coords;

        coords.y = smaaSearchYUp(edgesTexture, searchTexture, edgesSampler, searchSampler, offset1.xy, offset2.z, texelSize);
        coords.x = offset0.x;
        d.x = coords.y;

        float e1 = edgesTexture.sample(edgesSampler, coords).g;

        coords.y = smaaSearchYDown(edgesTexture, searchTexture, edgesSampler, searchSampler, offset1.zw, offset2.w, texelSize);
        d.y = coords.y;

        d = abs(round(d / texelSize.y - pixcoord.y));
        float2 sqrtD = sqrt(d);

        coords.y += texelSize.y;
        float e2 = smaaSampleEdgesOffset(edgesTexture, edgesSampler, coords, int2(0, 1), texelSize).g;

        weights.ba = smaaArea(areaTexture, areaSampler, sqrtD, e1, e2, 0.0);
    }

    return weights;
}

fragment float4 fragmentSMAANeighborhoodShader(
    VertexCompositeOutput in             [[stage_in]],
    texture2d<float>      colorTexture   [[texture(0)]],
    texture2d<float>      blendTexture   [[texture(1)]],
    constant float2      &texelSize      [[buffer(smaaPassTexelSizeIndex)]]
) {
    constexpr sampler s(min_filter::linear, mag_filter::linear, address::clamp_to_edge);

    float2 texcoord = in.uvCoords;

    float4 a;
    a.x = blendTexture.sample(s, texcoord + float2(1.0, 0.0) * texelSize).a; // Right
    a.y = blendTexture.sample(s, texcoord + float2(0.0, 1.0) * texelSize).g; // Top
    a.z = blendTexture.sample(s, texcoord).b; // Left
    a.w = blendTexture.sample(s, texcoord).r; // Bottom

    float4 center = colorTexture.sample(s, texcoord);
    if (dot(a, float4(1.0)) < 1e-5) {
        return center;
    }

    bool horizontal = max(a.x, a.z) > max(a.y, a.w);
    float4 blendingOffset = float4(0.0, a.y, 0.0, a.w);
    float2 blendingWeight = float2(a.y, a.w);
    if (horizontal) {
        blendingOffset = float4(a.x, 0.0, a.z, 0.0);
        blendingWeight = float2(a.x, a.z);
    }
    blendingWeight /= dot(blendingWeight, float2(1.0));

    float4 blendingCoord = texcoord.xyxy + blendingOffset * texelSize.xyxy * float4(1.0, -1.0, 1.0, -1.0);
    float4 mixedColor = blendingWeight.x * colorTexture.sample(s, blendingCoord.xy);
    mixedColor += blendingWeight.y * colorTexture.sample(s, blendingCoord.zw);
    mixedColor.a = center.a;
    return mixedColor;
}

fragment float4 fragmentSMAADifferenceShader(
    VertexCompositeOutput in             [[stage_in]],
    texture2d<float>      smaaTexture    [[texture(0)]],
    texture2d<float>      originalTexture[[texture(1)]]
) {
    constexpr sampler s(min_filter::linear, mag_filter::linear, address::clamp_to_edge);

    float4 smaa = smaaTexture.sample(s, in.uvCoords);
    float4 original = originalTexture.sample(s, in.uvCoords);
    float3 diff = min(abs(smaa.rgb - original.rgb) * 16.0, float3(1.0));

    return float4(diff, 1.0);
}

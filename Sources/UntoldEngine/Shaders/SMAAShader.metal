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
constant int SMAA_MAX_SEARCH_STEPS_DIAG = 8;
constant float SMAA_CORNER_ROUNDING_NORM = 0.25;
constant float SMAA_AREATEX_MAX_DISTANCE = 16.0;
constant float SMAA_AREATEX_MAX_DISTANCE_DIAG = 20.0;
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

void smaaDetectHorizontalCornerPattern(
    texture2d<float> edgesTexture,
    sampler edgesSampler,
    thread float2 &weights,
    float4 texcoord,
    float2 d,
    float2 texelSize
) {
    float2 leftRight = step(d.xy, d.yx);
    float denominator = max(leftRight.x + leftRight.y, 1.0e-5);
    float2 rounding = (1.0 - SMAA_CORNER_ROUNDING_NORM) * leftRight / denominator;

    float2 factor = float2(1.0);
    factor.x -= rounding.x * smaaSampleEdgesOffset(edgesTexture, edgesSampler, texcoord.xy, int2(0, 1), texelSize).r;
    factor.x -= rounding.y * smaaSampleEdgesOffset(edgesTexture, edgesSampler, texcoord.zw, int2(1, 1), texelSize).r;
    factor.y -= rounding.x * smaaSampleEdgesOffset(edgesTexture, edgesSampler, texcoord.xy, int2(0, -2), texelSize).r;
    factor.y -= rounding.y * smaaSampleEdgesOffset(edgesTexture, edgesSampler, texcoord.zw, int2(1, -2), texelSize).r;

    weights *= saturate(factor);
}

void smaaDetectVerticalCornerPattern(
    texture2d<float> edgesTexture,
    sampler edgesSampler,
    thread float2 &weights,
    float4 texcoord,
    float2 d,
    float2 texelSize
) {
    float2 leftRight = step(d.xy, d.yx);
    float denominator = max(leftRight.x + leftRight.y, 1.0e-5);
    float2 rounding = (1.0 - SMAA_CORNER_ROUNDING_NORM) * leftRight / denominator;

    float2 factor = float2(1.0);
    factor.x -= rounding.x * smaaSampleEdgesOffset(edgesTexture, edgesSampler, texcoord.xy, int2(1, 0), texelSize).g;
    factor.x -= rounding.y * smaaSampleEdgesOffset(edgesTexture, edgesSampler, texcoord.zw, int2(1, 1), texelSize).g;
    factor.y -= rounding.x * smaaSampleEdgesOffset(edgesTexture, edgesSampler, texcoord.xy, int2(-2, 0), texelSize).g;
    factor.y -= rounding.y * smaaSampleEdgesOffset(edgesTexture, edgesSampler, texcoord.zw, int2(-2, 1), texelSize).g;

    weights *= saturate(factor);
}

float2 smaaDecodeDiagBilinearAccess(float2 e) {
    e.r = e.r * abs(5.0 * e.r - 5.0 * 0.75);
    return round(e);
}

float4 smaaDecodeDiagBilinearAccess(float4 e) {
    e.rb = e.rb * abs(5.0 * e.rb - 5.0 * 0.75);
    return round(e);
}

float2 smaaSearchDiag1(
    texture2d<float> edgesTexture,
    sampler edgesSampler,
    float2 texcoord,
    float2 dir,
    float2 texelSize,
    thread float2 &end
) {
    float4 coord = float4(texcoord, -1.0, 1.0);
    for (int i = 0; i < SMAA_MAX_SEARCH_STEPS_DIAG; i++) {
        if (!(coord.z < float(SMAA_MAX_SEARCH_STEPS_DIAG - 1) && coord.w > 0.9)) {
            break;
        }

        coord.xy += dir * texelSize;
        coord.z += 1.0;
        end = edgesTexture.sample(edgesSampler, coord.xy).rg;
        coord.w = dot(end, float2(0.5));
    }

    return coord.zw;
}

float2 smaaSearchDiag2(
    texture2d<float> edgesTexture,
    sampler edgesSampler,
    float2 texcoord,
    float2 dir,
    float2 texelSize,
    thread float2 &end
) {
    float4 coord = float4(texcoord + float2(0.25 * texelSize.x, 0.0), -1.0, 1.0);
    for (int i = 0; i < SMAA_MAX_SEARCH_STEPS_DIAG; i++) {
        if (!(coord.z < float(SMAA_MAX_SEARCH_STEPS_DIAG - 1) && coord.w > 0.9)) {
            break;
        }

        coord.xy += dir * texelSize;
        coord.z += 1.0;
        end = smaaDecodeDiagBilinearAccess(edgesTexture.sample(edgesSampler, coord.xy).rg);
        coord.w = dot(end, float2(0.5));
    }

    return coord.zw;
}

float2 smaaAreaDiag(texture2d<float> areaTexture, sampler s, float2 dist, float2 e, float offset) {
    float2 texcoord = SMAA_AREATEX_MAX_DISTANCE_DIAG * e + dist;
    texcoord = SMAA_AREATEX_PIXEL_SIZE * texcoord + 0.5 * SMAA_AREATEX_PIXEL_SIZE;
    texcoord.x += 0.5;
    texcoord.y += SMAA_AREATEX_SUBTEX_SIZE * offset;
    return areaTexture.sample(s, texcoord).rg;
}

float2 smaaCalculateDiagWeights(
    texture2d<float> edgesTexture,
    texture2d<float> areaTexture,
    sampler edgesSampler,
    sampler areaSampler,
    float2 texcoord,
    float2 e,
    float2 texelSize
) {
    float2 weights = float2(0.0);
    float4 d = float4(0.0);
    float2 end = float2(0.0);

    if (e.r > 0.0) {
        d.xz = smaaSearchDiag1(edgesTexture, edgesSampler, texcoord, float2(-1.0, 1.0), texelSize, end);
        d.x += float(end.y > 0.9);
    }
    d.yw = smaaSearchDiag1(edgesTexture, edgesSampler, texcoord, float2(1.0, -1.0), texelSize, end);

    if (d.x + d.y > 2.0) {
        float4 coords = texcoord.xyxy + float4(-d.x + 0.25, d.x, d.y, -d.y - 0.25) * texelSize.xyxy;
        float4 c;
        c.xy = smaaSampleEdgesOffset(edgesTexture, edgesSampler, coords.xy, int2(-1, 0), texelSize);
        c.zw = smaaSampleEdgesOffset(edgesTexture, edgesSampler, coords.zw, int2(1, 0), texelSize);

        float4 decoded = smaaDecodeDiagBilinearAccess(c);
        c = float4(decoded.y, decoded.x, decoded.w, decoded.z);

        float2 cc = 2.0 * c.xz + c.yw;
        cc = select(cc, float2(0.0), d.zw >= float2(0.9));
        weights += smaaAreaDiag(areaTexture, areaSampler, d.xy, cc, 0.0);
    }

    d.xz = smaaSearchDiag2(edgesTexture, edgesSampler, texcoord, float2(-1.0, -1.0), texelSize, end);
    if (smaaSampleEdgesOffset(edgesTexture, edgesSampler, texcoord, int2(1, 0), texelSize).r > 0.0) {
        d.yw = smaaSearchDiag2(edgesTexture, edgesSampler, texcoord, float2(1.0, 1.0), texelSize, end);
        d.y += float(end.y > 0.9);
    } else {
        d.yw = float2(0.0);
    }

    if (d.x + d.y > 2.0) {
        float4 coords = texcoord.xyxy + float4(-d.x, -d.x, d.y, d.y) * texelSize.xyxy;
        float4 c;
        c.x = smaaSampleEdgesOffset(edgesTexture, edgesSampler, coords.xy, int2(-1, 0), texelSize).g;
        c.y = smaaSampleEdgesOffset(edgesTexture, edgesSampler, coords.xy, int2(0, -1), texelSize).r;
        c.zw = smaaSampleEdgesOffset(edgesTexture, edgesSampler, coords.zw, int2(1, 0), texelSize).gr;

        float2 cc = 2.0 * c.xz + c.yw;
        cc = select(cc, float2(0.0), d.zw >= float2(0.9));
        weights += smaaAreaDiag(areaTexture, areaSampler, d.xy, cc, 0.0).gr;
    }

    return weights;
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

    weights.rg = smaaCalculateDiagWeights(
        edgesTexture,
        areaTexture,
        edgesSampler,
        areaSampler,
        texcoord,
        e,
        texelSize
    );

    if (dot(weights.rg, float2(1.0)) > 0.0) {
        return weights;
    }

    if (e.y > 0.0) {
        float2 d;
        float3 coords;

        coords.x = smaaSearchXLeft(edgesTexture, searchTexture, edgesSampler, searchSampler, offset0.xy, offset2.x, texelSize);
        coords.y = offset1.y;
        d.x = coords.x;

        float e1 = edgesTexture.sample(edgesSampler, coords.xy).r;

        coords.z = smaaSearchXRight(edgesTexture, searchTexture, edgesSampler, searchSampler, offset0.zw, offset2.y, texelSize);
        d.y = coords.z;

        d = abs(round(d / texelSize.x - pixcoord.x));
        float2 sqrtD = sqrt(d);

        coords.y += texelSize.y;
        float e2 = smaaSampleEdgesOffset(edgesTexture, edgesSampler, coords.zy, int2(1, 0), texelSize).r;

        float2 horizontalWeights = smaaArea(areaTexture, areaSampler, sqrtD, e1, e2, 0.0);

        coords.y = texcoord.y;
        smaaDetectHorizontalCornerPattern(
            edgesTexture,
            edgesSampler,
            horizontalWeights,
            coords.xyzy,
            d,
            texelSize
        );
        weights.rg = horizontalWeights;
    }

    if (e.x > 0.0) {
        float2 d;
        float3 coords;

        coords.y = smaaSearchYUp(edgesTexture, searchTexture, edgesSampler, searchSampler, offset1.xy, offset2.z, texelSize);
        coords.x = offset0.x;
        d.x = coords.y;

        float e1 = edgesTexture.sample(edgesSampler, coords.xy).g;

        coords.z = smaaSearchYDown(edgesTexture, searchTexture, edgesSampler, searchSampler, offset1.zw, offset2.w, texelSize);
        d.y = coords.z;

        d = abs(round(d / texelSize.y - pixcoord.y));
        float2 sqrtD = sqrt(d);

        float e2 = smaaSampleEdgesOffset(edgesTexture, edgesSampler, coords.xz, int2(0, 1), texelSize).g;

        float2 verticalWeights = smaaArea(areaTexture, areaSampler, sqrtD, e1, e2, 0.0);

        coords.x = texcoord.x;
        smaaDetectVerticalCornerPattern(
            edgesTexture,
            edgesSampler,
            verticalWeights,
            coords.xyxz,
            d,
            texelSize
        );
        weights.ba = verticalWeights;
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

//
//  TAAShader.metal
//  UntoldEngine
//
//  Temporal anti-aliasing resolve. The frame was drawn with the projection jittered by a
//  sub-pixel amount (TemporalAntiAliasing.swift); this pass blends the jittered frame with the
//  eye's history, reprojected through the depth buffer and the two frames' unjittered
//  view-projections, after clipping the history to the colour range of the pixel's 3×3
//  neighbourhood so that what moved or was uncovered does not ghost. Over frames the jitter
//  averages sub-pixel detail — thin wires, fine normal maps — that a single sample flickers on.
//
//  Under a rasterization rate map (XR foveation) the colour, depth and history textures are in
//  physical space, not the screen the geometry was projected to, and each frame's map differs:
//  a pixel is mapped physical → screen (this frame's map) → world → screen (previous frame,
//  previous matrices) → physical (the history frame's map) before the history is sampled.
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

vertex VertexCompositeOutput vertexTAAShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput out;
    out.position = float4(float3(in.position), 1.0);
    out.uvCoords = in.uvCoords;
    return out;
}

struct TAAFragmentOut {
    float4 color [[color(0)]];
    float4 history [[color(1)]];
};

// Luma-chroma space for the neighbourhood clip: a box in YCoCg hugs the local colours more
// tightly than one in RGB, so less ghosting gets through on moving edges.
static inline float3 taaRGBToYCoCg(float3 c) {
    return float3(0.25 * c.r + 0.5 * c.g + 0.25 * c.b,
                  0.5 * c.r - 0.5 * c.b,
                  -0.25 * c.r + 0.5 * c.g - 0.25 * c.b);
}

static inline float3 taaYCoCgToRGB(float3 c) {
    return float3(c.x + c.y - c.z, c.x + c.z, c.x - c.y - c.z);
}

// Moves `history` towards `current` until it lies inside the box [lo, hi]: the direction the
// history came from is kept, only its distance is cut, which avoids the colour shifts a plain
// clamp introduces (Karis 2014).
static inline float3 taaClipToBox(float3 lo, float3 hi, float3 current, float3 history) {
    const float3 center = 0.5 * (hi + lo);
    const float3 extent = 0.5 * (hi - lo) + 1e-4;
    const float3 offset = history - center;
    const float3 unit = abs(offset / extent);
    const float maxUnit = max(unit.x, max(unit.y, unit.z));
    return maxUnit > 1.0 ? center + offset / maxUnit : history;
}

// Where a texel of this frame's textures sits on the screen, in pixels.
static inline float2 taaScreenFromPhysical(float2 physical, float4 sizes, constant rasterization_rate_map_data *rateMap) {
    if (sizes.x <= 0.0) {
        return physical;
    }
    rasterization_rate_map_decoder decoder(*rateMap);
    return decoder.map_physical_to_screen_coordinates(physical);
}

// Where a screen position of the history's frame sits in the history texture, in pixels.
static inline float2 taaPhysicalFromScreen(float2 screen, float4 sizes, constant rasterization_rate_map_data *rateMap) {
    if (sizes.x <= 0.0) {
        return screen;
    }
    rasterization_rate_map_decoder decoder(*rateMap);
    return decoder.map_screen_to_physical_coordinates(screen);
}

// The history at a fractional position, Catmull-Rom filtered with nine bilinear taps (Jimenez
// 2016): resampling the history every frame with a bilinear filter smears it a little more
// each time, which under a moving head or a moving rate map shows as a soft halo that settles
// only when everything stands still; the cubic keeps it sharp.
static inline float4 taaSampleHistory(texture2d<float> history, sampler linearSampler, float2 uv, float2 size) {
    const float2 texel = 1.0 / size;
    const float2 position = uv * size;
    const float2 center = floor(position - 0.5) + 0.5;
    const float2 f = position - center;
    const float2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
    const float2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
    const float2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
    const float2 w3 = f * f * (-0.5 + 0.5 * f);
    const float2 w12 = w1 + w2;
    const float2 offset12 = w2 / w12;
    const float2 uv0 = (center - 1.0) * texel;
    const float2 uv3 = (center + 2.0) * texel;
    const float2 uv12 = (center + offset12) * texel;
    float4 result = float4(0.0);
    result += history.sample(linearSampler, float2(uv0.x, uv0.y)) * w0.x * w0.y;
    result += history.sample(linearSampler, float2(uv12.x, uv0.y)) * w12.x * w0.y;
    result += history.sample(linearSampler, float2(uv3.x, uv0.y)) * w3.x * w0.y;
    result += history.sample(linearSampler, float2(uv0.x, uv12.y)) * w0.x * w12.y;
    result += history.sample(linearSampler, float2(uv12.x, uv12.y)) * w12.x * w12.y;
    result += history.sample(linearSampler, float2(uv3.x, uv12.y)) * w3.x * w12.y;
    result += history.sample(linearSampler, float2(uv0.x, uv3.y)) * w0.x * w3.y;
    result += history.sample(linearSampler, float2(uv12.x, uv3.y)) * w12.x * w3.y;
    result += history.sample(linearSampler, float2(uv3.x, uv3.y)) * w3.x * w3.y;
    return max(result, 0.0);
}

fragment TAAFragmentOut fragmentTAAShader(
    VertexCompositeOutput in [[stage_in]],
    texture2d<float> colorTexture [[texture(taaPassColorTextureIndex)]],
    texture2d<float> historyTexture [[texture(taaPassHistoryTextureIndex)]],
    depth2d<float> depthTexture [[texture(taaPassDepthTextureIndex)]],
    constant TAAConstants &taa [[buffer(taaPassConstantsIndex)]],
    constant rasterization_rate_map_data *rateMap [[buffer(taaPassRateMapDataIndex)]],
    constant rasterization_rate_map_data *prevRateMap [[buffer(taaPassPrevRateMapDataIndex)]]
) {
    constexpr sampler linearSampler(min_filter::linear, mag_filter::linear, mip_filter::none, address::clamp_to_edge);
    constexpr sampler pointSampler(min_filter::nearest, mag_filter::nearest, mip_filter::none, address::clamp_to_edge);

    const float2 uv = in.uvCoords;
    const float2 texel = 1.0 / max(taa.physicalSize, float2(1.0));
    const float4 current = colorTexture.sample(pointSampler, uv);

    TAAFragmentOut out;
    if (taa.historyValid == 0u) {
        out.color = current;
        out.history = current;
        return out;
    }

    // The colour box of the 3×3 neighbourhood, in YCoCg: the mean ± γ·σ (variance clipping,
    // Salvi 2016) rather than the hard min/max. A feature a pixel wide — a wire, a line of
    // text — is rasterized in some jittered frames and not others; a min/max box of a frame
    // that missed it excludes its colour and the clip wipes it from the history, so it flickers.
    // The statistical box still reaches towards it through the frames that miss it.
    float3 m1 = float3(0.0);
    float3 m2 = float3(0.0);
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            const float3 c = taaRGBToYCoCg(colorTexture.sample(pointSampler, uv + float2(x, y) * texel).rgb);
            m1 += c;
            m2 += c * c;
        }
    }
    const float3 mean = m1 / 9.0;
    const float3 sigma = sqrt(max(m2 / 9.0 - mean * mean, 0.0));
    const float3 lo = mean - taa.clipGamma * sigma;
    const float3 hi = mean + taa.clipGamma * sigma;

    // This pixel's position in space, from its depth. A texel at the clear depth has none:
    // nothing opaque was drawn there — the background, or a transparent quad over it — and
    // reprojecting it from the far plane would fetch the wrong history and ghost or wipe it
    // under a moving camera; such a pixel keeps its own frame.
    const float depth = depthTexture.sample(pointSampler, uv);
    const bool cleared = (taa.reverseZ != 0u) ? (depth <= 1e-6) : (depth >= 1.0 - 1e-6);
    if (cleared) {
        out.color = current;
        out.history = current;
        return out;
    }
    const float2 physical = in.position.xy;
    const float2 screen = taaScreenFromPhysical(physical, taa.rateMapSizes, rateMap);
    const float2 screenSize = taa.rateMapSizes.x > 0.0 ? taa.rateMapSizes.xy : taa.physicalSize;
    const float2 ndc = float2(screen.x / screenSize.x * 2.0 - 1.0, 1.0 - screen.y / screenSize.y * 2.0);
    float4 world = taa.invViewProjection * float4(ndc, depth, 1.0);
    if (abs(world.w) < 1e-12) {
        out.color = current;
        out.history = current;
        return out;
    }
    world /= world.w;

    // Where it was on the previous frame's screen, then in the history texture.
    const float4 prevClip = taa.prevViewProjection * world;
    if (prevClip.w <= 0.0) {
        out.color = current;
        out.history = current;
        return out;
    }
    const float2 prevNdc = prevClip.xy / prevClip.w;
    const float2 prevScreenSize = taa.prevRateMapSizes.x > 0.0 ? taa.prevRateMapSizes.xy : taa.physicalSize;
    const float2 prevScreen = float2((prevNdc.x * 0.5 + 0.5) * prevScreenSize.x, (1.0 - (prevNdc.y * 0.5 + 0.5)) * prevScreenSize.y);
    const float2 prevPhysical = taaPhysicalFromScreen(prevScreen, taa.prevRateMapSizes, prevRateMap);
    const float2 historyUV = prevPhysical * texel;
    if (any(historyUV < 0.0) || any(historyUV > 1.0)) {
        out.color = current;
        out.history = current;
        return out;
    }

    // Under foveation the history may be coarser here than this frame: the spot was in the
    // periphery of the previous map (one texel spanning several screen pixels) and the gaze
    // has moved onto it. Trusting such a history at full weight shows the sharp frame with a
    // blurry shadow that fades over twenty frames; its weight is cut by how much coarser it
    // was, measured from the two maps' local rates (texels per screen pixel).
    float weight = taa.historyWeight;
    if (taa.rateMapSizes.x > 0.0 || taa.prevRateMapSizes.x > 0.0) {
        const float2 screenStep = taaScreenFromPhysical(physical + float2(1.0, 1.0), taa.rateMapSizes, rateMap) - screen;
        const float currentRate = 1.0 / max(max(abs(screenStep.x), abs(screenStep.y)), 1e-3);
        const float2 prevStep = taaPhysicalFromScreen(prevScreen + float2(1.0, 1.0), taa.prevRateMapSizes, prevRateMap) - prevPhysical;
        const float prevRate = max(max(abs(prevStep.x), abs(prevStep.y)), 1e-3);
        weight *= saturate(prevRate / currentRate);
    }

    const float4 history = taaSampleHistory(historyTexture, linearSampler, historyUV, taa.physicalSize);
    const float3 clipped = taaYCoCgToRGB(taaClipToBox(lo, hi, taaRGBToYCoCg(current.rgb), taaRGBToYCoCg(history.rgb)));
    const float3 blended = mix(current.rgb, clipped, weight);
    const float alpha = mix(current.a, history.a, weight);
    out.color = float4(blended, alpha);
    out.history = out.color;
    return out;
}

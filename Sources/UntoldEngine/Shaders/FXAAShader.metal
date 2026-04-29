//
//  FXAAShader.metal
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

// Perceptual luma from linear RGB.
// sqrt approximates gamma encoding so edge detection behaves as if in sRGB space.
inline float lumaFromLinear(float3 c) {
    return dot(sqrt(max(c, 0.0)), float3(0.299, 0.587, 0.114));
}

// Return center luma when a neighbor is transparent so it doesn't register as a contrast edge.
// This prevents FXAA from blending model silhouette pixels towards the transparent background
// (which would produce dark halos in XR passthrough compositing).
inline float guardedLuma(float4 neighbor, float centerLuma, float alphaThreshold) {
    return neighbor.a > alphaThreshold ? lumaFromLinear(neighbor.rgb) : centerLuma;
}

vertex VertexCompositeOutput vertexFXAAShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput out;
    out.position = float4(float3(in.position), 1.0);
    out.uvCoords = in.uvCoords;
    return out;
}

fragment float4 fragmentFXAAShader(
    VertexCompositeOutput in              [[stage_in]],
    texture2d<float>      colorTexture    [[texture(0)]],
    constant float2      &texelSize       [[buffer(fxaaPassTexelSizeIndex)]],
    constant int         &enabled         [[buffer(fxaaPassEnabledIndex)]],
    constant float       &subpixelQuality [[buffer(fxaaPassSubpixelIndex)]],
    constant float       &edgeThreshold   [[buffer(fxaaPassEdgeThresholdIndex)]],
    constant float       &edgeThresholdMin[[buffer(fxaaPassEdgeThresholdMinIndex)]]
) {
    constexpr sampler s(min_filter::linear, mag_filter::linear, address::clamp_to_edge);

    float2 uv    = in.uvCoords;
    float4 center = colorTexture.sample(s, uv);  // preserve alpha throughout

    if (!enabled) return center;

    // --- Cardinal neighbors (sampled as float4 to check alpha) ---
    const float kAlpha = 0.1;
    float lumaM = lumaFromLinear(center.rgb);

    float4 sN = colorTexture.sample(s, uv + float2( 0.0,  1.0) * texelSize);
    float4 sS = colorTexture.sample(s, uv + float2( 0.0, -1.0) * texelSize);
    float4 sE = colorTexture.sample(s, uv + float2( 1.0,  0.0) * texelSize);
    float4 sW = colorTexture.sample(s, uv + float2(-1.0,  0.0) * texelSize);

    float lumaN = guardedLuma(sN, lumaM, kAlpha);
    float lumaS = guardedLuma(sS, lumaM, kAlpha);
    float lumaE = guardedLuma(sE, lumaM, kAlpha);
    float lumaW = guardedLuma(sW, lumaM, kAlpha);

    float lumaMin   = min(lumaM, min(min(lumaN, lumaS), min(lumaE, lumaW)));
    float lumaMax   = max(lumaM, max(max(lumaN, lumaS), max(lumaE, lumaW)));
    float lumaRange = lumaMax - lumaMin;

    // Skip flat areas — no aliasing here
    if (lumaRange < max(edgeThresholdMin, lumaMax * edgeThreshold)) return center;

    // --- Diagonal neighbors ---
    float4 sNW = colorTexture.sample(s, uv + float2(-1.0,  1.0) * texelSize);
    float4 sNE = colorTexture.sample(s, uv + float2( 1.0,  1.0) * texelSize);
    float4 sSW = colorTexture.sample(s, uv + float2(-1.0, -1.0) * texelSize);
    float4 sSE = colorTexture.sample(s, uv + float2( 1.0, -1.0) * texelSize);

    float lumaNW = guardedLuma(sNW, lumaM, kAlpha);
    float lumaNE = guardedLuma(sNE, lumaM, kAlpha);
    float lumaSW = guardedLuma(sSW, lumaM, kAlpha);
    float lumaSE = guardedLuma(sSE, lumaM, kAlpha);

    // --- Sub-pixel blend factor (weighted 3×3 average) ---
    float lumaAvg = (2.0 * (lumaN + lumaS + lumaE + lumaW) + lumaNW + lumaNE + lumaSW + lumaSE) / 12.0;
    float subBlend = saturate(abs(lumaAvg - lumaM) / lumaRange);
    subBlend = subBlend * subBlend * subpixelQuality;

    // --- Edge orientation (Sobel-style) ---
    float edgeH = abs(-2.0 * lumaW + lumaNW + lumaSW)
                + abs(-2.0 * lumaM + lumaN  + lumaS)  * 2.0
                + abs(-2.0 * lumaE + lumaNE + lumaSE);
    float edgeV = abs(-2.0 * lumaN + lumaNW + lumaNE)
                + abs(-2.0 * lumaM + lumaW  + lumaE)  * 2.0
                + abs(-2.0 * lumaS + lumaSW + lumaSE);

    bool isH = edgeH >= edgeV;

    // Identify which side of the edge is steeper
    float luma1 = isH ? lumaS : lumaW;
    float luma2 = isH ? lumaN : lumaE;
    float grad1 = abs(luma1 - lumaM);
    float grad2 = abs(luma2 - lumaM);
    bool is1Steeper = grad1 >= grad2;

    // Step perpendicular to edge, towards the steeper side
    float stepLen = isH ? texelSize.y : texelSize.x;
    float lumaEdgeAvg;
    if (is1Steeper) {
        stepLen     = -stepLen;
        lumaEdgeAvg = 0.5 * (luma1 + lumaM);
    } else {
        lumaEdgeAvg = 0.5 * (luma2 + lumaM);
    }

    // Move to the edge midline (half a pixel perpendicular)
    float2 edgeUV = uv;
    if (isH) edgeUV.y += stepLen * 0.5;
    else      edgeUV.x += stepLen * 0.5;

    // Walk direction: along the edge
    float2 edgeDir = isH ? float2(texelSize.x, 0.0) : float2(0.0, texelSize.y);

    // --- Search for edge endpoints in both directions ---
    float2 uv1 = edgeUV - edgeDir;
    float2 uv2 = edgeUV + edgeDir;

    float lumaEnd1 = lumaFromLinear(colorTexture.sample(s, uv1).rgb) - lumaEdgeAvg;
    float lumaEnd2 = lumaFromLinear(colorTexture.sample(s, uv2).rgb) - lumaEdgeAvg;

    float gradThreshold = 0.25 * max(grad1, grad2);
    bool reached1 = abs(lumaEnd1) >= gradThreshold;
    bool reached2 = abs(lumaEnd2) >= gradThreshold;

    // Accelerated walk — step sizes increase with distance
    float stepSizes[10] = {1.5, 2.0, 2.0, 2.0, 2.0, 4.0, 4.0, 4.0, 4.0, 8.0};

    for (int i = 0; i < 10; i++) {
        if (reached1 && reached2) break;
        float sz = stepSizes[i];
        if (!reached1) {
            uv1 -= edgeDir * sz;
            lumaEnd1 = lumaFromLinear(colorTexture.sample(s, uv1).rgb) - lumaEdgeAvg;
            reached1 = abs(lumaEnd1) >= gradThreshold;
        }
        if (!reached2) {
            uv2 += edgeDir * sz;
            lumaEnd2 = lumaFromLinear(colorTexture.sample(s, uv2).rgb) - lumaEdgeAvg;
            reached2 = abs(lumaEnd2) >= gradThreshold;
        }
    }

    // Distance to each endpoint along the edge
    float dist1 = isH ? (uv.x - uv1.x) : (uv.y - uv1.y);
    float dist2 = isH ? (uv2.x - uv.x) : (uv2.y - uv.y);

    bool useP1 = dist1 < dist2;
    float distNearer = useP1 ? dist1 : dist2;
    float spanLen    = dist1 + dist2;

    // Apply edge blend only if the closer endpoint confirms the edge direction
    bool isLumaSmaller = lumaM < lumaEdgeAvg;
    bool goodVariation = useP1 ? ((lumaEnd1 < 0.0) != isLumaSmaller)
                                : ((lumaEnd2 < 0.0) != isLumaSmaller);
    float edgeBlend = goodVariation ? (0.5 - distNearer / spanLen) : 0.0;

    float finalBlend = max(subBlend, edgeBlend);

    // Sample at blended position (move perpendicular to edge), preserving alpha
    float2 finalUV = uv;
    if (isH) finalUV.y += finalBlend * stepLen;
    else      finalUV.x += finalBlend * stepLen;

    return colorTexture.sample(s, finalUV);
}

//
//  taaResolveShader.metal
//  Untold Engine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Custom Temporal Anti-Aliasing resolve pass.
//
// Algorithm (neighbourhood-clamped temporal accumulation):
//   1. Sample current-frame colour and reprojected history (via motion vectors).
//   2. Build a tight AABB from a 3×3 neighbourhood in the current frame.
//   3. Clamp history to that AABB — kills ghosting when objects move.
//   4. Blend adaptively: base weight (0.65 XR / 0.1 desktop) is floored up by
//      two signals — per-pixel motion and camera-centre displacement — so that
//      head rotation clears history quickly even for pixels at the rotation axis.
//
// On the first frame (reset == true) the shader outputs current colour only so
// no garbage history bleeds into the accumulated result.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
using namespace metal;

typedef enum {
    taaCurrentColorIndex = 0,
    taaHistoryColorIndex = 1,
    taaVelocityMapIndex  = 2,
    taaPositionMapIndex  = 3,
    taaPositionHistoryIndex = 4,
} TAATextureIndices;

typedef enum {
    taaViewportSizeIndex    = 0,
    taaResetFlagIndex       = 1,
    taaBlendFactorIndex     = 2,
    taaCamDisplacementIndex = 3,
    taaCameraPositionIndex  = 4,
    taaPositionRejectBaseIndex = 5,
    taaPositionRejectDistanceScaleIndex = 6,
    taaMotionBlendStartIndex = 7,
    taaMotionBlendEndIndex = 8,
    taaCameraBoostStartIndex = 9,
    taaCameraBoostEndIndex = 10,
    taaClampRadiusIndex = 11,
} TAABufferIndices;

vertex VertexCompositeOutput vertexTAAResolveShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput out;
    out.position = float4(float3(in.position), 1.0);
    out.uvCoords = in.uvCoords;
    return out;
}

fragment float4 fragmentTAAResolveShader(
    VertexCompositeOutput  in              [[stage_in]],
    texture2d<float>       currentColor    [[texture(taaCurrentColorIndex)]],
    texture2d<float>       historyColor    [[texture(taaHistoryColorIndex)]],
    texture2d<half>        velocityMap     [[texture(taaVelocityMapIndex)]],
    texture2d<float>       positionMap     [[texture(taaPositionMapIndex)]],
    texture2d<float>       positionHistory [[texture(taaPositionHistoryIndex)]],
    constant float2       &viewportSize    [[buffer(taaViewportSizeIndex)]],
    constant uint         &resetFlag       [[buffer(taaResetFlagIndex)]],
    constant float        &blendFactor     [[buffer(taaBlendFactorIndex)]],
    constant float        &camDisplacement [[buffer(taaCamDisplacementIndex)]],
    constant float3       &cameraPosition  [[buffer(taaCameraPositionIndex)]],
    constant float        &positionRejectBase [[buffer(taaPositionRejectBaseIndex)]],
    constant float        &positionRejectDistanceScale [[buffer(taaPositionRejectDistanceScaleIndex)]],
    constant float        &motionBlendStart [[buffer(taaMotionBlendStartIndex)]],
    constant float        &motionBlendEnd [[buffer(taaMotionBlendEndIndex)]],
    constant float        &cameraBoostStart [[buffer(taaCameraBoostStartIndex)]],
    constant float        &cameraBoostEnd [[buffer(taaCameraBoostEndIndex)]],
    constant int          &clampRadiusParam [[buffer(taaClampRadiusIndex)]]
) {
    uint2 gid     = uint2(in.position.xy);
    float4 current = currentColor.read(gid);

    // First frame or after a scene cut — skip history to avoid garbage blend.
    if (resetFlag != 0u) return current;

    // Pixels without opaque G-buffer position do not have reliable camera-only
    // velocity, so do not blend old history into them.
    float4 worldPos = positionMap.read(gid);
    if (worldPos.w < 0.5) return current;

    // Reproject: find the previous-frame UV for this pixel using motion vectors.
    // velocityMap stores pixel-space backward motion (current -> previous).
    float2 motion  = float2(velocityMap.read(gid));
    float2 prevUV  = (float2(gid) + motion + 0.5) / viewportSize;

    // Disocclusion / offscreen history rejection. Clamping here would pull old
    // edge pixels into the current frame during fast head movement.
    if (any(prevUV < 0.0) || any(prevUV > 1.0)) return current;

    constexpr sampler bilinear(coord::normalized, filter::linear, address::clamp_to_edge);

    float4 previousWorldPos = positionHistory.sample(bilinear, prevUV);
    if (previousWorldPos.w < 0.5) return current;

    // Camera/head motion should reproject to the same world-space surface.
    // Reject history when it does not; this catches disocclusion and stale
    // reprojected samples around silhouettes.
    float positionDelta = length(previousWorldPos.xyz - worldPos.xyz);
    float cameraDistance = length(worldPos.xyz - cameraPosition);
    float positionRejectThreshold = max(0.0, positionRejectBase)
        + cameraDistance * max(0.0, positionRejectDistanceScale);
    if (positionDelta > positionRejectThreshold) return current;

    float4 history = historyColor.sample(bilinear, prevUV);

    // Build a colour AABB in the current frame to clamp the history.
    // This is the key ghost-rejection step: history that falls outside the
    // neighbourhood's plausible colour range is pulled back to the boundary.
    int2 iSize = int2(viewportSize);
    int radius = clamp(clampRadiusParam, 1, 2);
    float4 minC = current, maxC = current;
    for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
            if (dx == 0 && dy == 0) continue;
            int2 coord  = clamp(int2(gid) + int2(dx, dy), int2(0), iSize - 1);
            float4 nb   = currentColor.read(uint2(coord));
            minC = min(minC, nb);
            maxC = max(maxC, nb);
        }
    }
    history = clamp(history, minC, maxC);

    // Temporal blend. Two signals drive the current-frame weight:
    //
    // 1. Per-pixel motion magnitude — handles edge/object motion.
    // 2. Camera displacement (passed from CPU) — handles head rotation where
    //    center pixels have near-zero local motion but the whole view has changed.
    //    smoothstep(2, 20) ramps the boost from zero at 2 px to full at 20 px of
    //    view-center displacement, raising the floor blend for all pixels so that
    //    even the rotation-axis center converges quickly after a head turn.
    float motionPixels  = length(motion);
    float motionStart   = min(motionBlendStart, motionBlendEnd);
    float motionEnd     = max(max(motionBlendStart, motionBlendEnd), motionStart + 0.001);
    float cameraStart   = min(cameraBoostStart, cameraBoostEnd);
    float cameraEnd     = max(max(cameraBoostStart, cameraBoostEnd), cameraStart + 0.001);
    float cameraBoost   = smoothstep(cameraStart, cameraEnd, camDisplacement);
    float adaptiveBlend = max(blendFactor + cameraBoost * (1.0 - blendFactor),
                              smoothstep(motionStart, motionEnd, motionPixels));
    return mix(history, current, adaptiveBlend);
}

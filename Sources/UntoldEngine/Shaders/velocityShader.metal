//
//  velocityShader.metal
//  Untold Engine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Camera-only velocity (motion vector) pass for TAA / MetalFX Temporal Scaler.
//
// For every pixel this shader reconstructs the world-space position from the
// G-buffer positionMap, projects it with the current and previous (unjittered)
// view-projection matrices, then outputs the pixel-space delta as rg16Float.
//
// Motion vector convention (matches MetalFX default with scaleX/Y = 1):
//   +x = moved right (screen-space)
//   +y = moved DOWN  (screen-space / Metal texture origin)

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
using namespace metal;

typedef enum {
    velocityPositionMapIndex = 0,
} VelocityTextureIndices;

typedef enum {
    velocityCurrentVPIndex  = 0,
    velocityPreviousVPIndex = 1,
    velocityViewportIndex   = 2,
} VelocityBufferIndices;

vertex VertexCompositeOutput vertexVelocityShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput out;
    out.position = float4(float3(in.position), 1.0);
    out.uvCoords = in.uvCoords;
    return out;
}

fragment half2 fragmentVelocityShader(
    VertexCompositeOutput in                          [[stage_in]],
    texture2d<float>      positionMap                [[texture(velocityPositionMapIndex)]],
    constant float4x4    &currentVP                  [[buffer(velocityCurrentVPIndex)]],
    constant float4x4    &previousVP                 [[buffer(velocityPreviousVPIndex)]],
    constant float2      &viewportSize               [[buffer(velocityViewportIndex)]]
) {
    // Read the world-space position stored by the G-buffer model pass.
    // w == 0 means background (sky / no geometry) → zero velocity.
    uint2 gid = uint2(in.position.xy);
    float4 worldPos = positionMap.read(gid);
    if (worldPos.w < 0.5h) {
        return half2(0.0h);
    }

    // Project world position with unjittered current and previous VP matrices.
    float4 clipCurrent = currentVP  * float4(worldPos.xyz, 1.0);
    float4 clipPrev    = previousVP * float4(worldPos.xyz, 1.0);

    float2 ndcCurrent = clipCurrent.xy / clipCurrent.w;
    float2 ndcPrev    = clipPrev.xy    / clipPrev.w;

    // Motion vectors point from the current pixel BACK to where it came from in the
    // previous frame (reprojection direction), which is what MetalFX expects.
    // NDC +Y is up; Metal texture +Y is down, so the Y sign flips cancel out:
    //   backward direction negate (-ndcDelta) × screen-Y-flip negate = no net Y negate.
    float2 ndcDelta     = ndcCurrent - ndcPrev;
    float2 pixelMotion  = float2(-ndcDelta.x, ndcDelta.y) * viewportSize * 0.5;

    return half2(pixelMotion);
}

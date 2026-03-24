//
//  debugShader.metal
//  UntoldShadersKernels
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

vertex VertexDebugOutput vertexDebugShader(VertexCompositeIn in [[stage_in]]){

    VertexDebugOutput vertexOut;
    vertexOut.position=float4(float3(in.position),1.0);
    vertexOut.uvCoords=in.uvCoords;

    return vertexOut;
}

fragment float4 fragmentDebugShader(VertexDebugOutput vertexOut [[stage_in]],
                                    texture2d<float> finalTexture[[texture(0)]],
                                    depth2d<float> depthTexture [[texture(1)]],
                                    constant int &debugMode [[buffer(debugPassModeIndex)]],
                                    constant simd_float2 &frustumPlanes [[buffer(debugPassFrustumPlanesIndex)]]) {

    constexpr sampler s(min_filter::linear,mag_filter::linear);

    // Keep these values aligned with RenderDebugViewMode.
    const int depthMode = 3;
    const int normalMode = 2;
    const int ssaoMode = 4;

    if (debugMode == depthMode) {
        float near = frustumPlanes.x;
        float far = frustumPlanes.y;
        float rawDepth = depthTexture.sample(s, vertexOut.uvCoords);
        float normalized = linearizeDepthForViewing(rawDepth, near, far);
        return float4(normalized, normalized, normalized, 1.0);
    }

    float4 sampled = finalTexture.sample(s, vertexOut.uvCoords);
    if (debugMode == normalMode) {
        sampled = float4(sampled.xyz * 0.5 + 0.5, 1.0);
    } else if (debugMode == ssaoMode) {
        sampled = float4(sampled.r, sampled.r, sampled.r, 1.0);
    }

    return sampled;
}

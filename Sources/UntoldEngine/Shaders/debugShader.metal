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
                                    constant simd_float2 &frustumPlanes [[buffer(debugPassFrustumPlanesIndex)]],
                                    constant bool &reverseZ [[buffer(debugPassReverseZIndex)]]) {

    constexpr sampler s(min_filter::linear,mag_filter::linear);

    // Keep these values aligned with RenderDebugViewMode.
    const int depthMode = 3;
    const int normalMode = 2;
    const int ssaoMode = 4;
    const int positionMode = 10;
    const int roughnessMode = 11;
    const int metallicMode = 12;
    const int preTonemapHDRLuminanceMode = 13;
    const int heightDebugMode = 15;
    const int pomOffsetDebugMode = 16;

    if (debugMode == depthMode) {
        float near = frustumPlanes.x;
        float far = frustumPlanes.y;
        float rawDepth = depthTexture.sample(s, vertexOut.uvCoords);
        float normalized = linearizeDepthForViewing(rawDepth, near, far, reverseZ);
        return float4(normalized, normalized, normalized, 1.0);
    }

    float4 sampled = finalTexture.sample(s, vertexOut.uvCoords);
    if (debugMode == normalMode) {
        sampled = float4(sampled.xyz * 0.5 + 0.5, 1.0);
    } else if (debugMode == positionMode) {
        sampled = float4(fract(sampled.xyz * 0.1), 1.0);
    } else if (debugMode == roughnessMode) {
        sampled = float4(sampled.r, sampled.r, sampled.r, 1.0);
    } else if (debugMode == metallicMode) {
        sampled = float4(sampled.g, sampled.g, sampled.g, 1.0);
    } else if (debugMode == heightDebugMode) {
        sampled = float4(sampled.b, sampled.b, sampled.b, 1.0);
    } else if (debugMode == pomOffsetDebugMode) {
        sampled = float4(sampled.a, sampled.a, sampled.a, 1.0);
    } else if (debugMode == preTonemapHDRLuminanceMode) {
        float luminance = dot(max(sampled.rgb, 0.0), float3(0.2126, 0.7152, 0.0722));
        float mapped = log2(1.0 + luminance) / 6.0;
        sampled = float4(mapped, mapped, mapped, 1.0);
    } else if (debugMode == ssaoMode) {
        sampled = float4(sampled.r, sampled.r, sampled.r, 1.0);
    }

    return sampled;
}

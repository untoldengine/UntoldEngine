//
//  iblPreFilterShaders.metal
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
#include "ShadersUtils.h"
using namespace metal;

vertex VertexCompositeOutput vertexIBLPreFilterShader(VertexCompositeIn in [[stage_in]]){

    VertexCompositeOutput vertexOut;
    vertexOut.position=float4(float3(in.position),1.0);
    vertexOut.uvCoords=in.uvCoords;

    return vertexOut;
}

fragment IBLFragmentOut fragmentIBLPreFilterShader(VertexCompositeOutput in [[stage_in]],
                                        texture2d<float> environmentTexture[[texture(0)]]){


//    constexpr sampler s(coord::normalized,
//                        filter::linear,
//                        mip_filter::linear,
//                        address::repeat);

    IBLFragmentOut out;

    out.irradiance=diffuseImportanceMap(in.uvCoords, environmentTexture);
    out.specular=specularImportanceMap(in.uvCoords, environmentTexture, 0.0);
    out.brdfMap=BRDFIntegrationMap(1.0-in.uvCoords.y, in.uvCoords.x);

    return out;
}

fragment float4 fragmentIBLSpecularPreFilterShader(VertexCompositeOutput in [[stage_in]],
                                                   texture2d<float> environmentTexture [[texture(0)]],
                                                   constant float &roughness [[buffer(0)]]) {
    return specularImportanceMap(in.uvCoords, environmentTexture, roughness);
}

static float3 xrIBLNormalFromEquirectUV(float2 texCoords) {
    float thetaN = M_PI_F * (1.0 - texCoords.y);
    float phiN = 2.0 * M_PI_F * (1.0 - texCoords.x);
    return float3(sin(thetaN) * cos(phiN), sin(thetaN) * sin(phiN), cos(thetaN));
}

static float4 diffuseImportanceMapCube(float2 texCoords, texturecube<float> environmentTexture) {
    constexpr sampler s(coord::normalized,
                        filter::linear,
                        mip_filter::none,
                        address::clamp_to_edge);

    constexpr uint sampleCount = 128u;
    float3 normal = xrIBLNormalFromEquirectUV(texCoords);
    float3x3 normalSpace = getNormalSpace(normal);
    float3 result = float3(0.0);

    for (uint n = 1u; n <= sampleCount; n++) {
        float2 p = hammersley(n, sampleCount);
        float theta = asin(sqrt(p.y));
        float phi = 2.0 * M_PI_F * p.x;
        float3 pos = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
        float3 posGlob = normalize(normalSpace * pos);
        result += environmentTexture.sample(s, posGlob).rgb;
    }

    return float4(result / float(sampleCount), 1.0);
}

static float4 specularImportanceMapCube(float2 texCoords, texturecube<float> environmentTexture, float roughness) {
    constexpr sampler s(coord::normalized,
                        filter::linear,
                        mip_filter::none,
                        address::clamp_to_edge);

    uint sampleCount = roughness < 0.001 ? 1u : 128u;
    float3 normal = xrIBLNormalFromEquirectUV(texCoords);
    float3 result = float3(0.0);
    float totalWeight = 0.0;

    for (uint n = 1u; n <= sampleCount; n++) {
        float2 p = hammersley(n, sampleCount);
        float3 H = roughness < 0.001 ? normal : importanceSampleGGX(p, roughness, normal);
        float3 L = normalize(2.0 * dot(normal, H) * H - normal);
        float NoL = max(dot(normal, L), 0.0);
        if (NoL > 0.0) {
            result += environmentTexture.sample(s, L).rgb * NoL;
            totalWeight += NoL;
        }
    }

    result = totalWeight > 0.0 ? result / totalWeight : float3(0.0);
    return float4(result, 1.0);
}

fragment IBLFragmentOut fragmentXRIBLCubePreFilterShader(VertexCompositeOutput in [[stage_in]],
                                                         texturecube<float> environmentTexture [[texture(0)]]) {
    IBLFragmentOut out;
    out.irradiance = diffuseImportanceMapCube(in.uvCoords, environmentTexture);
    out.specular = specularImportanceMapCube(in.uvCoords, environmentTexture, 0.0);
    out.brdfMap = BRDFIntegrationMap(1.0 - in.uvCoords.y, in.uvCoords.x);
    return out;
}

fragment float4 fragmentXRIBLCubeSpecularPreFilterShader(VertexCompositeOutput in [[stage_in]],
                                                         texturecube<float> environmentTexture [[texture(0)]],
                                                         constant float &roughness [[buffer(0)]]) {
    return specularImportanceMapCube(in.uvCoords, environmentTexture, roughness);
}

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
    // One row per roughness, from 0 in the first row to 1 in the last, and one column per
    // angle of view: specularIBL reads it at (NoV, roughness). The rows used to run the
    // other way, so a polished surface took the share of a rough one and the reverse.
    out.brdfMap=BRDFIntegrationMap(in.uvCoords.y, in.uvCoords.x);

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

// The direction a texel of the maps stands for, in the world. The maps are read with a
// world direction through equirectUVFromCubeDirection (y up, the azimuth from x and z) and
// written here from the texel's direction in the pre-filter's own frame (z the pole, the
// azimuth from x and y); the two compose to a fixed turn of the axes, d = (−n.z, −n.x, −n.y)
// for a world direction n. The source is read with the texel's world direction, so that the
// probe's +y face, the ceiling, lights what faces up. Without it each face lit the wrong side
// (the ceiling lit the left of a sphere, what was behind the wearer lit its underside, and a
// chrome ball reflected a wall for the room behind), and the static maps only got away with
// it because an equirect image reads the same whichever way its azimuth is turned.
static float3 xrIBLWorldDirection(float3 d) {
    return float3(-d.y, -d.z, -d.x);
}

// The probe is eight texels a face. Importance sampling it, 128 samples a texel of the maps,
// left the maps with the structure of the sample set: with a window's worth of light in one
// texel, whether none, one or two of the samples land in it turns with the normal, and a white
// sphere showed ridges and spirals. The maps are convolved instead: the irradiance from the
// probe's first nine spherical harmonics, which hold light this smooth exactly, and the rougher
// specular mips by a fixed quadrature of directions, which the normal does not turn.
constant uint kXRProbeQuadratureCount = 1024u;

// The k-th of a Fibonacci set of directions over the sphere, in the pre-filter's frame.
static float3 xrProbeQuadratureDirection(uint k, uint count) {
    float z = 1.0 - (2.0 * (float(k) + 0.5)) / float(count);
    float r = sqrt(max(1.0 - z * z, 0.0));
    float phi = 2.399963229728653 * float(k);
    return float3(r * cos(phi), r * sin(phi), z);
}

// The real spherical-harmonic basis to the second band.
static void xrProbeSHBasis(float3 d, thread float *y) {
    y[0] = 0.282095;
    y[1] = 0.488603 * d.y;
    y[2] = 0.488603 * d.z;
    y[3] = 0.488603 * d.x;
    y[4] = 1.092548 * d.x * d.y;
    y[5] = 1.092548 * d.y * d.z;
    y[6] = 0.315392 * (3.0 * d.z * d.z - 1.0);
    y[7] = 1.092548 * d.x * d.z;
    y[8] = 0.546274 * (d.x * d.x - d.y * d.y);
}

// Projects the probe onto its first nine spherical harmonics: one threadgroup, each thread a
// share of the quadrature directions, reduced across the group into nine float4s (rgb and a
// spare).
kernel void xrProbeSHProjection(texturecube<float> environmentTexture [[texture(0)]],
                                device float4 *sh [[buffer(0)]],
                                uint threadIndex [[thread_index_in_threadgroup]],
                                uint threads [[threads_per_threadgroup]],
                                uint simdLane [[thread_index_in_simdgroup]],
                                uint simdIndex [[simdgroup_index_in_threadgroup]],
                                uint simdCount [[simdgroups_per_threadgroup]]) {
    constexpr sampler s(coord::normalized, filter::linear, mip_filter::none, address::clamp_to_edge);
    threadgroup float3 partial[32][9];
    float3 sum[9];
    for (uint i = 0u; i < 9u; i++) {
        sum[i] = float3(0.0);
    }
    for (uint k = threadIndex; k < kXRProbeQuadratureCount; k += threads) {
        float3 d = xrProbeQuadratureDirection(k, kXRProbeQuadratureCount);
        float3 radiance = environmentTexture.sample(s, xrIBLWorldDirection(d)).rgb;
        float y[9];
        xrProbeSHBasis(d, y);
        for (uint i = 0u; i < 9u; i++) {
            sum[i] += radiance * y[i];
        }
    }
    for (uint i = 0u; i < 9u; i++) {
        float3 total = float3(simd_sum(sum[i].x), simd_sum(sum[i].y), simd_sum(sum[i].z));
        if (simdLane == 0u) {
            partial[simdIndex][i] = total;
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (threadIndex == 0u) {
        const float weight = 4.0 * M_PI_F / float(kXRProbeQuadratureCount);
        for (uint i = 0u; i < 9u; i++) {
            float3 total = float3(0.0);
            for (uint g = 0u; g < simdCount; g++) {
                total += partial[g][i];
            }
            sh[i] = float4(total * weight, 0.0);
        }
    }
}

// The irradiance over π at a normal, from the harmonics: Ramamoorthi and Hanrahan's
// convolution, the bands weighted π, 2π/3 and π/4, taken over π as the map stores it.
static float3 xrProbeIrradiance(float3 normal, constant float4 *sh) {
    float y[9];
    xrProbeSHBasis(normal, y);
    float3 e = sh[0].rgb * y[0];
    e += (2.0 / 3.0) * (sh[1].rgb * y[1] + sh[2].rgb * y[2] + sh[3].rgb * y[3]);
    e += 0.25 * (sh[4].rgb * y[4] + sh[5].rgb * y[5] + sh[6].rgb * y[6] + sh[7].rgb * y[7] + sh[8].rgb * y[8]);
    return max(e, 0.0);
}

static float4 specularImportanceMapCube(float2 texCoords, texturecube<float> environmentTexture, float roughness) {
    constexpr sampler s(coord::normalized,
                        filter::linear,
                        mip_filter::none,
                        address::clamp_to_edge);

    float3 normal = xrIBLNormalFromEquirectUV(texCoords);
    if (roughness >= 0.25) {
        // The rougher mips by the quadrature: the GGX lobe about the normal, which stands in
        // for the view (the split sum), weighs each direction.
        float3 convolved = float3(0.0);
        float convolvedWeight = 0.0;
        for (uint k = 0u; k < kXRProbeQuadratureCount; k++) {
            float3 L = xrProbeQuadratureDirection(k, kXRProbeQuadratureCount);
            float NoL = dot(normal, L);
            if (NoL <= 0.0) {
                continue;
            }
            float3 H = normalize(L + normal);
            float weight = distributionGGX(max(dot(normal, H), 0.0), roughness) * NoL;
            convolved += environmentTexture.sample(s, xrIBLWorldDirection(L)).rgb * weight;
            convolvedWeight += weight;
        }
        return float4(convolvedWeight > 0.0 ? convolved / convolvedWeight : float3(0.0), 1.0);
    }

    uint sampleCount = roughness < 0.001 ? 1u : 128u;
    float3 result = float3(0.0);
    float totalWeight = 0.0;

    for (uint n = 1u; n <= sampleCount; n++) {
        float2 p = hammersley(n, sampleCount);
        float3 H = roughness < 0.001 ? normal : importanceSampleGGX(p, roughness, normal);
        float3 L = normalize(2.0 * dot(normal, H) * H - normal);
        float NoL = max(dot(normal, L), 0.0);
        if (NoL > 0.0) {
            result += environmentTexture.sample(s, xrIBLWorldDirection(L)).rgb * NoL;
            totalWeight += NoL;
        }
    }

    result = totalWeight > 0.0 ? result / totalWeight : float3(0.0);
    return float4(result, 1.0);
}

fragment IBLFragmentOut fragmentXRIBLCubePreFilterShader(VertexCompositeOutput in [[stage_in]],
                                                         texturecube<float> environmentTexture [[texture(0)]],
                                                         constant float4 *probeSH [[buffer(1)]]) {
    IBLFragmentOut out;
    out.irradiance = float4(xrProbeIrradiance(xrIBLNormalFromEquirectUV(in.uvCoords), probeSH), 1.0);
    out.specular = specularImportanceMapCube(in.uvCoords, environmentTexture, 0.0);
    // See fragmentIBLPreFilterShader: one row per roughness, as specularIBL reads it.
    out.brdfMap = BRDFIntegrationMap(in.uvCoords.y, in.uvCoords.x);
    return out;
}

fragment float4 fragmentXRIBLCubeSpecularPreFilterShader(VertexCompositeOutput in [[stage_in]],
                                                         texturecube<float> environmentTexture [[texture(0)]],
                                                         constant float &roughness [[buffer(0)]]) {
    return specularImportanceMapCube(in.uvCoords, environmentTexture, roughness);
}

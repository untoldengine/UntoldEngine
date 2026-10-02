//
//  MLDeformerCompute.metal
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
using namespace metal;

// ML deformer decode: one thread per active vertex reconstructs its skin
// delta from the PCA mean and basis with the coefficients the CPU network
// predicted for this pose, then adds it to the skinned position and bends
// the normal. Structurally the morph path with a dense, learned basis.
kernel void deformMLDecode(
    device simd_float4 *positions [[buffer(mlDecodePositionsIndex)]],
    device simd_float4 *normals [[buffer(mlDecodeNormalsIndex)]],
    const device uint *activeIndices [[buffer(mlDecodeActiveIndicesIndex)]],
    const device half *deltaMean [[buffer(mlDecodeDeltaMeanIndex)]],
    const device half *basis [[buffer(mlDecodeBasisIndex)]],
    const device float *coefficients [[buffer(mlDecodeCoefficientsIndex)]],
    constant MLDecodeParams &params [[buffer(mlDecodeParamsIndex)]],
    uint aid [[thread_position_in_grid]])
{
    if (aid >= params.activeCount) {
        return;
    }
    uint vertexIndex = activeIndices[aid];
    if (vertexIndex >= params.vertexCount) {
        return;
    }

    uint meanBase = aid * 6;
    float3 dPosition = float3(deltaMean[meanBase], deltaMean[meanBase + 1], deltaMean[meanBase + 2]);
    float3 dNormal = float3(deltaMean[meanBase + 3], deltaMean[meanBase + 4], deltaMean[meanBase + 5]);
    for (uint k = 0; k < params.componentCount; k++) {
        float c = coefficients[k];
        uint base = (k * params.activeCount + aid) * 6;
        dPosition += c * float3(basis[base], basis[base + 1], basis[base + 2]);
        dNormal += c * float3(basis[base + 3], basis[base + 4], basis[base + 5]);
    }

    simd_float4 position = positions[vertexIndex];
    position.xyz += dPosition * params.weight;
    positions[vertexIndex] = position;

    simd_float4 normal = normals[vertexIndex];
    float3 bent = normal.xyz + dNormal * params.weight;
    float len = length(bent);
    if (len > 1e-8f) {
        normal.xyz = bent / len;
        normals[vertexIndex] = normal;
    }
}

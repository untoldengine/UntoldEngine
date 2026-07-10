//
//  BitonicSort.metal
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  BitonicSort.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 11/10/25.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
#include "ShadersUtils.h"
using namespace metal;


// Depth-sorting key: front-to-back or back-to-front without float->int scaling
inline uint float_to_sortable_u32(float x) {
    uint u = as_type<uint>(x);
    // Map IEEE754 to a total order in unsigned ints:
    //   negatives (sign=1)  -> flip all bits
    //   non-negatives       -> flip sign bit
    uint mask = (u >> 31) ? 0xffffffffu : 0x80000000u;
    return u ^ mask;
}

inline float eye_space_depth(const float4x4 modelView, float3 worldPos) {
    float4 v = modelView * float4(worldPos, 1.0);
    // If camera looks down -Z, nearer = smaller (-v.z); make it non-negative
    return max(-v.z, 0.0f);
}

kernel void gaussianResetVisibleCount(
    device atomic_uint *visibleCount [[buffer(gaussianVisibleCountIndex)]],
    uint index [[thread_position_in_grid]])
{
    if (index == 0u) {
        atomic_store_explicit(visibleCount, 0u, memory_order_relaxed);
    }
}

kernel void gaussianFrustumCull(
    const device EncodedGaussianSplat *splats [[buffer(gaussianEncodedSplatIndex)]],
    constant Uniforms &uniforms [[buffer(gaussianUniformIndex)]],
    constant uint &numOfSplats [[buffer(gaussianNumberOfSplatsIndex)]],
    constant float &clipGuardBand [[buffer(gaussianIndicesIndex)]],
    device uint *visibleIndices [[buffer(gaussianVisibleIndicesIndex)]],
    device atomic_uint *visibleCount [[buffer(gaussianVisibleCountIndex)]],
    uint index [[thread_position_in_grid]])
{
    if (index >= numOfSplats) return;

    float4 centerClip = uniforms.projectionMatrix *
                        uniforms.modelViewMatrix *
                        float4(splats[index].position, 1.0f);

    if (centerClip.w <= 0.0f) return;

    float limit = max(0.0f, 1.0f + clipGuardBand);
    float2 ndc = centerClip.xy / centerClip.w;
    if (abs(ndc.x) > limit || abs(ndc.y) > limit) return;
    if (centerClip.z < -centerClip.w * clipGuardBand || centerClip.z > centerClip.w * limit) return;

    uint writeIndex = atomic_fetch_add_explicit(visibleCount, 1u, memory_order_relaxed);
    visibleIndices[writeIndex] = index;
}

kernel void gaussianDepthKeys(device uint64_t *outKeys              [[buffer(gaussianIndicesIndex)]],
                              const device EncodedGaussianSplat *splats [[buffer(gaussianEncodedSplatIndex)]],
                              constant uint &numOfSplats [[buffer(gaussianNumberOfSplatsIndex)]],
                              constant Uniforms &uniforms     [[buffer(gaussianUniformIndex)]],
                              const device uint *visibleIndices [[buffer(gaussianVisibleIndicesIndex)]],
                              const device uint *visibleCount [[buffer(gaussianVisibleCountIndex)]],
                              uint index                              [[thread_position_in_grid]],
                              uint gridSize                           [[threads_per_grid]])
{
    if (index >= numOfSplats) return;

    if (index >= visibleCount[0]) {
        uint64_t invalidPacked = ((uint64_t)0xffffffffu << 32) | (uint64_t)0xffffffffu;
        outKeys[index] = invalidPacked;
        return;
    }

    uint splatIndex = visibleIndices[index];

    // 1) Eye-space depth
    float z = eye_space_depth(uniforms.modelViewMatrix, splats[splatIndex].position);

    // 2) Convert to lexicographically sortable unsigned int
    uint keyFrontToBack = float_to_sortable_u32(z);

    // gaussian sorting
    //uint keyBackToFront = 0xffffffffu - keyFrontToBack;

    // 3) Pack [key | index] for 64-bit radix sort (key in high bits)
    uint64_t packed = (uint64_t)keyFrontToBack << 32 | (uint64_t)splatIndex;
    outKeys[index] = packed;
}

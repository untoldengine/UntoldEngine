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

// Runs once per entity right after gaussianFrustumCull, in the same (serial) encoder, so it
// sees the final appended count. Writes the indirect dispatch and draw arguments that every
// later pass of this frame consumes — see GaussianVisibleSet in ShaderTypes.h.
kernel void gaussianFinalizeVisibleSet(
    device GaussianVisibleSet *visibleSet [[buffer(gaussianVisibleCountIndex)]],
    uint index [[thread_position_in_grid]])
{
    if (index != 0u) return;

    uint count = visibleSet->visibleCount;
    uint threadgroups = (count + (uint)gaussianVisibleBlockSize - 1u) / (uint)gaussianVisibleBlockSize;
    visibleSet->threadgroupCount = threadgroups;
    visibleSet->overflowCount = 0u;
    visibleSet->threadgroupsPerGrid[0] = threadgroups;
    visibleSet->threadgroupsPerGrid[1] = 1u;
    visibleSet->threadgroupsPerGrid[2] = 1u;
    visibleSet->vertexCount = 4u;
    visibleSet->instanceCount = count;
    visibleSet->vertexStart = 0u;
    visibleSet->baseInstance = 0u;
}

// The per-splat visibility test, shared by gaussianFrustumCull (one thread per resident splat)
// and gaussianChunkSplatCull (GaussianChunkCull.metal, one threadgroup per visible chunk) so
// the two paths keep exactly the same splats: centre inside the guard-banded clip volume,
// then optionally not behind the previous frame's HZB.
inline bool gaussianSplatPassesCull(
    float3 position,
    constant Uniforms &uniforms,
    float clipGuardBand,
    uint hzbReverseZ,
    float hzbOcclusionBias,
    uint hzbValid,
    texture2d<float, access::sample> hzbDepthPyramid)
{
    float4 centerClip = uniforms.projectionMatrix *
                        uniforms.modelViewMatrix *
                        float4(position, 1.0f);

    if (centerClip.w <= 0.0f) return false;

    float limit = max(0.0f, 1.0f + clipGuardBand);
    float2 ndc = centerClip.xy / centerClip.w;
    if (abs(ndc.x) > limit || abs(ndc.y) > limit) return false;
    if (centerClip.z < -centerClip.w * clipGuardBand || centerClip.z > centerClip.w * limit) return false;

    // Coarse per-splat occlusion pre-cull against the same (previous-frame, temporal) HZB
    // pyramid mesh occlusion culling already builds and uses (see HZBCompute.metal). A
    // single center-point sample at HZB mip 0 is enough here — unlike mesh AABBs, which
    // sample a 5x5 grid to avoid landing entirely on a porous occluder, an individual
    // splat is small enough that its footprint rarely spans more than the texel this
    // samples. This is a cheap, conservative pre-filter that keeps wholly-occluded splats
    // (e.g. behind a wall) out of preprocess/depth/sort/draw entirely; the fragment
    // shader's own per-pixel opaque-depth test still runs afterward and remains the
    // source of truth for partial occlusion.
    if (hzbValid != 0u) {
        float2 uv = float2(ndc.x * 0.5f + 0.5f, 1.0f - (ndc.y * 0.5f + 0.5f));
        float splatDepth = clamp(centerClip.z / centerClip.w, 0.0f, 1.0f);
        constexpr sampler pointSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
        float hzbDepth = hzbDepthPyramid.sample(pointSampler, uv, level(0)).x;
        bool occluded = (hzbReverseZ != 0u)
            ? (splatDepth < hzbDepth - hzbOcclusionBias)
            : (splatDepth > hzbDepth + hzbOcclusionBias);
        if (occluded) return false;
    }
    return true;
}

// One thread per resident splat: the whole-buffer cull for entities without a chunk table
// (.ply, CPU-decoded .untoldgs). Chunked entities run gaussianChunkSplatCull instead.
kernel void gaussianFrustumCull(
    const device EncodedGaussianSplat *splats [[buffer(gaussianEncodedSplatIndex)]],
    constant Uniforms &uniforms [[buffer(gaussianUniformIndex)]],
    constant uint &numOfSplats [[buffer(gaussianNumberOfSplatsIndex)]],
    constant float &clipGuardBand [[buffer(gaussianIndicesIndex)]],
    device uint *visibleIndices [[buffer(gaussianVisibleIndicesIndex)]],
    device atomic_uint *visibleCount [[buffer(gaussianVisibleCountIndex)]],
    constant uint &hzbReverseZ [[buffer(gaussianCullHZBReverseZIndex)]],
    constant float &hzbOcclusionBias [[buffer(gaussianCullHZBOcclusionBiasIndex)]],
    constant uint &hzbValid [[buffer(gaussianCullHZBValidIndex)]],
    texture2d<float, access::sample> hzbDepthPyramid [[texture(gaussianCullHZBDepthPyramidTextureIndex)]],
    uint index [[thread_position_in_grid]])
{
    if (index >= numOfSplats) return;
    if (!gaussianSplatPassesCull(splats[index].position, uniforms, clipGuardBand, hzbReverseZ, hzbOcclusionBias, hzbValid, hzbDepthPyramid)) return;

    uint writeIndex = atomic_fetch_add_explicit(visibleCount, 1u, memory_order_relaxed);
    visibleIndices[writeIndex] = index;
}

// The frame's shared working set: gaussianPreprocess appends past the capacity when the
// entities hold more visible splats than the set can take, so the count is clamped here and
// the excess recorded. Runs once after every entity's preprocess dispatch, same encoder.
kernel void gaussianFinalizeSharedVisibleSet(
    device GaussianVisibleSet *visibleSet [[buffer(gaussianVisibleCountIndex)]],
    constant uint &capacity [[buffer(gaussianNumberOfSplatsIndex)]],
    uint index [[thread_position_in_grid]])
{
    if (index != 0u) return;

    uint appended = visibleSet->visibleCount;
    uint count = min(appended, capacity);
    uint threadgroups = (count + (uint)gaussianVisibleBlockSize - 1u) / (uint)gaussianVisibleBlockSize;
    visibleSet->visibleCount = count;
    visibleSet->overflowCount = appended - count;
    visibleSet->threadgroupCount = threadgroups;
    visibleSet->threadgroupsPerGrid[0] = threadgroups;
    visibleSet->threadgroupsPerGrid[1] = 1u;
    visibleSet->threadgroupsPerGrid[2] = 1u;
    visibleSet->vertexCount = 4u;
    visibleSet->instanceCount = count;
    visibleSet->vertexStart = 0u;
    visibleSet->baseInstance = 0u;
}


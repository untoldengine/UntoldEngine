//
//  GaussianChunkCull.metal
//  UntoldEngine
//
//  Chunk-level culling of .untoldgs entities. Runs inside the "Gaussian Frustum Culling"
//  encoder: one thread per chunk tests the chunk's centre AABB, padded by the largest splat it
//  holds, against the guard-banded clip volume of each view (either eye in stereo) and, when a
//  pyramid is valid, against the previous frame's HZB with the mesh cull's conservative
//  sampling. Survivors are appended to a per-entity, per-frame visible-chunk list whose
//  GaussianVisibleSet-shaped record then drives one threadgroup of gaussianChunkDecodePreprocess
//  (GaussianChunkPreprocess.metal) per visible chunk, after gaussianComputeChunkQuotas
//  (GaussianWorkingSetBudget.metal) has fitted the list to the frame's working-set budget.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
#include "HZBOcclusion.h"
using namespace metal;

// Conservative test of an entity-local box against the guard-banded clip volume the per-splat
// cull uses: w > 0, |x| <= w(1+g), |y| <= w(1+g), -w·g <= z <= w(1+g). Every one of these is a
// half-space in homogeneous clip coordinates, so the box — convex — is rejected only when all
// eight corners fall beyond the same plane. A splat centre that passes the per-splat test lies
// inside every half-space, and its chunk's padded box contains it, so that chunk always passes
// here: the chunk cull can only ever remove splats the per-splat cull would have removed too.
static inline bool gaussianBoxPassesClipPlanes(
    const float3 boxMin,
    const float3 boxMax,
    constant float4x4 &viewProjection,
    const float clipGuardBand)
{
    const float limit = max(0.0f, 1.0f + clipGuardBand);
    uint outsideEveryCorner = 0x7Fu;
    for (uint i = 0u; i < 8u; ++i) {
        const float3 corner = float3(((i & 1u) != 0u) ? boxMax.x : boxMin.x,
                                     ((i & 2u) != 0u) ? boxMax.y : boxMin.y,
                                     ((i & 4u) != 0u) ? boxMax.z : boxMin.z);
        const float4 c = viewProjection * float4(corner, 1.0f);
        uint outside = 0u;
        outside |= (c.w <= 0.0f) ? 0x01u : 0u;
        outside |= (c.x < -c.w * limit) ? 0x02u : 0u;
        outside |= (c.x > c.w * limit) ? 0x04u : 0u;
        outside |= (c.y < -c.w * limit) ? 0x08u : 0u;
        outside |= (c.y > c.w * limit) ? 0x10u : 0u;
        outside |= (c.z < -c.w * clipGuardBand) ? 0x20u : 0u;
        outside |= (c.z > c.w * limit) ? 0x40u : 0u;
        outsideEveryCorner &= outside;
    }
    return outsideEveryCorner == 0u;
}

// One view's verdict on a chunk: inside the clip volume and, with a valid pyramid, not behind
// the HZB. The occlusion test is the mesh cull's (HZBOcclusion.h): the box's screen rect at the
// mip that covers it, 5x5 samples, nearest box depth against the farthest sample plus the bias.
static inline bool gaussianChunkVisibleInView(
    const float3 boxMin,
    const float3 boxMax,
    constant float4x4 &viewProjection,
    constant GaussianChunkCullConstants &params,
    texture2d<float, access::sample> hzbDepthPyramid)
{
    if (!gaussianBoxPassesClipPlanes(boxMin, boxMax, viewProjection, params.clipGuardBand)) {
        return false;
    }
    if (params.hzbValid == 0u) {
        return true;
    }
    const bool reverseZ = params.hzbReverseZ != 0u;
    float2 uvMin;
    float2 uvMax;
    float nearDepth;
    if (!projectAABBToScreenRect(0.5f * (boxMin + boxMax), 0.5f * (boxMax - boxMin), viewProjection, reverseZ, uvMin, uvMax, nearDepth)) {
        return true;
    }
    return !hzbRectIsOccluded(hzbDepthPyramid, uvMin, uvMax, nearDepth, params.viewport, params.hzbMipCount, reverseZ, params.hzbOcclusionBias);
}

// Zeroes the two counters of an entity's visible-chunk record before gaussianChunkCull appends.
kernel void gaussianResetVisibleChunkSet(
    device GaussianVisibleSet *chunkSet [[buffer(gaussianVisibleCountIndex)]],
    uint index [[thread_position_in_grid]])
{
    if (index != 0u) return;
    chunkSet->visibleCount = 0u;
    chunkSet->threadgroupCount = 0u;
}

// One thread per chunk of one entity. A chunk's box is its centre AABB (the decode constants)
// padded on every side by kGaussianQuadSigma·exp(logScaleMax): the largest splat in the chunk
// reaches at most that far from its centre along any axis, so the box holds every splat's
// rendered quad. Visible if it passes any of the frame's views.
kernel void gaussianChunkCull(
    const device GaussianChunkDecodeConstants *chunks [[buffer(gaussianChunkCullChunkTableIndex)]],
    constant GaussianChunkCullConstants &params [[buffer(gaussianChunkCullConstantsIndex)]],
    device GaussianVisibleChunk *visibleChunks [[buffer(gaussianChunkCullVisibleChunksIndex)]],
    device atomic_uint *visibleSplatTotal [[buffer(gaussianChunkCullSplatTotalIndex)]],
    device atomic_uint *visibleChunkTotal [[buffer(gaussianChunkCullChunkTotalIndex)]],
    texture2d<float, access::sample> hzbDepthPyramid [[texture(gaussianChunkCullHZBDepthPyramidTextureIndex)]],
    uint chunkIndex [[thread_position_in_grid]])
{
    if (chunkIndex >= params.chunkCount) return;
    const GaussianChunkDecodeConstants chunk = chunks[chunkIndex];

    bool visible = params.forceAllVisible != 0u;
    if (!visible) {
        const float pad = kGaussianQuadSigma * exp(chunk.logScaleMax);
        const float3 boxMin = float3(chunk.aabbMinX, chunk.aabbMinY, chunk.aabbMinZ) - pad;
        const float3 boxMax = float3(chunk.aabbMaxX, chunk.aabbMaxY, chunk.aabbMaxZ) + pad;
        visible = gaussianChunkVisibleInView(boxMin, boxMax, params.viewProjection0, params, hzbDepthPyramid);
        if (!visible && params.viewCount > 1u) {
            visible = gaussianChunkVisibleInView(boxMin, boxMax, params.viewProjection1, params, hzbDepthPyramid);
        }
    }
    if (!visible) return;

    const uint slot = atomic_fetch_add_explicit(visibleChunkTotal, 1u, memory_order_relaxed);
    atomic_fetch_add_explicit(visibleSplatTotal, chunk.splatCount, memory_order_relaxed);
    GaussianVisibleChunk entry;
    entry.chunkIndex = chunkIndex;
    entry.splatCount = chunk.splatCount;
    entry.quota = chunk.splatCount;   // gaussianComputeChunkQuotas lowers it when the frame is over budget
    entry._pad0 = 0u;
    visibleChunks[slot] = entry;
}

// Runs once per entity after gaussianChunkCull, same serial encoder: turns the appended chunk
// count into the indirect dispatch of gaussianChunkDecodePreprocess — one threadgroup per
// visible chunk — keeps the splat total as the entity's request in instanceCount (visibleCount
// holds it too until gaussianComputeChunkQuotas replaces it with the quota sum; nothing draws
// from this record), and adds the request to the frame's budget state.
kernel void gaussianFinalizeVisibleChunks(
    device GaussianVisibleSet *chunkSet [[buffer(gaussianVisibleCountIndex)]],
    device atomic_uint *requestedSplats [[buffer(gaussianChunkCullBudgetStateIndex)]],
    uint index [[thread_position_in_grid]])
{
    if (index != 0u) return;

    const uint visibleChunks = chunkSet->threadgroupCount;
    const uint visibleSplats = chunkSet->visibleCount;
    chunkSet->overflowCount = 0u;
    chunkSet->threadgroupsPerGrid[0] = visibleChunks;
    chunkSet->threadgroupsPerGrid[1] = 1u;
    chunkSet->threadgroupsPerGrid[2] = 1u;
    chunkSet->vertexCount = 4u;
    chunkSet->instanceCount = visibleSplats;
    chunkSet->vertexStart = 0u;
    chunkSet->baseInstance = 0u;
    atomic_fetch_add_explicit(requestedSplats, visibleSplats, memory_order_relaxed);
}

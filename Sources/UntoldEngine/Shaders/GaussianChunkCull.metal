//
//  GaussianChunkCull.metal
//  UntoldEngine
//
//  Chunk-level culling of .untoldgs entities. Runs inside the "Gaussian Frustum Culling"
//  encoder: one thread per chunk tests the chunk's centre AABB, padded by the largest splat it
//  holds, against the guard-banded clip volume of each view (either eye in stereo) and, when a
//  pyramid is valid, against the previous frame's HZB with the mesh cull's conservative
//  sampling. The same corner loop yields the chunk's clipped screen area — the weight of its
//  quota — and its density (splats per view unit of area) is binned into the frame's
//  GaussianBudgetDensityHistogram, from which the budget solves the frame's density cap.
//  Survivors are appended to a per-entity, per-frame visible-chunk list whose
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
#include "GaussianDensityTier.h"
using namespace metal;

// Conservative test of an entity-local box against the guard-banded clip volume the per-splat
// cull uses: w > 0, |x| <= w(1+g), |y| <= w(1+g), -w·g <= z <= w(1+g). Every one of these is a
// half-space in homogeneous clip coordinates, so the box — convex — is rejected only when all
// eight corners fall beyond the same plane. A splat centre that passes the per-splat test lies
// inside every half-space, and its chunk's padded box contains it, so that chunk always passes
// here: the chunk cull can only ever remove splats the per-splat cull would have removed too.
//
// The same corners give the box's screen area in view units — the NDC rect of the corners in
// front of the eye, clipped to the guard-banded view, as a fraction of the view's width times
// its height, so a box filling the view has area 1, a box entering through the guard band an
// area near 0 that grows as it comes in, and a box half off-screen is charged for the half on
// screen; a box that reaches behind the eye (the chunk the camera stands in) gets the whole
// guard-banded volume, (1 + g)²; a rejected box 0. Mirrored by GaussianChunkCullMath.screenArea
// in the same operation order.
static inline bool gaussianBoxPassesClipPlanes(
    const float3 boxMin,
    const float3 boxMax,
    constant float4x4 &viewProjection,
    const float clipGuardBand,
    thread float &area)
{
    const float limit = max(0.0f, 1.0f + clipGuardBand);
    uint outsideEveryCorner = 0x7Fu;
    bool behind = false;
    float2 ndcMin = float2(INFINITY, INFINITY);
    float2 ndcMax = float2(-INFINITY, -INFINITY);
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
        if (c.w > 0.0f) {
            const float2 ndc = c.xy / c.w;
            ndcMin = min(ndcMin, ndc);
            ndcMax = max(ndcMax, ndc);
        } else {
            behind = true;
        }
    }
    const bool passes = outsideEveryCorner == 0u;
    if (!passes) {
        area = 0.0f;
    } else if (behind) {
        area = limit * limit;
    } else {
        const float2 lo = clamp(ndcMin, -limit, limit);
        const float2 hi = clamp(ndcMax, -limit, limit);
        const float2 extent = max(hi - lo, 0.0f) * 0.5f;
        area = extent.x * extent.y;
    }
    return passes;
}

// One view's verdict on a chunk: inside the clip volume and, with a valid pyramid, not behind
// the HZB. The occlusion test is the mesh cull's (HZBOcclusion.h): the box's screen rect at the
// mip that covers it, 5x5 samples, nearest box depth against the farthest sample plus the bias.
// `area` is the box's clipped screen area in this view, 0 when the view rejects or occludes it.
static inline bool gaussianChunkVisibleInView(
    const float3 boxMin,
    const float3 boxMax,
    constant float4x4 &viewProjection,
    constant GaussianChunkCullConstants &params,
    const uint hzbValid,
    texture2d<float, access::sample> hzbDepthPyramid,
    thread float &area)
{
    if (!gaussianBoxPassesClipPlanes(boxMin, boxMax, viewProjection, params.clipGuardBand, area)) {
        area = 0.0f;
        return false;
    }
    if (hzbValid == 0u) {
        return true;
    }
    const bool reverseZ = params.hzbReverseZ != 0u;
    float2 uvMin;
    float2 uvMax;
    float nearDepth;
    if (!projectAABBToScreenRect(0.5f * (boxMin + boxMax), 0.5f * (boxMax - boxMin), viewProjection, reverseZ, uvMin, uvMax, nearDepth)) {
        return true;
    }
    if (hzbRectIsOccluded(hzbDepthPyramid, uvMin, uvMax, nearDepth, params.viewport, params.hzbMipCount, reverseZ, params.hzbOcclusionBias)) {
        area = 0.0f;
        return false;
    }
    return true;
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
// rendered quad. Visible if it passes any of the frame's views — both are always evaluated in
// stereo, since the chunk's screen area is the larger of the two eyes' that keep it (either-eye
// semantics, no double counting, continuous under a head turn). In stereo the HZB is the mono
// pyramid of the last eye drawn (eye 1), so only eye 1's test samples it (see
// gaussianChunkSplatPassesCull); in mono view 0 is the head view the pyramid was built from.
//
// A survivor is charged for its area, clamped to [kGaussianScreenAreaMin, (1 + g)²] — a chunk
// no view keeps (forceAllVisible) gets the minimum, so it is the densest chunk of the frame and
// is cut first — and binned by its density into the frame's histogram: its splats, and its area
// in whole-splat units of the tier's lower density, ceil(area × ρ_t), an over-estimate that
// keeps the budget's bound one-sided. With uniformQuotas the entry carries splatCount as its
// area (density 1 for every chunk, the uniform rule) while the histogram still holds the real
// areas for the readback.
kernel void gaussianChunkCull(
    const device GaussianChunkDecodeConstants *chunks [[buffer(gaussianChunkCullChunkTableIndex)]],
    constant GaussianChunkCullConstants &params [[buffer(gaussianChunkCullConstantsIndex)]],
    device GaussianVisibleChunk *visibleChunks [[buffer(gaussianChunkCullVisibleChunksIndex)]],
    device atomic_uint *visibleSplatTotal [[buffer(gaussianChunkCullSplatTotalIndex)]],
    device atomic_uint *visibleChunkTotal [[buffer(gaussianChunkCullChunkTotalIndex)]],
    device atomic_uint *densityHistogram [[buffer(gaussianChunkCullDensityHistogramIndex)]],
    texture2d<float, access::sample> hzbDepthPyramid [[texture(gaussianChunkCullHZBDepthPyramidTextureIndex)]],
    uint chunkIndex [[thread_position_in_grid]])
{
    if (chunkIndex >= params.chunkCount) return;
    const GaussianChunkDecodeConstants chunk = chunks[chunkIndex];

    const float limit = max(0.0f, 1.0f + params.clipGuardBand);
    const float pad = kGaussianQuadSigma * exp(chunk.logScaleMax);
    const float3 boxMin = float3(chunk.aabbMinX, chunk.aabbMinY, chunk.aabbMinZ) - pad;
    const float3 boxMax = float3(chunk.aabbMaxX, chunk.aabbMaxY, chunk.aabbMaxZ) + pad;
    const uint hzbValidForView0 = params.viewCount > 1u ? 0u : params.hzbValid;
    float area0 = 0.0f;
    float area1 = 0.0f;
    const bool keep0 = gaussianChunkVisibleInView(boxMin, boxMax, params.viewProjection0, params, hzbValidForView0, hzbDepthPyramid, area0);
    const bool keep1 = params.viewCount > 1u
        ? gaussianChunkVisibleInView(boxMin, boxMax, params.viewProjection1, params, params.hzbValid, hzbDepthPyramid, area1)
        : false;
    const bool visible = keep0 || keep1 || params.forceAllVisible != 0u;
    if (!visible) return;
    const float area = clamp(max(keep0 ? area0 : 0.0f, keep1 ? area1 : 0.0f), kGaussianScreenAreaMin, limit * limit);

    const uint slot = atomic_fetch_add_explicit(visibleChunkTotal, 1u, memory_order_relaxed);
    atomic_fetch_add_explicit(visibleSplatTotal, chunk.splatCount, memory_order_relaxed);
    const uint tier = gaussianDensityTier((float)chunk.splatCount / area);
    atomic_fetch_add_explicit(&densityHistogram[2u * tier], chunk.splatCount, memory_order_relaxed);
    atomic_fetch_add_explicit(&densityHistogram[2u * tier + 1u], (uint)ceil(area * gaussianDensityTierFloor(tier)), memory_order_relaxed);
    GaussianVisibleChunk entry;
    entry.chunkIndex = chunkIndex;
    entry.splatCount = chunk.splatCount;
    entry.quota = chunk.splatCount;   // gaussianComputeChunkQuotas lowers it when the frame is over budget
    entry.screenArea = params.uniformQuotas != 0u ? (float)chunk.splatCount : area;
    visibleChunks[slot] = entry;
}

// Runs once per entity after gaussianChunkCull, same serial encoder: turns the appended chunk
// count into the indirect dispatch of gaussianChunkDecodePreprocess — one threadgroup per
// visible chunk — keeps the splat total as the entity's request in instanceCount (visibleCount
// holds it too until gaussianComputeChunkQuotas replaces it with the quota sum; nothing draws
// from this record), and adds the request to the frame's budget state and the chunk count to
// the frame's histogram.
kernel void gaussianFinalizeVisibleChunks(
    device GaussianVisibleSet *chunkSet [[buffer(gaussianVisibleCountIndex)]],
    device atomic_uint *requestedSplats [[buffer(gaussianChunkCullBudgetStateIndex)]],
    device atomic_uint *visibleChunkTotal [[buffer(gaussianChunkCullDensityHistogramIndex)]],
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
    atomic_fetch_add_explicit(visibleChunkTotal, visibleChunks, memory_order_relaxed);
}

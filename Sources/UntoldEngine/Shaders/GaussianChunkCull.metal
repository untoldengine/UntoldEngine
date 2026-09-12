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
//
// A paged entity (params.paged != 0, GaussianPageManager.swift) has its records in a page pool
// and not every chunk resident. For every chunk the cull then writes the frame's demand word —
// the chunk's seen screen area as float bits, 0 when no view keeps it (forceAllVisible does not
// count; the real area even under uniformQuotas) — which the pager reads back three frames
// later to decide what to load; with paged == 2 (a warming tier the LOD system is about to
// switch to) that is all it does. A resident chunk is listed with drawable = min(splatCount,
// residentRanks), so the request, the histogram and the quotas see only ranks the fused pass can
// read; a chunk with no resident rank is not listed at all — it contributes nothing this frame.
//
// An entity with per-chunk coarse levels (lvl.hasCoarse != 0, per-chunk-lod-tiers; off under
// uniformQuotas and in the fine-only debug mode) lists every visible chunk once for the level
// state left by last frame's quota pass — a non-resident paged chunk included, for its finest
// landed coarse level, with that level's count as its listed splats; a partially resident one
// with at least that count, so the request the solve charges in the fine regime is never below
// what the chunk draws at its level — bins it by its full density (splatCount / area, the same
// tier whatever its residency) and adds to the tier the counts the level rule would draw in
// each coarse regime (coarse1, coarse2), the listed splats of the chunks that have a level
// (levelledSplats) and their scaled area (levelledScaledArea). A chunk whose previous level is still
// fading out — a switch detected last frame (pendingValid), a fade in progress, or a fine head
// that arrived within the fade window over a drawn coarse level — is listed a second time for
// its outgoing window: the entry tagged kGaussianVisibleChunkOutgoing with the window's level,
// its count reserved in the frame's transitionSplats (inside the request, so the solve fits
// only the incoming entries) and granted by the quota pass at the complementary fade weight.
// With hasCoarse == 0 nothing of this runs and the frame is byte for byte the frame before the
// levels existed.
kernel void gaussianChunkCull(
    const device GaussianChunkDecodeConstants *chunks [[buffer(gaussianChunkCullChunkTableIndex)]],
    constant GaussianChunkCullConstants &params [[buffer(gaussianChunkCullConstantsIndex)]],
    device GaussianVisibleChunk *visibleChunks [[buffer(gaussianChunkCullVisibleChunksIndex)]],
    device atomic_uint *visibleSplatTotal [[buffer(gaussianChunkCullSplatTotalIndex)]],
    device atomic_uint *visibleChunkTotal [[buffer(gaussianChunkCullChunkTotalIndex)]],
    device atomic_uint *transitionSplats [[buffer(gaussianChunkCullBudgetStateIndex)]],
    device atomic_uint *densityHistogram [[buffer(gaussianChunkCullDensityHistogramIndex)]],
    const device GaussianChunkResidency *residency [[buffer(gaussianChunkCullResidencyIndex)]],
    device uint *demand [[buffer(gaussianChunkCullDemandIndex)]],
    const device GaussianChunkDecodeConstants *coarseTable [[buffer(gaussianChunkCullCoarseTableIndex)]],
    const device GaussianChunkLevelState *levelState [[buffer(gaussianChunkCullLevelStateIndex)]],
    constant GaussianChunkLevelConstants &lvl [[buffer(gaussianChunkCullLevelConstantsIndex)]],
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
    const bool seen = keep0 || keep1;
    const float area = clamp(max(keep0 ? area0 : 0.0f, keep1 ? area1 : 0.0f), kGaussianScreenAreaMin, limit * limit);
    const bool levels = lvl.hasCoarse != 0u && params.uniformQuotas == 0u && lvl.levelMode != (uint)gaussianChunkLevelModeFineOnly;
    uint drawable = chunk.splatCount;
    GaussianChunkResidency res = { chunk.splatCount, chunk.splatCount, 0u, 0u };
    if (params.paged != 0u) {
        demand[chunkIndex] = seen ? as_type<uint>(area) : 0u;
        if (params.paged == 2u) return;
        res = residency[chunkIndex];
        drawable = min(drawable, res.residentRanks);
        if (drawable == 0u && !levels) return;
    }
    const bool visible = seen || params.forceAllVisible != 0u;

    // The coarse levels of this chunk: the counts of the runtime's level 1 and 2 rows and which
    // of them are available (a paged entity: landed for this chunk; whole-resident: every level
    // the entity has). A non-resident paged chunk is listed for its finest available level.
    uint m1 = 0u;
    uint m2 = 0u;
    uint available = 0u;
    GaussianChunkLevelState state = { 0u, 0u };
    if (levels) {
        m1 = coarseTable[chunkIndex].splatCount;
        m2 = lvl.hasCoarse >= 2u ? coarseTable[params.chunkCount + chunkIndex].splatCount : m1;
        const uint coarseBits = params.paged != 0u ? res.coarseAvailable : 3u;
        available = gaussianLevelAvailability(drawable != 0u, coarseBits, m1, m2, lvl.hasCoarse);
        state = levelState[chunkIndex];
        if (drawable == 0u) {
            if ((available & 6u) == 0u || !seen) return;
        }
    }
    if (!visible) return;
    const uint finestCoarse = ((available & 2u) != 0u) ? m1 : (((available & 4u) != 0u) ? m2 : 0u);
    const uint listed = max(drawable, finestCoarse);

    const uint slot = atomic_fetch_add_explicit(visibleChunkTotal, 1u, memory_order_relaxed);
    atomic_fetch_add_explicit(visibleSplatTotal, listed, memory_order_relaxed);
    const uint tier = gaussianDensityTier((levels ? (float)chunk.splatCount : (float)drawable) / area);
    const uint scaledArea = (uint)ceil(area * gaussianDensityTierFloor(tier));
    atomic_fetch_add_explicit(&densityHistogram[8u * tier], listed, memory_order_relaxed);
    atomic_fetch_add_explicit(&densityHistogram[8u * tier + 1u], scaledArea, memory_order_relaxed);
    if (levels && (available & 6u) != 0u) {
        atomic_fetch_add_explicit(&densityHistogram[8u * tier + 2u], finestCoarse, memory_order_relaxed);
        atomic_fetch_add_explicit(&densityHistogram[8u * tier + 3u], ((available & 4u) != 0u) ? m2 : m1, memory_order_relaxed);
        atomic_fetch_add_explicit(&densityHistogram[8u * tier + 4u], listed, memory_order_relaxed);
        atomic_fetch_add_explicit(&densityHistogram[8u * tier + 5u], scaledArea, memory_order_relaxed);
    }
    GaussianVisibleChunk entry;
    entry.chunkIndex = levels ? (chunkIndex | (gaussianLevelStateLevel(state.word0) << kGaussianVisibleChunkLevelShift)) : chunkIndex;
    entry.splatCount = listed;
    entry.quota = listed;   // gaussianComputeChunkQuotas lowers it when the frame is over budget
    entry.screenArea = params.uniformQuotas != 0u ? (float)listed : area;
    visibleChunks[slot] = entry;
    if (!levels) return;

    // The outgoing window, listed and reserved one frame before the quota pass commits the
    // switch and on every frame of the fade; the quota pass grants it (or zeroes it when the
    // switch does not commit) from the same state. With the cross-fade off (fadeFrames 0) a
    // switch draws the new level alone from its commit frame: no outgoing window is listed.
    uint out = 0u;
    uint outLevel = 0u;
    const uint level = gaussianLevelStateLevel(state.word0);
    if (lvl.fadeFrames == 0u) {
        return;
    }
    if (gaussianLevelStatePendingValid(state.word0)) {
        out = gaussianLevelStateOutCount(state.word0);
        outLevel = level;
    } else if (gaussianLevelStateFading(state, lvl.frameIndex, lvl.fadeFrames)) {
        out = gaussianLevelStateOutCount(state.word0);
        outLevel = gaussianLevelStateOut(state.word0) - 1u;
    } else if (params.paged != 0u && drawable != 0u && level != 0u && lvl.fadeFrames != 0u
               && res.fadeFromRank == 0u && (lvl.frameIndex - res.arrivalFrame) < lvl.fadeFrames
               && (available & (1u << level)) != 0u) {
        // The fine head landed on a chunk drawn coarse: the coarse level is the outgoing window.
        out = level == 1u ? m1 : m2;
        outLevel = level;
    }
    if (out == 0u) return;
    atomic_fetch_add_explicit(transitionSplats, out, memory_order_relaxed);
    atomic_fetch_add_explicit(visibleSplatTotal, out, memory_order_relaxed);
    const uint outSlot = atomic_fetch_add_explicit(visibleChunkTotal, 1u, memory_order_relaxed);
    GaussianVisibleChunk outgoing;
    outgoing.chunkIndex = chunkIndex | (outLevel << kGaussianVisibleChunkLevelShift) | kGaussianVisibleChunkOutgoing;
    outgoing.splatCount = out;
    outgoing.quota = out;
    outgoing.screenArea = area;
    visibleChunks[outSlot] = outgoing;
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

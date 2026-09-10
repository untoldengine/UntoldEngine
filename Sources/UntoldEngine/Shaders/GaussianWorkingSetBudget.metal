//
//  GaussianWorkingSetBudget.metal
//  UntoldEngine
//
//  Fits the frame's chunked (.untoldgs) entities to the shared working set's capacity. After
//  every chunked entity's chunk cull has added its visible splat total to the frame's
//  GaussianBudgetState — and binned every visible chunk's density into the frame's
//  GaussianBudgetDensityHistogram — and every whole-buffer entity's cull has reserved its
//  visible count, gaussianComputeBudgetScale turns the request into one density cap d — the
//  splats per view unit of screen area the frame may keep — such that the bounded grant
//  G(d) = Σ_t min(splats_t, d · area_t) over the histogram's tiers stays within the room the
//  headroom leaves of the budget after the reservation, and gaussianComputeChunkQuotas grants
//  each visible chunk its quota, the first (most important) min(splatCount, floor(d · screenArea))
//  records the bake ordered it by: a chunk sparser than the cap (near, large on screen) keeps
//  everything, a denser one (far, many splats per pixel) is cut to the cap. The frame-wide
//  scale of the uniform rule is still computed and published for the readback, and is the
//  rule when the quotas are uniform (GaussianDebugOptions.disableScreenWeightedQuotas: every
//  chunk's area is its count, so floor(d · area) is floor(scale · splatCount)). A fall of the cap
//  is taken at once (the set is already at its capacity, and a lower cap never overflows it),
//  a rise is smoothed against the previous frame's cap so a budget boundary never flickers, and
//  a frame that fits stays whole (cap +inf). Because the fused pass never reads past a chunk's
//  quota and the reservation is counted first, the atomic slot reservation in the shared set
//  never overflows; gaussianFinalizeSharedVisibleSet stays as the safety net.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "GaussianDensityTier.h"
using namespace metal;

// Zeroes the frame's request, reservation and grant counters and the density histogram before
// the entities' culls add to them: one threadgroup of gaussianBudgetDensityTierCount threads,
// thread t zeroing tier t, thread 0 also the counters and the histogram's header.
kernel void gaussianResetBudgetRequest(
    device GaussianBudgetState *state [[buffer(gaussianBudgetStateIndex)]],
    device GaussianBudgetDensityHistogram *histogram [[buffer(gaussianBudgetDensityHistogramIndex)]],
    uint index [[thread_position_in_grid]])
{
    if (index < (uint)gaussianBudgetDensityTierCount) {
        histogram->tiers[index].splats = 0u;
        histogram->tiers[index].scaledArea = 0u;
    }
    if (index != 0u) return;
    state->requestedSplats = 0u;
    state->quotaSplats = 0u;
    state->reservedSplats = 0u;
    histogram->targetDensity = 0.0f;
    histogram->fullDensity = 0.0f;
    histogram->grant = 0u;
    histogram->visibleChunks = 0u;
}

// One thread per whole-buffer entity, after its gaussianFinalizeVisibleSet on the same serial
// encoder: its visible count is appended to the shared set unbudgeted, so it is reserved out of
// the budget before the chunked entities are fitted to the rest.
kernel void gaussianReserveBudgetSplats(
    const device GaussianVisibleSet *visibleSet [[buffer(gaussianBudgetChunkSetIndex)]],
    device atomic_uint *reservedSplats [[buffer(gaussianBudgetReservedTotalIndex)]],
    uint index [[thread_position_in_grid]])
{
    if (index != 0u) return;
    atomic_fetch_add_explicit(reservedSplats, visibleSet->visibleCount, memory_order_relaxed);
}

// The bounded grant at cap `density`: Σ over the tiers of min(splats, density · area), with
// `splats` the tier's splats and `area` its scaled area over the tier's lower density
// (scaledArea / ρ_t), both loaded into thread memory once before the solve so the bisection's
// evaluations neither re-read the histogram nor re-divide. Each tier's scaled area
// over-estimates its chunks' area, so this is at least what the per-chunk rule grants at that
// cap; continuous and non-decreasing in the cap. Summed in tier order, the order
// GaussianChunkCullMath.boundedGrant sums it in.
static inline float gaussianBoundedGrant(const thread float *splats, const thread float *area, const float density)
{
    float total = 0.0f;
    for (uint tier = 0u; tier < (uint)gaussianBudgetDensityTierCount; ++tier) {
        if (splats[tier] == 0.0f) continue;
        total += min(splats[tier], density * area[tier]);
    }
    return total;
}

// One thread, after every entity's request and reservation is in. First the scale of the
// uniform rule, as before: the chunked request is fitted to what the whole-buffer entities
// leave of the budget with the headroom — target = 1 while it fits, else that room over the
// request (0 when nothing is left) — with its hysteresis against the previous frame's scale (a
// fall at once, a rise by at most max(maxStepFraction · previous, minStep)); the first frame,
// the first after a frame without splat entities, and a frame with no chunked request take the
// target as is, and with the budget switched off every chunk keeps its whole count.
//
// Then the density cap the weighted quotas apply. The grant is the request when the frame fits,
// else the room itself (never scale · request, so a request that falls faster than the scale
// climbs cannot dip the grant). A fitting frame's target cap is +inf ("whole"); a frame with no
// room targets 0; otherwise 24 bisection steps on log2 of the cap between 2^-16 and the density
// at which every chunk is whole find the largest cap whose bounded grant stays within the grant
// — the lower endpoint of the last interval, so G(target) <= grant in this same arithmetic. The
// cap's hysteresis mirrors the scale's: a fall is taken at once (fewer splats never overflow a
// set already at capacity; the cut lands on the densest chunks first), and whole stays whole
// at once; a rise climbs by at most max(maxStepFraction · previous, densityMinStepFraction ·
// target) per frame, never past the target. Toward an infinite target the climb density stands
// in for it: the floor of the tier above the densest tiers holding together at most
// kGaussianBudgetDensityClimbTail of the request — not the full density, which a single sliver
// of a chunk in the guard band (or a forced chunk no view keeps) sets orders of magnitude above
// every other chunk's density and whose 5 % would take them all to whole in one frame — and a
// climb toward a fitting frame becomes whole once it reaches the climb density, so a chunk
// still climbing never pops and the pop of the tail, the smallest chunks on screen, is bounded
// to that fraction of the request. A previous cap of zero climbs like any other (as the scale
// climbs from zero: a chunked entity that drew nothing beside a whole-buffer entity that filled
// the set fades in when room appears, it does not pop in). The frames that take the scale's
// target take the cap's too. With uniform quotas the cap is the scale itself (+inf when the
// scale is 1), no solve, so the per-chunk rule reproduces floor(scale · splatCount) byte for
// byte. The solve is recorded in the histogram's header for the readback.
kernel void gaussianComputeBudgetScale(
    device GaussianBudgetState *state [[buffer(gaussianBudgetStateIndex)]],
    constant GaussianBudgetScaleConstants &constants [[buffer(gaussianBudgetScaleConstantsIndex)]],
    device GaussianBudgetDensityHistogram *histogram [[buffer(gaussianBudgetDensityHistogramIndex)]],
    uint index [[thread_position_in_grid]])
{
    if (index != 0u) return;

    const uint requested = state->requestedSplats;
    const uint reserved = state->reservedSplats;
    const uint frameCount = state->frameCount;
    // The request fits when it is within what the reservation leaves of the budget; only a
    // truncated frame aims for the headroom's share, so a scene that exactly fills the set
    // keeps every splat.
    const uint available = constants.budget > reserved ? constants.budget - reserved : 0u;
    const bool fits = constants.forceUnitScale != 0u || requested <= available;
    const float room = max(constants.headroom * (float)constants.budget - (float)reserved, 0.0f);
    float target = 1.0f;
    if (!fits) {
        target = min(1.0f, room / (float)requested);
    }
    // With no chunked request nothing is drawn under the scale, so nothing can pop: the frame
    // takes the target rather than fading a scale nobody sees.
    const bool takeTarget = frameCount == 0u || constants.forceUnitScale != 0u || constants.resetHysteresis != 0u || requested == 0u;
    float scale = target;
    if (!takeTarget) {
        const float previous = clamp(state->scale, 0.0f, 1.0f);
        if (target > previous) {
            const float step = max(previous * constants.maxStepFraction, constants.minStep);
            scale = min(target, previous + step);
        }
    }
    state->budget = constants.budget;
    state->targetScale = target;
    state->scale = clamp(scale, 0.0f, 1.0f);
    state->frameCount = frameCount + 1u;

    // The grant and the density cap.
    const uint grant = fits ? requested : (uint)room;
    float targetDensity;
    float fullDensity;
    float cap;
    if (constants.uniformQuotas != 0u) {
        const float uniformScale = state->scale;
        cap = (uniformScale < 1.0f) ? uniformScale : INFINITY;
        targetDensity = INFINITY;
        fullDensity = INFINITY;
    } else {
        // The tiers once into thread memory: the splats as floats and the area each tier's
        // scaled area stands for, so the solve's evaluations are register arithmetic.
        float splats[gaussianBudgetDensityTierCount];
        float area[gaussianBudgetDensityTierCount];
        int highestTier = -1;
        for (uint tier = 0u; tier < (uint)gaussianBudgetDensityTierCount; ++tier) {
            const GaussianBudgetDensityTier entry = histogram->tiers[tier];
            splats[tier] = (float)entry.splats;
            area[tier] = entry.splats == 0u ? 0.0f : (float)entry.scaledArea / gaussianDensityTierFloor(tier);
            if (entry.splats != 0u) highestTier = (int)tier;
        }
        const bool anyChunk = highestTier >= 0;
        fullDensity = anyChunk ? gaussianDensityTierFloor((uint)(highestTier + 1)) : INFINITY;
        // The climb density: down from the top, the tiers that together hold at most the tail
        // of the request are left to the whole (GaussianChunkCullMath.climbDensity).
        const uint tail = (uint)(kGaussianBudgetDensityClimbTail * (float)requested);
        int climbTier = highestTier;
        uint tailSplats = 0u;
        while (climbTier >= 0) {
            const uint tierSplats = histogram->tiers[climbTier].splats;
            if (tailSplats + tierSplats > tail) break;
            tailSplats += tierSplats;
            --climbTier;
        }
        const float climbDensity = anyChunk ? gaussianDensityTierFloor((uint)(climbTier + 1)) : INFINITY;

        const bool whole = requested == 0u || fits;
        if (whole) {
            targetDensity = INFINITY;
        } else if (grant == 0u || !anyChunk) {
            targetDensity = 0.0f;
        } else {
            const float grantValue = (float)grant;
            float lo = -16.0f;
            float hi = log2(fullDensity);
            if (gaussianBoundedGrant(splats, area, exp2(lo)) > grantValue) {
                targetDensity = 0.0f;
            } else {
                for (uint step = 0u; step < 24u; ++step) {
                    const float mid = (lo + hi) * 0.5f;
                    if (gaussianBoundedGrant(splats, area, exp2(mid)) <= grantValue) {
                        lo = mid;
                    } else {
                        hi = mid;
                    }
                }
                targetDensity = exp2(lo);
            }
        }

        // A previous cap that is not a number at or above zero takes the target (a guard: the
        // state never holds one); zero itself climbs by the step like any other cap.
        const float previousCap = state->densityCap;
        if (takeTarget || !(previousCap >= 0.0f) || targetDensity <= previousCap) {
            cap = targetDensity;   // a fall at once; whole stays whole
        } else {
            const float stepTarget = whole ? climbDensity : targetDensity;
            const float step = max(previousCap * constants.maxStepFraction, constants.densityMinStepFraction * stepTarget);
            cap = min(previousCap + step, targetDensity);
            if (whole && cap >= climbDensity) {
                cap = INFINITY;   // the climb toward a fitting frame arrived: every chunk is whole
            }
        }
    }
    state->densityCap = cap;
    histogram->targetDensity = targetDensity;
    histogram->fullDensity = fullDensity;
    histogram->grant = grant;
}

// One threadgroup per entity, striding over its visible chunks: quota = min(splatCount,
// floor(densityCap · screenArea)) — the whole count when the cap grants it (+inf always does),
// else the floor, never ceil, so the quotas of a frame sum to at most the bounded grant at the
// cap, which the solve kept within the headroom's share of the budget whatever the chunk size —
// written back into the visible-chunk entry the fused pass reads. Thread 0 records the
// entity's quota sum in the chunk record and adds it to the frame's state.
kernel void gaussianComputeChunkQuotas(
    device GaussianVisibleSet *chunkSet [[buffer(gaussianBudgetChunkSetIndex)]],
    device GaussianVisibleChunk *visibleChunks [[buffer(gaussianBudgetVisibleChunksIndex)]],
    const device GaussianBudgetState *state [[buffer(gaussianBudgetStateIndex)]],
    device atomic_uint *quotaTotal [[buffer(gaussianBudgetQuotaTotalIndex)]],
    uint localIndex [[thread_position_in_threadgroup]],
    uint threadsPerGroup [[threads_per_threadgroup]])
{
    threadgroup atomic_uint groupTotal;
    if (localIndex == 0u) {
        atomic_store_explicit(&groupTotal, 0u, memory_order_relaxed);
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    const float densityCap = state->densityCap;
    const uint visibleChunkCount = chunkSet->threadgroupCount;
    uint mine = 0u;
    for (uint i = localIndex; i < visibleChunkCount; i += threadsPerGroup) {
        GaussianVisibleChunk entry = visibleChunks[i];
        // +inf × area is +inf (the area is at least kGaussianScreenAreaMin), so the comparison
        // grants the whole count before any conversion of the product.
        const float granted = densityCap * entry.screenArea;
        const uint quota = (granted >= (float)entry.splatCount) ? entry.splatCount : (uint)floor(max(granted, 0.0f));
        entry.quota = quota;
        visibleChunks[i] = entry;
        mine += quota;
    }
    atomic_fetch_add_explicit(&groupTotal, mine, memory_order_relaxed);
    threadgroup_barrier(mem_flags::mem_threadgroup);

    if (localIndex == 0u) {
        const uint total = atomic_load_explicit(&groupTotal, memory_order_relaxed);
        chunkSet->visibleCount = total;
        atomic_fetch_add_explicit(quotaTotal, total, memory_order_relaxed);
    }
}

// Copies the frame's final state and density histogram into its in-flight slot for the CPU
// readback: one threadgroup of gaussianBudgetDensityTierCount threads, thread t copying tier t,
// thread 0 also the state and the histogram's header.
kernel void gaussianPublishBudgetState(
    const device GaussianBudgetState *state [[buffer(gaussianBudgetStateIndex)]],
    device GaussianBudgetState *readback [[buffer(gaussianBudgetReadbackIndex)]],
    const device GaussianBudgetDensityHistogram *histogram [[buffer(gaussianBudgetDensityHistogramIndex)]],
    device GaussianBudgetDensityHistogram *histogramReadback [[buffer(gaussianBudgetDensityReadbackIndex)]],
    uint index [[thread_position_in_grid]])
{
    if (index < (uint)gaussianBudgetDensityTierCount) {
        histogramReadback->tiers[index] = histogram->tiers[index];
    }
    if (index != 0u) return;
    *readback = *state;
    histogramReadback->targetDensity = histogram->targetDensity;
    histogramReadback->fullDensity = histogram->fullDensity;
    histogramReadback->grant = histogram->grant;
    histogramReadback->visibleChunks = histogram->visibleChunks;
}

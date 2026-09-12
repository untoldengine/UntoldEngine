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
//  Entities with per-chunk coarse levels (per-chunk-lod-tiers, GaussianChunkLevelConstants
//  .hasCoarse) fold the level rule into the same solve: the bounded request R(d) charges each
//  histogram tier's levelled chunks with their fine term, their level-1 counts or their level-2
//  counts according to the tier distance the rule evaluates at that cap, so the cap and the
//  levels share one fixed point, and gaussianComputeChunkQuotas chooses each chunk's level from
//  the solved cap, runs the two-phase switch (detect, reserve, commit) of the per-chunk level
//  state and grants the incoming and the outgoing window of a fading chunk. With hasCoarse == 0
//  every kernel here is byte for byte what it was.
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
        histogram->tiers[index].coarse1 = 0u;
        histogram->tiers[index].coarse2 = 0u;
        histogram->tiers[index].levelledSplats = 0u;
        histogram->tiers[index].levelledScaledArea = 0u;
    }
    if (index != 0u) return;
    state->requestedSplats = 0u;
    state->quotaSplats = 0u;
    state->reservedSplats = 0u;
    state->transitionSplats = 0u;
    state->coarseChunks = 0u;
    state->coarseSplats = 0u;
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

// The tiers of the histogram in thread memory, loaded once before the solve so the bisection's
// evaluations neither re-read the histogram nor re-divide: the splats as floats, the area each
// tier's scaled area stands for (scaledArea / ρ_t), and for the tiers with levelled chunks the
// listed splats of those chunks, their own scaled area and the coarse counts — each population
// with its own over-estimated area, so the bound is one-sided for each.
struct GaussianBudgetTiers {
    float splats[gaussianBudgetDensityTierCount];
    float area[gaussianBudgetDensityTierCount];
    float levelled[gaussianBudgetDensityTierCount];
    float levelledArea[gaussianBudgetDensityTierCount];
    float coarse1[gaussianBudgetDensityTierCount];
    float coarse2[gaussianBudgetDensityTierCount];
};

// The bounded request at cap `density`: Σ over the tiers of min(splats, density · area) for the
// chunks without a coarse level — the bounded grant of the screen-weighted quotas, byte for byte
// when no tier holds a levelled chunk — plus, for a tier's levelled chunks, the term of the
// regime the level rule picks at that cap: k = tier(min(density, floor)) against the tier t,
// fine (min(levelled, density · levelledArea)) while k ≥ t − s1 − 1 — one tier more than the
// rule's own threshold, so density · levelledArea is at least the level-1 count of every chunk
// of the tier whatever its density inside the tier (the area of a chunk of density below √2 ρ_t
// is at least n / (√2 ρ_t)) — level 1's counts while k ≥ t − s2 − 1, level 2's counts below.
// Each population's scaled area over-estimates its chunks' area and every levelled chunk is
// listed with at least its level-1 count, so this is at least what the per-chunk rules grant at
// that cap (the min over a population is at least the sum of the per-chunk mins; the hysteresis
// only ever holds a chunk coarser) and non-decreasing in the cap: the fine term is floored at
// the level-1 counts, which changes nothing in a tier whose chunks lie within its density bounds
// and keeps the last tier — where every density above 2^29.5 clamps and the area bound does not
// hold — from dipping below the level-1 regime it leaves. Summed in tier order, fine-only term
// first, the order GaussianChunkCullMath.boundedRequest sums it in.
static inline float gaussianBoundedRequest(const thread GaussianBudgetTiers &tiers, const float density, const float densityFloor, const uint tierShift1, const uint tierShift2)
{
    const int k = (int)gaussianDensityTier(min(density, densityFloor));
    const int s1 = (int)tierShift1;
    const int s2 = (int)tierShift2;
    float total = 0.0f;
    for (uint tier = 0u; tier < (uint)gaussianBudgetDensityTierCount; ++tier) {
        if (tiers.splats[tier] == 0.0f) continue;
        if (tiers.levelled[tier] == 0.0f) {
            total += min(tiers.splats[tier], density * tiers.area[tier]);
            continue;
        }
        const float fineOnly = tiers.splats[tier] - tiers.levelled[tier];
        if (fineOnly > 0.0f) {
            total += min(fineOnly, density * (tiers.area[tier] - tiers.levelledArea[tier]));
        }
        const int delta = k - (int)tier;
        if (delta >= -s1 - 1) {
            total += max(min(tiers.levelled[tier], density * tiers.levelledArea[tier]), tiers.coarse1[tier]);
        } else if (delta >= -s2 - 1) {
            total += tiers.coarse1[tier];
        } else {
            total += tiers.coarse2[tier];
        }
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

    // The outgoing windows of fading chunks are inside the request (the culls listed them) and
    // reserved in transitionSplats: the solve fits the incoming entries to what they leave.
    const uint listed = state->requestedSplats;
    const uint transition = min(state->transitionSplats, listed);
    const uint requested = listed - transition;
    const uint reserved = state->reservedSplats;
    const uint frameCount = state->frameCount;
    // The request fits when the whole of it — the outgoing windows are drawn too — is within
    // what the reservation leaves of the budget; only a truncated frame aims for the headroom's
    // share, so a scene that exactly fills the set keeps every splat. A frame that fits without
    // its windows but not with them is truncated: the incoming entries are fitted to the room
    // the windows leave, so the set never overflows while a switch fades.
    const uint available = constants.budget > reserved ? constants.budget - reserved : 0u;
    const bool fits = constants.forceUnitScale != 0u || listed <= available;
    const float room = max(constants.headroom * (float)constants.budget - (float)reserved - (float)transition, 0.0f);
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
        // scaled area stands for, so the solve's evaluations are register arithmetic; the
        // levelled share of each tier beside them (all zero without coarse levels).
        GaussianBudgetTiers tiers;
        int highestTier = -1;
        for (uint tier = 0u; tier < (uint)gaussianBudgetDensityTierCount; ++tier) {
            const GaussianBudgetDensityTier entry = histogram->tiers[tier];
            tiers.splats[tier] = (float)entry.splats;
            tiers.area[tier] = entry.splats == 0u ? 0.0f : (float)entry.scaledArea / gaussianDensityTierFloor(tier);
            const uint levelled = min(entry.levelledSplats, entry.splats);
            tiers.levelled[tier] = (float)levelled;
            tiers.levelledArea[tier] = levelled == 0u ? 0.0f : (float)min(entry.levelledScaledArea, entry.scaledArea) / gaussianDensityTierFloor(tier);
            tiers.coarse1[tier] = (float)entry.coarse1;
            tiers.coarse2[tier] = (float)entry.coarse2;
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
            if (gaussianBoundedRequest(tiers, exp2(lo), constants.densityFloor, constants.tierShift1, constants.tierShift2) > grantValue) {
                targetDensity = 0.0f;
            } else {
                for (uint step = 0u; step < 24u; ++step) {
                    const float mid = (lo + hi) * 0.5f;
                    if (gaussianBoundedRequest(tiers, exp2(mid), constants.densityFloor, constants.tierShift1, constants.tierShift2) <= grantValue) {
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

// The fine quota of a chunk at the cap: min(splatCount, floor(densityCap · screenArea)) — the
// whole count when the cap grants it (+inf × area is +inf, the area is at least
// kGaussianScreenAreaMin, so the comparison grants the whole count before any conversion of the
// product), else the floor, never ceil, so the quotas of a frame sum to at most the bounded
// grant at the cap. The same rule grants a coarse level its count.
static inline uint gaussianLevelQuota(const float densityCap, const float screenArea, const uint splatCount)
{
    const float granted = densityCap * screenArea;
    return (granted >= (float)splatCount) ? splatCount : (uint)floor(max(granted, 0.0f));
}

// One threadgroup per entity, striding over its visible chunks: quota = min(splatCount,
// floor(densityCap · screenArea)) — the whole count when the cap grants it (+inf always does),
// else the floor, never ceil, so the quotas of a frame sum to at most the bounded grant at the
// cap, which the solve kept within the headroom's share of the budget whatever the chunk size —
// written back into the visible-chunk entry the fused pass reads. Thread 0 records the
// entity's quota sum in the chunk record and adds it to the frame's state.
//
// An entity with coarse levels (lvl.hasCoarse != 0; off under uniformQuotas and in the
// fine-only mode) chooses each listed chunk's level here, from the same cap: the incoming entry
// evaluates the level rule (GaussianDensityTier.h) against the chunk's level state, runs the
// two-phase switch — a level that differs from the drawn one is recorded as pending and the old
// level's draw capped at the new level's count (what the solve charged); next frame, once the
// cull has listed and reserved the outgoing window, the switch commits: the old level becomes
// the outgoing window, the new one the level, switchFrame the fade's clock; a fine head that
// arrived within the fade window on a chunk drawn coarse commits at once with the coarse level
// outgoing from the arrival frame — writes the level into the entry's tag bits, the level's
// quota (fine: on the resident ranks; coarse: on its count) and the state (the one writer per
// chunk). The outgoing entry the cull appended derives its quota from the same pre-commit state
// and the same rule: the window's count when the switch commits or the fade is running, 0
// otherwise. The two entries of one chunk may run on different threads (or on one thread in
// either order), so the pass runs in two strides over the list with a device-memory barrier
// between them — every outgoing entry first, reading the state no thread has written yet, then
// the incoming entries with their writes — and the grant never depends on the slots the cull's
// atomics handed out. Thread 0 also adds the entries drawn coarse and their quota sum to the
// state for the readback.
kernel void gaussianComputeChunkQuotas(
    device GaussianVisibleSet *chunkSet [[buffer(gaussianBudgetChunkSetIndex)]],
    device GaussianVisibleChunk *visibleChunks [[buffer(gaussianBudgetVisibleChunksIndex)]],
    const device GaussianBudgetState *state [[buffer(gaussianBudgetStateIndex)]],
    device atomic_uint *quotaTotal [[buffer(gaussianBudgetQuotaTotalIndex)]],
    device GaussianChunkLevelState *levelState [[buffer(gaussianBudgetLevelStateIndex)]],
    const device GaussianChunkResidency *residency [[buffer(gaussianBudgetResidencyIndex)]],
    const device GaussianChunkDecodeConstants *coarseTable [[buffer(gaussianBudgetCoarseTableIndex)]],
    constant GaussianChunkLevelConstants &lvl [[buffer(gaussianBudgetLevelConstantsIndex)]],
    const device GaussianChunkDecodeConstants *chunks [[buffer(gaussianBudgetChunkTableIndex)]],
    device atomic_uint *levelTotals [[buffer(gaussianBudgetLevelTotalsIndex)]],
    uint localIndex [[thread_position_in_threadgroup]],
    uint threadsPerGroup [[threads_per_threadgroup]])
{
    threadgroup atomic_uint groupTotal;
    threadgroup atomic_uint groupCoarseChunks;
    threadgroup atomic_uint groupCoarseSplats;
    if (localIndex == 0u) {
        atomic_store_explicit(&groupTotal, 0u, memory_order_relaxed);
        atomic_store_explicit(&groupCoarseChunks, 0u, memory_order_relaxed);
        atomic_store_explicit(&groupCoarseSplats, 0u, memory_order_relaxed);
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    const float densityCap = state->densityCap;
    const uint visibleChunkCount = chunkSet->threadgroupCount;
    const bool levels = lvl.hasCoarse != 0u && lvl.uniformQuotas == 0u && lvl.levelMode != (uint)gaussianChunkLevelModeFineOnly;
    uint mine = 0u;
    uint myCoarseChunks = 0u;
    uint myCoarseSplats = 0u;
    // Pass 0 (levels only): the outgoing entries, from the pre-commit state. Pass 1: the
    // incoming entries (every entry without levels), the one writer of the state.
    for (uint pass = levels ? 0u : 1u; pass < 2u; ++pass) {
        if (pass == 1u && levels) {
            threadgroup_barrier(mem_flags::mem_device);
        }
        for (uint i = localIndex; i < visibleChunkCount; i += threadsPerGroup) {
            GaussianVisibleChunk entry = visibleChunks[i];
            if (!levels) {
                entry.quota = gaussianLevelQuota(densityCap, entry.screenArea, entry.splatCount);
                visibleChunks[i] = entry;
                mine += entry.quota;
                continue;
            }

            const uint chunkIndex = entry.chunkIndex & kGaussianVisibleChunkIndexMask;
            const bool outgoing = (entry.chunkIndex & kGaussianVisibleChunkOutgoing) != 0u;
            if (outgoing != (pass == 0u)) continue;
            const GaussianChunkDecodeConstants chunk = chunks[chunkIndex];
            const uint m1 = coarseTable[chunkIndex].splatCount;
            const uint m2 = lvl.hasCoarse >= 2u ? coarseTable[lvl.chunkCount + chunkIndex].splatCount : m1;
            GaussianChunkResidency res = { chunk.splatCount, chunk.splatCount, 0u, 3u };
            if (lvl.paged != 0u) {
                res = residency[chunkIndex];
            }
            const uint resident = min(res.residentRanks, chunk.splatCount);
            const uint available = gaussianLevelAvailability(resident != 0u, res.coarseAvailable, m1, m2, lvl.hasCoarse);
            const GaussianChunkLevelState previous = levelState[chunkIndex];
            const uint level = gaussianLevelStateLevel(previous.word0);
            const uint wanted = gaussianChunkLevel(densityCap, lvl.densityFloor, (float)chunk.splatCount, entry.screenArea,
                                                   level, available, lvl.tierShift1, lvl.tierShift2, lvl.levelMode);
            // The quota of each level at this cap: fine on the resident ranks, a coarse level on its count.
            const uint fineQuota = gaussianLevelQuota(densityCap, entry.screenArea, resident);
            const uint quota1 = gaussianLevelQuota(densityCap, entry.screenArea, m1);
            const uint quota2 = gaussianLevelQuota(densityCap, entry.screenArea, m2);
            const uint quotaOfLevel = level == 0u ? fineQuota : (level == 1u ? quota1 : quota2);
            const uint quotaOfWanted = wanted == 0u ? fineQuota : (wanted == 1u ? quota1 : quota2);
            const bool pendingValid = gaussianLevelStatePendingValid(previous.word0);
            const uint pending = gaussianLevelStatePending(previous.word0);
            const bool fading = gaussianLevelStateFading(previous, lvl.frameIndex, lvl.fadeFrames);
            // A fine head that landed within the fade window on a chunk drawn coarse, now wanted
            // fine — with no switch pending and no fade running, the predicate the cull listed the
            // window by (a head landing inside a coarse-to-coarse fade goes through the detect and
            // commit path instead, with the window the cull reserved).
            const bool headArrival = !pendingValid && !fading && lvl.paged != 0u && resident != 0u && level != 0u && wanted == 0u
                && lvl.fadeFrames != 0u && res.fadeFromRank == 0u && (lvl.frameIndex - res.arrivalFrame) < lvl.fadeFrames
                && (available & (1u << level)) != 0u;

            if (outgoing) {
                // The window the cull listed from the same pre-commit state (pass 0: no incoming
                // entry has written it yet): granted when the switch it anticipates commits (or the
                // fade runs), zero otherwise. Never writes the state.
                uint quota = 0u;
                if (pendingValid) {
                    quota = wanted == pending ? min(entry.splatCount, gaussianLevelStateOutCount(previous.word0)) : 0u;
                } else if (fading) {
                    quota = min(entry.splatCount, gaussianLevelStateOutCount(previous.word0));
                } else if (headArrival) {
                    quota = min(entry.splatCount, level == 1u ? m1 : m2);
                }
                entry.quota = quota;
                visibleChunks[i] = entry;
                mine += quota;
                continue;
            }

            GaussianChunkLevelState next = previous;
            uint drawn = level;
            uint quota;
            if (pendingValid && wanted == pending) {
                // Commit: the cull listed and reserved the outgoing window this frame.
                next.word0 = gaussianLevelStateWord(wanted, level + 1u, 0u, false, gaussianLevelStateOutCount(previous.word0));
                next.switchFrame = lvl.frameIndex;
                drawn = wanted;
                quota = quotaOfWanted;
            } else if (pendingValid && wanted == level) {
                // The rule flipped back before the commit: nothing changes.
                next.word0 = gaussianLevelStateWord(level, gaussianLevelStateOut(previous.word0), 0u, false, gaussianLevelStateOutCount(previous.word0));
                quota = quotaOfLevel;
            } else if (headArrival) {
                // Commit at once, the coarse level outgoing on the arrival's own clock.
                next.word0 = gaussianLevelStateWord(0u, level + 1u, 0u, false, level == 1u ? m1 : m2);
                next.switchFrame = res.arrivalFrame;
                drawn = 0u;
                quota = fineQuota;
            } else if (wanted != level) {
                // Detect (or replace a pending that the cap moved past): the old level keeps drawing,
                // capped at the new level's count when the new one is coarser — what the solve
                // charged — and a fade still running is cut, its slot is the new window's.
                const uint outCount = min(quotaOfLevel, quotaOfWanted);
                next.word0 = gaussianLevelStateWord(level, 0u, wanted, true, outCount);
                quota = wanted > level ? outCount : quotaOfLevel;
            } else {
                quota = quotaOfLevel;
            }
            levelState[chunkIndex] = next;
            entry.chunkIndex = chunkIndex | (drawn << kGaussianVisibleChunkLevelShift);
            entry.quota = quota;
            visibleChunks[i] = entry;
            mine += quota;
            if (drawn != 0u) {
                myCoarseChunks += 1u;
                myCoarseSplats += quota;
            }
        }
    }
    atomic_fetch_add_explicit(&groupTotal, mine, memory_order_relaxed);
    if (levels) {
        atomic_fetch_add_explicit(&groupCoarseChunks, myCoarseChunks, memory_order_relaxed);
        atomic_fetch_add_explicit(&groupCoarseSplats, myCoarseSplats, memory_order_relaxed);
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    if (localIndex == 0u) {
        const uint total = atomic_load_explicit(&groupTotal, memory_order_relaxed);
        chunkSet->visibleCount = total;
        atomic_fetch_add_explicit(quotaTotal, total, memory_order_relaxed);
        if (levels) {
            atomic_fetch_add_explicit(&levelTotals[1], atomic_load_explicit(&groupCoarseChunks, memory_order_relaxed), memory_order_relaxed);
            atomic_fetch_add_explicit(&levelTotals[2], atomic_load_explicit(&groupCoarseSplats, memory_order_relaxed), memory_order_relaxed);
        }
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

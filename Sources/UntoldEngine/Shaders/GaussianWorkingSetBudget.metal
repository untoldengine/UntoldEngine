//
//  GaussianWorkingSetBudget.metal
//  UntoldEngine
//
//  Fits the frame's chunked (.untoldgs) entities to the shared working set's capacity. After
//  every chunked entity's chunk cull has added its visible splat total to the frame's
//  GaussianBudgetState and every whole-buffer entity's cull has reserved its visible count,
//  gaussianComputeBudgetScale turns the request into one scale — the fraction of each visible
//  chunk's splats the frame may keep in what the reservation leaves of the budget — and
//  gaussianComputeChunkQuotas grants each visible chunk its quota, the first (most important)
//  floor(scale · splatCount) records the bake ordered it by. A fall of the scale is taken at
//  once (the set is already at its capacity, and a lower scale never overflows it), a rise is
//  smoothed against the previous frame's scale so a budget boundary never flickers. Because the
//  fused pass never reads past a chunk's quota and the reservation is counted first, the atomic
//  slot reservation in the shared set never overflows; gaussianFinalizeSharedVisibleSet stays
//  as the safety net.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
using namespace metal;

// Zeroes the frame's request, reservation and grant counters before the entities' culls add
// to them.
kernel void gaussianResetBudgetRequest(
    device GaussianBudgetState *state [[buffer(gaussianBudgetStateIndex)]],
    uint index [[thread_position_in_grid]])
{
    if (index != 0u) return;
    state->requestedSplats = 0u;
    state->quotaSplats = 0u;
    state->reservedSplats = 0u;
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

// One thread, after every entity's request and reservation is in: the chunked request is fitted
// to what the whole-buffer entities leave of the budget with the headroom — target = 1 while
// it fits, else that room over the request (0 when nothing is left). A target below the
// previous frame's scale is taken at once: the set is already at its capacity, so a lower scale
// can never overflow it, and a lagging scale would grant more than the set holds, dropping
// splats by arrival order for several frames. A target above the previous scale is approached
// by at most max(maxStepFraction · previous, minStep) per frame, so a step in the budget or a
// turn to a sparser view fades the chunks back in over several frames instead of flipping the
// visible set. The first frame, the first after a frame without splat entities, and a frame
// with no chunked request take the target as is. With the budget switched off every chunk
// keeps its whole count.
kernel void gaussianComputeBudgetScale(
    device GaussianBudgetState *state [[buffer(gaussianBudgetStateIndex)]],
    constant GaussianBudgetScaleConstants &constants [[buffer(gaussianBudgetScaleConstantsIndex)]],
    uint index [[thread_position_in_grid]])
{
    if (index != 0u) return;

    const uint requested = state->requestedSplats;
    const uint reserved = state->reservedSplats;
    // The request fits when it is within what the reservation leaves of the budget; only a
    // truncated frame aims for the headroom's share, so a scene that exactly fills the set
    // keeps every splat.
    const uint available = constants.budget > reserved ? constants.budget - reserved : 0u;
    float target = 1.0f;
    if (constants.forceUnitScale == 0u && requested > available) {
        const float room = max(constants.headroom * (float)constants.budget - (float)reserved, 0.0f);
        target = min(1.0f, room / (float)requested);
    }
    // With no chunked request nothing is drawn under the scale, so nothing can pop: the frame
    // takes the target rather than fading a scale nobody sees.
    float scale = target;
    if (state->frameCount > 0u && constants.forceUnitScale == 0u && constants.resetHysteresis == 0u && requested > 0u) {
        const float previous = clamp(state->scale, 0.0f, 1.0f);
        if (target > previous) {
            const float step = max(previous * constants.maxStepFraction, constants.minStep);
            scale = min(target, previous + step);
        }
    }
    state->budget = constants.budget;
    state->targetScale = target;
    state->scale = clamp(scale, 0.0f, 1.0f);
    state->frameCount += 1u;
}

// One threadgroup per entity, striding over its visible chunks: quota = floor(scale ·
// splatCount) — never above the count, and floor rather than ceil so the quotas of a frame sum
// to at most headroom · budget whatever the chunk size — written back into the visible-chunk
// entry the fused pass reads. Thread 0 records the entity's quota sum in the chunk record and
// adds it to the frame's state.
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

    const float scale = state->scale;
    const uint visibleChunkCount = chunkSet->threadgroupCount;
    uint mine = 0u;
    for (uint i = localIndex; i < visibleChunkCount; i += threadsPerGroup) {
        GaussianVisibleChunk entry = visibleChunks[i];
        uint quota = entry.splatCount;
        if (scale < 1.0f) {
            quota = min(entry.splatCount, (uint)floor(scale * (float)entry.splatCount));
        }
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

// Copies the frame's final state into its in-flight slot for the CPU readback.
kernel void gaussianPublishBudgetState(
    const device GaussianBudgetState *state [[buffer(gaussianBudgetStateIndex)]],
    device GaussianBudgetState *readback [[buffer(gaussianBudgetReadbackIndex)]],
    uint index [[thread_position_in_grid]])
{
    if (index != 0u) return;
    *readback = *state;
}

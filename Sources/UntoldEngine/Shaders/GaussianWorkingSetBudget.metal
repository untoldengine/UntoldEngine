//
//  GaussianWorkingSetBudget.metal
//  UntoldEngine
//
//  Fits the frame's chunked (.untoldgs) entities to the shared working set's capacity. After
//  every entity's chunk cull has added its visible splat total to the frame's GaussianBudgetState,
//  gaussianComputeBudgetScale turns the total into one scale — the fraction of each visible
//  chunk's splats the frame may keep — smoothed against the previous frame's so a budget
//  boundary never flickers, and gaussianComputeChunkQuotas grants each visible chunk its quota,
//  the first (most important) floor(scale · splatCount) records the bake ordered it by. Because
//  the fused pass never reads past a chunk's quota, the atomic slot reservation in the shared set
//  cannot overflow once the scale has settled; gaussianFinalizeSharedVisibleSet stays as the
//  safety net while it moves.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
using namespace metal;

// Zeroes the frame's request and grant counters before the entities' chunk culls add to them.
kernel void gaussianResetBudgetRequest(
    device GaussianBudgetState *state [[buffer(gaussianBudgetStateIndex)]],
    uint index [[thread_position_in_grid]])
{
    if (index != 0u) return;
    state->requestedSplats = 0u;
    state->quotaSplats = 0u;
}

// One thread, after every chunked entity's request is in: target = 1 while the request fits the
// budget, else headroom · budget / requested; then the scale applied this frame moves from the
// previous frame's by at most maxStepFraction of it in either direction (the first frame takes
// the target as is), so a step in the budget or in what the camera sees converges over several
// frames instead of flipping the visible set. With the budget switched off every chunk keeps
// its whole count.
kernel void gaussianComputeBudgetScale(
    device GaussianBudgetState *state [[buffer(gaussianBudgetStateIndex)]],
    constant GaussianBudgetScaleConstants &constants [[buffer(gaussianBudgetScaleConstantsIndex)]],
    uint index [[thread_position_in_grid]])
{
    if (index != 0u) return;

    const uint requested = state->requestedSplats;
    float target = 1.0f;
    if (constants.forceUnitScale == 0u && requested > constants.budget) {
        target = min(1.0f, constants.headroom * (float)constants.budget / (float)requested);
    }
    float scale = target;
    if (state->frameCount > 0u && constants.forceUnitScale == 0u) {
        const float previous = clamp(state->scale, 0.0f, 1.0f);
        const float step = max(previous * constants.maxStepFraction, 1.0e-4f);
        scale = clamp(target, previous - step, previous + step);
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

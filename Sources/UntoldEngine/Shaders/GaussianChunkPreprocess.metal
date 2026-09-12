//
//  GaussianChunkPreprocess.metal
//  UntoldEngine
//
//  The per-frame pass of a .untoldgs entity whose 16-byte core records stay resident: one
//  threadgroup per visible chunk (indirect from the entity's chunk record) walks the first
//  `quota` splats of the chunk — the bake orders each chunk by importance, so these are the
//  ones worth keeping — and for each one decodes the record with the chunk's constants exactly
//  as gaussianDecodeChunks does, tests the centre the way gaussianFrustumCull does (against
//  either eye in stereo), evaluates the spherical harmonics by original index, and projects and
//  appends a GaussianWorkingSetSplat record and depth key into the frame's shared working set
//  exactly as gaussianPreprocess does. The last fifth of a truncated chunk's quota fades its
//  opacity linearly to zero by rank, so a moving cut never pops. For a paged entity
//  (cull.paged != 0) the records live in a page pool of 256-rank tiers: the rank is mapped to
//  its pool record through this slot's page table, the chunk's quota is bounded by its
//  resident ranks, and a tier that arrived within the last fadeFrames frames fades in. For an
//  entity with per-chunk coarse levels (lvl.hasCoarse != 0, per-chunk-lod-tiers) the entry's
//  tag bits name the level it draws: a coarse level reads its merged records from the entity's
//  coarse record buffer with the level's own decode constants, DC colour only, no page table;
//  a fading chunk's two entries — the incoming window and the outgoing one — are drawn at the
//  coverage-preserving weights 1 − (1 − α)^w and 1 − (1 − α)^(1 − w), w counted from the
//  switch frame, so the surface they both cover keeps its transmittance 1 − α through the fade.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
#include "GaussianDensityTier.h"
using namespace metal;

// The fraction of a truncated chunk's quota over which opacity fades toward the cut: ranks in
// [0.8·quota, quota) scale from full opacity down to nearly none. Mirrored by
// gaussianOpacityBandFraction (Swift) for the tests.
constant float kGaussianOpacityBandFraction = 0.8f;

// The opacity multiplier of rank `rank` in a chunk granted `quota` of its `splatCount` splats: 1
// for a chunk kept whole and for every rank before the band, then linear from 1 at the band's
// first rank down to 1/(bandLength) at the last kept rank, so consecutive ranks differ by one
// step and the cut itself is at zero.
inline float gaussianOpacityBandFactor(uint rank, uint quota, uint splatCount)
{
    if (quota >= splatCount) return 1.0f;
    const uint bandStart = (uint)(kGaussianOpacityBandFraction * (float)quota);
    if (rank < bandStart || quota <= bandStart) return 1.0f;
    return (float)(quota - rank) / (float)(quota - bandStart);
}

// The per-splat test of a chunked entity: exactly the whole-buffer kernel's in mono (the same
// head-centre matrices, the same arithmetic, so the set kept is identical), and in stereo the
// centre passes if either eye's view-projection keeps it — a splat only one eye sees is drawn.
// The HZB is the mono pyramid built from the last eye drawn (eye 1), so only eye 1's test
// samples it: eye 0's clip test alone decides for eye 0, else a splat in eye 0's margin would
// be tested against depth eye 1 saw ~6 cm to the side and pop out near depth edges.
inline bool gaussianChunkSplatPassesCull(
    float3 position,
    constant Uniforms &uniforms,
    constant GaussianChunkCullConstants &params,
    texture2d<float, access::sample> hzbDepthPyramid)
{
    if (params.viewCount <= 1u) {
        return gaussianSplatPassesCull(position, uniforms, params.clipGuardBand, params.hzbReverseZ, params.hzbOcclusionBias, params.hzbValid, hzbDepthPyramid);
    }
    const float4 local = float4(position, 1.0f);
    if (gaussianClipCentrePassesCull(params.viewProjection0 * local, params.clipGuardBand, params.hzbReverseZ, params.hzbOcclusionBias, 0u, hzbDepthPyramid)) {
        return true;
    }
    return gaussianClipCentrePassesCull(params.viewProjection1 * local, params.clipGuardBand, params.hzbReverseZ, params.hzbOcclusionBias, params.hzbValid, hzbDepthPyramid);
}

kernel void gaussianChunkDecodePreprocess(
    const device uint4                        *packed        [[buffer(gaussianChunkPreprocessPackedIndex)]],
    const device GaussianChunkDecodeConstants *chunks        [[buffer(gaussianChunkPreprocessChunkTableIndex)]],
    const device GaussianVisibleChunk         *visibleChunks [[buffer(gaussianChunkPreprocessVisibleChunksIndex)]],
    constant Uniforms                         &uniforms      [[buffer(gaussianChunkPreprocessUniformIndex)]],
    constant GaussianChunkCullConstants       &cull          [[buffer(gaussianChunkPreprocessCullConstantsIndex)]],
    constant float2                           &viewport      [[buffer(gaussianChunkPreprocessViewportIndex)]],
    const device uchar                        *shCoefficients [[buffer(gaussianChunkPreprocessSHIndex)]],
    constant GaussianSHMetadata               &shMetadata    [[buffer(gaussianChunkPreprocessSHMetadataIndex)]],
    constant float3                           &localCameraPosition [[buffer(gaussianChunkPreprocessLocalCameraIndex)]],
    constant GaussianPreprocessEntityConstants &entity       [[buffer(gaussianChunkPreprocessEntityConstantsIndex)]],
    device GaussianWorkingSetSplat            *workingSet    [[buffer(gaussianChunkPreprocessWorkingSetIndex)]],
    device uint64_t                           *sharedKeys    [[buffer(gaussianChunkPreprocessSharedKeysIndex)]],
    device atomic_uint                        *sharedVisibleCount [[buffer(gaussianChunkPreprocessSharedVisibleSetIndex)]],
    const device GaussianChunkResidency       *residency     [[buffer(gaussianChunkPreprocessResidencyIndex)]],
    const device uint                         *pageTable     [[buffer(gaussianChunkPreprocessPageTableIndex)]],
    constant GaussianChunkPagingConstants     &paging        [[buffer(gaussianChunkPreprocessPagingConstantsIndex)]],
    const device uint4                        *coarseRecords [[buffer(gaussianChunkPreprocessCoarseRecordsIndex)]],
    const device GaussianChunkDecodeConstants *coarseTable   [[buffer(gaussianChunkPreprocessCoarseTableIndex)]],
    const device GaussianChunkLevelState      *levelState    [[buffer(gaussianChunkPreprocessLevelStateIndex)]],
    constant GaussianChunkLevelConstants      &lvl           [[buffer(gaussianChunkPreprocessLevelConstantsIndex)]],
    texture2d<float, access::sample>          hzbDepthPyramid [[texture(gaussianChunkPreprocessHZBDepthPyramidTextureIndex)]],
    uint chunkSlot                                           [[threadgroup_position_in_grid]],
    uint localIndex                                          [[thread_position_in_threadgroup]],
    uint threadsPerGroup                                     [[threads_per_threadgroup]])
{
    // A faded-out entity (cross-fade at zero, or hidden) contributes nothing to the frame.
    if (entity.opacityScale <= 0.0f) {
        return;
    }
    const GaussianVisibleChunk visibleChunk = visibleChunks[chunkSlot];
    // The entry's tag bits (an entity with coarse levels; none otherwise): the level this entry
    // draws and whether it is the outgoing window of a fading chunk.
    const bool levels = lvl.hasCoarse != 0u && cull.uniformQuotas == 0u && lvl.levelMode != (uint)gaussianChunkLevelModeFineOnly;
    const uint chunkIndex = visibleChunk.chunkIndex & kGaussianVisibleChunkIndexMask;
    const uint level = levels ? ((visibleChunk.chunkIndex & kGaussianVisibleChunkLevelMask) >> kGaussianVisibleChunkLevelShift) : 0u;
    const bool outgoing = levels && (visibleChunk.chunkIndex & kGaussianVisibleChunkOutgoing) != 0u;
    // The level's own decode constants: the fine row, or the coarse row of the level.
    const GaussianChunkDecodeConstants chunk = level == 0u ? chunks[chunkIndex] : coarseTable[(level - 1u) * cull.chunkCount + chunkIndex];
    // A whole-resident entity: every rank resident, nothing fading. A paged one: this slot's
    // residency of the chunk (the cull already bounded the quota by it). A coarse level is
    // resident whole and never fades by rank.
    GaussianChunkResidency res = { chunk.splatCount, chunk.splatCount, 0u, 0u };
    if (cull.paged != 0u && level == 0u) {
        res = residency[chunkIndex];
    }
    const uint quota = min(visibleChunk.quota, min(chunk.splatCount, res.residentRanks));
    const uint pageRow = chunkIndex * paging.pagesPerChunk;
    const uint rankMask = (1u << paging.ranksPerPageLog2) - 1u;
    // The cross-fade weight of a fading chunk's windows: the incoming at w, the outgoing at
    // 1 − w, w counted from the switch frame; 1 (no blend) for every other entry.
    float weight = 1.0f;
    if (levels && lvl.fadeFrames != 0u) {
        const GaussianChunkLevelState state = levelState[chunkIndex];
        if (outgoing || gaussianLevelStateOut(state.word0) != 0u) {
            weight = clamp((float)(lvl.frameIndex - state.switchFrame + 1u) / (float)lvl.fadeFrames, 0.0f, 1.0f);
            if (outgoing) weight = 1.0f - weight;
        }
    }

    const float3 aabbMin = float3(chunk.aabbMinX, chunk.aabbMinY, chunk.aabbMinZ);
    const float3 aabbMax = float3(chunk.aabbMaxX, chunk.aabbMaxY, chunk.aabbMaxZ);
    const float logScaleRange = chunk.logScaleMax - chunk.logScaleMin;

    for (uint rank = localIndex; rank < quota; rank += threadsPerGroup) {
        uint splatIndex;
        uint4 record;
        if (level != 0u) {
            // A coarse level: its records as stored in the entity's coarse buffer, no page table.
            splatIndex = chunk.firstSplat + rank;
            record = coarseRecords[splatIndex];
        } else if (cull.paged != 0u) {
            // The rank's tier through the page table; under the prefix invariant every tier
            // below residentRanks is mapped, the test is defensive.
            const uint page = pageTable[pageRow + (rank >> paging.ranksPerPageLog2)];
            if (page == kGaussianPageSlotInvalid) {
                continue;
            }
            splatIndex = (page << paging.ranksPerPageLog2) | (rank & rankMask);
            record = packed[splatIndex];
        } else {
            splatIndex = chunk.firstSplat + rank;
            record = packed[splatIndex];
        }

        // The decode, word for word gaussianDecodeChunks (Gaussians.metal): the positions are
        // bit-identical to what the whole-buffer path loaded, and the covariance and colour
        // pass through half precision the way EncodedGaussianSplat stores them.
        const float3 centerLocal = mix(aabbMin, aabbMax, gaussianUnpack11_10_11(record.x));
        if (!gaussianChunkSplatPassesCull(centerLocal, uniforms, cull, hzbDepthPyramid)) {
            continue;
        }

        float4 centerView = uniforms.modelViewMatrix * float4(centerLocal, 1.0);
        float4 centerClip = uniforms.projectionMatrix * centerView;
        if (centerClip.w <= 0.0f) {
            continue;
        }

        float4 quaternion = gaussianUnpackRotation(record.y);
        float3 scale = exp(chunk.logScaleMin + gaussianUnpack11_10_11(record.z) * logScaleRange);
        if (logScaleRange <= 0.0f) {
            scale = float3(exp(chunk.logScaleMin));
        }
        float3x3 rotation = gaussianRotationMatrix(quaternion);
        float3x3 transform = float3x3(rotation[0] * scale.x, rotation[1] * scale.y, rotation[2] * scale.z);
        float3x3 covariance = transform * transpose(transform);
        const half3 covA = half3(half(covariance[0][0]), half(covariance[1][0]), half(covariance[2][0]));
        const half3 covB = half3(half(covariance[1][1]), half(covariance[2][1]), half(covariance[2][2]));

        const uint rgba = record.w;
        const half4 colorAndOpacity = half4(float4(
            float((rgba >> 24u) & 0xFFu) / 255.0f,
            float((rgba >> 16u) & 0xFFu) / 255.0f,
            float((rgba >> 8u) & 0xFFu) / 255.0f,
            float(rgba & 0xFFu) / 255.0f
        ));

        // From here on gaussianPreprocess, for the head-centre view.
        float3x3 cov3D = float3x3(
            float(covA.x), float(covA.y), float(covA.z),
            float(covA.y), float(covB.x), float(covB.y),
            float(covA.z), float(covB.y), float(covB.z)
        );
        float3 cov2D = computeCov2D(float4(centerLocal, 1.0),
                                    cov3D,
                                    uniforms.modelViewMatrix,
                                    uniforms.projectionMatrix,
                                    viewport);

        // Computed here (before sizing the quad, not just before writing the record) so a
        // truncated chunk's fading tail — gaussianOpacityBandFactor ramping toward zero near
        // the cut — shrinks its quad the same way any other low-opacity splat does; see
        // gaussianAdaptiveSigma (Gaussians.metal).
        // An arriving tier of a paged entity fades in over fadeFrames executed frames, counted
        // from its arrival tick, so the same residency and tick give the same image.
        float fade = 1.0f;
        if (cull.paged != 0u && level == 0u && paging.fadeFrames != 0u && rank >= res.fadeFromRank) {
            fade = clamp((float)(paging.frameIndex - res.arrivalFrame + 1u) / (float)paging.fadeFrames, 0.0f, 1.0f);
        }
        const float fullOpacity = float(colorAndOpacity.w) * entity.opacityScale
            * gaussianOpacityBandFactor(rank, quota, chunk.splatCount);
        float opacity = fullOpacity * fade;
        // The level cross-fade (coverage-preserving, GaussianDensityTier.h): a fading chunk's
        // incoming window at w, its outgoing one at 1 − w. Fine ranks still fading in from their
        // arrival over an outgoing coarse window take the same power law on the arrival's ramp —
        // a fine head arriving over a coarse level fades in at 1 − (1 − α)^fade while the coarse
        // window fades out at 1 − (1 − α)^(1 − w) on the same clock, so the surface both cover
        // keeps its transmittance — and never brighter than either clock allows; the arrival
        // fade of a chunk with no window fading stays the linear ramp of the paging.
        if (weight < 1.0f) {
            opacity = (outgoing || fade >= 1.0f)
                ? gaussianCoverageWeight(opacity, weight)
                : gaussianCoverageWeight(fullOpacity, min(weight, fade));
        }
        float sigma = gaussianAdaptiveSigma(opacity);

        float2 axis1 = float2(0.0f);
        float2 axis2 = float2(0.0f);
        bool valid = true;
        float3 conic = computeInverseCovarianceConic(cov2D, sigma, axis1, axis2, valid);
        if (!valid || (axis1.x == 0.0f && axis1.y == 0.0f) || (axis2.x == 0.0f && axis2.y == 0.0f)) {
            continue;
        }

        // Reserve a slot in the frame's shared working set. Past its capacity the splat is
        // dropped; gaussianFinalizeSharedVisibleSet clamps the count and records the overflow.
        // The quotas are fitted below the capacity less the whole-buffer entities' counts, and
        // the scale never lags above its target, so this does not happen in practice.
        uint slot = atomic_fetch_add_explicit(sharedVisibleCount, 1u, memory_order_relaxed);
        if (slot >= entity.workingSetCapacity) {
            continue;
        }

        float3 color;
        if (entity.debugColorEnabled != 0u) {
            color = entity.debugColor.xyz;
        } else if (level != 0u) {
            // A coarse record carries the DC colour only.
            color = gaussianSRGBToLinear(float3(colorAndOpacity.xyz));
        } else {
            color = gaussianSRGBToLinear(evaluateGaussianSphericalHarmonics(
                float3(colorAndOpacity.xyz),
                shCoefficients,
                shMetadata,
                splatIndex,
                centerLocal - localCameraPosition
            ));
        }
        if (paging.debugMode == 1u) {
            // Residency tint: green for a whole chunk, red for a head-only one.
            const float resident = (float)res.residentRanks / (float)max(chunk.splatCount, 1u);
            color = mix(float3(1.0f, 0.15f, 0.1f), float3(0.1f, 1.0f, 0.2f), resident);
        }
        if (levels && lvl.debugTint != 0u) {
            // Level tint: white fine, yellow level 1, red level 2 (over the residency tint).
            color = level == 0u ? float3(1.0f) : (level == 1u ? float3(1.0f, 0.85f, 0.1f) : float3(1.0f, 0.15f, 0.1f));
        }
        GaussianWorkingSetSplat out;
        out.positionAndEntity = float4(centerLocal, as_type<float>(entity.entityIndex));
        out.conicAndOpacity = float4(conic, opacity);
        out.color = float4(color * entity.colorGain.xyz, 0.0f);
        out.axes = float4(axis1, axis2);
        workingSet[slot] = out;

        // Depth key for the one sort across every entity: eye-space depth of the centre in the
        // head-centre view, front to back, with the slot in the low word.
        float depth = max(-centerView.z, 0.0f);
        sharedKeys[slot] = ((uint64_t)float_to_sortable_u32(depth) << 32) | (uint64_t)slot;
    }
}

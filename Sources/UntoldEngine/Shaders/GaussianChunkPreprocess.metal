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
//  opacity linearly to zero by rank, so a moving cut never pops.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
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
    const GaussianChunkDecodeConstants chunk = chunks[visibleChunk.chunkIndex];
    const uint quota = min(visibleChunk.quota, chunk.splatCount);

    const float3 aabbMin = float3(chunk.aabbMinX, chunk.aabbMinY, chunk.aabbMinZ);
    const float3 aabbMax = float3(chunk.aabbMaxX, chunk.aabbMaxY, chunk.aabbMaxZ);
    const float logScaleRange = chunk.logScaleMax - chunk.logScaleMin;

    for (uint rank = localIndex; rank < quota; rank += threadsPerGroup) {
        const uint splatIndex = chunk.firstSplat + rank;
        const uint4 record = packed[splatIndex];

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
        const float opacity = float(colorAndOpacity.w) * entity.opacityScale
            * gaussianOpacityBandFactor(rank, quota, chunk.splatCount);
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

        float3 color = entity.debugColorEnabled != 0u
            ? entity.debugColor.xyz
            : gaussianSRGBToLinear(evaluateGaussianSphericalHarmonics(
                float3(colorAndOpacity.xyz),
                shCoefficients,
                shMetadata,
                splatIndex,
                centerLocal - localCameraPosition
            ));
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

//
//  HZBOcclusion.h
//  UntoldEngine
//
//  Conservative box-versus-HZB occlusion test shared by the mesh cull (HZBCompute.metal,
//  hzbCullVisibleEntities) and the Gaussian chunk cull (GaussianChunkCull.metal,
//  gaussianChunkCull): project the box to a screen rect, pick the mip whose texel covers the
//  rect, sample a dense grid over it and compare the box's nearest depth with the farthest
//  depth found. One implementation so the two culls accept and reject the same boxes.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#ifndef HZBOcclusion_h
#define HZBOcclusion_h

#include <metal_stdlib>
using namespace metal;

/// Projects the box `center ± extent` through `viewProjection` and returns its screen rect
/// (UV, y down) and nearest depth. Returns false — treat as visible — when a corner is behind
/// the camera, the rect misses the screen or degenerates to a line.
static inline bool projectAABBToScreenRect(
    const float3 center,
    const float3 extent,
    constant float4x4 &viewProjection,
    const bool reverseZ,
    thread float2 &uvMinOut,
    thread float2 &uvMaxOut,
    thread float &nearDepthOut
) {
    float minX = 1.0;
    float minY = 1.0;
    float maxX = -1.0;
    float maxY = -1.0;
    float minZ = 1.0;
    float maxZ = 0.0;

    for (uint i = 0u; i < 8u; ++i) {
        float3 corner = center;
        corner.x += ((i & 1u) != 0u) ? extent.x : -extent.x;
        corner.y += ((i & 2u) != 0u) ? extent.y : -extent.y;
        corner.z += ((i & 4u) != 0u) ? extent.z : -extent.z;

        float4 clip = viewProjection * float4(corner, 1.0);
        if (clip.w <= 0.0) {
            return false;
        }

        float3 ndc = clip.xyz / clip.w;
        minX = min(minX, ndc.x);
        minY = min(minY, ndc.y);
        maxX = max(maxX, ndc.x);
        maxY = max(maxY, ndc.y);
        minZ = min(minZ, ndc.z);
        maxZ = max(maxZ, ndc.z);
    }

    if (maxX < -1.0 || minX > 1.0 || maxY < -1.0 || minY > 1.0) {
        return false;
    }

    float2 uvMin;
    float2 uvMax;
    uvMin.x = clamp(minX * 0.5 + 0.5, 0.0, 1.0);
    uvMax.x = clamp(maxX * 0.5 + 0.5, 0.0, 1.0);
    uvMin.y = clamp(1.0 - (maxY * 0.5 + 0.5), 0.0, 1.0);
    uvMax.y = clamp(1.0 - (minY * 0.5 + 0.5), 0.0, 1.0);

    if ((uvMax.x - uvMin.x) <= 1e-6 || (uvMax.y - uvMin.y) <= 1e-6) {
        return false;
    }

    uvMinOut = uvMin;
    uvMaxOut = uvMax;
    nearDepthOut = clamp(reverseZ ? maxZ : minZ, 0.0, 1.0);
    return true;
}

/// True when the rect `uvMin..uvMax` whose nearest depth is `nearDepth` lies behind the HZB
/// everywhere it is sampled. The mip is the one whose texel spans the rect; a 5x5 grid across
/// the rect keeps porous occluders (window frames, glass assemblies) from falsely culling what
/// shows through them, and the farthest sample (nearest for reverse-Z) is the depth compared.
static inline bool hzbRectIsOccluded(
    texture2d<float, access::sample> hzbDepthPyramid,
    const float2 uvMin,
    const float2 uvMax,
    const float nearDepth,
    const float2 viewport,
    const uint mipCount,
    const bool reverseZ,
    const float occlusionBias
) {
    float rectWidth = max(1.0, (uvMax.x - uvMin.x) * viewport.x);
    float rectHeight = max(1.0, (uvMax.y - uvMin.y) * viewport.y);
    float rectMaxDim = max(rectWidth, rectHeight);

    uint mipLevel = 0u;
    if (mipCount > 1u) {
        mipLevel = min((uint)floor(log2(rectMaxDim)), mipCount - 1u);
    }

    constexpr sampler pointSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
    const float lod = float(mipLevel);

    float hzbDepth = reverseZ ? 1.0 : 0.0;
    for (uint y = 0u; y < 5u; ++y) {
        const float ty = float(y) * 0.25;
        for (uint x = 0u; x < 5u; ++x) {
            const float tx = float(x) * 0.25;
            const float2 uv = mix(uvMin, uvMax, float2(tx, ty));
            const float sampleDepth = hzbDepthPyramid.sample(pointSampler, uv, level(lod)).x;
            hzbDepth = reverseZ ? min(hzbDepth, sampleDepth) : max(hzbDepth, sampleDepth);
        }
    }

    return reverseZ
        ? (nearDepth < hzbDepth - occlusionBias)
        : (nearDepth > hzbDepth + occlusionBias);
}

#endif /* HZBOcclusion_h */

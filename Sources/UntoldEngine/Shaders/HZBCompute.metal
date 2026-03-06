//
//  HZBCompute.metal
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"

using namespace metal;

struct HZBVisibleEntity {
    float4 center;
    float4 halfExtent;
    uint index;
    uint version;
    uint pad0;
    uint pad1;
};

kernel void hzbBuildDepthPyramid(
    constant uint &mipLevel [[buffer(hzbBuildPassMipLevelIndex)]],
    constant uint2 &sourceDimensions [[buffer(hzbBuildPassSourceDimensionsIndex)]],
    constant uint &reverseZ [[buffer(hzbBuildPassReverseZIndex)]],
    depth2d<float, access::sample> depthTexture [[texture(hzbBuildPassDepthTextureIndex)]],
    texture2d<float, access::read> sourceMipTexture [[texture(hzbBuildPassSourceMipTextureIndex)]],
    texture2d<float, access::write> destMipTexture [[texture(hzbBuildPassDestMipTextureIndex)]],
    uint2 gid [[thread_position_in_grid]]
) {
    const uint2 destDimensions = uint2(destMipTexture.get_width(), destMipTexture.get_height());
    if (gid.x >= destDimensions.x || gid.y >= destDimensions.y) {
        return;
    }

    float depth = (reverseZ != 0u) ? 0.0 : 1.0;

    if (mipLevel == 0u) {
        if (gid.x >= sourceDimensions.x || gid.y >= sourceDimensions.y) {
            return;
        }

        constexpr sampler pointSampler(coord::pixel, address::clamp_to_edge, filter::nearest);
        depth = depthTexture.sample(pointSampler, float2(gid) + 0.5);
    } else {
        const uint2 sourceMax = sourceDimensions - 1u;
        const uint2 base = gid * 2u;

        const uint2 p0 = uint2(min(base.x, sourceMax.x), min(base.y, sourceMax.y));
        const uint2 p1 = uint2(min(base.x + 1u, sourceMax.x), min(base.y, sourceMax.y));
        const uint2 p2 = uint2(min(base.x, sourceMax.x), min(base.y + 1u, sourceMax.y));
        const uint2 p3 = uint2(min(base.x + 1u, sourceMax.x), min(base.y + 1u, sourceMax.y));

        const float d0 = sourceMipTexture.read(p0).x;
        const float d1 = sourceMipTexture.read(p1).x;
        const float d2 = sourceMipTexture.read(p2).x;
        const float d3 = sourceMipTexture.read(p3).x;

        if (reverseZ != 0u) {
            depth = min(min(d0, d1), min(d2, d3));
        } else {
            depth = max(max(d0, d1), max(d2, d3));
        }
    }

    destMipTexture.write(depth, gid);
}

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

kernel void hzbCullVisibleEntities(
    device HZBVisibleEntity *outVisible [[buffer(hzbCullPassEntityAABBIndex)]],
    device const uint *inputVisibleCount [[buffer(hzbCullPassEntityAABBCountIndex)]],
    device const HZBVisibleEntity *inVisible [[buffer(hzbCullPassVisibilityIndex)]],
    device atomic_uint *outVisibleCount [[buffer(hzbCullPassVisibleCountIndex)]],
    constant float4x4 &viewProjection [[buffer(hzbCullPassProjectionMatrixIndex)]],
    constant float2 &viewport [[buffer(hzbCullPassViewportIndex)]],
    constant uint &mipCount [[buffer(hzbCullPassMipCountIndex)]],
    constant uint &reverseZ [[buffer(hzbCullPassReverseZIndex)]],
    texture2d<float, access::sample> hzbDepthPyramid [[texture(hzbCullPassDepthPyramidTextureIndex)]],
    uint tid [[thread_position_in_grid]]
) {
    const uint count = inputVisibleCount[0];
    if (tid >= count) {
        return;
    }

    HZBVisibleEntity candidate = inVisible[tid];

    float2 uvMin;
    float2 uvMax;
    float nearDepth;
    if (!projectAABBToScreenRect(candidate.center.xyz, candidate.halfExtent.xyz, viewProjection, reverseZ != 0u, uvMin, uvMax, nearDepth)) {
        uint dst = atomic_fetch_add_explicit(outVisibleCount, 1u, memory_order_relaxed);
        outVisible[dst] = candidate;
        return;
    }

    float rectWidth = max(1.0, (uvMax.x - uvMin.x) * viewport.x);
    float rectHeight = max(1.0, (uvMax.y - uvMin.y) * viewport.y);
    float rectMaxDim = max(rectWidth, rectHeight);

    uint mipLevel = 0u;
    if (mipCount > 1u) {
        mipLevel = min((uint)floor(log2(rectMaxDim)), mipCount - 1u);
    }

    constexpr sampler pointSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
    float d0 = hzbDepthPyramid.sample(pointSampler, float2(uvMin.x, uvMin.y), level(float(mipLevel))).x;
    float d1 = hzbDepthPyramid.sample(pointSampler, float2(uvMax.x, uvMin.y), level(float(mipLevel))).x;
    float d2 = hzbDepthPyramid.sample(pointSampler, float2(uvMin.x, uvMax.y), level(float(mipLevel))).x;
    float d3 = hzbDepthPyramid.sample(pointSampler, float2(uvMax.x, uvMax.y), level(float(mipLevel))).x;
    float hzbDepth = (reverseZ != 0u)
        ? min(min(d0, d1), min(d2, d3))
        : max(max(d0, d1), max(d2, d3));

    bool isOccluded = (reverseZ != 0u)
        ? (nearDepth < hzbDepth - 1e-4)
        : (nearDepth > hzbDepth + 1e-4);
    if (!isOccluded) {
        uint dst = atomic_fetch_add_explicit(outVisibleCount, 1u, memory_order_relaxed);
        outVisible[dst] = candidate;
    }
}

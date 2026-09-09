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
#include "HZBOcclusion.h"

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

kernel void hzbCullVisibleEntities(
    device HZBVisibleEntity *outVisible [[buffer(hzbCullPassEntityAABBIndex)]],
    device const uint *inputVisibleCount [[buffer(hzbCullPassEntityAABBCountIndex)]],
    device const HZBVisibleEntity *inVisible [[buffer(hzbCullPassVisibilityIndex)]],
    device atomic_uint *outVisibleCount [[buffer(hzbCullPassVisibleCountIndex)]],
    constant float4x4 &viewProjection [[buffer(hzbCullPassProjectionMatrixIndex)]],
    constant float2 &viewport [[buffer(hzbCullPassViewportIndex)]],
    constant uint &mipCount [[buffer(hzbCullPassMipCountIndex)]],
    constant uint &reverseZ [[buffer(hzbCullPassReverseZIndex)]],
    constant float &occlusionBias [[buffer(hzbCullPassOcclusionBiasIndex)]],
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

    // Shared with the Gaussian chunk cull — see HZBOcclusion.h.
    bool isOccluded = hzbRectIsOccluded(hzbDepthPyramid, uvMin, uvMax, nearDepth, viewport, mipCount, reverseZ != 0u, occlusionBias);
    if (!isOccluded) {
        uint dst = atomic_fetch_add_explicit(outVisibleCount, 1u, memory_order_relaxed);
        outVisible[dst] = candidate;
    }
}

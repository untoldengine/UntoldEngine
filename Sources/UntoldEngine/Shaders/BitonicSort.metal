//
//  BitonicSort.metal
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  BitonicSort.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 11/10/25.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
#include "ShadersUtils.h"
using namespace metal;


// Depth-sorting key: front-to-back or back-to-front without float->int scaling
inline uint float_to_sortable_u32(float x) {
    uint u = as_type<uint>(x);
    // Map IEEE754 to a total order in unsigned ints:
    //   negatives (sign=1)  -> flip all bits
    //   non-negatives       -> flip sign bit
    uint mask = (u >> 31) ? 0xffffffffu : 0x80000000u;
    return u ^ mask;
}

inline float eye_space_depth(const float4x4 modelView, float3 worldPos) {
    float4 v = modelView * float4(worldPos, 1.0);
    // If camera looks down -Z, nearer = smaller (-v.z); make it non-negative
    return max(-v.z, 0.0f);
}

kernel void gaussianDepthKeys(device uint64_t *outKeys              [[buffer(gaussianIndicesIndex)]],
                              const device EncodedGaussianSplat *splats [[buffer(gaussianEncodedSplatIndex)]],
                              constant uint &numOfSplats [[buffer(gaussianNumberOfSplatsIndex)]],
                              constant Uniforms &uniforms     [[buffer(gaussianUniformIndex)]],
                              uint index                              [[thread_position_in_grid]],
                              uint gridSize                           [[threads_per_grid]])
{
    if (index >= numOfSplats) return;

    // 1) Eye-space depth
    float z = eye_space_depth(uniforms.modelViewMatrix, splats[index].position);

    // 2) Convert to lexicographically sortable unsigned int
    uint keyFrontToBack = float_to_sortable_u32(z);

    // gaussian sorting
    //uint keyBackToFront = 0xffffffffu - keyFrontToBack;

    // 3) Pack [key | index] for 64-bit radix sort (key in high bits)
    uint64_t packed = (uint64_t)keyFrontToBack << 32 | (uint64_t)index;
    outKeys[index] = packed;
}

//
//  DeformOverrideCompute.metal
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
using namespace metal;

// Deformation override: one thread per overridden vertex writes the
// externally supplied position and normal over the deformed stream (after
// skinning, morphs, muscles and the ML deformer), so a simulation can own
// part of a skinned mesh, a cape on a character for one.
kernel void deformOverride(
    const device uint *indices [[buffer(deformOverrideIndicesIndex)]],
    const device simd_float4 *positions [[buffer(deformOverridePositionsIndex)]],
    const device simd_float4 *normals [[buffer(deformOverrideNormalsIndex)]],
    device simd_float4 *outPositions [[buffer(deformOverrideOutPositionIndex)]],
    device simd_float4 *outNormals [[buffer(deformOverrideOutNormalIndex)]],
    constant DeformOverrideParams &params [[buffer(deformOverrideParamsIndex)]],
    uint id [[thread_position_in_grid]])
{
    if (id >= params.count) {
        return;
    }
    const uint target = indices[id];
    outPositions[target] = simd_float4(positions[id].xyz, 1.0);
    outNormals[target] = simd_float4(normals[id].xyz, 0.0);
}

//
//  shadowShader.metal
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include <simd/simd.h>
#import "../../CShaderTypes/ShaderTypes.h"
#include "ShadersUtils.h"
#include "ShaderStructs.h"

using namespace metal;

struct VertexShadowInput {

    float3 position [[attribute(shadowPassModelPositionIndex)]];
    ushort4 jointIndices [[attribute(shadowPassJointIdIndex)]];
    float4 jointWeights [[attribute(shadowPassJointWeightsIndex)]];
};

struct VertexShadowOutput{

    float4 position [[position]];
};

vertex VertexShadowOutput vertexShadowShader(VertexShadowInput in [[stage_in]],
                                       constant Uniforms & uniforms [[ buffer(shadowPassModelUniform) ]],
                                       constant simd_float4x4 &lightOrthoView [[buffer(shadowPassLightMatrixUniform)]],
                                             constant bool &hasArmature [[buffer(shadowPassHasArmature)]],
    const device simd_float4x4 *jointMatrices [[buffer(shadowPassJointTransformIndex)]],
                                       uint vid [[vertex_id]]){

    VertexShadowOutput vertexOut;

    float4 position = float4(in.position, 1.0);
if (hasArmature) {
        float4 weights = in.jointWeights;
        ushort4 joints = in.jointIndices;

        position = (weights.x * (jointMatrices[joints.x] * position) +
                    weights.y * (jointMatrices[joints.y] * position) +
                    weights.z * (jointMatrices[joints.z] * position) +
                    weights.w * (jointMatrices[joints.w] * position));
        
    }
    vertexOut.position=lightOrthoView*(uniforms.modelMatrix*position);


    return vertexOut;
}

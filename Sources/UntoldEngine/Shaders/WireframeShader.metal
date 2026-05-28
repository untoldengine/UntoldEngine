//
//  WireframeShader.metal
//  UntoldEngine
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

vertex VertexOutWireframe vertexWireframeShader(
    VertexInModel in [[stage_in]],
    constant Uniforms &uniforms [[buffer(modelPassUniformIndex)]],
    constant bool &hasArmature [[buffer(modelPassHasArmature)]],
    const device simd_float4x4 *jointMatrices [[buffer(modelPassJointTransformIndex)]]
) {
    VertexOutWireframe out;

    float4 position = in.position;

    if (hasArmature) {
        float4 weights = in.jointWeights;
        ushort4 joints = in.jointIndices;
        position = (weights.x * (jointMatrices[joints.x] * position) +
                    weights.y * (jointMatrices[joints.y] * position) +
                    weights.z * (jointMatrices[joints.z] * position) +
                    weights.w * (jointMatrices[joints.w] * position));
    }

    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    float4 worldPosition = uniforms.modelMatrix * position;
    out.wireDistance = distance(uniforms.cameraPosition, worldPosition.xyz);

    return out;
}

fragment float4 fragmentWireframeShader(
    VertexOutWireframe in [[stage_in]],
    constant float4 &wireframeColor [[buffer(0)]],
    constant float4 &fadeParams [[buffer(1)]]
) {
    float fadeStart = fadeParams.x;
    float fadeEnd = max(fadeParams.y, fadeStart + 0.001);
    float minimumAlpha = clamp(fadeParams.z, 0.0, 1.0);
    bool fadeEnabled = fadeParams.w > 0.5;
    float fade = fadeEnabled ? 1.0 - smoothstep(fadeStart, fadeEnd, in.wireDistance) : 1.0;
    float alpha = wireframeColor.a * mix(minimumAlpha, 1.0, fade);
    return float4(wireframeColor.rgb, alpha);
}

//
//  GizmoShader.metal
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
using namespace metal;


vertex VertexOutModel vertexGizmoShader(
    VertexInModel in [[stage_in]],
    constant Uniforms &uniforms [[buffer(modelPassUniformIndex)]]) {
    VertexOutModel out;

    float4 position = in.position;

    out.vPosition = position;
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;

    return out;
}


fragment FragmentModelOut fragmentGizmoShader(VertexOutModel in [[stage_in]],
                                    constant Uniforms & uniforms [[ buffer(modelPassUniformIndex) ]],
                                 constant MaterialParametersUniform &materialParameter [[buffer(modelPassFragmentMaterialParameterIndex)]])
{

    FragmentModelOut fragmentOut;
    
    fragmentOut.color = materialParameter.baseColor;
 
    return fragmentOut;

}

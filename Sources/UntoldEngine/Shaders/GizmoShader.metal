//
//  GizmoShader.metal
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

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

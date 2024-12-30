//
//  shadowShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 1/26/24.
//

#include <metal_stdlib>
#include <simd/simd.h>
#import "../../CShaderTypes/ShaderTypes.h"
#include "ShadersUtils.h"
#include "ShaderStructs.h"

using namespace metal;

struct VertexShadowInput {

    float3 position [[attribute(shadowPassModelPositionIndex)]];

};

struct VertexShadowOutput{

    float4 position [[position]];
};

vertex VertexShadowOutput vertexShadowShader(VertexShadowInput in [[stage_in]],
                                       constant Uniforms & uniforms [[ buffer(shadowPassModelUniform) ]],
                                       constant simd_float4x4 &lightOrthoView [[buffer(shadowPassLightMatrixUniform)]],
                                       uint vid [[vertex_id]]){

    VertexShadowOutput vertexOut;

    float4 position = float4(in.position, 1.0);

    vertexOut.position=lightOrthoView*(uniforms.modelMatrix*position);


    return vertexOut;
}

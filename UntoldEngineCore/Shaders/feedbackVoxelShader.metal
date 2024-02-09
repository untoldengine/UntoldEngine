//
//  feedbackVoxelShader.metal
//  UntoldEngine3D
//
//  Created by Harold Serrano on 6/13/23.
//

#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"
#include "ShaderStructs.h"
using namespace metal;



vertex VertexOutFeedback vertexFeedbackShader(VertexFeedback in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(voxelUniform) ]]){
    VertexOutFeedback out;
    
    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    
    return out;
}

fragment float4 fragmentFeedbackShader(VertexOutFeedback in [[stage_in]],  constant Uniforms & uniforms [[ buffer(voxelUniform) ]]){
    
    
    return float4(1.0,1.0,1.0,1.0);
}


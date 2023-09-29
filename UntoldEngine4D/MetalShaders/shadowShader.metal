//
//  shadowShader.metal
//  MetalRendering
//
//  Created by Harold Serrano on 7/6/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include <simd/simd.h>
#include "U4DShaderProtocols.h"

struct VertexInput {
    
    float3 position [[attribute(positionBufferIndex)]];
    
};

struct VertexOutput{
    
    float4 position [[position]];
};

vertex VertexOutput vertexShadowShader(VertexInput in [[stage_in]],
                                       constant UniformSpace & uniforms [[ buffer(uniformSpaceBufferIndex) ]],
                                       constant simd_float4x4 &lightOrthoView [[buffer(lightOrthoViewSpaceBufferIndex)]],
                                       uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    float4 position = float4(in.position, 1.0);
    
    vertexOut.position=lightOrthoView*(uniforms.modelSpace*position);

    
    return vertexOut;
}

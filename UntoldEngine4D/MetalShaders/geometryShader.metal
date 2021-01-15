//
//  geometryShader.metal
//  MetalRendering
//
//  Created by Harold Serrano on 7/13/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include <simd/simd.h>
#include "U4DShaderProtocols.h"

struct VertexInput {
    
    float4    position [[ attribute(0) ]];
    
};

struct VertexOutput{
    
    float4 position [[position]];
    
};

vertex VertexOutput vertexGeometryShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(viSpaceBuffer)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    return vertexOut;
}

fragment float4 fragmentGeometryShader(VertexOutput vertexOut [[stage_in]], constant UniformGeometryProperty &uniformGeometryProperty [[buffer(fiGeometryBuffer)]]){
    
    return uniformGeometryProperty.lineColor;
    
}

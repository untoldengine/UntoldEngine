//
//  worldShader.metal
//  MetalRendering
//
//  Created by Harold Serrano on 7/14/17.
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
    float4 color;
};

vertex VertexOutput vertexWorldShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    float4 axisColor;
    
    //set the color of the grid
    if(vert.position.y==2 || vert.position.y==-2){
        
        axisColor=float4(0.0,1.0,0.0,0.5);
        
    }else{
        
        axisColor=float4(1.0,1.0,1.0,1.0);
        
    }
    
    
    vertexOut.position=position;
    vertexOut.color=axisColor;
    
    return vertexOut;
}

fragment float4 fragmentWorldShader(VertexOutput vertexOut [[stage_in]]){
    
    return vertexOut.color;
    
}

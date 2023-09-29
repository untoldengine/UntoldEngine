//
//  compositionShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 1/22/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "U4DShaderProtocols.h"

using namespace metal;
#include "U4DShaderHelperFunctions.h"

struct VertexCompOutput{
    
    float4 position [[position]];
    float2 uvCoords;
    
};

vertex VertexCompOutput vertexCompositeShader(constant float2 *quadVertices[[buffer(0)]], constant float2 *quadTexCoords[[buffer(1)]], uint vid [[vertex_id]]){
    
    VertexCompOutput vertexOut;
    
    vertexOut.uvCoords=quadTexCoords[vid];
    
    vertexOut.position=float4(quadVertices[vid],0.0,1.0);
    
    return vertexOut;
}

fragment float4 fragmentCompositeShader(VertexCompOutput vertexOut [[stage_in]],
                                        texture2d<float> voxelTexture[[texture(0)]],
                                        texture2d<float> compTexture[[texture(1)]]){
    
    ushort2 texelCoords=ushort2(vertexOut.uvCoords.x*voxelTexture.get_width(),vertexOut.uvCoords.y*voxelTexture.get_height());
    
    float4 color=voxelTexture.read(ushort2(texelCoords));
    
    float3 w=float3(0.2125,0.7154,0.0721);
    float lumen=dot(w,color.rgb);
    
    if(lumen>0.0){
        return color;
    }
    
    return compTexture.read(ushort2(texelCoords));
    
}





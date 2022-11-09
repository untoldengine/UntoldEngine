//
//  voronoiShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 10/29/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include <simd/simd.h>
#include "U4DShaderProtocols.h"
#include "U4DShaderHelperFunctions.h"

struct VertexInput {
    
    float4    position [[ attribute(0) ]];
    float4    normal   [[ attribute(1) ]];
    float4    uv       [[ attribute(2) ]];
    
};

struct VertexOutput{
    
    float4 position [[position]];
    float2 uvCoords;
    float4 shadowCoords;
    float3 normalVectorInMVSpace;
    float4 verticesInMVSpace;
    float4 lightPosition;
    float4 lightPositionInTangentSpace;
    float4 verticesInTangentSpace;
    int materialIndex [[flat]];
};


vertex VertexOutput vertexVoronoiShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(viSpaceBuffer)]], constant UniformGlobalData &uniformGlobalData [[buffer(viGlobalDataBuffer)]], constant UniformModelShaderProperty &uniformModelShaderProperty [[buffer(viModelShaderPropertyBuffer)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    float4 position;
    
    //1. transform the vertices by the mvp transformation
    position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.uvCoords=vert.uv.xy;
    
    vertexOut.position=position;
    
    return vertexOut;
    
}


fragment float4 fragmentVoronoiShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(fiGlobalDataBuffer)]], constant UniformModelShaderProperty &uniformModelShaderProperty [[buffer(fiModelShaderPropertyBuffer)]]){
    
    float2 st=-1.0+2.0*vertexOut.uvCoords.xy;
    
    float3 color=float3(0.0);
    st/=2.0;
    st+=float2(0.5,-0.5);
    
    int count=(int)uniformModelShaderProperty.shaderParameter[0].x;
    
    
    for(int i=0;i<count;i++){
        
        int index=i+1;
        
        float2 pointA=float2(uniformModelShaderProperty.shaderParameter[index].y,-uniformModelShaderProperty.shaderParameter[index].x);
        
        float2 pointB=float2(uniformModelShaderProperty.shaderParameter[index].w,-uniformModelShaderProperty.shaderParameter[index].z);
        
        float c=sdfLine(st,pointA,pointB);
        c=sharpen(c,0.008,uniformGlobalData.resolution);
        color+=float3(c);
    }
    
    
    return float4(color,1.0);
    
}




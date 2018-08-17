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
    
    float4    position [[ attribute(0) ]];
    float4    normal   [[ attribute(1) ]];
    float4    uv       [[ attribute(2) ]];
    float4    tangent  [[ attribute(3) ]];
    float4    materialIndex [[ attribute(4) ]];
    float4    vertexWeight [[attribute(5)]];
    float4    boneIndex [[attribute(6)]];
    
};

struct VertexOutput{
    
    float4 position [[position]];
    float4 color;
    float2 uvCoords;
    
};

vertex VertexOutput vertexShadowShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], constant UniformModelRenderFlags &uniformModelRenderFlags [[buffer(2)]], constant UniformBoneSpace &uniformBoneSpace [[buffer(3)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    float4 position;
    
    //if model has armature, compute the shadow with with armature vertices
    if(uniformModelRenderFlags.hasArmature){
        
        float4 newVertex=float4(0);
        
        int boneIndicesArray[4];
        
        boneIndicesArray[0]=vert.boneIndex.x;
        boneIndicesArray[1]=vert.boneIndex.y;
        boneIndicesArray[2]=vert.boneIndex.z;
        boneIndicesArray[3]=vert.boneIndex.w;
        
        float weightArray[4];
        
        weightArray[0]=vert.vertexWeight.x;
        weightArray[1]=vert.vertexWeight.y;
        weightArray[2]=vert.vertexWeight.z;
        weightArray[3]=vert.vertexWeight.w;
        
        for(int i=0;i<4;i++){
            
            newVertex+=(uniformBoneSpace.boneSpace[boneIndicesArray[i]]*float4(vert.position))*weightArray[i];
            
        }
        
        position=uniformSpace.lightShadowProjectionSpace*(uniformSpace.modelSpace*newVertex);
        
        //if no armature exist, then do shadow mapping as normal
    }else{
        
        position=uniformSpace.lightShadowProjectionSpace*(uniformSpace.modelSpace*float4(vert.position));
        
    }
    
    
    vertexOut.position=position;
    
    
    return vertexOut;
}

//
//  InfluenceMapShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 7/26/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
#include "../UntoldEngine4D/MetalShaders/U4DShaderProtocols.h"
#include "../UntoldEngine4D/MetalShaders/U4DShaderHelperFunctions.h"

struct VertexInput {
    
    float4    position [[ attribute(0) ]];
    float2    uv       [[ attribute(1) ]];
    
};

struct VertexOutput{
    
    float4 position [[position]];
    float4 color;
    float2 uvCoords;
    
};


vertex VertexOutput vertexInfluenceShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], constant UniformGlobalData &uniformGlobalData [[buffer(2)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    vertexOut.uvCoords=vert.uv;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    return vertexOut;
}

fragment float4 fragmentInfluenceShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(0)]], constant UniformShaderEntityProperty &uniformShaderEntityProperty [[buffer(1)]], texture2d<float> texture[[texture(0)]], sampler sam [[sampler(0)]]){
    
    float2 st=-1. + 2. * vertexOut.uvCoords;
    
    //sample the texture color
    float4 fieldTexture=texture.sample(sam,vertexOut.uvCoords.xy);
    
    float3 color =float3(0.0);
    
    //divide the field into spaces
    st*=10.0;
    
    float2 fid=fract(st);

    float2 iid=floor(st);
    
    float2 visualInfluence=float2(0.0);
    
    for(int i=0;i<441;i++){

        float2 cellPosition=float2(uniformShaderEntityProperty.shaderParameter[i].x,-uniformShaderEntityProperty.shaderParameter[i].y);
        float cellInfluence=uniformShaderEntityProperty.shaderParameter[i].z;
        float cellIsTeam=uniformShaderEntityProperty.shaderParameter[i].w;

        cellInfluence=abs(cellInfluence);

        if(iid.x==cellPosition.x && iid.y==cellPosition.y){

            visualInfluence+=float2(cellInfluence*(1.0-cellIsTeam),cellInfluence*cellIsTeam);
            
        }

    }

    color+=float3(visualInfluence.x,visualInfluence.y,0.0);
    
    //draw the lines separating the spaces
    if(fid.x<0.05 || fid.x>0.95 || fid.y<0.05 || fid.y>0.95){

        color+=float3(0.0,0.0,0.9);

    }

    
    float4 finalColor=mix(float4(color,1.0),fieldTexture,0.3);
    
    return finalColor;
    
}


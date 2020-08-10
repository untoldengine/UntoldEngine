//
//  menuSelectionShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 8/3/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include <simd/simd.h>
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

vertex VertexOutput vertexMenuSelectionShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], constant UniformGlobalData &uniformGlobalData [[buffer(2)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    vertexOut.uvCoords=vert.uv;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    return vertexOut;
}

fragment float4 fragmentMenuSelectionShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(0)]], constant UniformShaderEntityProperty &uniformShaderEntityProperty [[buffer(1)]], texture2d<float> texture[[texture(0)]], sampler sam [[sampler(0)]]){
    
    float2 st=vertexOut.uvCoords;
    
    //sample the texture color
    float4 menuTexture=texture.sample(sam,vertexOut.uvCoords.xy);
    
    float3 color =float3(0.0);
    
    st.y*=3.0;
    
    //float2 fid=fract(st);
    float2 iid=floor(st);
    
    if(iid.x==0.0 && iid.y==uniformShaderEntityProperty.shaderParameter[0].y){
    
        st=float2(1.0,0.0);
    
    }else{
        st=float2(0.0);
    }
    
    color+=float3(st,0.0);
    color*=50.0;
    //if(fid.x>0.95 || fid.y>0.95) color.r=1.0;
    
    return mix(float4(color,1.0),menuTexture,0.3);
    
}

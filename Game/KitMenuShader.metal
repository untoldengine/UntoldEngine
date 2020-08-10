//
//  KitMenuShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 8/4/20.
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

vertex VertexOutput vertexKitMenuShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], constant UniformGlobalData &uniformGlobalData [[buffer(2)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    vertexOut.uvCoords=vert.uv;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    return vertexOut;
}

fragment float4 fragmentKitMenuShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(0)]], constant UniformShaderEntityProperty &uniformShaderEntityProperty [[buffer(1)]], texture2d<float> texture[[texture(0)]], sampler sam [[sampler(0)]]){
    
    float2 st=vertexOut.uvCoords;
    
    //sample the texture color
    float4 kitMenuTexture=texture.sample(sam,vertexOut.uvCoords.xy);
    
    //discard the fragment if the alpha value less than 0.15
    if(kitMenuTexture.a<0.15){
        
        discard_fragment();
        
    }
    
    float3 color =float3(0.0);
    
    st.x*=4.0;
    
    float2 fid=fract(st);
    float2 iid=floor(st);
    
    if(iid.x==uniformShaderEntityProperty.shaderParameter[0].x && iid.y==0.0){
    
        float2 bl = step(float2(0.01),fid);       // bottom-left
        float2 tr = step(float2(0.01),1.0-fid);   // top-right

        color+=float3(1.0-bl.x * bl.y * tr.x * tr.y);
    
    }else{
        color=float3(0.0);
    }
    
    //if(fid.x>0.95 || fid.y>0.95) color.r=1.0;
    
    return max(float4(color,0.2),kitMenuTexture);
    
}


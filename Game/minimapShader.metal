//
//  minimapShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 3/24/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
#include "../UntoldEngine4D/MetalShaders/U4DShaderProtocols.h"
#include "../UntoldEngine4D/MetalShaders/U4DShaderHelperFunctions.h"

#define M_PI 3.1415926535897932384626433832795

struct VertexInput {
    
    float4    position [[ attribute(0) ]];
    float2    uv       [[ attribute(1) ]];
    
};

struct VertexOutput{
    
    float4 position [[position]];
    float4 color;
    float2 uvCoords;
    
};



vertex VertexOutput vertexMinimapShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(viSpaceBuffer)]], constant UniformGlobalData &uniformGlobalData [[buffer(viGlobalDataBuffer)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    vertexOut.uvCoords=vert.uv;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    return vertexOut;
}

fragment float4 fragmentMinimapShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(fiGlobalDataBuffer)]], constant UniformShaderEntityProperty &uniformShaderEntityProperty [[buffer(fiShaderEntityPropertyBuffer)]], texture2d<float> texture[[texture(fiTexture0)]], sampler sam [[sampler(fiSampler0)]]){
    
    float2 st = -1. + 2. * vertexOut.uvCoords;
    st.x*=-1.0;
    
    float b=abs(sdfBox(st,float2(0.5)))-0.1;
    
    float4 minimapTexture=texture.sample(sam,vertexOut.uvCoords);
    
    float2 heroPosition=float2(uniformShaderEntityProperty.shaderParameter[0].x,uniformShaderEntityProperty.shaderParameter[0].y);
    
    //Make a circle
    float soldier=sdfCircle(st+heroPosition, 0.005);
    
    soldier=sharpen(soldier,0.03,uniformGlobalData.resolution);
    
    minimapTexture=max(minimapTexture,float4(soldier)*1.0/float4(0.0,0.0,1.0,0.0));
    
    float m=0.0;
    
    for(int i=1;i<4;i++){
        
        float2 enemyPosition=float2(uniformShaderEntityProperty.shaderParameter[i].x,uniformShaderEntityProperty.shaderParameter[i].y);
        
        float enemy=sdfCircle(st+enemyPosition, 0.005);
        
        enemy=sharpen(enemy, 0.03, uniformGlobalData.resolution);
        
        m+=enemy;
        
    }
    
    minimapTexture=max(minimapTexture,float4(m)*float4(1.0,0.0,0.0,0.0));
    minimapTexture=max(minimapTexture,b);
    return minimapTexture;
    
}


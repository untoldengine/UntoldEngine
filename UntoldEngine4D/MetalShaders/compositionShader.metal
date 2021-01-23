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

//struct VertexInput {
//
//    float4    position [[ attribute(0) ]];
//    float2    uv       [[ attribute(1) ]];
//
//};

struct VertexOutput{
    
    float4 position [[position]];
    float2 uvCoords;
    
};

vertex VertexOutput vertexCompShader(constant float2 *quadVertices[[buffer(0)]], constant float2 *quadTexCoords[[buffer(1)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    vertexOut.uvCoords=quadTexCoords[vid];
    
    vertexOut.position=float4(quadVertices[vid],0.0,1.0);
    
    return vertexOut;
}

fragment float4 fragmentCompShader(VertexOutput vertexOut [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], constant UniformDirectionalLightProperties &uniformDirLightProperties [[buffer(fiDirLightPropertiesBuffer)]], constant UniformPointLightProperties *uniformPointLightProperties [[buffer(fiPointLightsPropertiesBuffer)]], constant UniformGlobalData &uniformGlobalData [[buffer(fiGlobalDataBuffer)]],  texture2d<float> albedoTexture[[texture(0)]], texture2d<float> normalTexture[[texture(1)]], texture2d<float> positionTexture[[texture(2)]], depth2d<float> shadowTexture [[texture(fiDepthTexture)]]){
    
    constexpr sampler s(min_filter::linear,mag_filter::linear);
    
    float4 albedoData=albedoTexture.sample(s,vertexOut.uvCoords);
    float4 normalData=normalTexture.sample(s,vertexOut.uvCoords);
    float4 positionData=positionTexture.sample(s,vertexOut.uvCoords);
    
    float3 baseColor=albedoData.rgb;
    
    float4 lightPosition=uniformSpace.viewSpace*uniformDirLightProperties.lightPosition;
    
    Material material;
    
    material.diffuseMaterialColor=baseColor;
    material.ambientMaterialColor=float3(1.0)*material.diffuseMaterialColor;
    
    //set the light color
    LightColor lightColor;
    lightColor.ambientColor=float3(0.5,0.5,0.5);
    lightColor.diffuseColor=uniformDirLightProperties.diffuseColor;
    lightColor.specularColor=uniformDirLightProperties.specularColor;
    
    float4 diffuseColor=computeLights(lightPosition, positionData, normalData.rgb, material, lightColor);
    
    float4 pointColor=float4(0.0,0.0,0.0,1.0);
    
    for(int i=0; i<uniformGlobalData.numberOfPointLights;i++){
        
        LightColor pointLightColor;
        
        pointLightColor.ambientColor=float3(0.5);
        pointLightColor.diffuseColor=uniformPointLightProperties[i].diffuseColor;
        
        float4 pointLightPos=uniformSpace.viewSpace*uniformPointLightProperties[i].lightPosition;
        
        pointColor+=computeLights(pointLightPos, positionData, normalData.rgb, material, pointLightColor);
        
    }
    
    //diffuseColor=mix(diffuseColor,pointColor,0.5);
    diffuseColor.a=1.0;
    
    float shadow=albedoData.a;

    if(shadow>0){
        
        diffuseColor*=shadow;
    }
    
    return diffuseColor;
    
}




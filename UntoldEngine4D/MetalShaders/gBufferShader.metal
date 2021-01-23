//
//  gBufferShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 1/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "U4DShaderProtocols.h"

using namespace metal;
#include "U4DShaderHelperFunctions.h"

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
    float2 uvCoords;
    float4 shadowCoords;
    float3 normalVectorInMVSpace;
    float4 verticesInMVSpace;
    int materialIndex [[flat]];
    
};

struct GBufferOutput{

    float4 albedo [[color(0)]];
    float4 normal [[color(1)]];
    float4 position [[color(2)]];

};

vertex VertexOutput vertexGBufferShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(viSpaceBuffer)]], constant UniformDirectionalLightProperties &uniformLightProperties [[buffer(viDirLightPropertiesBuffer)]], constant UniformModelRenderFlags &uniformModelRenderFlags [[buffer(viModelRenderFlagBuffer)]], constant UniformBoneSpace &uniformBoneSpace [[buffer(viBoneBuffer)]], constant UniformGlobalData &uniformGlobalData [[buffer(viGlobalDataBuffer)]], constant UniformModelShaderProperty &uniformModelShaderProperty [[buffer(viModelShaderPropertyBuffer)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    float4 position;
    
    float3 normalVectorInMVSpace;
    
    float4 verticesInMVSpace;
    
    //if model has armature, compute the transformation with armature vertices
    if(uniformModelRenderFlags.hasArmature){
        
        float4 newVertex=float4(0.0);
        float3 newNormal=float3(0.0);
        
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
            newNormal+=float3((uniformBoneSpace.boneSpace[boneIndicesArray[i]]*float4(float3(vert.normal.xyz),0.0))*weightArray[i]);
        }
        
        position=uniformSpace.modelViewProjectionSpace*float4(newVertex);
        
        normalVectorInMVSpace=normalize(uniformSpace.normalSpace*float3(newNormal));
        
        verticesInMVSpace=uniformSpace.modelViewSpace*float4(newVertex);
        
        //if no armature exist, then do transformation as usual
    }else{
      
        //1. transform the vertices by the mvp transformation
        position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
        
        //2. transform the normal vectors by the normal matrix space
        normalVectorInMVSpace=normalize(uniformSpace.normalSpace*float3(vert.normal.xyz));
        
        //3. transform the vertices of the surface into the Model-View Space
        verticesInMVSpace=uniformSpace.modelViewSpace*float4(vert.position);
    }
    
    
    vertexOut.uvCoords=vert.uv.xy; 
    
    vertexOut.position=position;
    
    //Pass the vertices in MV space
    vertexOut.verticesInMVSpace=verticesInMVSpace;
    
    //Pass the normal vector in MV space
    vertexOut.normalVectorInMVSpace=normalVectorInMVSpace;
    
    vertexOut.shadowCoords=(uniformLightProperties.lightShadowProjectionSpace*(uniformSpace.modelSpace*float4(vert.position)));
    
    //send the material index
    vertexOut.materialIndex=vert.materialIndex.x;
    
    return vertexOut;
    
}


fragment GBufferOutput fragmentGBufferShader(VertexOutput vertexOut [[stage_in]], constant UniformModelRenderFlags &uniformModelRenderFlags [[buffer(fiModelRenderFlagsBuffer)]], constant UniformModelMaterial &uniformModelMaterial [[buffer(fiMaterialBuffer)]],constant UniformDirectionalLightProperties &uniformLightProperties [[buffer(fiDirLightPropertiesBuffer)]] ,constant UniformShadowProperties &uniformModelShadowProperties [[buffer(fiShadowPropertiesBuffer)]], constant UniformGlobalData &uniformGlobalData [[buffer(fiGlobalDataBuffer)]], constant UniformModelShaderProperty &uniformModelShaderProperty [[buffer(fiModelShaderPropertyBuffer)]], texture2d<float> texture[[texture(fiTexture0)]], depth2d<float> shadowTexture [[texture(fiDepthTexture)]], texture2d<float> normalMaptexture[[texture(fiNormalTexture)]], sampler sam [[sampler(fiSampler0)]], sampler normalMapSam [[sampler(fiNormalSampler)]]){
    
    GBufferOutput finalColor;
    
    float4 albedo=texture.sample(sam,vertexOut.uvCoords.xy);
    
    //finalColor.albedo=float4(uniformModelMaterial.diffuseMaterialColor[vertexOut.materialIndex].xyz,1.0);
    finalColor.albedo=albedo;
    
    finalColor.normal=float4(normalize(vertexOut.normalVectorInMVSpace),1.0);
    finalColor.position=float4(vertexOut.verticesInMVSpace);
    
    constexpr sampler shadowSampler(coord::normalized, filter::linear, address::clamp_to_edge);
    
    float biasShadow=uniformModelShadowProperties.biasDepth;
    
    float3 proj=vertexOut.shadowCoords.xyz/vertexOut.shadowCoords.w;
    
    proj.xy=proj.xy*0.5+0.5;
    
    //flip the texture. Metal's texture coordinate system has its origin in the top left corner, unlike opengl where the origin is the bottom
    //left corner
    proj.y=1.0-proj.y;
    
    float visibility=1.0;
    

    //Use PCF
    for(int i=0;i<16;i++){

        if(float4(shadowTexture.sample(shadowSampler, proj.xy+poissonDisk[i]/700.0)).x-biasShadow>=proj.z){
            visibility-=0.0125;
        }
    }
    
    finalColor.albedo.a=visibility;
    
    return finalColor;

}

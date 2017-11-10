//
//  Shaders.metal
//  MetalRendering
//
//  Created by Harold Serrano on 7/2/17.
//  Copyright © 2017 Harold Serrano. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "U4DShaderProtocols.h"

using namespace metal;

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
    float4 lightPosition;
    float4 lightPositionInTangentSpace;
    float4 verticesInTangentSpace;
    int materialIndex [[flat]];
};

struct LightColor{
    
    float3 ambientColor;
    float3 diffuseColor;
    float3 specularColor;
};

struct Material{
    
    float3 ambientMaterialColor;
    float3 diffuseMaterialColor;
    float3 specularMaterialColor;
    float specularReflectionPower;
};




//
//constant Material material={
//    
//    .ambientReflection={0.1,0.1,0.1},
//    .diffuseReflection={1.0,1.0,1.0},
//    .specularReflection={1.0,1.0,1.0},
//    .specularReflectionPower=5
//    
//};

float4 computeLights(float4 uLightPosition, float4 uVerticesInMVSpace, float3 uNormalInMVSpace, Material uMaterial, LightColor uLightColor);

vertex VertexOutput vertexModelShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], constant float4 &lightPosition[[buffer(2)]], constant UniformModelRenderFlags &uniformModelRenderFlags [[buffer(3)]], constant UniformBoneSpace &uniformBoneSpace [[buffer(4)]], uint vid [[vertex_id]]){
    
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
    
    vertexOut.lightPosition=uniformSpace.viewSpace*lightPosition;
    
    //compute Normal Map
    if(uniformModelRenderFlags.enableNormalMap){
        
        //set tangent vector in model view space
        float3 tangentVectorInMVSpace=float3(normalize(uniformSpace.modelViewSpace*float4(vert.tangent.xyz,1.0)));
        
        //re-orthogonalize T with respect to N
        tangentVectorInMVSpace=normalize(tangentVectorInMVSpace-dot(tangentVectorInMVSpace,normalVectorInMVSpace)*normalVectorInMVSpace);
        
        //compute the binormal.
        float3 binormal=normalize(cross(normalVectorInMVSpace,tangentVectorInMVSpace))*vert.tangent.w;
        
        
        //Transformation matrix from model-world-view space to tangent space.
//        float3x3 tangentSpace=float3x3{{tangentVectorInMVSpace.x,tangentVectorInMVSpace.y,tangentVectorInMVSpace.z},
//                                        {binormal.x,binormal.y,binormal.z},
//                                        {normalVectorInMVSpace.x,normalVectorInMVSpace.y,normalVectorInMVSpace.z}};
//
//        
//        tangentSpace=transpose(tangentSpace);
        
        float3x3 tangentSpace=float3x3{{tangentVectorInMVSpace.x,binormal.x,normalVectorInMVSpace.x},
            {tangentVectorInMVSpace.y,binormal.y,normalVectorInMVSpace.y},
            {tangentVectorInMVSpace.z,binormal.z,normalVectorInMVSpace.z}};
        
        float4 lightPos=uniformSpace.modelViewSpace*lightPosition;
        
        vertexOut.lightPositionInTangentSpace.xyz=tangentSpace*float3(lightPos.xyz);
        
        vertexOut.verticesInTangentSpace.xyz=tangentSpace*float3(verticesInMVSpace.xyz);
        
    }
    
    
    //shadow coordinates
    if(uniformModelRenderFlags.enableShadows){
        
        vertexOut.shadowCoords=(uniformSpace.lightShadowProjectionSpace*(uniformSpace.modelSpace*float4(vert.position)));
        
        //flip the texture. Metal's texture coordinate system has its origin in the top left corner, unlike opengl where the origin is the bottom
        //left corner
        //vertexOut.shadowCoords.y=-vertexOut.shadowCoords.y;
        
    }
    
    //send the material index
    vertexOut.materialIndex=vert.materialIndex.x;
    
    return vertexOut;
    
}


fragment float4 fragmentModelShader(VertexOutput vertexOut [[stage_in]], constant UniformModelRenderFlags &uniformModelRenderFlags [[buffer(1)]], constant UniformModelMaterial &uniformModelMaterial [[buffer(2)]], constant UniformLightColor &uniformLightColor [[buffer(3)]], texture2d<float> texture[[texture(0)]], depth2d<float> shadowTexture [[texture(1)]], texture2d<float> normalMaptexture[[texture(2)]], sampler sam [[sampler(0)]], sampler normalMapSam [[sampler(1)]]){
    
    
    float4 totalLights;
    
    //Compute the material information per fragment
    
    Material material;
    
    material.diffuseMaterialColor=float3(uniformModelMaterial.diffuseMaterialColor[vertexOut.materialIndex].xyz);
    
    material.ambientMaterialColor=float3(0.1,0.1,0.1)*material.diffuseMaterialColor;
    
    material.specularMaterialColor=float3(uniformModelMaterial.specularMaterialColor[vertexOut.materialIndex].xyz);
    
    material.specularReflectionPower=float(uniformModelMaterial.specularMaterialHardness[vertexOut.materialIndex]);
    
    //set the light color
    LightColor lightColor;
    lightColor.ambientColor=float3(0.1,0.1,0.1);
    lightColor.diffuseColor=uniformLightColor.diffuseColor;
    lightColor.specularColor=uniformLightColor.specularColor;
    
    //compute Normal Map
    if(uniformModelRenderFlags.enableNormalMap){
        
        //sample the normal maptexture color
        float4 sampledNormalMapColor=texture.sample(normalMapSam,vertexOut.uvCoords.xy);
        
        totalLights=computeLights(vertexOut.lightPositionInTangentSpace, vertexOut.verticesInTangentSpace, sampledNormalMapColor.xyz, material, lightColor);
        
    }else{
    
        totalLights=computeLights(vertexOut.lightPosition, vertexOut.verticesInMVSpace, vertexOut.normalVectorInMVSpace,material, lightColor);
        
    }
    
    
    float4 finalColor;


    //set color fragment to the mix value of the shading and sampled color
        
    //enable textures
    if(uniformModelRenderFlags.hasTexture){
        
        //sample the texture color
        float4 sampledColor=texture.sample(sam,vertexOut.uvCoords.xy);
        
        //discard the fragment if the alpha value less than 0.15
        if(sampledColor.a<0.15){
            
            discard_fragment();
            
        }
        finalColor=float4(mix(sampledColor,totalLights,0.5));
        
    }else{
        
        finalColor=totalLights;
    }
    
    
    //compute shadow
    
    if(uniformModelRenderFlags.enableShadows){
        
        constexpr sampler shadowSampler(coord::normalized, filter::linear, address::clamp_to_edge);
        
        // Compute the direction of the light ray betweent the light position and the vertices of the surface
        float3 lightRayDirection=normalize(vertexOut.lightPosition.xyz-vertexOut.verticesInMVSpace.xyz);
        
        float biasShadow=0.005;
        //float biasShadow = max(0.05*(1.0 - dot(vertexOut.normalVectorInMVSpace, lightRayDirection)), 0.005);
        
        float3 proj=vertexOut.shadowCoords.xyz/vertexOut.shadowCoords.w;
        
        proj.xy=proj.xy*0.5+0.5;
        
        proj.y=1.0-proj.y;
        
        float4 shadowMap = shadowTexture.sample(shadowSampler, proj.xy);
    
        float visibility=1.0;
        
        if(shadowMap.x-biasShadow>=proj.z){
            visibility=0.8;
        }
        
        finalColor*=visibility;
        
    }
    
    return finalColor;

}


float4 computeLights(float4 uLightPosition, float4 uVerticesInMVSpace, float3 uNormalInMVSpace, Material uMaterial, LightColor uLightColor){
    
    //2. Compute the direction of the light ray betweent the light position and the vertices of the surface
    float3 lightRayDirection=normalize(uLightPosition.xyz-uVerticesInMVSpace.xyz);
    
    //3. Normalize View Vector
    float3 viewVector=normalize(-uVerticesInMVSpace.xyz);
    
    //4. Compute reflection vector
    float3 reflectionVector=reflect(-lightRayDirection,uNormalInMVSpace);
    
    //COMPUTE LIGHTS
    
    //5. compute ambient lighting
    float3 ambientLight=uLightColor.ambientColor*uMaterial.ambientMaterialColor;
    
    //6. compute diffuse intensity by computing the dot product. We obtain the maximum the value between 0 and the dot product
    float diffuseIntensity=max(0.0,dot(uNormalInMVSpace,lightRayDirection));
    
    //7. compute Diffuse Color
    float3 diffuseLight=diffuseIntensity*uLightColor.diffuseColor*uMaterial.diffuseMaterialColor;
    
    //8. compute specular lighting
    float3 specularLight=float3(0.0,0.0,0.0);
    
    if(diffuseIntensity>0.0){
        
        specularLight=uLightColor.specularColor*uMaterial.specularMaterialColor*pow(max(dot(reflectionVector,viewVector),0.0),uMaterial.specularReflectionPower);
        
    }
    
    return float4(ambientLight+diffuseLight+specularLight,1.0);
    
}




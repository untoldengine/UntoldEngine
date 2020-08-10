//
//  KitSelectionShader.metal
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


vertex VertexOutput vertexKitShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], constant float4 &lightPosition[[buffer(2)]], constant UniformModelRenderFlags &uniformModelRenderFlags [[buffer(3)]], constant UniformBoneSpace &uniformBoneSpace [[buffer(4)]], uint vid [[vertex_id]]){
    
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

        float3x3 tangentSpace=float3x3{tangentVectorInMVSpace,binormal,normalVectorInMVSpace};

        tangentSpace=transpose(tangentSpace);
        
        float4 lightPos=uniformSpace.viewSpace*lightPosition;
        
        vertexOut.lightPositionInTangentSpace.xyz=tangentSpace*float3(lightPos.xyz);
        
        vertexOut.verticesInTangentSpace.xyz=tangentSpace*float3(verticesInMVSpace.xyz);
        
    }
    
    
    //shadow coordinates
    if(uniformModelRenderFlags.enableShadows){
        
        vertexOut.shadowCoords=(uniformSpace.lightShadowProjectionSpace*(uniformSpace.modelSpace*float4(vert.position)));
        
    }
    
    //send the material index
    vertexOut.materialIndex=vert.materialIndex.x;
    
    return vertexOut;
    
}


fragment float4 fragmentKitShader(VertexOutput vertexOut [[stage_in]], constant UniformModelRenderFlags &uniformModelRenderFlags [[buffer(1)]], constant UniformModelMaterial &uniformModelMaterial [[buffer(2)]], constant UniformLightColor &uniformLightColor [[buffer(3)]],constant UniformModelShadowProperties &uniformModelShadowProperties [[buffer(4)]], constant UniformModelShaderProperty &uniformModelShaderProperty [[buffer(6)]], texture2d<float> texture[[texture(0)]], depth2d<float> shadowTexture [[texture(1)]], texture2d<float> normalMaptexture[[texture(2)]], sampler sam [[sampler(0)]], sampler normalMapSam [[sampler(1)]]){
    
    
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
        float4 sampledNormalMapColor=normalMaptexture.sample(normalMapSam,vertexOut.uvCoords.xy);
        sampledNormalMapColor = normalize(sampledNormalMapColor * 2.0 - 1.0);
        
        totalLights=computeLights(vertexOut.lightPositionInTangentSpace, vertexOut.verticesInTangentSpace, sampledNormalMapColor.xyz, material, lightColor);
        
    }else{
    
        totalLights=computeLights(vertexOut.lightPosition, vertexOut.verticesInMVSpace, vertexOut.normalVectorInMVSpace,material, lightColor);
        
    }
    
    
    float4 finalColor;


    //set color fragment to the mix value of the shading and sampled color
        
    //enable textures
    if(uniformModelRenderFlags.hasTexture){
        
        //sample the texture color
        float4 sampledTexture0Color=texture.sample(sam,vertexOut.uvCoords.xy);
        
        finalColor=float4(mix(sampledTexture0Color,totalLights,0.3));
        
    }else{
        
        finalColor=totalLights;
    }
    
    float2 st=-1.0+2.0*vertexOut.uvCoords.xy;
    float3 color=float3(0.0);
    
    st*=5.0;
    
    //float2 fid=fract(st);
    float2 iid=floor(st);
    
   if((iid.x<=-3.0 && iid.x>=-5.0)){
    
        //jersey
        if(iid.y>=-2.0 && iid.y<1){
            color.xyz+=uniformModelShaderProperty.shaderParameter[0].xyz;
            
        }else if(iid.y>-5 && iid.y<-2){ //shorts
            
            color+=uniformModelShaderProperty.shaderParameter[1].xyz;
            
        }else if(iid.y>=-5 && iid.y<=-5){ //cleats
            
            color+=uniformModelShaderProperty.shaderParameter[2].xyz;
        }else{
            color+=float3(0.0,0.0,0.0);
        }
        //socks
    }else if((iid.x>1.0 && iid.x<=4.0) && (iid.y>=-4 && iid.y<-1)){
        
        color+=uniformModelShaderProperty.shaderParameter[3].xyz;
    }else{
        
        color+=float3(0.0,0.0,0.0);
    }
    
    return mix(float4(color,1.0)*3.0,finalColor,0.8);

}

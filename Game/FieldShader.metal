//
//  FieldShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 8/6/20.
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


float sd_Circle(float2 p, float2 c, float r)
{
    return abs(r - length(p - c));
}

float sd_Line( float2 p, float2 a, float2 b)
{
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa,ba) / dot(ba,ba), 0., 1.);
    return length(pa - ba * h);
}

float sharpen_Shape(float d, float w, float2 resolution)
{
    float e = 1. / min(resolution.y , resolution.x);
    return 1. - smoothstep(-e, e, d - w);
}


vertex VertexOutput vertexFieldShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(viSpaceBuffer)]], constant UniformDirectionalLightProperties &uniformLightProperties [[buffer(viDirLightPropertiesBuffer)]], constant UniformModelRenderFlags &uniformModelRenderFlags [[buffer(viModelRenderFlagBuffer)]], constant UniformBoneSpace &uniformBoneSpace [[buffer(viBoneBuffer)]], constant UniformGlobalData &uniformGlobalData [[buffer(viGlobalDataBuffer)]], constant UniformModelShaderProperty &uniformModelShaderProperty [[buffer(viModelShaderPropertyBuffer)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    float4 position;
    
    float3 normalVectorInMVSpace;
    
    float4 verticesInMVSpace;
    
    //1. transform the vertices by the mvp transformation
    position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    //2. transform the normal vectors by the normal matrix space
    normalVectorInMVSpace=normalize(uniformSpace.normalSpace*float3(vert.normal.xyz));
    
    //3. transform the vertices of the surface into the Model-View Space
    verticesInMVSpace=uniformSpace.modelViewSpace*float4(vert.position);
    
    
    vertexOut.uvCoords=vert.uv.xy;
    
    vertexOut.position=position;
    
    //Pass the vertices in MV space
    vertexOut.verticesInMVSpace=verticesInMVSpace;
    
    //Pass the normal vector in MV space
    vertexOut.normalVectorInMVSpace=normalVectorInMVSpace;
    
    vertexOut.lightPosition=uniformSpace.viewSpace*uniformLightProperties.lightPosition;
    
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
        
        float4 lightPos=uniformSpace.viewSpace*uniformLightProperties.lightPosition;
        
        vertexOut.lightPositionInTangentSpace.xyz=tangentSpace*float3(lightPos.xyz);
        
        vertexOut.verticesInTangentSpace.xyz=tangentSpace*float3(verticesInMVSpace.xyz);
        
    }
    
    
    //shadow coordinates
    if(uniformModelRenderFlags.enableShadows){
        
        vertexOut.shadowCoords=(uniformLightProperties.lightShadowProjectionSpace*(uniformSpace.modelSpace*float4(vert.position)));
        
    }
    
    //send the material index
    vertexOut.materialIndex=vert.materialIndex.x;
    
    return vertexOut;
    
}


fragment float4 fragmentFieldShader(VertexOutput vertexOut [[stage_in]], constant UniformModelRenderFlags &uniformModelRenderFlags [[buffer(fiModelRenderFlagsBuffer)]], constant UniformModelMaterial &uniformModelMaterial [[buffer(fiMaterialBuffer)]],constant UniformDirectionalLightProperties &uniformLightProperties [[buffer(fiDirLightPropertiesBuffer)]] ,constant UniformShadowProperties &uniformModelShadowProperties [[buffer(fiShadowPropertiesBuffer)]], constant UniformGlobalData &uniformGlobalData [[buffer(fiGlobalDataBuffer)]], constant UniformModelShaderProperty &uniformModelShaderProperty [[buffer(fiModelShaderPropertyBuffer)]], texture2d<float> texture[[texture(fiTexture0)]], depth2d<float> shadowTexture [[texture(fiDepthTexture)]], texture2d<float> normalMaptexture[[texture(fiNormalTexture)]], sampler sam [[sampler(fiSampler0)]], sampler normalMapSam [[sampler(fiNormalSampler)]]){
    
    
    float4 totalLights;
    
    //Compute the material information per fragment
    
    Material material;
    
    material.diffuseMaterialColor=float3(uniformModelMaterial.diffuseMaterialColor[vertexOut.materialIndex].xyz);
    
    material.ambientMaterialColor=float3(0.1,0.1,0.1)*material.diffuseMaterialColor;
    
    material.specularMaterialColor=float3(uniformModelMaterial.specularMaterialColor[vertexOut.materialIndex].xyz);
    
    material.specularReflectionPower=float(uniformModelMaterial.specularMaterialHardness[vertexOut.materialIndex]);
    
    //set the light color
    Light lightColor;
    lightColor.ambientColor=float3(0.1,0.1,0.1);
    lightColor.diffuseColor=uniformLightProperties.diffuseColor;
    lightColor.specularColor=uniformLightProperties.specularColor;
    lightColor.energy=uniformLightProperties.energy;
    
    //compute Normal Map
    if(uniformModelRenderFlags.enableNormalMap){
        
        //sample the normal maptexture color
        float4 sampledNormalMapColor=normalMaptexture.sample(normalMapSam,vertexOut.uvCoords.xy);
        sampledNormalMapColor = normalize(sampledNormalMapColor * 2.0 - 1.0);
        
        lightColor.position=vertexOut.lightPositionInTangentSpace;
        
        totalLights=computeLightColor(vertexOut.verticesInTangentSpace, sampledNormalMapColor.xyz, material, lightColor);
        
    }else{
    
        lightColor.position=vertexOut.lightPosition;
        totalLights=computeLightColor(vertexOut.verticesInMVSpace, vertexOut.normalVectorInMVSpace,material, lightColor);
        
    }
    
    
    float4 finalColor;


    //set color fragment to the mix value of the shading and sampled color
        
    //enable textures
    if(uniformModelRenderFlags.hasTexture){
        
        //sample the texture color
        float4 sampledTexture0Color=texture.sample(sam,vertexOut.uvCoords.xy);
        
        //discard the fragment if the alpha value less than 0.15
        if(sampledTexture0Color.a<0.15){
            
            discard_fragment();
            
        }
        //finalColor=float4(mix(sampledTexture0Color,totalLights,0.3));
        finalColor=sampledTexture0Color*mix(totalLights,float4(1.0),0.7); //Let's try this combination for the final color. You can play with this.
        
    }else{
        
        finalColor=totalLights;
    }
    
    
    //compute shadow
    
    //if(uniformModelRenderFlags.enableShadows){
        
        constexpr sampler shadowSampler(coord::normalized, filter::linear, address::clamp_to_edge);
        
        // Compute the direction of the light ray betweent the light position and the vertices of the surface
        //float3 lightRayDirection=normalize(vertexOut.lightPosition.xyz-vertexOut.verticesInMVSpace.xyz);
        
        float biasShadow=uniformModelShadowProperties.biasDepth;
        //float biasShadow = max(0.01*(1.0 - dot(vertexOut.normalVectorInMVSpace, lightRayDirection)), 0.01);
        //float biasShadow=0.01*tan(acos(dot(vertexOut.normalVectorInMVSpace, -lightRayDirection)));
        //biasShadow=clamp(biasShadow,0.005,0.01);
        
        float3 proj=vertexOut.shadowCoords.xyz/vertexOut.shadowCoords.w;
        
        proj.xy=proj.xy*0.5+0.5;
        
        //flip the texture. Metal's texture coordinate system has its origin in the top left corner, unlike opengl where the origin is the bottom
        //left corner
        proj.y=1.0-proj.y;
        
        float visibility=1.0;
        
        //use normal shadow
//        float4 shadowMap = shadowTexture.sample(shadowSampler, proj.xy);
//        if(shadowMap.x-biasShadow>=proj.z){
//            visibility=0.8;
//        }

        //Use PCF
        for(int i=0;i<16;i++){

            if(float4(shadowTexture.sample(shadowSampler, proj.xy+poissonDisk[i]/700.0)).x-biasShadow>=proj.z){
                visibility-=0.0125;
            }
        }
        
        finalColor*=visibility;
        
    //}
    return finalColor;
    //add lines
//    float2 st=-1.0+2.0*vertexOut.uvCoords.xy;
//
//    float3 color=float3(0.0);
//
//
//    float2 p1=float2(uniformModelShaderProperty.shaderParameter[0].x,uniformModelShaderProperty.shaderParameter[0].y);
//
//    float2 mousePosition=float2(uniformModelShaderProperty.shaderParameter[0].z,uniformModelShaderProperty.shaderParameter[0].w);
//
//    float2 p3=p1+(mousePosition);
//
//    float c=sd_Circle(st,p1,0.009);
//    c=sharpen_Shape(c,0.001*0.6,uniformGlobalData.resolution);
//
//        //color+=float3(c);
//
//        c=sd_Circle(st,p3,0.009);
//        c=sharpen_Shape(c,0.005*0.3,uniformGlobalData.resolution);
//
//        color+=float3(c);
//
//    float l=sd_Line(st,p1,p3);
//
//        l=sharpen_Shape(l,0.005*0.3,uniformGlobalData.resolution);
//
//        color+=float3(l);
//
//    return mix(float4(color,1.0),finalColor,0.7);

}


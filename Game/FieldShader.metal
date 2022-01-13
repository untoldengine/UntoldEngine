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
    
    
        
    vertexOut.shadowCoords=(uniformLightProperties.lightShadowProjectionSpace*(uniformSpace.modelSpace*float4(vert.position)));
        
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
    
    //add lines
    float2 st=-1.0+2.0*vertexOut.uvCoords.xy;
    
    float3 color=float3(0.0);

    //divide the field into spaces
//    float2 influenceST=st;
//
//    float2 pathfinderST=st;
//
    float2 chaseBallVisualizer=st;

    float2 charactersST=st;
    
    float m=0.0;
    //[0]= player position
    //[1].x= player yaw
    //[1].y= out of bound
    //[1].z= goal
    //[2].x=Ball Position
    //[2].z=Ball position
    //[3].x=mouse position
    //[3].y=mouse position
    //[3].z=show mouse position
    //[4].x=team 0 score
    //[4].y=team 1 score
    //[4].z=clock tenth
    //[4].w=clock digit
    
    //using the mouse/keyboard
//    if(uniformModelShaderProperty.shaderParameter[3].z==1){
//
//        float2 p1=float2(-uniformModelShaderProperty.shaderParameter[0].x,uniformModelShaderProperty.shaderParameter[0].y);
//
//            float2 mousePosition=float2(-uniformModelShaderProperty.shaderParameter[3].y,uniformModelShaderProperty.shaderParameter[3].x);
//
//            float2 p3=p1+mousePosition;
//
//            //draw the mouse position ring
//            float c=sdfRing(st,p3,0.03);
//            c=sharpen(c,0.006,uniformGlobalData.resolution);
//
//            color+=float3(c);
//
//            //draw starting position of line to mouse ring
//            float2 b=p1+(p3-p1)*0.1;
//
//            //draw line to mouse ring
//            float l=sdfLine(st,b,p3);
//
//            l=sharpen(l,0.005,uniformGlobalData.resolution);
//
//            color+=float3(l);
//
//
//    }else{
        
        float2 p1=float2(uniformModelShaderProperty.shaderParameter[0].x,-uniformModelShaderProperty.shaderParameter[0].y);

        st=st+p1;
        st=rotate2d((-uniformModelShaderProperty.shaderParameter[1].x+90.0)*M_PI/180.0)*st;
        
        st*=2.0;
        
        float c=sdfRing(st,float2(0.0,0.0),0.09);
        c=sharpen(c,0.008,uniformGlobalData.resolution);

        color=float3(c);
        
        
        for(int i=0;i<4;i++){
           
            float2 lST=st;
            
            lST=rotate2d(90.0*i*M_PI/180.0)*lST;
            
            float l=sdfLine(lST,float2(0.0,0.0),float2(0.0,0.6));
            
            l=sharpen(l,0.002,uniformGlobalData.resolution);
            
            m+=l;
           
           }
            
            color=min(color,1.0-m);
            
            float2 tST=-st;

            tST.y-=0.15;

            float t=sdfTriangle(tST*24.0);
            t=sharpen(t,0.06,uniformGlobalData.resolution);

            color=max(color,float3(t));
        
    //}
    
    //start render ball indicator
    if(uniformModelShaderProperty.shaderParameter[2].z==1.0){
        
        float2 b1=float2(uniformModelShaderProperty.shaderParameter[2].x,-uniformModelShaderProperty.shaderParameter[2].y);

        chaseBallVisualizer=chaseBallVisualizer+b1;

        chaseBallVisualizer*=2.0;

        float b=sdfRing(chaseBallVisualizer,float2(0.0,0.0),0.09);
        b=sharpen(b,0.008,uniformGlobalData.resolution);

        color=max(color,float3(1.0,0.0,0.0)*b);

    }
    //end render ball indicator
    
    
    return max(float4(color,1.0),finalColor);
    
}


//
//  IndicatorDirectionShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 9/2/20.
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

float2x2 rotate2d(float _angle){
    return float2x2(cos(_angle),-sin(_angle),
                sin(_angle),cos(_angle));
}

vertex VertexOutput vertexIndicatorDirectionShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], constant float4 &lightPosition[[buffer(2)]], constant UniformModelRenderFlags &uniformModelRenderFlags [[buffer(3)]], constant UniformBoneSpace &uniformBoneSpace [[buffer(4)]], uint vid [[vertex_id]]){
    
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


fragment float4 fragmentIndicatorDirectionShader(VertexOutput vertexOut [[stage_in]], constant UniformModelRenderFlags &uniformModelRenderFlags [[buffer(1)]], constant UniformModelMaterial &uniformModelMaterial [[buffer(2)]], constant UniformLightColor &uniformLightColor [[buffer(3)]],constant UniformModelShadowProperties &uniformModelShadowProperties [[buffer(4)]], constant UniformGlobalData &uniformGlobalData [[buffer(5)]], constant UniformModelShaderProperty &uniformModelShaderProperty [[buffer(6)]], texture2d<float> texture[[texture(0)]], depth2d<float> shadowTexture [[texture(1)]], texture2d<float> normalMaptexture[[texture(2)]], sampler sam [[sampler(0)]], sampler normalMapSam [[sampler(1)]]){
    
    
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
            
            //discard the fragment if the alpha value less than 0.15
            if(sampledTexture0Color.a<0.15){
                
                discard_fragment();
                
            }
            finalColor=float4(mix(sampledTexture0Color,totalLights,0.3));
            
        }else{
            
            finalColor=totalLights;
        }
        
        
        //compute shadow
        
        if(uniformModelRenderFlags.enableShadows){
            
            constexpr sampler shadowSampler(coord::normalized, filter::linear, address::clamp_to_edge);
            
            // Compute the direction of the light ray betweent the light position and the vertices of the surface
            float3 lightRayDirection=normalize(vertexOut.lightPosition.xyz-vertexOut.verticesInMVSpace.xyz);
            
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
            
        }
        
    
    //add lines
    float2 st=-1.0+2.0*vertexOut.uvCoords.xy;
    float2 formationST=st;
    
    float3 color=float3(0.0);
    
    float m=0.0;
    
    st*=30.0;
    
    float3 playerDir=float3(uniformModelShaderProperty.shaderParameter[0].x,uniformModelShaderProperty.shaderParameter[0].y,uniformModelShaderProperty.shaderParameter[0].z);
    playerDir=normalize(playerDir);
    
    //We need to get the correct scale position for the player. So, we need to do a transformation.
    //the shader ranges from [-.5,5] and the soccer field horizonal size is 200. So, do the following (1.0/200)*stScale*2.0, which gives 0.3. Do the same for the y.
    
    float2 playerPosition=float2(uniformModelShaderProperty.shaderParameter[1].x*0.3,uniformModelShaderProperty.shaderParameter[1].y*0.45);
    
    float3 zAxis=float3(0.0,0.0,1.0);
    float3 xAxis=float3(1.0,0.0,0.0);
    
    float angle=acos(dot(playerDir,zAxis)/(length(playerDir)*length(zAxis)));
    
    if(dot(playerDir,xAxis)>=0.0){
        
        angle*=-1.0;
        
    }
    
    st-=playerPosition;
    
    st=rotate2d(angle)*st;
    
    float c=sdfCircle(st,float2(0.0,0.0),0.5);
      
    c=sharpen(c,0.06,uniformGlobalData.resolution);
      
    color=float3(c);
      
    for(int i=0;i<4;i++){
      
       float2 lST=st;
       
       lST=rotate2d(90.0*i*M_PI/180.0)*lST;
       
       float l=sdfLine(lST,float2(0.0,0.0),float2(0.0,0.6));
       
       l=sharpen(l,0.02,uniformGlobalData.resolution);
       
       m+=l;
      
    }
       
    color=min(color,1.0-m);
       
    float2 tST=st;
       
    tST.y-=0.7;
       
    float t=sdfTriangle(tST*8.0);
    t=sharpen(t,0.06,uniformGlobalData.resolution);
       
    color=max(color,t);
    
    //Render Team formation
    formationST*=30.0;
    
    float horLine=sdfLine(formationST-playerPosition,float2(-10.0,0.0),float2(10.0,0.0));

    horLine=sharpen(horLine,0.02,uniformGlobalData.resolution);

    color=max(color,float3(horLine)*float3(1.0,0.0,0.0));

    //Vertical line

    float verLine=sdfLine(formationST-playerPosition,float2(0.0,-10.0),float2(0.0,10.0));

    verLine=sharpen(verLine,0.02,uniformGlobalData.resolution);

    color=max(color,float3(verLine)*float3(1.0,0.0,0.0));

    //circle
    
    
    m=0.0;

    for(int i=2;i<=4;i++){

        float2 playerFormation=float2(uniformModelShaderProperty.shaderParameter[i].x*0.3,uniformModelShaderProperty.shaderParameter[i].y*0.45);

    float mRing=sdfCircle(formationST,float2(playerFormation.x,playerFormation.y),0.5);

        mRing=sharpen(mRing,0.06,uniformGlobalData.resolution);

        m+=mRing;

    }

    color=max(color,m);
    
    return finalColor=max(float4(color,1.0),finalColor);
    
}


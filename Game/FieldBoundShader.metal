//
//  FieldBoundShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 8/21/20.
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



float3 arrow(float2 st,float2 resolution){

    st.y*=-1.0;
    //arrow
        float c=sdfRing(st,float2(0.0,0.0),0.3);
  c=sharpen(c,0.06,resolution);
  
  float s=1.0-step(0.0,st.y);
  c*=s;
  
  float t=sdfTriangle(st*6.0+float2(1.5,0.0));
  t=sharpen(t,0.06,resolution);
  
  return max(float3(c),float3(t));

}

vertex VertexOutput vertexFieldBoundShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], constant float4 &lightPosition[[buffer(2)]], constant UniformModelRenderFlags &uniformModelRenderFlags [[buffer(3)]], constant UniformBoneSpace &uniformBoneSpace [[buffer(4)]], uint vid [[vertex_id]]){
    
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


fragment float4 fragmentFieldBoundShader(VertexOutput vertexOut [[stage_in]], constant UniformModelRenderFlags &uniformModelRenderFlags [[buffer(1)]], constant UniformModelMaterial &uniformModelMaterial [[buffer(2)]], constant UniformLightColor &uniformLightColor [[buffer(3)]],constant UniformModelShadowProperties &uniformModelShadowProperties [[buffer(4)]], constant UniformGlobalData &uniformGlobalData [[buffer(5)]], constant UniformModelShaderProperty &uniformModelShaderProperty [[buffer(6)]], texture2d<float> texture[[texture(0)]], depth2d<float> shadowTexture [[texture(1)]], texture2d<float> normalMaptexture[[texture(2)]], sampler sam [[sampler(0)]], sampler normalMapSam [[sampler(1)]]){
    
    
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
        
      float3 color=float3(0.0);
    
    float2 playerPosition=float2(uniformModelShaderProperty.shaderParameter[0].x,uniformModelShaderProperty.shaderParameter[0].y);
    
    float playerDirection=sign(-1.0*uniformModelShaderProperty.shaderParameter[0].z);
        
      st*=10.0;

    st.x+=step(1.0,mod(st.y,2.0))*0.5;
    
      float2 fid=fract(st);
      float2 iid=floor(st);
    float3 lines=float3(0.0);
      float2 arrowST=-1.0+2.0*fid;
    
      float a=(-atan2(arrowST.y,arrowST.x)+M_PI)/(2.0*M_PI);
    
      if(iid.y==0.0 || iid.y==-2.0){

       float l1=step(0.9,fid.y);

       float b=step(0.5,mod(fid.x*2.0,1.0));

       lines=float3(l1*b);

      }
    
    float playerBoundary1=1.0-step(-1.0,playerPosition.y);
    float playerBoundary2=step(0.01,playerPosition.y);
    
    float playerBoundary=playerBoundary1+playerBoundary2;
    
    if(playerBoundary==1.0){
        float m=mod(uniformGlobalData.time*2.0,1.0);

        lines*=m;
    }

    //same as iid.y is <= to 0
    float s1=step(0.0,-iid.y);

    //if iid.y is greater than -1.0
    float s2=step(-1.0,iid.y);

    //same as if(s1 AND s2)
    float s12=s1*s2;

    float m=step(1.0,mod(iid.x,2.0)); //returns a value of [0,1]
    float n=step(1.0,mod(iid.y,2.0)); //returns a value of [0,1]
    n=(0.5-n)/0.5; //transform it to [-1,1]

    arrowST.y*=n; //flip the coordinate depending on the value of n
    arrowST.x*=playerDirection; //you can control the direction of the arrows horizontally
    //color=arrow(arrowST,uniformGlobalData.resolution)*m*s12;

    //create the animation
    a=mod(n*uniformGlobalData.time*0.7 + a, 1.0);
    //color*=(1.0-a);
    
    //if player is not in grid, then don't render the arrow
    if(iid.x!=playerPosition.x || iid.y!=playerPosition.y){
    
        //color*=float3(0.0,0.0,0.0);
    }
    
    color=max(lines,color);
    
    //if(fid.x<0.05 || fid.x>0.95 || fid.y<0.05 || fid.y>0.95) color.b=1.0;
    
    return max(float4(color,1.0),finalColor);
    
}





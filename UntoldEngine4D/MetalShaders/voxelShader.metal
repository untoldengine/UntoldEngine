//
//  voxelShader.metal
//  UntoldVoxelEditor
//
//  Created by Harold Serrano on 2/17/23.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "U4DShaderProtocols.h"
#include "U4DShaderHelperFunctions.h"

using namespace metal;

typedef struct
{
    float4 position [[attribute(positionBufferIndex)]];
    float4 normals [[attribute(normalBufferIndex)]];
    float4 color [[attribute(colorBufferIndex)]];
    float4 material [[attribute(materialBufferIndex)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float4 color [[flat]];
    float4 material [[flat]];
    float3 normalVectorInMVSpace;
    float4 verticesInMVSpace;
    float4 normal [[flat]];
    float4 vPosition;
    float4 shadowCoords;
} VertexOut;

vertex VertexOut vertexVoxelShader(Vertex in [[stage_in]],
                                   constant simd_float3 &lightPosition[[buffer(lightPositionBufferIndex)]],
                                   constant simd_float4x4 &lightOrthoView [[buffer(lightOrthoViewSpaceBufferIndex)]],
                               constant UniformSpace & uniforms [[ buffer(uniformSpaceBufferIndex) ]]){
    VertexOut out;
    
    float4 position = float4(in.position);
    out.vPosition=position;
    out.position = uniforms.projectionSpace * uniforms.modelViewSpace * position;
    out.normal=normalize(in.normals);
    out.color=in.color;
    out.material=in.material;
    out.shadowCoords=lightOrthoView*(uniforms.modelSpace*position);
    return out;
}

fragment float4 fragmentVoxelShader(VertexOut in [[stage_in]],
                                    constant simd_float3 &lightPosition[[buffer(lightPositionBufferIndex)]],
                                    constant UniformSpace &uniforms [[ buffer(uniformSpaceBufferIndex) ]],
                                    depth2d<float> shadowTexture[[texture(0)]]){
    
    //ambient
    float ambientStrength=0.2;
    float3 lightColor=float3(1.0);
    
    float3 ambient=ambientStrength*lightColor;
    
    //diffuse
    //compute the direction of the light ray between the light position and the vertices of the surface
    float3 lightSpace=(simd_float4(lightPosition.x,lightPosition.y,lightPosition.z,1.0)).xyz;

    float4 verticesInWorldSpace=uniforms.modelSpace*in.vPosition;

    float3 lightRayDirection=normalize(lightSpace-verticesInWorldSpace.xyz);

    float3 normalVectorInWorldSpace=normalize(uniforms.normalSpace*in.normal.xyz);
    
    float3 viewVector=normalize(uniforms.cameraPosition-verticesInWorldSpace.xyz);
    
    float3 brdf=cookTorranceBRDF(lightRayDirection, normalVectorInWorldSpace, viewVector, in.color.rgb, float3(1.0), in.material.x, in.material.y, in.material.z);
    
    float3 color=ambient*in.color.rgb+brdf*lightColor;
    
    //for debugging uncomment this line so you can render the normals
    //return float4(normalVectorInWorldSpace,1.0);
    
    //Shadows
    constexpr sampler shadowSampler(coord::normalized, filter::linear, address::clamp_to_edge);
    
    //project from Clip space to NDC
    float3 proj=in.shadowCoords.xyz/in.shadowCoords.w;
    
    //map NDC space [-1,-1] to [0,1]
    proj.xy=proj.xy*0.5+0.5;
    
    //flip the texture. Metal's texture coordinate system has its origin in the top left corner, unlike opengl where the origin is the bottom
    //left corner
    proj.y=1.0-proj.y;
    
    float visibility=1.0;

    float biasShadow=0.00001;
    
    //Use PCF to smooth out shadows hard edges
    for(int i=0;i<16;i++){

        if(float4(shadowTexture.sample(shadowSampler, proj.xy+poissonDisk[i]/700.0)).x-biasShadow>=proj.z){
            visibility+=0.0125;
        }
    }
    
    return float4(color*visibility,1.0);
    
    
}



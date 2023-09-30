//
//  voxelShader.metal
//  UntoldVoxelEditor
//
//  Created by Harold Serrano on 2/17/23.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include "U4DShaderProtocols.h"

using namespace metal;

typedef struct
{
    float4 position [[attribute(positionBufferIndex)]];
    float4 normals [[attribute(normalBufferIndex)]];
    float4 color [[attribute(colorBufferIndex)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float4 color [[flat]];
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
    out.normal=in.normals;
    out.color=in.color;
    out.shadowCoords=lightOrthoView*(uniforms.modelSpace*position);
    return out;
}

fragment float4 fragmentVoxelShader(VertexOut in [[stage_in]],
                                    constant simd_float3 &lightPosition[[buffer(lightPositionBufferIndex)]],
                                    constant UniformSpace &uniforms [[ buffer(uniformSpaceBufferIndex) ]],
                                    depth2d<float> shadowTexture[[texture(0)]]){
    
    //compute the direction of the light ray between the light position and the vertices of the surface
    float3 lightInViewSpace=(uniforms.viewSpace*simd_float4(lightPosition.x,lightPosition.y,lightPosition.z,1.0)).xyz;

    float4 verticesInMVSpace=uniforms.modelViewSpace*in.vPosition;

    float3 lightRayDirection=normalize(lightInViewSpace-verticesInMVSpace.xyz);

    float3 normalVectorInMVSpace=(uniforms.normalSpace*in.normal).xyz;

    float4 color=in.color;

    float cosFactor=max(0.3,dot(normalVectorInMVSpace,lightRayDirection));

    color.xyz*=cosFactor;
    //for debugging uncomment this line so you can render the normals
    //return float4((in.normal+1.0)*0.5);
    
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
    float closestDepth=shadowTexture.sample(shadowSampler, proj.xy);
    float currentDepth=proj.z;
    visibility=currentDepth>closestDepth ? 0.5 : 1.0;
        
    color*=visibility;
    
    return color;
    
    
}



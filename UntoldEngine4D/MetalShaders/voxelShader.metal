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

constant float2 poissonDisk[16]={float2( 0.282571, 0.023957 ),
    float2( 0.792657, 0.945738 ),
    float2( 0.922361, 0.411756 ),
    float2( 0.165838, 0.552995 ),
    float2( 0.566027, 0.216651),
    float2( 0.335398,0.783654),
    float2( 0.0190741,0.318522),
    float2( 0.647572,0.581896),
    float2( 0.916288,0.0120243),
    float2( 0.0278329,0.866634),
    float2( 0.398053,0.4214),
    float2( 0.00289926,0.051149),
    float2( 0.517624,0.989044),
    float2( 0.963744,0.719901),
    float2( 0.76867,0.018128),
    float2( 0.684194,0.167302)
};

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
    out.normal=normalize(uniforms.modelSpace*in.normals);
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

    float3 color=in.color.rgb;

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

    float biasShadow=0.00001;
    
    //Use PCF to smooth out shadows hard edges
    for(int i=0;i<16;i++){

        if(float4(shadowTexture.sample(shadowSampler, proj.xy+poissonDisk[i]/700.0)).x-biasShadow>=proj.z){
            visibility+=0.0125;
        }
    }
    
    return float4(color*visibility,1.0);
    
    
}



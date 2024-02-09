//
//  voxelShader.metal
//  UntoldVoxelEditor
//
//  Created by Harold Serrano on 2/17/23.
//

#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"
#include "ShadersUtils.h"
#include "ShaderStructs.h"

using namespace metal;



vertex VertexOut vertexBlockShader(Vertex in [[stage_in]],
                                   constant simd_float4x4 &lightOrthoView [[buffer(voxelPassLightOrthoViewMatrixIndex)]],
                               constant Uniforms & uniforms [[ buffer(voxelPassUniformIndex) ]]){
    VertexOut out;
    
    float4 position = float4(in.position, 1.0);
    out.vPosition=position;
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.normal=in.normals;
    out.color=float4(float3(in.color),1.0);
    out.roughness=in.roughness;
    out.metallic=in.metallic;
    out.shadowCoords=lightOrthoView*uniforms.modelMatrix*position;
    return out;
}

fragment FragmentVoxelOut fragmentBlockShader(VertexOut in [[stage_in]],
                                    constant Uniforms & uniforms [[ buffer(voxelPassUniformIndex) ]],
                                    constant simd_float3 &lightDirection [[buffer(voxelPassLightDirectionIndex)]],
                                    constant PointLightUniform *pointLights [[buffer(voxelPassPointLightsIndex)]],
                                    constant int *pointLightsCount [[buffer(voxelPassPointLightsCountIndex)]],
                                    texture2d<float> irradianceMap[[texture(0)]],
                                    texture2d<float> specularMap[[texture(1)]],
                                    texture2d<float> brdfMap[[texture(2)]],
                                    depth2d<float> shadowTexture[[texture(3)]])
{
    
    
    float lightBrightness=0.2;
    float3 lightColor=float3(1.0);
    float3 ambient=lightColor*lightBrightness;

    //compute the direction of the light ray between the light position and the vertices of the surface
    
    float4 verticesInWorldSpace=uniforms.modelMatrix*in.vPosition;
    float3 normalVectorInWorldSpace=uniforms.normalMatrix*in.normal;
    
    float3 lightRayDirection=normalize(lightDirection);
    float3 viewVector=normalize(uniforms.cameraPosition-verticesInWorldSpace.xyz);
    
    /*original brdf */
    float3 brdf=cookTorranceBRDF(lightRayDirection, normalVectorInWorldSpace, viewVector, in.color.rgb, float3(1.0), in.roughness, in.metallic, 0.2);

    float4 color=float4(brdf*lightColor+ambient*in.color.rgb,1.0);
    
    float4 pointColor=simd_float4(0.0);
    
    for(int i=0; i<pointLightsCount[0];i++){
        
        float3 pointLightRayDirection=normalize(pointLights[i].position.xyz-verticesInWorldSpace.xyz);
        float pointLightDistance=length(pointLights[i].position.xyz-verticesInWorldSpace.xyz);
        
        float3 pointLightBRDF=cookTorranceBRDF(pointLightRayDirection, normalVectorInWorldSpace, viewVector, pointLights[i].color.rgb, pointLights[i].color.rgb, in.roughness, in.metallic, 0.2);
        
        float attenuation=calculateAttenuation(pointLightDistance, pointLights[i].attenuation);
        
        pointColor+=float4(pointLightBRDF*attenuation+ambient*pointLights[i].color.rgb*attenuation,1.0);
        
    }
    
    color+=pointColor;
    
    //compute shadow
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
    
    FragmentVoxelOut fragmentOut;
    fragmentOut.albedo=float4(color.rgb*visibility,1.0);;
    fragmentOut.normals=float4((in.normal+1.0)*0.5,1.0);
    fragmentOut.positions=uniforms.modelViewMatrix*in.position;
    
    return fragmentOut;
    
    
    //Uncomment this for IBL
//    float reflectance=1.0;
//    float roughness=in.roughness;
//    float metallic=in.metallic;
//    
//    // F0 for dielectics in range [0.0, 0.16]
//    // default FO is (0.16 * 0.5^2) = 0.04
//    float3 f0 = float3(0.16 * (reflectance * reflectance));
//    // in case of metals, baseColor contains F0
//    f0 = mix(f0, in.color.rgb, metallic);
//    
//    // compute diffuse and specular factors
//    float3 F = fresnelSchlick(max(dot(normalVectorInWorldSpace, viewVector), 0.01), f0);
//    float3 kS = F;
//    float3 kD = 1.0 - kS;
//    kD *= 1.0 - metallic;
//    
//    float3 specular = specularIBL(f0, roughness, normalVectorInWorldSpace, viewVector,specularMap,brdfMap);
//    float3 diffuse = diffuseIBL(normalVectorInWorldSpace,irradianceMap);
//    
//    float4 color = float4(kD * in.color.rgb * diffuse + specular,1.0);
//    //color.rgb = pow(color.rgb, float3(1.0/2.2));
//    
//    //for debugging uncomment this line so you can render the normals
//    //return float4((in.normal+1.0)*0.5,1.0);
//    return color;
}



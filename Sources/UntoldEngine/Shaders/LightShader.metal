//
//  LightShader.metal
//
//
//  Created by Harold Serrano on 7/29/25.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
using namespace metal;

constant uint MAX_POINT_LIGHTS = 1024;

struct PointLightBlock{
    uint4 count;
    PointLightUniform lights[MAX_POINT_LIGHTS];
};

struct SpotLightBlock{
    uint4 count;
    SpotLightUniform lights[MAX_POINT_LIGHTS];
};

struct AreaLightBlock{
    uint4 count;
    AreaLightUniform lights[MAX_POINT_LIGHTS];
};

float computeShadow(float4 shadowCoords, depth2d<float> shadowTexture, float3 normal, float3 lightDir){
    
    float shadow=0.0;
    
    constexpr sampler shadowSampler(coord::normalized, filter::linear, address::clamp_to_edge);
    float2 texelSize = 1.0 / float2(shadowTexture.get_width(), shadowTexture.get_height());

    float bias = max(0.002 * (1.0 - dot(normalize(normal), normalize(lightDir))), 0.001);

    //project from Clip space to NDC
    float3 proj=shadowCoords.xyz/shadowCoords.w;

    //map NDC space [-1,-1] to [0,1]
    proj.xy=proj.xy*0.5+0.5;

    //flip the texture. Metal's texture coordinate system has its origin in the top left corner, unlike opengl where the origin is the bottom
    //left corner
    proj.y=1.0-proj.y;

    //float closestDepth=shadowTexture.sample(shadowSampler,proj.xy);
    float currentDepth=proj.z;
    int poissonSamples = 16;
    for (int i = 0; i < poissonSamples; ++i) {
            float2 offset = poissonDisk[i] * texelSize * 1.5;
            float sampledDepth = shadowTexture.sample(shadowSampler, proj.xy + offset);
            shadow += (currentDepth - bias) > sampledDepth ? 0.3 : 1.0;
        }
    shadow/=poissonSamples;
    //shadow = mix(0.3, 1.0, shadow);
    return shadow;
}

float3 computeIBLContribution(texture2d<float> irradianceTexture,
                              texture2d<float> specularTexture,
                              texture2d<float> iblBRDFTexture,
                              constant float &iblRotationAngle,
                              constant IBLParamsUniform &iblParam,
                              float4 inBaseColor,
                              float3 normalMap,
                              float3 viewVector,
                              float roughness,
                              float metallic
                              ){
    
    //compute ibl ambient contribution
    float NoV = max(dot(normalMap.xyz, viewVector), 0.001);
    
    float3 irradiance=diffuseIBL(normalMap.xyz, irradianceTexture, float3(0.0,1.0,0.0),degreesToRadians(iblRotationAngle));
    
    float3 diffuse = irradiance*inBaseColor.rgb;

    float3 f0 = mix(0.04, inBaseColor.rgb, metallic);
    float3 F=fresnelSchlick(NoV,f0);

    float3 specular=specularIBL(F, roughness, normalMap.xyz, viewVector, specularTexture, iblBRDFTexture,float3(0.0,1.0,0.0),degreesToRadians(iblRotationAngle));

    float3 ambient=mix(diffuse,specular,metallic);
    
    if(iblParam.applyIBL==false){
        ambient=diffuse.rgb;
    }
    
    return ambient;
}

float4 computePointLightContribution(constant PointLightUniform &light,
                                     float4 verticesInWorldSpace,
                                     float3 viewVector,
                                     float3 normalMap,
                                     float3 inBaseColor,
                                     float roughness,
                                     float metallic
                                     ){
    float3 lightDirection=normalize(light.position.xyz-verticesInWorldSpace.xyz);
    float lightDistance=length(light.position.xyz-verticesInWorldSpace.xyz);

    float3 lightBRDF=computeBRDF(lightDirection, viewVector, normalMap.xyz, inBaseColor, float3(1.0), roughness,metallic);

    float attenuation=calculateAttenuation(lightDistance, light.attenuation);

    float4 lightContribution=float4(lightBRDF*attenuation*light.intensity*light.color,1.0);
 
    return lightContribution;
}

float4 computeSpotLightContribution(constant SpotLightUniform &light,
                                     float4 verticesInWorldSpace,
                                     float3 viewVector,
                                     float3 normalMap,
                                     float3 inBaseColor,
                                     float roughness,
                                     float metallic
                                     ){
    
    float3 lightDirection=normalize(light.position.xyz-verticesInWorldSpace.xyz);
    float3 spotDirection = normalize(light.direction.xyz);
    float lightDistance=length(light.position.xyz-verticesInWorldSpace.xyz);
    
    float attenuation=calculateAttenuation(lightDistance, light.attenuation);
    
    float3 lightBRDF=computeBRDF(lightDirection, viewVector, normalMap.xyz, inBaseColor, float3(1.0), roughness,metallic);
    
    float theta = dot(-lightDirection, spotDirection); // cosine of angle between light dir and spot dir
    float epsilon = cos(light.innerCone) - cos(light.outerCone);
    float coneFalloff = clamp((theta-cos(light.outerCone))/epsilon, 0.0, 1.0);
    
    float4 lightContribution=float4(lightBRDF*attenuation*coneFalloff*light.intensity*light.color,1.0);
 
    return lightContribution;
}


float4 evaluateAreaLight(constant AreaLightUniform &light,
                            float4 verticesInWorldSpace,
                            float3 viewVector,
                            float3 normalMap,
                            texture2d<float> ltcMat,
                            texture2d<float> ltcMag,
                            float3 inBaseColor,
                            float roughness,
                            float metallic
                            ){
    
    constexpr sampler s(
        min_filter::linear,
        mag_filter::linear,
        mip_filter::none,
        s_address::clamp_to_edge,
        t_address::clamp_to_edge
    );

    //float NoV = max(dot(normalMap, viewVector), 0.001);
    
    float theta = acos(clamp(dot(normalMap, viewVector), 0.0, 1.0));
    float2 uv = float2(roughness, theta / (0.5 * M_PI_F));
    uv = uv * LUT_SCALE + LUT_BIAS;

    
    float4 t = ltcMat.sample(s, uv);
    float4 t2 = ltcMag.sample(s,uv);
    
    float3x3 Minv= float3x3(float3(t.x,0,t.y),
                            float3(0,1.0,0),
                            float3(t.z,0,t.w));
    Minv=transpose(Minv);
    
    float3 P = verticesInWorldSpace.xyz;
    
    // Compute corners
    float3 u = light.right * light.bounds.x;
    float3 v = light.up * light.bounds.y;
    float3 p0 = light.position - 0.5 * u - 0.5 * v;
    float3 p1 = light.position + 0.5 * u - 0.5 * v;
    float3 p2 = light.position + 0.5 * u + 0.5 * v;
    float3 p3 = light.position - 0.5 * u + 0.5 * v;

    float3 points[4];
    points[0]=p0;
    points[1]=p1;
    points[2]=p2;
    points[3]=p3;
    
    float3x3 identity=float3x3(float3(1.0,0.0,0.0),
                               float3(0.0,1.0,0.0),
                               float3(0.0,0.0,1.0));
    float3 Lo_spec=LTC_Evaluate(normalMap.xyz, viewVector, P,Minv, points, light.twoSided);
    
    Lo_spec *= t2.x;

    float3 Lo_diffuse = LTC_Evaluate(normalMap.xyz, viewVector, P,identity, points, light.twoSided);

    float3 lightDirection=normalize(light.position.xyz-verticesInWorldSpace.xyz);
    
    float3 diffuseBRDF = computeDiffuseBRDF(lightDirection, viewVector, normalMap, inBaseColor.rgb, float3(1.0), roughness, metallic);

    float3 specBRDF = computeSpecBRDF(lightDirection, viewVector, normalMap, inBaseColor.rgb, float3(1.0), roughness, metallic);

    
    float3 finalLight = light.intensity * (Lo_diffuse * diffuseBRDF + Lo_spec * specBRDF)*light.color;
    

    return float4(finalLight, 1.0);
    
}

vertex VertexCompositeOutput vertexLightShader(VertexCompositeIn in [[stage_in]]){

    VertexCompositeOutput vertexOut;
    vertexOut.position=float4(float3(in.position),1.0);
    vertexOut.uvCoords=in.uvCoords;

    return vertexOut;
}

fragment float4 fragmentLightShader(VertexCompositeOutput vertexOut [[stage_in]],
                                    texture2d<half> albedoMap[[texture(lightPassAlbedoTextureIndex)]],
                                    texture2d<half> normalMap[[texture(lightPassNormalTextureIndex)]],
                                    texture2d<float> positionMap[[texture(lightPassPositionTextureIndex)]],
                                    texture2d<half> materialMap[[texture(lightPassMaterialTextureIndex)]],
                                    depth2d<float> shadowTexture[[texture(lightPassShadowTextureIndex)]],
                                    texture2d<float> irradianceTexture [[texture(lightPassIBLIrradianceTextureIndex)]],
                                    texture2d<float> specularTexture [[texture(lightPassIBLSpecularTextureIndex)]],
                                    texture2d<half> ssaoTexture [[texture(lightPassSSAOTextureIndex)]],
                                    texture2d<float> iblBRDFTexture [[texture(lightPassIBLBRDFMapTextureIndex)]],
                                    texture2d<float> ltcMagTexture [[texture(lightPassAreaLTCMagTextureIndex)]],
                                    texture2d<float> ltcMatTexture [[texture(lightPassAreaLTCMatTextureIndex)]],
                                    constant simd_float4x4 &lightOrthoView [[buffer(lightPassLightOrthoViewMatrixIndex)]],
                                    constant simd_float3 &cameraPosition [[buffer(lightPassCameraPositionIndex)]],
                                    constant LightParameters &lights [[buffer(lightPassLightParamsIndex)]],
                                    constant PointLightBlock &plBlock[[buffer(lightPassPointLightsIndex)]],
                                    constant SpotLightBlock &slBlock[[buffer(lightPassSpotLightsIndex)]],
                                    constant IBLParamsUniform &iblParam [[buffer(lightPassIBLParamIndex)]],
                                    constant AreaLightBlock &alBlock[[buffer(lightPassAreaLightsIndex)]],
                                    constant float &iblRotationAngle [[buffer(lightPassIBLRotationAngleIndex)]],
                                    constant bool &isGameMode[[buffer(lightPassGameModeIndex)]]
                                    ){

    float3 lightRayDirection=normalize(lights.direction);
    
    uint2 pixelCoord = uint2(vertexOut.position.xy);
    half4 albedo_h = albedoMap.read(pixelCoord, 0);
    float4 albedo = float4(albedo_h);
    
    float4 verticesInWorldSpace = positionMap.read(pixelCoord, 0);
    half3 surfaceNormal_h = normalMap.read(pixelCoord, 0).xyz;
    float3 surfaceNormal = float3(surfaceNormal_h);
    
    half4 materialTexture = materialMap.read(pixelCoord, 0);
    float roughness = (float)materialTexture.r;
    float metallic = (float)materialTexture.g;
    
    float ambientOcclusion = isGameMode ? (float)ssaoTexture.read(pixelCoord, 0).r : 1.0;
    
    float3 viewVector=normalize(cameraPosition-verticesInWorldSpace.xyz);
   
    //compute ibl ambient contribution
    float3 indirectLighting=computeIBLContribution(irradianceTexture,
                                              specularTexture,
                                              iblBRDFTexture,
                                              iblRotationAngle,
                                              iblParam,
                                              albedo,
                                              surfaceNormal,
                                              viewVector,
                                              roughness,
                                              metallic);
    
    indirectLighting *= ambientOcclusion*iblParam.ambientIntensity;
    
    indirectLighting = ACESFilmicToneMapping(indirectLighting);
    
    // Compute BRDF
    float3 brdf=float3(0.0);
    
    brdf=computeBRDF(lightRayDirection, viewVector, surfaceNormal, albedo.rgb, float3(1.0), roughness,metallic);
    
    float4 color = float4(brdf*lights.color*lights.intensity,1.0);
    
    float4 shadowCoords = lightOrthoView * float4(verticesInWorldSpace.xyz,1.0);
    
    // Compute shadow
    float shadow = computeShadow(shadowCoords, shadowTexture, surfaceNormal, lightRayDirection);
   
    // shadows affect directional light for now
    color = color*shadow;
    
    
    // compute point light contribution

    float4 pointColor=simd_float4(0.0);
    uint lightCount = min(plBlock.count.x, MAX_POINT_LIGHTS);
    for (uint i=0; i<lightCount; ++i){
        pointColor += computePointLightContribution(plBlock.lights[i],
                                                    verticesInWorldSpace,
                                                    viewVector,
                                                    surfaceNormal,
                                                    albedo.rgb,
                                                    roughness,
                                                    metallic);
    }
    color+=pointColor;
    
    // Compute spot light contribution

    float4 spotLightColor = simd_float4(0.0);
    uint spotLightCount = min(slBlock.count.x, MAX_POINT_LIGHTS);
    for (uint i=0 ; i< spotLightCount; ++i){
        spotLightColor += computeSpotLightContribution(slBlock.lights[i],
                                                       verticesInWorldSpace,
                                                       viewVector,
                                                       surfaceNormal,
                                                       albedo.rgb,
                                                       roughness,
                                                       metallic);
    }

    color += spotLightColor;
    
    // Compute Area Light contribution
    simd_float4 areaLightColor = simd_float4(0.0);

    uint areaLightCount = min(alBlock.count.x, MAX_POINT_LIGHTS);
    for (uint i=0 ; i< areaLightCount; ++i){
        areaLightColor += evaluateAreaLight(alBlock.lights[i],
                                               verticesInWorldSpace,
                                               viewVector,
                                                surfaceNormal,
                                               ltcMatTexture,
                                               ltcMagTexture,
                                                albedo.rgb,
                                               roughness,
                                               metallic);
    }

    color += areaLightColor;

    color = float4(color.rgb + indirectLighting,1.0);
    
    return color;

}



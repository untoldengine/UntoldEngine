//
//  LightShader.metal
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
#include "ShadersUtils.h"
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

// Cascaded shadow map sampling.
// Selects the cascade whose far-split encloses the fragment's camera view-depth,
// then performs a 16-tap Poisson-disk PCF on that cascade's depth slice.
float computeCSMShadow(
    depth2d_array<float> shadowArray,
    constant CSMUniforms &csm,
    float3 worldPos,
    float3 cameraPos,
    float3 normal,
    float3 lightDir
) {
    // Pick cascade using the same right-handed camera depth space as the CPU split calculation.
    float viewDepth = -(csm.cameraViewMatrix * float4(worldPos, 1.0)).z;
    int cascade = csm.cascadeCount - 1;
    for (int i = 0; i < csm.cascadeCount - 1; i++) {
        if (viewDepth < csm.cascadeSplits[i]) { cascade = i; break; }
    }

    float4 shadowCoords = csm.lightSpaceMatrices[cascade] * float4(worldPos, 1.0);

    // Clip → NDC → [0,1] UV
    float3 proj = shadowCoords.xyz / shadowCoords.w;
    proj.xy = proj.xy * 0.5 + 0.5;
    proj.y  = 1.0 - proj.y; // Metal origin is top-left

    if (proj.x < 0.0 || proj.x > 1.0 ||
        proj.y < 0.0 || proj.y > 1.0 ||
        proj.z < 0.0 || proj.z > 1.0) {
        return 1.0;
    }

    constexpr sampler shadowSampler(coord::normalized, filter::linear, address::clamp_to_edge);
    float2 texelSize = 1.0 / float2(shadowArray.get_width(), shadowArray.get_height());

    float bias = max(0.002 * (1.0 - dot(normalize(normal), normalize(lightDir))), 0.001);
    float currentDepth = proj.z;

    float shadow = 0.0;
    for (int i = 0; i < 16; ++i) {
        float2 offset = poissonDisk[i] * texelSize * 1.5;
        float sampledDepth = shadowArray.sample(shadowSampler, proj.xy + offset, cascade);
        shadow += (currentDepth - bias) > sampledDepth ? 0.3 : 1.0;
    }
    return shadow / 16.0;
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

LightContribution computePointLightContribution(constant PointLightUniform &light,
                                     float4 verticesInWorldSpace,
                                     float3 viewVector,
                                     float3 normalMap,
                                     float3 inBaseColor,
                                     float roughness,
                                     float metallic
                                     ){
    float3 lightDirection=normalize(light.position.xyz-verticesInWorldSpace.xyz);
    float lightDistance=length(light.position.xyz-verticesInWorldSpace.xyz);

    LightContribution br=computeBRDF(lightDirection, viewVector, normalMap.xyz, inBaseColor, float3(1.0), roughness,metallic);

    float attenuation=calculateAttenuation(lightDistance, light.attenuation);

    LightContribution outC;
    outC.diff = br.diff * (half)attenuation * (half)light.intensity * (half3)light.color;
    outC.spec = br.spec * attenuation * light.intensity * (float3)light.color;
        
    return outC;
}

LightContribution computeSpotLightContribution(constant SpotLightUniform &light,
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
    
    LightContribution br=computeBRDF(lightDirection, viewVector, normalMap.xyz, inBaseColor, float3(1.0), roughness,metallic);
    
    float theta = dot(-lightDirection, spotDirection); // cosine of angle between light dir and spot dir
    float epsilon = cos(light.innerCone) - cos(light.outerCone);
    float coneFalloff = clamp((theta-cos(light.outerCone))/epsilon, 0.0, 1.0);
    
    LightContribution outC;
    outC.diff = br.diff * (half)attenuation * (half)coneFalloff * (half)light.intensity * half3(light.color);
    outC.spec = br.spec * attenuation*coneFalloff*light.intensity*light.color;
    
    return outC;
}


LightContribution evaluateAreaLight(constant AreaLightUniform &light,
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
    
    half3 diffuseBRDF = computeDiffuseBRDF(lightDirection, viewVector, normalMap, inBaseColor.rgb, float3(1.0), roughness, metallic);

    float3 specBRDF = computeSpecBRDF(lightDirection, viewVector, normalMap, inBaseColor.rgb, float3(1.0), roughness, metallic);

    
    LightContribution outC;
    outC.diff = (half)light.intensity * (half3)Lo_diffuse * diffuseBRDF * (half3)light.color;
    outC.spec = light.intensity * Lo_spec * specBRDF * light.color;

    return outC;
    
}

// Output struct for the TBDR light pass — writes to attachment 5 (deferredColorMap).
// Attachments 0-4 are the G-buffer slots; the light quad does not write to them.
struct TBDRLightOutput {
    float4 litColor [[color(5)]];
};

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
                                    depth2d_array<float> csmShadowArray[[texture(lightPassShadowTextureIndex)]],
                                    texture2d<float> irradianceTexture [[texture(lightPassIBLIrradianceTextureIndex)]],
                                    texture2d<float> specularTexture [[texture(lightPassIBLSpecularTextureIndex)]],
                                    texture2d<half> ssaoTexture [[texture(lightPassSSAOTextureIndex)]],
                                    texture2d<float> iblBRDFTexture [[texture(lightPassIBLBRDFMapTextureIndex)]],
                                    texture2d<float> ltcMagTexture [[texture(lightPassAreaLTCMagTextureIndex)]],
                                    texture2d<float> ltcMatTexture [[texture(lightPassAreaLTCMatTextureIndex)]],
                                    constant CSMUniforms &csmUniforms [[buffer(lightPassLightOrthoViewMatrixIndex)]],
                                    constant simd_float3 &cameraPosition [[buffer(lightPassCameraPositionIndex)]],
                                    constant LightParameters &lights [[buffer(lightPassLightParamsIndex)]],
                                    constant PointLightBlock &plBlock[[buffer(lightPassPointLightsIndex)]],
                                    constant SpotLightBlock &slBlock[[buffer(lightPassSpotLightsIndex)]],
                                    constant IBLParamsUniform &iblParam [[buffer(lightPassIBLParamIndex)]],
                                    constant AreaLightBlock &alBlock[[buffer(lightPassAreaLightsIndex)]],
                                    constant float &iblRotationAngle [[buffer(lightPassIBLRotationAngleIndex)]],
                                    constant bool &isGameMode[[buffer(lightPassGameModeIndex)]],
                                    constant bool &ssaoEnabled[[buffer(lightPassSSAOEnabledIndex)]]
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
    
    float ambientOcclusion = (isGameMode && ssaoEnabled) ? (float)ssaoTexture.read(pixelCoord, 0).r : 1.0;
    
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
    
    // Compute BRDF
    LightContribution brdf;
    
    brdf=computeBRDF(lightRayDirection, viewVector, surfaceNormal, albedo.rgb, float3(1.0), roughness,metallic);
   
    LightContribution color;
    
    color.diff = brdf.diff * (half3)lights.color * (half)lights.intensity;
    color.spec = brdf.spec*lights.color*lights.intensity;
    
    // Compute shadow using cascaded shadow maps
    float shadow = computeCSMShadow(csmShadowArray, csmUniforms, verticesInWorldSpace.xyz, cameraPosition, surfaceNormal, lightRayDirection);
   
    // shadows affect directional light for now
    color.diff = color.diff*(half)shadow;
    color.spec = color.spec*shadow;
    
    // compute point light contribution

    LightContribution pointColor;
    uint lightCount = min(plBlock.count.x, MAX_POINT_LIGHTS);
    for (uint i=0; i<lightCount; ++i){
        LightContribution pl = computePointLightContribution(plBlock.lights[i],
                                                    verticesInWorldSpace,
                                                    viewVector,
                                                    surfaceNormal,
                                                    albedo.rgb,
                                                    roughness,
                                                    metallic);
        pointColor.diff += pl.diff;
        pointColor.spec += pl.spec;
    }
    
    color.diff += pointColor.diff;
    color.spec += pointColor.spec;
    
    // Compute spot light contribution

    LightContribution spotLightColor;
    uint spotLightCount = min(slBlock.count.x, MAX_POINT_LIGHTS);
    for (uint i=0 ; i< spotLightCount; ++i){
        LightContribution sl = computeSpotLightContribution(slBlock.lights[i],
                                                       verticesInWorldSpace,
                                                       viewVector,
                                                       surfaceNormal,
                                                       albedo.rgb,
                                                       roughness,
                                                       metallic);
        spotLightColor.diff += sl.diff;
        spotLightColor.spec += sl.spec;
    }

    color.diff += spotLightColor.diff;
    color.spec += spotLightColor.spec;
    
    // Compute Area Light contribution
    LightContribution areaLightColor;

    uint areaLightCount = min(alBlock.count.x, MAX_POINT_LIGHTS);
    for (uint i=0 ; i< areaLightCount; ++i){
        LightContribution al = evaluateAreaLight(alBlock.lights[i],
                                               verticesInWorldSpace,
                                               viewVector,
                                                surfaceNormal,
                                               ltcMatTexture,
                                               ltcMagTexture,
                                                albedo.rgb,
                                               roughness,
                                               metallic);
        areaLightColor.diff += al.diff;
        areaLightColor.spec += al.spec;
    }

    color.diff += areaLightColor.diff;
    color.spec += areaLightColor.spec;

    float4 finalcolor = float4((float3)color.diff + color.spec + indirectLighting, albedo.a);

    return finalcolor;

}

// TBDR light pass: reads G-buffer from tile memory via framebuffer fetch ([[color(N)]]).
// The geometry and lighting sub-passes share one MTLRenderCommandEncoder, so the
// G-buffer data never leaves the GPU tile. Outputs lit color to attachment 5.
fragment TBDRLightOutput fragmentLightShaderTBDR(
    VertexCompositeOutput vertexOut [[stage_in]],
    // G-buffer — read directly from tile memory, no texture2d binding needed
    half4  gbAlbedo   [[color(0)]],
    half4  gbNormal   [[color(1)]],
    float4 gbPosition [[color(2)]],
    half4  gbMaterial [[color(3)]],
    half4  gbEmissive [[color(4)]],
    // Shadow and IBL textures (still come from main memory)
    depth2d_array<float> csmShadowArray  [[texture(lightPassShadowTextureIndex)]],
    texture2d<float>     irradianceTexture [[texture(lightPassIBLIrradianceTextureIndex)]],
    texture2d<float>     specularTexture   [[texture(lightPassIBLSpecularTextureIndex)]],
    texture2d<float>     iblBRDFTexture    [[texture(lightPassIBLBRDFMapTextureIndex)]],
    texture2d<float>     ltcMagTexture     [[texture(lightPassAreaLTCMagTextureIndex)]],
    texture2d<float>     ltcMatTexture     [[texture(lightPassAreaLTCMatTextureIndex)]],
    // Uniform buffers
    constant CSMUniforms      &csmUniforms      [[buffer(lightPassLightOrthoViewMatrixIndex)]],
    constant simd_float3      &cameraPosition   [[buffer(lightPassCameraPositionIndex)]],
    constant LightParameters  &lights           [[buffer(lightPassLightParamsIndex)]],
    constant PointLightBlock  &plBlock          [[buffer(lightPassPointLightsIndex)]],
    constant SpotLightBlock   &slBlock          [[buffer(lightPassSpotLightsIndex)]],
    constant IBLParamsUniform &iblParam         [[buffer(lightPassIBLParamIndex)]],
    constant AreaLightBlock   &alBlock          [[buffer(lightPassAreaLightsIndex)]],
    constant float            &iblRotationAngle [[buffer(lightPassIBLRotationAngleIndex)]],
    constant bool             &isGameMode       [[buffer(lightPassGameModeIndex)]],
    uint                      sampleID          [[sample_id]]
) {
    (void)sampleID;
    // Background pixels were cleared to (0,0,0,0). Skip lighting entirely —
    // normalize(float3(0)) is undefined, and the IBL/shadow paths would produce
    // garbage that can corrupt the environment composite downstream.
    if (gbAlbedo.a <= 0.0h) {
        TBDRLightOutput out;
        out.litColor = float4(0.0);
        return out;
    }

    float3 lightRayDirection = normalize(lights.direction);

    float4 albedo               = float4(gbAlbedo);
    float4 verticesInWorldSpace = gbPosition;
    float3 surfaceNormal        = normalize(float3(gbNormal.xyz));
    float  roughness          = float(gbMaterial.r);
    float  metallic           = float(gbMaterial.g);
    float3 emissive           = float3(gbEmissive.rgb);

    // SSAO is disabled in the TBDR path; will be revisited once SSAO is
    // restructured as a tile kernel running inside this same encoder.
    float ambientOcclusion = 1.0;

    float3 viewVector = normalize(cameraPosition - verticesInWorldSpace.xyz);

    float3 indirectLighting = computeIBLContribution(
        irradianceTexture, specularTexture, iblBRDFTexture,
        iblRotationAngle, iblParam,
        albedo, surfaceNormal, viewVector, roughness, metallic
    );
    indirectLighting *= ambientOcclusion * iblParam.ambientIntensity;

    LightContribution brdf = computeBRDF(lightRayDirection, viewVector, surfaceNormal, albedo.rgb, float3(1.0), roughness, metallic);

    LightContribution color;
    color.diff = brdf.diff * (half3)lights.color * (half)lights.intensity;
    color.spec = brdf.spec * lights.color * lights.intensity;

    float shadow = computeCSMShadow(csmShadowArray, csmUniforms, verticesInWorldSpace.xyz, cameraPosition, surfaceNormal, lightRayDirection);
    color.diff *= (half)shadow;
    color.spec *= shadow;

    LightContribution pointColor;
    uint lightCount = min(plBlock.count.x, MAX_POINT_LIGHTS);
    for (uint i = 0; i < lightCount; ++i) {
        LightContribution pl = computePointLightContribution(plBlock.lights[i], verticesInWorldSpace, viewVector, surfaceNormal, albedo.rgb, roughness, metallic);
        pointColor.diff += pl.diff;
        pointColor.spec += pl.spec;
    }
    color.diff += pointColor.diff;
    color.spec += pointColor.spec;

    LightContribution spotLightColor;
    uint spotLightCount = min(slBlock.count.x, MAX_POINT_LIGHTS);
    for (uint i = 0; i < spotLightCount; ++i) {
        LightContribution sl = computeSpotLightContribution(slBlock.lights[i], verticesInWorldSpace, viewVector, surfaceNormal, albedo.rgb, roughness, metallic);
        spotLightColor.diff += sl.diff;
        spotLightColor.spec += sl.spec;
    }
    color.diff += spotLightColor.diff;
    color.spec += spotLightColor.spec;

    LightContribution areaLightColor;
    uint areaLightCount = min(alBlock.count.x, MAX_POINT_LIGHTS);
    for (uint i = 0; i < areaLightCount; ++i) {
        LightContribution al = evaluateAreaLight(alBlock.lights[i], verticesInWorldSpace, viewVector, surfaceNormal, ltcMatTexture, ltcMagTexture, albedo.rgb, roughness, metallic);
        areaLightColor.diff += al.diff;
        areaLightColor.spec += al.spec;
    }
    color.diff += areaLightColor.diff;
    color.spec += areaLightColor.spec;

    // set emissive to zero for now - need  to revisit this
    emissive = 0.0;
    float3 finalRGB = (float3)color.diff + color.spec + indirectLighting + emissive;

    TBDRLightOutput out;
    out.litColor = float4(finalRGB, albedo.a);
    return out;
}

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
                              MaterialParametersUniform materialParameter,
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

    float fr=artistFriendlyF0(inBaseColor.r, materialParameter.edgeTint.x, NoV);
    float fg=artistFriendlyF0(inBaseColor.g, materialParameter.edgeTint.y, NoV);
    float fb=artistFriendlyF0(inBaseColor.b, materialParameter.edgeTint.z, NoV);

    float3 f0=float3(fr, fg, fb);

    f0=mix(0.04,f0,metallic);

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
                                     MaterialParametersUniform materialParameter,
                                     float3 inBaseColor,
                                     float roughness,
                                     float metallic
                                     ){
    float3 lightDirection=normalize(light.position.xyz-verticesInWorldSpace.xyz);
    float lightDistance=length(light.position.xyz-verticesInWorldSpace.xyz);

    float3 lightBRDF=computeBRDF(lightDirection, viewVector, normalMap.xyz, inBaseColor, float3(1.0), materialParameter,roughness,metallic);

    float attenuation=calculateAttenuation(lightDistance, light.attenuation);

    float4 lightContribution=float4(lightBRDF*attenuation*light.intensity*light.color,1.0);
 
    return lightContribution;
}

float4 computeSpotLightContribution(constant SpotLightUniform &light,
                                     float4 verticesInWorldSpace,
                                     float3 viewVector,
                                     float3 normalMap,
                                     MaterialParametersUniform materialParameter,
                                     float3 inBaseColor,
                                     float roughness,
                                     float metallic
                                     ){
    
    float3 lightDirection=normalize(light.position.xyz-verticesInWorldSpace.xyz);
    float3 spotDirection = normalize(light.direction.xyz);
    float lightDistance=length(light.position.xyz-verticesInWorldSpace.xyz);
    
    float attenuation=calculateAttenuation(lightDistance, light.attenuation);
    
    float3 lightBRDF=computeBRDF(lightDirection, viewVector, normalMap.xyz, inBaseColor, float3(1.0), materialParameter,roughness,metallic);
    
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
                            MaterialParametersUniform materialParameter,
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
    
    float3 diffuseBRDF = computeDiffuseBRDF(lightDirection, viewVector, normalMap, inBaseColor.rgb, float3(1.0), materialParameter, roughness, metallic);

    float3 specBRDF = computeSpecBRDF(lightDirection, viewVector, normalMap, inBaseColor.rgb, float3(1.0), materialParameter, roughness, metallic);

    
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
                                    texture2d<float> albedoMap[[texture(lightPassAlbedoTextureIndex)]],
                                    texture2d<float> normalMap[[texture(lightPassNormalTextureIndex)]],
                                    texture2d<float> positionMap[[texture(lightPassPositionTextureIndex)]],
                                    texture2d<float> materialMap[[texture(lightPassMaterialTextureIndex)]],
                                    depth2d<float> shadowTexture[[texture(lightPassShadowTextureIndex)]],
                                    texture2d<float> irradianceTexture [[texture(lightPassIBLIrradianceTextureIndex)]],
                                    texture2d<float> specularTexture [[texture(lightPassIBLSpecularTextureIndex)]],
                                    texture2d<float> ssaoTexture [[texture(lightPassSSAOTextureIndex)]],
                                    texture2d<float> iblBRDFTexture [[texture(lightPassIBLBRDFMapTextureIndex)]],
                                    texture2d<float> ltcMagTexture [[texture(lightPassAreaLTCMagTextureIndex)]],
                                    texture2d<float> ltcMatTexture [[texture(lightPassAreaLTCMatTextureIndex)]],
                                    constant simd_float4x4 &lightOrthoView [[buffer(lightPassLightOrthoViewMatrixIndex)]],
                                    constant simd_float3 &cameraPosition [[buffer(lightPassCameraPositionIndex)]],
                                    constant LightParameters &lights [[buffer(lightPassLightParamsIndex)]],
                                    constant PointLightUniform *pointLights [[buffer(lightPassPointLightsIndex)]],
                                    constant int *pointLightsCount [[buffer(lightPassPointLightsCountIndex)]],
                                    constant SpotLightUniform *spotLights [[buffer(lightPassSpotLightsIndex)]],
                                    constant int *spotLightsCount [[buffer(lightPassSpotLightsCountIndex)]],
                                   constant IBLParamsUniform &iblParam [[buffer(lightPassIBLParamIndex)]],
                                  constant AreaLightUniform *areaLights[[buffer(lightPassAreaLightsIndex)]],
                                  constant int *areaLightsCount [[buffer(lightPassAreaLightsCountIndex)]],
                                  constant float &iblRotationAngle [[buffer(lightPassIBLRotationAngleIndex)]],
                                    constant bool &isGameMode[[buffer(lightPassGameModeIndex)]]
                                    ){

   // Base Color and Normal Maps: Linear filtering, mipmaps, repeat wrapping
    constexpr sampler s(min_filter::linear, mag_filter::linear, mip_filter::linear, s_address::repeat, t_address::repeat);
    
    constexpr sampler positionSampler(min_filter::linear, mag_filter::linear, mip_filter::linear,
                                    s_address::clamp_to_edge, t_address::clamp_to_edge);
    
     constexpr sampler normalSampler(min_filter::linear, mag_filter::linear, mip_filter::linear,
                                     s_address::clamp_to_edge, t_address::clamp_to_edge);

     // Roughness and Metallic: Linear filtering, mipmaps, default to repeat wrapping
     constexpr sampler materialSampler(min_filter::linear, mag_filter::linear, mip_filter::linear,
                                       s_address::clamp_to_edge, t_address::clamp_to_edge);
     
    constexpr sampler ssaoSampler(min_filter::linear, mag_filter::linear, mip_filter::linear,
                                    s_address::clamp_to_edge, t_address::clamp_to_edge);

    MaterialParametersUniform materialParameter;
    materialParameter.edgeTint = float4(0.0,0.0,0.0,0.0);
    float3 lightRayDirection=normalize(lights.direction);
    
    // sample textures

    float4 albedo=albedoMap.sample(s, vertexOut.uvCoords);
    float4 verticesInWorldSpace = positionMap.sample(positionSampler, vertexOut.uvCoords);
    float3 surfaceNormal = normalMap.sample(normalSampler, vertexOut.uvCoords).xyz;
    float roughness = materialMap.sample(materialSampler, vertexOut.uvCoords).r;
    float metallic = materialMap.sample(materialSampler, vertexOut.uvCoords).g;
    float ambientOcclusion = ssaoTexture.sample(ssaoSampler, vertexOut.uvCoords).r;
    
    if(!isGameMode){
        ambientOcclusion = 1.0;
    }
    
    float3 viewVector=normalize(cameraPosition-verticesInWorldSpace.xyz);
   
    //compute ibl ambient contribution
    float3 indirectLighting=computeIBLContribution(irradianceTexture,
                                              specularTexture,
                                              iblBRDFTexture,
                                              iblRotationAngle,
                                              iblParam,
                                              materialParameter,
                                              albedo,
                                              surfaceNormal,
                                              viewVector,
                                              roughness,
                                              metallic);
    
    indirectLighting *= ambientOcclusion*iblParam.ambientIntensity;
    
    indirectLighting = ACESFilmicToneMapping(indirectLighting);
    
    // Compute BRDF
    float3 brdf=float3(0.0);
    
    brdf=computeBRDF(lightRayDirection, viewVector, surfaceNormal, albedo.rgb, float3(1.0), materialParameter,roughness,metallic);
    
    float4 color = float4(brdf*lights.color*lights.intensity,1.0);
    
    float4 shadowCoords = lightOrthoView * float4(verticesInWorldSpace.xyz,1.0);
    
    // Compute shadow
    float shadow = computeShadow(shadowCoords, shadowTexture, surfaceNormal, lightRayDirection);
   
    // shadows affect directional light for now
    color = color*shadow;
    
    // compute point ligth contribution
    float4 pointColor=simd_float4(0.0);

    for(int i=0; i<pointLightsCount[0];i++){

        pointColor += computePointLightContribution(pointLights[i],
                                                    verticesInWorldSpace,
                                                    viewVector,
                                                    surfaceNormal,
                                                    materialParameter,
                                                    albedo.rgb,
                                                    roughness,
                                                    metallic);
    }

    color+=pointColor;
    
    // Compute spot light contribution
    float4 spotLightColor = simd_float4(0.0);
    
    for(int i=0; i<spotLightsCount[0]; i++){
        spotLightColor += computeSpotLightContribution(spotLights[i],
                                                       verticesInWorldSpace,
                                                       viewVector,
                                                       surfaceNormal,
                                                       materialParameter,
                                                       albedo.rgb,
                                                       roughness,
                                                       metallic);
    }
    
    color += spotLightColor;
    
    // Compute Area Light contribution
    simd_float4 areaLightColor = simd_float4(0.0);
    
    for (int i=0; i<areaLightsCount[0]; i++){
        
        areaLightColor += evaluateAreaLight(areaLights[i],
                                               verticesInWorldSpace,
                                               viewVector,
                                                surfaceNormal,
                                               ltcMatTexture,
                                               ltcMagTexture,
                                               materialParameter,
                                                albedo.rgb,
                                               roughness,
                                               metallic);
    }
    
    color += areaLightColor;

    color = float4(color.rgb + indirectLighting,1.0);
    
    return color;

}



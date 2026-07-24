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

    constexpr sampler shadowSampler(
        coord::normalized,
        filter::linear,
        address::clamp_to_edge,
        compare_func::less_equal
    );
    float2 texelSize = 1.0 / float2(shadowArray.get_width(), shadowArray.get_height());

    float NoL = clamp(dot(normalize(normal), normalize(lightDir)), 0.0, 1.0);
    float bias = max(0.0011 * (1.0 - NoL), 0.0003);
    float currentDepth = proj.z;
    float shadowDistance = max(csm.cascadeSplits[max(csm.cascadeCount - 1, 0)], 0.001);
    float depthFade = clamp(viewDepth / shadowDistance, 0.0, 1.0) * clamp(csm.shadowSoftnessDepthScale, 0.0, 2.0);
    float nearRadius = max(csm.shadowSoftnessNear, 0.25);
    float farRadius = max(csm.shadowSoftnessFar, nearRadius);
    float filterRadius = csm.shadowSoftnessEnabled > 0.5
        ? mix(nearRadius, farRadius, clamp(depthFade, 0.0, 1.0))
        : 1.0;

    float shadow = 0.0;
    for (int i = 0; i < 16; ++i) {
        float2 offset = poissonDisk[i] * texelSize * filterRadius;
        shadow += shadowArray.sample_compare(shadowSampler, proj.xy + offset, cascade, currentDepth - bias);
    }
    return shadow / 16.0;
}

float computeSpotShadow(
    depth2d<float> shadowMap,
    constant SpotShadowUniforms &spotShadow,
    constant SpotLightUniform &light,
    float3 worldPos,
    float3 normal
) {
    if (spotShadow.enabled < 0.5) {
        return 1.0;
    }

    float4 shadowCoords = spotShadow.lightSpaceMatrix * float4(worldPos, 1.0);
    if (shadowCoords.w <= 0.0) {
        return 1.0;
    }

    float3 proj = shadowCoords.xyz / shadowCoords.w;
    proj.xy = proj.xy * 0.5 + 0.5;
    proj.y = 1.0 - proj.y;

    if (proj.x < 0.0 || proj.x > 1.0 ||
        proj.y < 0.0 || proj.y > 1.0 ||
        proj.z < 0.0 || proj.z > 1.0) {
        return 1.0;
    }

    constexpr sampler shadowSampler(
        coord::normalized,
        filter::linear,
        address::clamp_to_edge,
        compare_func::less_equal
    );

    float2 texelSize = 1.0 / float2(shadowMap.get_width(), shadowMap.get_height());
    float lightDistance = max(length(light.position - worldPos), 1.0e-3);
    float projectionScale = 0.5 * float(shadowMap.get_width())
        / max(tan(max(light.outerCone, 1.0e-3)), 1.0e-3);
    float radius = light.attenuation.x < 0.0
        ? clamp(
            (max(spotShadow.shadowSoftness, 1.0e-3) / lightDistance) * projectionScale,
            0.75,
            12.0
        )
        : max(spotShadow.shadowSoftness, 0.25);
    float3 lightDirection = normalize(light.position - worldPos);
    float NoL = clamp(dot(normalize(normal), lightDirection), 0.0, 1.0);
    float receiverBias = spotShadow.bias * mix(3.0, 1.0, NoL);
    float shadow = 0.0;
    for (int i = 0; i < 16; ++i) {
        float2 offset = poissonDisk[i] * texelSize * radius;
        shadow += shadowMap.sample_compare(shadowSampler, proj.xy + offset, proj.z - receiverBias);
    }
    return shadow / 16.0;
}

float computePointShadow(
    depthcube<float> shadowCube,
    constant PointShadowUniforms &pointShadow,
    float sourceRadius,
    float3 worldPos,
    float3 normal
) {
    if (pointShadow.enabled < 0.5) {
        return 1.0;
    }

    float3 lightToFragment = worldPos - pointShadow.lightPosition;
    float distanceToLight = length(lightToFragment);
    float farDistance = max(pointShadow.farDistance, 0.001);
    if (distanceToLight <= 0.001 || distanceToLight > farDistance) {
        return 1.0;
    }

    // The depth cube stores the perspective depth of the selected cube face.
    // Match that face-space depth by using the dominant axis, not radial distance.
    constexpr float nearDistance = 0.05;
    float3 absLightToFragment = abs(lightToFragment);
    float faceDepth;
    float2 ndc;
    uint face;

    if (absLightToFragment.x >= absLightToFragment.y && absLightToFragment.x >= absLightToFragment.z) {
        if (lightToFragment.x >= 0.0) {
            face = 0;
            faceDepth = lightToFragment.x;
            ndc = float2(-lightToFragment.z, -lightToFragment.y) / faceDepth;
        } else {
            face = 1;
            faceDepth = -lightToFragment.x;
            ndc = float2(lightToFragment.z, -lightToFragment.y) / faceDepth;
        }
    } else if (absLightToFragment.y >= absLightToFragment.z) {
        if (lightToFragment.y >= 0.0) {
            face = 2;
            faceDepth = lightToFragment.y;
            ndc = float2(lightToFragment.x, lightToFragment.z) / faceDepth;
        } else {
            face = 3;
            faceDepth = -lightToFragment.y;
            ndc = float2(lightToFragment.x, -lightToFragment.z) / faceDepth;
        }
    } else {
        if (lightToFragment.z >= 0.0) {
            face = 4;
            faceDepth = lightToFragment.z;
            ndc = float2(lightToFragment.x, -lightToFragment.y) / faceDepth;
        } else {
            face = 5;
            faceDepth = -lightToFragment.z;
            ndc = float2(-lightToFragment.x, -lightToFragment.y) / faceDepth;
        }
    }

    float projectedDepth = farDistance / (farDistance - nearDistance)
        - (farDistance * nearDistance) / ((farDistance - nearDistance) * faceDepth);

    // Metal origin is top-left, same flip as computeCSMShadow/computeSpotShadow.
    ndc.y = -ndc.y;

    float cubeSize = max(float(shadowCube.get_width()), 1.0);
    float2 texelSize = 1.0 / float2(cubeSize, cubeSize);
    float radius = sourceRadius > 0.0
        ? clamp(
            (max(sourceRadius, pointShadow.shadowSoftness) / max(distanceToLight, 1.0e-3)) * cubeSize * 0.5,
            0.75,
            12.0
        )
        : max(pointShadow.shadowSoftness, 0.25);
    float3 fragmentToLight = normalize(pointShadow.lightPosition - worldPos);
    float NoL = clamp(dot(normalize(normal), fragmentToLight), 0.0, 1.0);
    float receiverBias = pointShadow.bias * mix(3.0, 1.0, NoL);
    float shadow = 0.0;
    for (int i = 0; i < 16; ++i) {
        float2 uv = (ndc * 0.5 + 0.5) + poissonDisk[i] * texelSize * radius;
        uv = clamp(uv, float2(0.0), float2(1.0));
        uint2 texel = uint2(clamp(uv * (cubeSize - 1.0), float2(0.0), float2(cubeSize - 1.0)));
        float storedDepth = shadowCube.read(texel, face);
        shadow += ((projectedDepth - receiverBias) <= storedDepth) ? 1.0 : 0.0;
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
    float3 lightDelta = light.position.xyz - verticesInWorldSpace.xyz;
    float lightDistance = length(lightDelta);
    float3 lightDirection = lightDelta * rsqrt(max(dot(lightDelta, lightDelta), 1.0e-8));

    LightContribution br=computeBRDF(lightDirection, viewVector, normalMap.xyz, inBaseColor, float3(1.0), roughness,metallic);

    float attenuation=calculateAttenuation(lightDistance, light.attenuation, light.radius);
    float intensity = light.intensity;
    if (light.attenuation.x < 0.0) {
        // Blender point-light power is radiant flux in watts. Convert an
        // isotropic emitter to radiant intensity (W/sr).
        intensity *= 1.0 / (4.0 * M_PI_F);
    }

    LightContribution outC;
    outC.diff = br.diff * (half)attenuation * (half)intensity * (half3)light.color;
    outC.spec = br.spec * attenuation * intensity * (float3)light.color;
        
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
    
    float3 lightDelta = light.position.xyz - verticesInWorldSpace.xyz;
    float lightDistance = length(lightDelta);
    float3 lightDirection = lightDelta * rsqrt(max(dot(lightDelta, lightDelta), 1.0e-8));
    float directionLen2 = dot(light.direction.xyz, light.direction.xyz);
    float3 spotDirection = directionLen2 > 1.0e-8 ? light.direction.xyz * rsqrt(directionLen2) : float3(0.0, -1.0, 0.0);
    
    float attenuation=calculateAttenuation(lightDistance, light.attenuation, light.radius);
    
    LightContribution br=computeBRDF(lightDirection, viewVector, normalMap.xyz, inBaseColor, float3(1.0), roughness,metallic);
    
    float theta = dot(-lightDirection, spotDirection); // cosine of angle between light dir and spot dir
    float innerCone = clamp(light.innerCone, 0.0, M_PI_F - 1.0e-4);
    float outerCone = clamp(light.outerCone, innerCone + 1.0e-4, M_PI_F);
    float outerCos = cos(outerCone);
    float epsilon = max(cos(innerCone) - outerCos, 1.0e-4);
    float coneFalloff = clamp((theta - outerCos) / epsilon, 0.0, 1.0);
    float intensity = light.intensity;
    if (light.attenuation.x < 0.0) {
        // Normalize radiant power over the authored spot cone. The smooth
        // edge makes this an approximation, but it preserves power far more
        // closely than treating watts as arbitrary shader intensity.
        float coneSolidAngle = max(2.0 * M_PI_F * (1.0 - outerCos), 1.0e-4);
        intensity /= coneSolidAngle;
    }
    
    LightContribution outC;
    outC.diff = br.diff * (half)attenuation * (half)coneFalloff * (half)intensity * half3(light.color);
    outC.spec = br.spec * attenuation * coneFalloff * intensity * light.color;
    
    return outC;
}

static inline float areaLightSurfaceDistance(constant AreaLightUniform &light,
                                             float3 P,
                                             float3 emittingNormal) {
    float3 rightN = normalize(light.right);
    float3 upN = normalize(light.up);
    float3 toLightSample = P - light.position;
    float planeDistance = abs(dot(toLightSample, emittingNormal));
    float2 rectangleDistance = abs(float2(dot(toLightSample, rightN), dot(toLightSample, upN))) - light.bounds * 0.5;
    float edgeDistance = length(max(rectangleDistance, float2(0.0)));
    return length(float2(planeDistance, edgeDistance));
}

static inline float areaLightRangeAttenuation(constant AreaLightUniform &light,
                                              float3 P,
                                              float3 emittingNormal) {
    if (light.range <= 0.0) {
        return 1.0;
    }

    float distanceToLight = areaLightSurfaceDistance(light, P, emittingNormal);
    return 1.0 - smoothstep(light.range * 0.75, light.range, distanceToLight);
}

static inline float areaLightNearSourceAttenuation(constant AreaLightUniform &light,
                                                   float3 P,
                                                   float3 emittingNormal) {
    if (light.nearSourceSuppressionRadius <= 0.0) {
        return 1.0;
    }

    float sourceDistance = areaLightSurfaceDistance(light, P, emittingNormal);
    return smoothstep(
        light.nearSourceSuppressionRadius * 0.35,
        light.nearSourceSuppressionRadius,
        sourceDistance
    );
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
    
    float NoV = clamp(dot(normalMap, viewVector), 0.0, 1.0);
    float theta = acos(NoV);
    float2 uv = float2(clamp(roughness, 0.0, 1.0), theta / (0.5 * M_PI_F));
    uv = uv * LUT_SCALE + LUT_BIAS;

    
    float4 t = ltcMat.sample(s, uv);
    float4 t2 = ltcMag.sample(s,uv);

    if (light.bounds.x <= 0.0 || light.bounds.y <= 0.0) {
        LightContribution outC;
        return outC;
    }
    
    float3x3 Minv= float3x3(float3(t.x,0,t.y),
                            float3(0,1.0,0),
                            float3(t.z,0,t.w));
    Minv=transpose(Minv);
    
    float3 P = verticesInWorldSpace.xyz;
    
    // Compute corners
    float3 u = normalize(light.right) * light.bounds.x;
    float3 v = normalize(light.up) * light.bounds.y;
    float3 p0 = light.position - 0.5 * u - 0.5 * v;
    float3 p1 = light.position + 0.5 * u - 0.5 * v;
    float3 p2 = light.position + 0.5 * u + 0.5 * v;
    float3 p3 = light.position - 0.5 * u + 0.5 * v;

    float3 points[4];
    float3 areaNormalRaw = cross(u, v);
    float areaNormalLen2 = dot(areaNormalRaw, areaNormalRaw);
    float3 areaNormal = areaNormalLen2 > 1.0e-8 ? areaNormalRaw * rsqrt(areaNormalLen2) : float3(0.0, 0.0, 1.0);
    float forwardLen2 = dot(light.forward, light.forward);
    float3 emittingNormal = forwardLen2 > 1.0e-8 ? light.forward * rsqrt(forwardLen2) : areaNormal;
    if (dot(areaNormal, emittingNormal) >= 0.0) {
        points[0]=p0;
        points[1]=p1;
        points[2]=p2;
        points[3]=p3;
    } else {
        points[0]=p0;
        points[1]=p3;
        points[2]=p2;
        points[3]=p1;
    }
    
    float3x3 identity=float3x3(float3(1.0,0.0,0.0),
                               float3(0.0,1.0,0.0),
                               float3(0.0,0.0,1.0));
    float3 Lo_spec=LTC_Evaluate(normalMap.xyz, viewVector, P,Minv, points, light.twoSided);

    float3 Lo_diffuse = LTC_Evaluate(normalMap.xyz, viewVector, P,identity, points, light.twoSided);

    float3 f0 = mix(float3(0.04), inBaseColor.rgb, metallic);
    float3 fresnelScale = f0 * t2.x + (1.0 - f0) * t2.y;
    float3 diffuseBRDF = inBaseColor.rgb * (1.0 - metallic);
    float lightAttenuation = areaLightRangeAttenuation(light, P, emittingNormal)
        * areaLightNearSourceAttenuation(light, P, emittingNormal);
    
    LightContribution outC;
    outC.diff = (half3)(lightAttenuation * light.intensity * light.color * Lo_diffuse * diffuseBRDF);
    outC.spec = lightAttenuation * light.intensity * light.color * Lo_spec * fresnelScale;

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
                                    depthcube<float> pointShadowCube [[texture(lightPassPointShadowTextureIndex)]],
                                    depth2d<float> spotShadowMap [[texture(lightPassSpotShadowTextureIndex)]],
                                    constant CSMUniforms &csmUniforms [[buffer(lightPassLightOrthoViewMatrixIndex)]],
                                    constant simd_float3 &cameraPosition [[buffer(lightPassCameraPositionIndex)]],
                                    constant LightParameters &lights [[buffer(lightPassLightParamsIndex)]],
                                    constant PointLightBlock &plBlock[[buffer(lightPassPointLightsIndex)]],
                                    constant SpotLightBlock &slBlock[[buffer(lightPassSpotLightsIndex)]],
                                    constant IBLParamsUniform &iblParam [[buffer(lightPassIBLParamIndex)]],
                                    constant AreaLightBlock &alBlock[[buffer(lightPassAreaLightsIndex)]],
                                    constant float &iblRotationAngle [[buffer(lightPassIBLRotationAngleIndex)]],
                                    constant bool &isGameMode[[buffer(lightPassGameModeIndex)]],
                                    constant bool &ssaoEnabled[[buffer(lightPassSSAOEnabledIndex)]],
                                    constant PointShadowUniforms &pointShadowUniforms [[buffer(lightPassPointShadowUniformIndex)]],
                                    constant SpotShadowUniforms &spotShadowUniforms [[buffer(lightPassSpotShadowUniformIndex)]]
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
        if (pointShadowUniforms.enabled > 0.5 && int(i) == pointShadowUniforms.lightIndex) {
            float pointShadow = computePointShadow(
                pointShadowCube,
                pointShadowUniforms,
                plBlock.lights[i].attenuation.x < 0.0 ? plBlock.lights[i].radius : 0.0,
                verticesInWorldSpace.xyz,
                surfaceNormal
            );
            pl.diff *= (half)pointShadow;
            pl.spec *= pointShadow;
        }
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
        if (spotShadowUniforms.enabled > 0.5 && int(i) == spotShadowUniforms.lightIndex) {
            float spotShadow = computeSpotShadow(
                spotShadowMap,
                spotShadowUniforms,
                slBlock.lights[i],
                verticesInWorldSpace.xyz,
                surfaceNormal
            );
            sl.diff *= (half)spotShadow;
            sl.spec *= spotShadow;
        }
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
    depthcube<float>     pointShadowCube   [[texture(lightPassPointShadowTextureIndex)]],
    depth2d<float>       spotShadowMap     [[texture(lightPassSpotShadowTextureIndex)]],
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
    constant PointShadowUniforms &pointShadowUniforms [[buffer(lightPassPointShadowUniformIndex)]],
    constant SpotShadowUniforms &spotShadowUniforms [[buffer(lightPassSpotShadowUniformIndex)]],
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
        if (pointShadowUniforms.enabled > 0.5 && int(i) == pointShadowUniforms.lightIndex) {
            float pointShadow = computePointShadow(
                pointShadowCube,
                pointShadowUniforms,
                plBlock.lights[i].attenuation.x < 0.0 ? plBlock.lights[i].radius : 0.0,
                verticesInWorldSpace.xyz,
                surfaceNormal
            );
            pl.diff *= (half)pointShadow;
            pl.spec *= pointShadow;
        }
        pointColor.diff += pl.diff;
        pointColor.spec += pl.spec;
    }
    color.diff += pointColor.diff;
    color.spec += pointColor.spec;

    LightContribution spotLightColor;
    uint spotLightCount = min(slBlock.count.x, MAX_POINT_LIGHTS);
    for (uint i = 0; i < spotLightCount; ++i) {
        LightContribution sl = computeSpotLightContribution(slBlock.lights[i], verticesInWorldSpace, viewVector, surfaceNormal, albedo.rgb, roughness, metallic);
        if (spotShadowUniforms.enabled > 0.5 && int(i) == spotShadowUniforms.lightIndex) {
            float spotShadow = computeSpotShadow(
                spotShadowMap,
                spotShadowUniforms,
                slBlock.lights[i],
                verticesInWorldSpace.xyz,
                surfaceNormal
            );
            sl.diff *= (half)spotShadow;
            sl.spec *= spotShadow;
        }
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

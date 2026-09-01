//
//  ShadersUtils.h
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#ifndef ShadersUtils_h
#define ShadersUtils_h
using namespace metal;

// Centered Poisson disk used for shadow PCF.
constant float2 poissonDisk[16]={float2( -0.434858, -0.952086 ),
    float2( 0.585314, 0.891476 ),
    float2( 0.844722, -0.176488 ),
    float2( -0.668324, 0.105990 ),
    float2( 0.132054, -0.566698),
    float2( -0.329204,0.567308),
    float2( -0.961852,-0.362956),
    float2( 0.295144,0.163792),
    float2( 0.832576,-0.975952),
    float2( -0.944334,0.733268),
    float2( -0.203894,-0.157200),
    float2( -0.994202,-0.897702),
    float2( 0.035248,0.978088),
    float2( 0.927488,0.439802),
    float2( 0.537340,-0.963744),
    float2( 0.368388,-0.665396)
};

// Used for Area Lighting
constant float LUT_SIZE = 64.0;
constant float LUT_SCALE = (LUT_SIZE - 1.0)/LUT_SIZE;
constant float LUT_BIAS  = 0.5/LUT_SIZE;

struct LightContribution {
    half3 diff = half3(0.0);
    float3 spec = float3(0.0);
};

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

float degreesToRadians(float degrees);

float3 rotateDirection(float3 dir, float3 axis, float angle);

void transformToLogDepth(thread simd_float4 &position, float far);

float3x3 rotation_matrix(float3 axis, float angle);

float4x4 rotationmatrix4x4(float3 axis, float angle);

float calculateAttenuation(float distance, simd_float4 attenuation, float sourceRadius);

float mod(float x, float y);

float selectTextureChannel(float4 sample, int channel);

void transformToLogDepth(thread simd_float4 &position, float far);

//BRDF - Great intro: https://boksajak.github.io/files/CrashCourseBRDF.pdf 

float3 fresnelSchlick(float cosTheta,float3 F0);

float distributionGGX(float NoH,float roughness);

float g1GGXSchlick(float NoV, float roughness);

float geometricSmith(float NoV, float NoL,float roughness);

// Cook-Torrance BRDF function - Refer to https://graphicscompendium.com/gamedev/15-pbr
LightContribution computeBRDF(float3 incomingLightDir, float3 viewDir, float3 surfaceNormal, float3 diffuseColor, float3 specularColor, float roughnessMap, float metallicMap);

half3 computeDiffuseBRDF(float3 incomingLightDir, float3 viewDir, float3 surfaceNormal, float3 diffuseColor, float3 specularColor, float roughnessMap, float metallicMap);

float3 computeSpecBRDF(float3 incomingLightDir, float3 viewDir, float3 surfaceNormal, float3 diffuseColor, float3 specularColor, float roughnessMap, float metallicMap);



float3 blinnBRDF(float3 incomingLightDir, float3 viewDir, float3 surfaceNormal, float3 diffuseColor, float3 specularColor, float shininess);

float3 phongBRDF(float3 incomingLightDir, float3 viewDir, float3 surfaceNormal, float3 diffuseColor, float3 specularColor, float shininess);

//Gulbransen Parametrization
//Refer to http://jcgt.org/published/0003/04/03/paper.pdf
//https://nbviewer.org/github/belcour/sig2020_fresnel_decomposition/blob/master/notebook.ipynb

float n_min(float r);

float n_max(float r);

float get_n(float r,float g);

float get_k2(float r, float n);

float get_r(float n, float k);

float get_g(float n, float k);

float artistFriendlyF0(float r, float g,float theta);

float3 artistFriendlF0Vector(float f0);

//IBL - Refer to: https://www.youtube.com/watch?v=MkFS6lw6aEs&t=1882s

float2 directionToSphericalEnvmap(float3 dir);

float3x3 getNormalSpace(float3 normal);

float radicalInverse(uint bits);

float2 hammersley(uint n, uint N);

float random2(float2 n);

float4 diffuseImportanceMap(float2 texCoords, texture2d<float> environmentTexture);

float4 specularImportanceMap(float2 texCoords, texture2d<float> environmentTexture, float roughness);

float4 BRDFIntegrationMap(float roughness, float NoV);

// adapted from "Real Shading in Unreal Engine 4", Brian Karis, Epic Games
// https://cdn2.unrealengine.com/Resources/files/2013SiggraphPresentationsNotes-26915738.pdf
float3 specularIBL(float3 F0 , float roughness, float3 N, float3 V, texture2d<float> specularMap, texture2d<float> brdfMap, float3 rotationAxis, float rotationAngle);

float3 diffuseIBL(float3 normal, texture2d<float> irradianceMap, float3 rotationAxis, float rotationAngle);

float computeCSMShadow(depth2d_array<float> shadowArray,
                       constant CSMUniforms &csm,
                       float3 worldPos,
                       float3 cameraPos,
                       float3 normal,
                       float3 lightDir);

float3 computeIBLContribution(texture2d<float> irradianceTexture,
                              texture2d<float> specularTexture,
                              texture2d<float> iblBRDFTexture,
                              constant float &iblRotationAngle,
                              constant IBLParamsUniform &iblParam,
                              float4 inBaseColor,
                              float3 normalMap,
                              float3 viewVector,
                              float roughness,
                              float metallic);

LightContribution computePointLightContribution(constant PointLightUniform &light,
                                                float4 verticesInWorldSpace,
                                                float3 viewVector,
                                                float3 normalMap,
                                                float3 inBaseColor,
                                                float roughness,
                                                float metallic);

LightContribution computeSpotLightContribution(constant SpotLightUniform &light,
                                               float4 verticesInWorldSpace,
                                               float3 viewVector,
                                               float3 normalMap,
                                               float3 inBaseColor,
                                               float roughness,
                                               float metallic);

LightContribution evaluateAreaLight(constant AreaLightUniform &light,
                                    float4 verticesInWorldSpace,
                                    float3 viewVector,
                                    float3 normalMap,
                                    texture2d<float> ltcMat,
                                    texture2d<float> ltcMag,
                                    float3 inBaseColor,
                                    float roughness,
                                    float metallic);

float3 ACESFilmicToneMapping(float3 x);

// Filmic/Uncharted 2 Tone Mapping Function
float3 filmicToneMapping(float3 x);

// Reinhard Tone Mapping Function
float3 reinhardToneMapping(float3 color);

// AgX Tone Mapping (Blender's default View Transform since 4.0). See the
// implementation comment in ShadersUtils.metal for the exact domain contract.
float3 agxToneMapping(float3 color);

void createBasis(float3 normal, thread float &tangent,  thread float &bitangent);

float computeLuma(float3 color);

float linearizeDepthForViewing(float depth, float near, float far);

float linearizeDepth(float depth, float near, float far);
float linearizeDepth(float depth, float near, float far, bool reverseZ);


float integrateEdge(float3 v1, float3 v2);

float3 LTC_Evaluate(float3 N, float3 V, float3 P, float3x3 Minv, float3 points[4], bool twoSided);

float getLuminance(float3 color);

#endif /* ShadersUtils_h */

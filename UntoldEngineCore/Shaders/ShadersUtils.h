//
//  ShadersUtils.h
//  UntoldEngine
//
//  Created by Harold Serrano on 11/25/23.
//

#ifndef ShadersUtils_h
#define ShadersUtils_h
using namespace metal;

//This is used for shadows
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

float degreesToRadians(float degrees);

//BRDF
float3 fresnelSchlick(float cosTheta,float3 F0);

float D_GGX(float NoH,float roughness);

float G1_GGX_Schlick(float NoV, float roughness);

float G_smith(float NoV, float NoL,float roughness);

// Cook-Torrance BRDF function
float3 cookTorranceBRDF(float3 incomingLightDir, float3 surfaceNormal, float3 viewDir, float3 diffuseColor, float3 specularColor, float roughness, float metallic, float reflectance);


//IBL
float2 directionToSphericalEnvmap(float3 dir);

float3x3 getNormalSpace(float3 normal);

float radicalInverse(uint bits);

float2 hammersley(uint n, uint N);

float random2(float2 n);

float4 diffuseImportanceMap(float2 texCoords, texture2d<float> environmentTexture);

float4 specularImportanceMap(float2 texCoords, texture2d<float> environmentTexture);

float4 BRDFIntegrationMap(float roughness, float NoV);

// adapted from "Real Shading in Unreal Engine 4", Brian Karis, Epic Games
// https://cdn2.unrealengine.com/Resources/files/2013SiggraphPresentationsNotes-26915738.pdf
float3 specularIBL(float3 F0 , float roughness, float3 N, float3 V, texture2d<float> specularMap, texture2d<float> brdfMap);

float3 diffuseIBL(float3 normal, texture2d<float> irradianceMap);


float3x3 rotation_matrix(float3 axis, float angle);

float calculateAttenuation(float distance, simd_float4 attenuation);

#endif /* ShadersUtils_h */

//
//  ShadersUtils.h
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
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

// Used for Area Lighting
constant float LUT_SIZE = 64.0;
constant float LUT_SCALE = (LUT_SIZE - 1.0)/LUT_SIZE;
constant float LUT_BIAS  = 0.5/LUT_SIZE;

float degreesToRadians(float degrees);

float3 rotateDirection(float3 dir, float3 axis, float angle);

void transformToLogDepth(thread simd_float4 &position, float far);

float3x3 rotation_matrix(float3 axis, float angle);

float4x4 rotationmatrix4x4(float3 axis, float angle);

float calculateAttenuation(float distance, simd_float4 attenuation, float radius);

float mod(float x, float y);

void transformToLogDepth(thread simd_float4 &position, float far);

//BRDF - Great intro: https://boksajak.github.io/files/CrashCourseBRDF.pdf 

float3 fresnelSchlick(float cosTheta,float3 F0);

float distributionGGX(float NoH,float roughness);

float g1GGXSchlick(float NoV, float roughness);

float geometricSmith(float NoV, float NoL,float roughness);

// Cook-Torrance BRDF function - Refer to https://graphicscompendium.com/gamedev/15-pbr
LightContribution computeBRDF(float3 incomingLightDir, float3 viewDir, float3 surfaceNormal, float3 diffuseColor, float3 specularColor, MaterialParametersUniform materialParam,float roughnessMap, float metallicMap);

half3 computeDiffuseBRDF(float3 incomingLightDir, float3 viewDir, float3 surfaceNormal, float3 diffuseColor, float3 specularColor, MaterialParametersUniform materialParam,float roughnessMap, float metallicMap);

float3 computeSpecBRDF(float3 incomingLightDir, float3 viewDir, float3 surfaceNormal, float3 diffuseColor, float3 specularColor, MaterialParametersUniform materialParam,float roughnessMap, float metallicMap);



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

float4 specularImportanceMap(float2 texCoords, texture2d<float> environmentTexture);

float4 BRDFIntegrationMap(float roughness, float NoV);

// adapted from "Real Shading in Unreal Engine 4", Brian Karis, Epic Games
// https://cdn2.unrealengine.com/Resources/files/2013SiggraphPresentationsNotes-26915738.pdf
float3 specularIBL(float3 F0 , float roughness, float3 N, float3 V, texture2d<float> specularMap, texture2d<float> brdfMap, float3 rotationAxis, float rotationAngle);

float3 diffuseIBL(float3 normal, texture2d<float> irradianceMap, float3 rotationAxis, float rotationAngle);

float3 ACESFilmicToneMapping(float3 x);

// Filmic/Uncharted 2 Tone Mapping Function
float3 filmicToneMapping(float3 x);

// Reinhard Tone Mapping Function
float3 reinhardToneMapping(float3 color);

void createBasis(float3 normal, thread float &tangent,  thread float &bitangent);

float computeLuma(float3 color);

float linearizeDepthForViewing(float depth, float near, float far);

float linearizeDepth(float depth, float near, float far);


float integrateEdge(float3 v1, float3 v2);

float3 LTC_Evaluate(float3 N, float3 V, float3 P, float3x3 Minv, float3 points[4], bool twoSided);

float getLuminance(float3 color);

#endif /* ShadersUtils_h */

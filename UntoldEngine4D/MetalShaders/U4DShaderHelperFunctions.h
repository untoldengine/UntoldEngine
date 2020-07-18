//
//  U4DShaderHelperFunctions.h
//  UntoldEngine
//
//  Created by Harold Serrano on 10/22/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DShaderHelperFunctions_h
#define U4DShaderHelperFunctions_h

struct LightColor{
    
    float3 ambientColor;
    float3 diffuseColor;
    float3 specularColor;
};

struct Material{
    
    float3 ambientMaterialColor;
    float3 diffuseMaterialColor;
    float3 specularMaterialColor;
    float specularReflectionPower;
};

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

/**
 @brief random functions for 1d
 */
float random(float u);

/**
 @brief random functions for 2d
 */
float random(float2 st);

/**
 @brief hash function
 */
float2 hash(float2 u);

/**
 @brief Value noise
 @param st 2d coordinates
 */
float valueNoise(float2 st);

/**
 @brief Gradient noise
 @param st 2d coordinates
 */
float noise(float2 st);

/**
 @brief computes the light color for the 3d object
 @param uLightPosition light position
 @param uVerticesInMVSpace verts in Model-View Space
 @param uNormalInMVSpace normal vectors in Model-View Space
 @param uMaterial Material properties
 @param uLightColor light color properties
 */
float4 computeLights(float4 uLightPosition, float4 uVerticesInMVSpace, float3 uNormalInMVSpace, Material uMaterial, LightColor uLightColor);

/**
 @brief Computes mod
 */
float mod(float x, float y);

#endif /* U4DShaderHelperFunctions_h */

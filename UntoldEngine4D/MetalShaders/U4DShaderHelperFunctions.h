//
//  U4DShaderHelperFunctions.h
//  UntoldEngine
//
//  Created by Harold Serrano on 10/22/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DShaderHelperFunctions_h
#define U4DShaderHelperFunctions_h

struct Light{
    
    float3 ambientColor;
    float3 diffuseColor;
    float3 specularColor;
    float4 position;
    float constantAttenuation;
    float linearAttenuation;
    float expAttenuation;
    float energy;
    float falloutDistance;
    
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

#define M_PI 3.1415926535897932384626433832795

constant float3 backgroundColor=float3(0.20,0.23,0.28);
constant float3 foregroundColor=float3(0.88,0.69,0.17);
constant float3 panelColor=float3(0.2,0.23,0.28);
constant float3 borderPanelColor=float3(0.96,0.964,0.98);

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
float4 computeLightColor(float4 uVerticesInMVSpace, float3 uNormalInMVSpace, Material uMaterial, Light uLight);

float4 computePointLightColor(float4 uVerticesInMVSpace, float3 uNormalInMVSpace, Material uMaterial, Light uLight);

/**
 @brief Computes the modulus
 */
float mod(float x, float y);

/**
 @brief sharpens the sdf object
 */
float sharpen(float d, float w, float2 resolution);

/**
 @brief sdf for a circle
 @param p space coordinate, i.e. st
 @param r circle radius
 */
float sdfCircle(float2 p,float r);

/**
 @brief sdf for a ring
 @param p space coordinate, i.e. st
 @param c ring center
 @param r ring inner radius
*/
float sdfRing(float2 p, float2 c, float r);

/**
 @brief sdf for a line
 @param p space coordnate, i.e. st
 @param a starting point of line
 @param b ending point of line
 */
float sdfLine( float2 p, float2 a, float2 b);

/**
 @brief sdf for a triangle
 @param p space coordinate, i.e. st
 */
float sdfTriangle(float2 p );

float sdfBox( float2 p, float2 b);

#endif /* U4DShaderHelperFunctions_h */

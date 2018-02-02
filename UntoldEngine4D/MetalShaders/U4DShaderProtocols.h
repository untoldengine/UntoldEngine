//
//  U4DShaderProtocols.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/14/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DShaderProtocols_h
#define U4DShaderProtocols_h

#include <simd/simd.h>

typedef struct{
    matrix_float4x4 modelSpace;
    matrix_float4x4 modelViewProjectionSpace;
    matrix_float4x4 modelViewSpace;
    matrix_float4x4 viewSpace;
    matrix_float3x3 normalSpace;
    matrix_float4x4 lightShadowProjectionSpace;
} UniformSpace;

typedef struct{
    
    bool hasTexture;
    bool enableNormalMap;
    bool enableShadows;
    bool hasArmature;
    
}UniformModelRenderFlags;

typedef struct{
    
    float biasDepth;
    
}UniformModelShadowProperties;

typedef struct{
    
    vector_float4 diffuseMaterialColor[10];
    vector_float4 specularMaterialColor[10];
    float diffuseMaterialIntensity[10];
    float specularMaterialIntensity[10];
    float specularMaterialHardness[10];
    
}UniformModelMaterial;

typedef struct{
    
    vector_float3 diffuseColor;
    vector_float3 specularColor;
    
}UniformLightColor;

typedef struct{
    
    vector_float3 color;
    
}UniformParticleProperty;

typedef struct{
    
    bool hasTexture;
    bool enableNoise;
    float noiseDetail;
    
}UniformParticleSystemProperty;

typedef struct{
    
    float time;
    
}UniformParticleAnimation;

typedef struct{
    
    matrix_float4x4 boneSpace[30];
    
}UniformBoneSpace;

typedef struct{
    
    bool changeImage;
    
}UniformMultiImageState;

typedef struct{
    
    vector_float2 offset;
    
}UniformSpriteProperty;

typedef struct{
    
    vector_float4 lineColor;
    
}UniformGeometryProperty;

#endif /* U4DShaderProtocols_h */

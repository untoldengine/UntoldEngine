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

typedef enum VertexBufferIndices{
    
    viAttributeBuffer= 0,
    viSpaceBuffer = 1,
    viModelRenderFlagBuffer=2,
    viBoneBuffer=3,
    viModelShaderPropertyBuffer=4,
    viGlobalDataBuffer=5,
    viLightPropertiesBuffer=6,
    viParticlesPropertiesBuffer=7,
    
}VertexBufferIndices;

typedef enum FragmentBufferIndices{
    
    fiMaterialBuffer=0,
    fiModelRenderFlagsBuffer=1,
    fiModelShaderPropertyBuffer=2,
    fiGlobalDataBuffer=3,
    fiLightPropertiesBuffer=4,
    fiShadowPropertiesBuffer=5,
    fiParticleSysPropertiesBuffer=6,
    fiShaderEntityPropertyBuffer=7,
    fiGeometryBuffer=8,
    
}FragmentBufferIndices;

typedef enum FragmentTextureIndices{
    
    fiTexture0=0,
    fiTexture1=1,
    fiTexture2=2,
    fiTexture3=3,
    fiNormalTexture=4,
    fiDepthTexture=5,
    
}FragmentTextureIndices;

typedef enum FragmentSamplerIndices{
    
    fiSampler0=0,
    fiSampler1=1,
    fiSampler2=2,
    fiSampler3=3,
    fiNormalSampler=4,
    
}FragmentSamplerIndices;

typedef struct{
    matrix_float4x4 modelSpace;
    matrix_float4x4 modelViewProjectionSpace;
    matrix_float4x4 modelViewSpace;
    matrix_float4x4 viewSpace;
    matrix_float3x3 normalSpace;
} UniformSpace;

typedef struct{
    
    float time;
    vector_float2 resolution;
    
}UniformGlobalData;

typedef struct{
    
    bool hasTexture;
    bool enableNormalMap;
    bool enableShadows;
    bool hasArmature;
    
}UniformModelRenderFlags;

typedef struct{
    
    float biasDepth;
    
}UniformShadowProperties;

typedef struct{
    
    vector_float4 lightPosition;
    vector_float3 diffuseColor;
    vector_float3 specularColor;
    matrix_float4x4 lightShadowProjectionSpace;
    
}UniformLightProperties;

typedef struct{
    
    vector_float4 diffuseMaterialColor[10];
    vector_float4 specularMaterialColor[10];
    float diffuseMaterialIntensity[10];
    float specularMaterialIntensity[10];
    float specularMaterialHardness[10];
    
}UniformModelMaterial;

typedef struct{
    
    vector_float4 color;
    float scaleFactor;
    float rotationAngle;
    
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

typedef struct{
    
    vector_float4 shaderParameter[10];
    bool hasTexture;
    
}UniformShaderEntityProperty;

typedef struct{
    
    vector_float4 shaderParameter[10];
    
}UniformModelShaderProperty;

#endif /* U4DShaderProtocols_h */

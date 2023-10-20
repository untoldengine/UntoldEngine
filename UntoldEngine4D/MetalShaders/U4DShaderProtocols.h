//
//  U4DShaderProtocols.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/14/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DShaderProtocols_h
#define U4DShaderProtocols_h
#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
typedef metal::int32_t EnumBackingType;
#else
#import <Foundation/Foundation.h>
typedef NSInteger EnumBackingType;
#endif
#include <simd/simd.h>

typedef enum BufferIndex{
    positionBufferIndex=0,
    normalBufferIndex,
    colorBufferIndex,
    materialBufferIndex,
    uniformSpaceBufferIndex,
    lightOrthoViewSpaceBufferIndex,
    lightPositionBufferIndex,
}BufferIndex;

//typedef NS_ENUM(EnumBackingType, BufferIndex)
//{
//    BufferIndexMeshPositions = 0,
//    BufferIndexMeshGenerics  = 1,
//    BufferIndexMeshNormals = 2,
//    BufferIndexUniforms      = 3
//
//};

//typedef NS_ENUM(EnumBackingType, VertexAttribute)
//{
//    VertexAttributePosition  = 0,
//    VertexAttributeTexcoord  = 1,
//    VertexAttributeNormals = 2,
//};
//
//typedef NS_ENUM(EnumBackingType, TextureIndex)
//{
//    TextureIndexColor    = 0,
//};



typedef enum FragmentTextureIndices{
    
    shadowTextureIndex=0,
    
}FragmentTextureIndices;

typedef struct{
    matrix_float4x4 modelSpace;
    matrix_float4x4 modelViewProjectionSpace;
    matrix_float4x4 modelViewSpace;
    matrix_float4x4 projectionSpace;
    matrix_float4x4 viewSpace;
    matrix_float3x3 normalSpace;
    simd_float3 cameraPosition;
} UniformSpace;

typedef struct{
    
    float time;
    vector_float2 resolution;
    int numberOfPointLights;
    
}UniformGlobalData;

typedef struct{
    
    bool hasTexture;
    bool enableNormalMap;
    bool hasArmature;
    
}UniformModelRenderFlags;

typedef struct{
    
    float biasDepth;
    
}UniformShadowProperties;

typedef struct{
    
    vector_float4 lightPosition;
    vector_float3 diffuseColor;
    vector_float3 specularColor;
    float energy;
    matrix_float4x4 lightShadowProjectionSpace;
    
}UniformDirectionalLightProperties;

typedef struct{
    
    vector_float4 lightPosition;
    vector_float3 diffuseColor;
    vector_float3 specularColor;
    float constantAttenuation;
    float linearAttenuation;
    float expAttenuation;
    float energy;
    float falloutDistance;
    
}UniformPointLightProperties;

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
    
    matrix_float4x4 boneSpace[60];
    
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
    
    vector_float4 shaderParameter[60];
    bool hasTexture;
    
}UniformShaderEntityProperty;

typedef struct{
    
    vector_float4 shaderParameter[60];
    
}UniformModelShaderProperty;

#endif /* U4DShaderProtocols_h */

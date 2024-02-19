//
//  ShaderTypes.h
//  UntoldEngine3D Shared
//
//  Created by Harold Serrano on 5/17/23.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
typedef metal::int32_t EnumBackingType;
#else
#import <Foundation/Foundation.h>
typedef NSInteger EnumBackingType;
#endif

#include <simd/simd.h>

typedef NS_ENUM(EnumBackingType, BufferIndex)
{
    BufferIndexMeshPositions = 0,
    BufferIndexMeshGenerics  = 1,
    BufferIndexUniforms      = 2
};

typedef NS_ENUM(EnumBackingType, VertexAttribute)
{
    VertexAttributePosition  = 0,
    VertexAttributeTexcoord  = 1,
};

typedef NS_ENUM(EnumBackingType, TextureIndex)
{
    TextureIndexColor    = 0,
};

typedef struct
{
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 modelViewMatrix;
    matrix_float3x3 normalMatrix;
    matrix_float4x4 modelMatrix;
    simd_float3 cameraPosition;
} Uniforms;

typedef struct{
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 modelWorldMatrix;
    simd_float3 rayOrigin;
    simd_float3 rayDirection;
}RayUniforms;

typedef struct{
    simd_float4 position;
    simd_float4 color;
    simd_float4 attenuation;
    simd_float4 intensity;
}PointLightUniform;

struct VoxelData{
    uint guid;
    simd_float3 color;
    simd_float3 material;
};

typedef NS_ENUM(EnumBackingType, BufferIndices){
    voxelVertices=0,
    voxelNormal=1,
    voxelColor=2,
    voxelRoughness=3,
    voxelMetallic=4,
    voxelBaseColor,
    voxelVisible,
    voxelUniform,
    voxelOrigin,
    intersectionUniform,
    intersectionResult,
    intersectionTParam,
    intersectionPointInt,
    gridPosition,
    gridUniform,
    intersectGuid,
    lightPosition,
    lightOrthoViewSpaceBufferIndex,
    planeRayIntersectionResult,
    planeRayIntersectionPoint,
    planeRayIntersectionTime,
    voxelSerialized,
    voxelSerializedCount,
};

typedef enum{
    planeNormalRayIndex,
    planeNormalTParamIndex,
    planeNormalInterceptPointIndex,
    planeNormalIntResultIndex,
    planeNormalBoxOriginIndex,
    planeNormalBoxHalfwidthIndex,
    
}PlaneNormalIndices;

typedef enum{
    voxelInBoxOriginIndex,
    voxelInBoxVisibleIndex,
    voxelInBoxRayIndex,
    voxelInBoxInterceptedIndex,
    voxelInBoxCountIndex,
    voxelInBoxOrignIndex,
    voxelInBoxHalfwidthIndex,
    
}VoxelInBoxIndices;

typedef enum{
    voxelPassVerticesIndex,
    voxelPassNormalIndex,
    voxelPassColorIndex,
    voxelPassRoughnessIndex,
    voxelPassMetallicIndex,
    voxelPassUniformIndex,
    voxelPassLightDirectionIndex,
    voxelPassLightOrthoViewMatrixIndex,
    voxelPassPointLightsIndex,
    voxelPassPointLightsCountIndex
    
}VoxelPassBufferIndices;

typedef enum{
    shadowVoxelOriginIndex,
    shadowVoxelUniform,
    shadowVoxelLightMatrixUniform,
    shadowVoxelLightPositionUniform
}ShadowBufferIndices;

typedef struct{
    
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 modelMatrix;
    matrix_float4x4 environmentRotation;
    
}EnvironmentConstants;

typedef enum RenderTargets{
    colorTarget = 0,
    normalTarget,
    positionTarget
}RenderTargets;

#endif /* ShaderTypes_h */


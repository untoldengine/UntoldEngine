//
//  UntoldShaderTypes.h
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#ifndef UntoldShaderTypes_h
#define UntoldShaderTypes_h

#include <simd/simd.h>

#ifdef __METAL_VERSION__
typedef int UntoldEnumBackingType;
#else
#include <stdint.h>
typedef int32_t UntoldEnumBackingType;
#endif

#define UNTOLD_SHADER_BLOCK_SIZE 256

typedef struct {
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 modelViewMatrix;
    matrix_float3x3 normalMatrix;
    matrix_float4x4 modelMatrix;
    simd_float3 cameraPosition;
} UntoldModelUniforms;

typedef enum {
    UntoldModelVertexBufferPosition,
    UntoldModelVertexBufferNormal,
    UntoldModelVertexBufferUV,
    UntoldModelVertexBufferTangent,
    UntoldModelVertexBufferJointIDs,
    UntoldModelVertexBufferJointWeights,
    UntoldModelVertexBufferBitangent,
    UntoldModelVertexBufferUniforms,
    UntoldModelVertexBufferJointTransforms,
    UntoldModelVertexBufferHasArmature,
} UntoldModelVertexBufferIndex;

typedef enum {
    UntoldModelSurfaceExtensionFragmentBuffer0 = 10,
    UntoldModelSurfaceExtensionFragmentBuffer1 = 11,
    UntoldModelSurfaceExtensionFragmentBuffer2 = 12,
    UntoldModelSurfaceExtensionFragmentBuffer3 = 13,
} UntoldModelSurfaceExtensionFragmentBufferIndex;

typedef enum {
    UntoldModelSurfaceExtensionFragmentTexture0 = 10,
    UntoldModelSurfaceExtensionFragmentTexture1 = 11,
    UntoldModelSurfaceExtensionFragmentTexture2 = 12,
    UntoldModelSurfaceExtensionFragmentTexture3 = 13,
} UntoldModelSurfaceExtensionFragmentTextureIndex;

#endif /* UntoldShaderTypes_h */

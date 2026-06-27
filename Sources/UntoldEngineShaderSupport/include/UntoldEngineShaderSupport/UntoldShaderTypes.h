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

typedef enum {
    UntoldModelSurfaceExtensionArgumentBufferIndex = 10,
} UntoldModelSurfaceExtensionArgumentBufferSlot;

typedef enum {
    UntoldModelSurfaceExtensionArgumentTexture0 = 0,
    UntoldModelSurfaceExtensionArgumentTexture1 = 1,
    UntoldModelSurfaceExtensionArgumentTexture2 = 2,
    UntoldModelSurfaceExtensionArgumentTexture3 = 3,
    UntoldModelSurfaceExtensionArgumentTexture4 = 4,
    UntoldModelSurfaceExtensionArgumentTexture5 = 5,
    UntoldModelSurfaceExtensionArgumentTexture6 = 6,
    UntoldModelSurfaceExtensionArgumentTexture7 = 7,

    UntoldModelSurfaceExtensionArgumentSampler0 = 8,
    UntoldModelSurfaceExtensionArgumentSampler1 = 9,
    UntoldModelSurfaceExtensionArgumentSampler2 = 10,
    UntoldModelSurfaceExtensionArgumentSampler3 = 11,
    UntoldModelSurfaceExtensionArgumentSampler4 = 12,
    UntoldModelSurfaceExtensionArgumentSampler5 = 13,
    UntoldModelSurfaceExtensionArgumentSampler6 = 14,
    UntoldModelSurfaceExtensionArgumentSampler7 = 15,

    UntoldModelSurfaceExtensionArgumentBuffer0 = 16,
    UntoldModelSurfaceExtensionArgumentBuffer1 = 17,
    UntoldModelSurfaceExtensionArgumentBuffer2 = 18,
    UntoldModelSurfaceExtensionArgumentBuffer3 = 19,
    UntoldModelSurfaceExtensionArgumentBuffer4 = 20,
    UntoldModelSurfaceExtensionArgumentBuffer5 = 21,
    UntoldModelSurfaceExtensionArgumentBuffer6 = 22,
    UntoldModelSurfaceExtensionArgumentBuffer7 = 23,
    UntoldModelSurfaceExtensionArgumentBuffer8 = 24,
    UntoldModelSurfaceExtensionArgumentBuffer9 = 25,
    UntoldModelSurfaceExtensionArgumentBuffer10 = 26,
    UntoldModelSurfaceExtensionArgumentBuffer11 = 27,
    UntoldModelSurfaceExtensionArgumentBuffer12 = 28,
    UntoldModelSurfaceExtensionArgumentBuffer13 = 29,
    UntoldModelSurfaceExtensionArgumentBuffer14 = 30,
    UntoldModelSurfaceExtensionArgumentBuffer15 = 31,
} UntoldModelSurfaceExtensionArgumentID;

#endif /* UntoldShaderTypes_h */

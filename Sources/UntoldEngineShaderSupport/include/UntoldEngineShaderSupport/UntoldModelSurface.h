//
//  UntoldModelSurface.h
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#ifndef UntoldModelSurface_h
#define UntoldModelSurface_h

#include <UntoldEngineShaderSupport/UntoldShaderTypes.h>

#ifdef __METAL_VERSION__

#include <metal_stdlib>

typedef struct {
    metal::float4 position [[attribute(UntoldModelVertexBufferPosition)]];
    metal::float4 normals [[attribute(UntoldModelVertexBufferNormal)]];
    metal::float2 uv [[attribute(UntoldModelVertexBufferUV)]];
    metal::float4 tangent [[attribute(UntoldModelVertexBufferTangent)]];
    metal::ushort4 jointIndices [[attribute(UntoldModelVertexBufferJointIDs)]];
    metal::float4 jointWeights [[attribute(UntoldModelVertexBufferJointWeights)]];
} UntoldModelVertexIn;

typedef struct {
    metal::float4 position [[position]];
    metal::float4 shadowCoords;
    metal::float4 vPosition;
    metal::float4 verticesInMVSpace;
    metal::float3 normalVectorInMVSpace;
    metal::float3 normal;
    metal::float3 tbNormal;
    metal::float4 tangent;
    metal::float2 uvCoords;
} UntoldModelSurfaceVertexOut;

typedef struct {
    metal::texture2d<float> texture0 [[id(UntoldModelSurfaceExtensionArgumentTexture0)]];
    metal::texture2d<float> texture1 [[id(UntoldModelSurfaceExtensionArgumentTexture1)]];
    metal::texture2d<float> texture2 [[id(UntoldModelSurfaceExtensionArgumentTexture2)]];
    metal::texture2d<float> texture3 [[id(UntoldModelSurfaceExtensionArgumentTexture3)]];
    metal::texture2d<float> texture4 [[id(UntoldModelSurfaceExtensionArgumentTexture4)]];
    metal::texture2d<float> texture5 [[id(UntoldModelSurfaceExtensionArgumentTexture5)]];
    metal::texture2d<float> texture6 [[id(UntoldModelSurfaceExtensionArgumentTexture6)]];
    metal::texture2d<float> texture7 [[id(UntoldModelSurfaceExtensionArgumentTexture7)]];

    metal::sampler sampler0 [[id(UntoldModelSurfaceExtensionArgumentSampler0)]];
    metal::sampler sampler1 [[id(UntoldModelSurfaceExtensionArgumentSampler1)]];
    metal::sampler sampler2 [[id(UntoldModelSurfaceExtensionArgumentSampler2)]];
    metal::sampler sampler3 [[id(UntoldModelSurfaceExtensionArgumentSampler3)]];
    metal::sampler sampler4 [[id(UntoldModelSurfaceExtensionArgumentSampler4)]];
    metal::sampler sampler5 [[id(UntoldModelSurfaceExtensionArgumentSampler5)]];
    metal::sampler sampler6 [[id(UntoldModelSurfaceExtensionArgumentSampler6)]];
    metal::sampler sampler7 [[id(UntoldModelSurfaceExtensionArgumentSampler7)]];

    constant metal::uchar *buffer0 [[id(UntoldModelSurfaceExtensionArgumentBuffer0)]];
    constant metal::uchar *buffer1 [[id(UntoldModelSurfaceExtensionArgumentBuffer1)]];
    constant metal::uchar *buffer2 [[id(UntoldModelSurfaceExtensionArgumentBuffer2)]];
    constant metal::uchar *buffer3 [[id(UntoldModelSurfaceExtensionArgumentBuffer3)]];
    constant metal::uchar *buffer4 [[id(UntoldModelSurfaceExtensionArgumentBuffer4)]];
    constant metal::uchar *buffer5 [[id(UntoldModelSurfaceExtensionArgumentBuffer5)]];
    constant metal::uchar *buffer6 [[id(UntoldModelSurfaceExtensionArgumentBuffer6)]];
    constant metal::uchar *buffer7 [[id(UntoldModelSurfaceExtensionArgumentBuffer7)]];
    constant metal::uchar *buffer8 [[id(UntoldModelSurfaceExtensionArgumentBuffer8)]];
    constant metal::uchar *buffer9 [[id(UntoldModelSurfaceExtensionArgumentBuffer9)]];
    constant metal::uchar *buffer10 [[id(UntoldModelSurfaceExtensionArgumentBuffer10)]];
    constant metal::uchar *buffer11 [[id(UntoldModelSurfaceExtensionArgumentBuffer11)]];
    constant metal::uchar *buffer12 [[id(UntoldModelSurfaceExtensionArgumentBuffer12)]];
    constant metal::uchar *buffer13 [[id(UntoldModelSurfaceExtensionArgumentBuffer13)]];
    constant metal::uchar *buffer14 [[id(UntoldModelSurfaceExtensionArgumentBuffer14)]];
    constant metal::uchar *buffer15 [[id(UntoldModelSurfaceExtensionArgumentBuffer15)]];
} UntoldModelSurfaceExtensionArguments;

#endif /* __METAL_VERSION__ */

#endif /* UntoldModelSurface_h */

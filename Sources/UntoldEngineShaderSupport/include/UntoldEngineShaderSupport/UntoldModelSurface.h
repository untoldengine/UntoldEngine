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

#endif /* __METAL_VERSION__ */

#endif /* UntoldModelSurface_h */

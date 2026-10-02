//
//  TintSurface.metal
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include <UntoldEngineShaderSupport/UntoldModelSurface.h>

using namespace metal;

struct TintSurfaceUniforms {
    float4 color;
};

fragment float4 tintSurfaceFragment(
    UntoldModelSurfaceVertexOut in [[stage_in]],
    constant UntoldModelSurfaceExtensionArguments &arguments
        [[buffer(UntoldModelSurfaceExtensionArgumentBufferIndex)]]
) {
    constant TintSurfaceUniforms &uniforms =
        *reinterpret_cast<constant TintSurfaceUniforms *>(arguments.buffer0);
    return float4(
        uniforms.color.rgb * uniforms.color.a,
        uniforms.color.a
    );
}

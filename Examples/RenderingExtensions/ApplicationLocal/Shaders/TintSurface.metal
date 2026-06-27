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

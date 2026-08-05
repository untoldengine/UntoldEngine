//
//  Gaussians.metal
//  UntoldEngineVisionOS
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
#include "ShadersUtils.h"

using namespace metal;

constant float GAUSSIAN_SH_C1 = 0.4886025119029199f;
constant float GAUSSIAN_SH_C2[5] = {
    1.0925484305920792f,
   -1.0925484305920792f,
    0.31539156525252005f,
   -1.0925484305920792f,
    0.5462742152960396f
};
constant float GAUSSIAN_SH_C3[7] = {
   -0.5900435899266435f,
    2.890611442640554f,
   -0.4570457994644658f,
    0.3731763325901154f,
   -0.4570457994644658f,
    1.445305721320277f,
   -0.5900435899266435f
};

inline uint unpackIndex(uint64_t packed)  { return (uint)(packed & 0xffffffffu); }
inline uint unpackDepthKey(uint64_t packed) { return (uint)(packed >> 32); }

float3 loadGaussianSHCoefficient(
    const device half *coefficients,
    constant GaussianSHMetadata &metadata,
    uint splatIndex,
    uint coefficientIndex)
{
    uint perChannel = metadata.coefficientsPerChannel - 1;
    uint splatBase = splatIndex * metadata.higherOrderCoefficientsPerSplat;
    uint offset = coefficientIndex - 1;
    return float3(
        coefficients[splatBase + offset],
        coefficients[splatBase + perChannel + offset],
        coefficients[splatBase + 2 * perChannel + offset]
    );
}

float3 evaluateGaussianSphericalHarmonics(
    float3 baseColor,
    const device half *coefficients,
    constant GaussianSHMetadata &metadata,
    uint splatIndex,
    float3 direction)
{
    if (metadata.degree == 0 || metadata.higherOrderCoefficientsPerSplat == 0) {
        return baseColor;
    }

    float lengthSquared = dot(direction, direction);
    if (lengthSquared <= 1.0e-8f) {
        return baseColor;
    }
    float3 d = direction * rsqrt(lengthSquared);
    float x = d.x;
    float y = d.y;
    float z = d.z;
    float3 result = baseColor;
    result += GAUSSIAN_SH_C1 * (
        -y * loadGaussianSHCoefficient(coefficients, metadata, splatIndex, 1) +
         z * loadGaussianSHCoefficient(coefficients, metadata, splatIndex, 2) -
         x * loadGaussianSHCoefficient(coefficients, metadata, splatIndex, 3)
    );

    if (metadata.degree > 1) {
        float xx = x * x;
        float yy = y * y;
        float zz = z * z;
        result += GAUSSIAN_SH_C2[0] * x * y * loadGaussianSHCoefficient(coefficients, metadata, splatIndex, 4);
        result += GAUSSIAN_SH_C2[1] * y * z * loadGaussianSHCoefficient(coefficients, metadata, splatIndex, 5);
        result += GAUSSIAN_SH_C2[2] * (2.0f * zz - xx - yy) * loadGaussianSHCoefficient(coefficients, metadata, splatIndex, 6);
        result += GAUSSIAN_SH_C2[3] * x * z * loadGaussianSHCoefficient(coefficients, metadata, splatIndex, 7);
        result += GAUSSIAN_SH_C2[4] * (xx - yy) * loadGaussianSHCoefficient(coefficients, metadata, splatIndex, 8);

        if (metadata.degree > 2) {
            result += GAUSSIAN_SH_C3[0] * y * (3.0f * xx - yy) * loadGaussianSHCoefficient(coefficients, metadata, splatIndex, 9);
            result += GAUSSIAN_SH_C3[1] * x * y * z * loadGaussianSHCoefficient(coefficients, metadata, splatIndex, 10);
            result += GAUSSIAN_SH_C3[2] * y * (4.0f * zz - xx - yy) * loadGaussianSHCoefficient(coefficients, metadata, splatIndex, 11);
            result += GAUSSIAN_SH_C3[3] * z * (2.0f * zz - 3.0f * xx - 3.0f * yy) * loadGaussianSHCoefficient(coefficients, metadata, splatIndex, 12);
            result += GAUSSIAN_SH_C3[4] * x * (4.0f * zz - xx - yy) * loadGaussianSHCoefficient(coefficients, metadata, splatIndex, 13);
            result += GAUSSIAN_SH_C3[5] * z * (xx - yy) * loadGaussianSHCoefficient(coefficients, metadata, splatIndex, 14);
            result += GAUSSIAN_SH_C3[6] * x * (xx - 3.0f * yy) * loadGaussianSHCoefficient(coefficients, metadata, splatIndex, 15);
        }
    }

    return max(result, float3(0.0f));
}

// Standard 3DGS coefficients are fitted to normalized image-code values.
// Decode those display-referred values before writing to Untold's linear HDR
// Gaussian target. The final output transform will encode them exactly once.
float3 gaussianSRGBToLinear(float3 color)
{
    color = max(color, float3(0.0f));
    float3 low = color / 12.92f;
    float3 high = pow((color + 0.055f) / 1.055f, float3(2.4f));
    return select(high, low, color <= 0.04045f);
}

// Diagnostic entry point for validating the packed GPU SH contract against
// the exact evaluator used by the Gaussian vertex shader.
kernel void gaussianSphericalHarmonicsDiagnostic(
    const device half *coefficients       [[buffer(0)]],
    constant GaussianSHMetadata &metadata [[buffer(1)]],
    constant float4 &baseColor            [[buffer(2)]],
    constant float4 &direction            [[buffer(3)]],
    device float4 *result                 [[buffer(4)]])
{
    float3 evaluated = evaluateGaussianSphericalHarmonics(
        baseColor.xyz,
        coefficients,
        metadata,
        0,
        direction.xyz
    );
    result[0] = float4(evaluated, 1.0f);
    result[1] = float4(gaussianSRGBToLinear(evaluated), 1.0f);
}

// Project 3D covariance into 2D screen-pixel space
float3 computeCov2D(float4      splatCenter,
                    float3x3    cov3D,
                    float4x4    modelViewMatrix,
                    float4x4    projectionMatrix,
                    float2      viewport)
{
    // Center in view space
    float3 centerVS = (modelViewMatrix * splatCenter).xyz;

    // FOV clamp in view space
    float tanFovX = 1.0f / projectionMatrix[0][0];
    float tanFovY = 1.0f / projectionMatrix[1][1];

    float fovLimitX = 1.3f * tanFovX;
    float fovLimitY = 1.3f * tanFovY;

    float xOverZ = centerVS.x / centerVS.z;
    float yOverZ = centerVS.y / centerVS.z;

    centerVS.x = clamp(xOverZ, -fovLimitX, fovLimitX) * centerVS.z;
    centerVS.y = clamp(yOverZ, -fovLimitY, fovLimitY) * centerVS.z;

    float t[3] = { centerVS.x, centerVS.y, centerVS.z };

    // Focal length in pixels
    float focalX = viewport.x * projectionMatrix[0][0] * 0.5f;
    float focalY = viewport.y * projectionMatrix[1][1] * 0.5f;

    // Jacobian: view space → pixel space
    float3x3 J = float3x3(
        float3( focalX / t[2],      0.0f,                -(focalX * t[0]) / (t[2] * t[2]) ),
        float3( 0.0f,              -focalY / t[2],        (focalY * t[1]) / (t[2] * t[2]) ),
        float3( 0.0f,               0.0f,                 0.0f )
    );

    // 3×3 rotation from local → view, built to match your matrix convention
    float3x3 W = float3x3(
        modelViewMatrix[0][0], modelViewMatrix[1][0], modelViewMatrix[2][0],
        modelViewMatrix[0][1], modelViewMatrix[1][1], modelViewMatrix[2][1],
        modelViewMatrix[0][2], modelViewMatrix[1][2], modelViewMatrix[2][2]
    );

    // Total transform for covariance: local → view → pixels
    float3x3 T = W * J;

    // cov2D = Tᵀ Σ3D T
    float3x3 cov = transpose(T) * cov3D * T;

    // Low-pass filter to ensure at least ~1 pixel extent
    cov[0][0] += 0.1f;
    cov[1][1] += 0.1f;

    // Pack symmetric 2×2 into (a, b, c)
    return float3(cov[0][0], cov[0][1], cov[1][1]);
}

// Compute inverse covariance and a scalar radius (~3σ) in pixels
float3 computeInverseCovarianceConic(float3 cov2D,
                                     thread float &radius,
                                     thread bool  &valid)
{
    float a  = cov2D.x;
    float b  = cov2D.y;
    float c  = cov2D.z;

    float det = a * c - b * b;
    if (det == 0.0f) {
        valid = false;
        radius = 0.0f;
        return float3(0.0f);
    }

    float detInv = 1.0f / det;

    float3 conic = float3(
        c * detInv,
       -b * detInv,
        a * detInv
    );

    // Eigenvalues of the 2×2 covariance
    float mid     = 0.5f * (a + c);
    float disc    = max(0.1f, mid * mid - det);
    float lambda1 = mid + sqrt(disc);
    float lambda2 = mid - sqrt(disc);

    // Radius in pixels covering ~3σ of the larger axis
    radius = ceil(3.0f * sqrt(max(lambda1, lambda2)));

    valid = true;
    return conic;
}

// Vertex: builds a quad around the splat center and passes center + conic
inline float2 getCurrentQuadVertex(uint vertexId)
{
    return float2(vertexId & 1, (vertexId >> 1) & 1); // (0,0), (1,0), (0,1), (1,1)
}

inline float calcPowerFromConic(float3 conic, float2 d)
{
    return -0.5f * (conic.x * d.x * d.x +
                    conic.z * d.y * d.y +
                    2.0f   * conic.y * d.x * d.y);
}

inline float2 calcScreenSpaceDelta(float2 pixelPos,
                                   float2 centerPixel,
                                   float  projYSign)
{
    float2 d = pixelPos - centerPixel;
    d.y *= projYSign;
    return d;
}

typedef struct
{
    half4 color [[raster_order_group(0)]];
    float weightedDepth [[raster_order_group(0)]];
} GaussianTBDRFragmentValues;

typedef struct
{
    GaussianTBDRFragmentValues values [[imageblock_data]];
} GaussianTBDRFragmentStore;

typedef struct
{
    float4 color [[color(0)]];
    float depth [[depth(any)]];
} GaussianTBDRPostOut;

kernel void initializeGaussianFragmentStore(
    imageblock<GaussianTBDRFragmentValues, imageblock_layout_explicit> blockData,
    ushort2 localThreadID [[thread_position_in_threadgroup]])
{
    threadgroup_imageblock GaussianTBDRFragmentValues *values = blockData.data(localThreadID);
    values->color = half4(0.0h);
    values->weightedDepth = 0.0f;
}

vertex GaussianOutData vertexGaussianTBDRShader(
    const device uint64_t             *packedKeys [[buffer(gaussianTBDRRenderIndicesIndex)]],
    const device EncodedGaussianSplat *splats     [[buffer(gaussianTBDRRenderSplatIndex)]],
    constant Uniforms                 &uniforms   [[buffer(gaussianTBDRRenderUniformIndex)]],
    constant float2                   &viewport   [[buffer(gaussianTBDRRenderViewPortIndex)]],
    const device half                 *shCoefficients [[buffer(gaussianTBDRRenderSHIndex)]],
    constant GaussianSHMetadata       &shMetadata [[buffer(gaussianTBDRRenderSHMetadataIndex)]],
    constant float3                   &localCameraPosition [[buffer(gaussianTBDRRenderLocalCameraIndex)]],
    uint                               vid        [[vertex_id]],
    uint                               iid        [[instance_id]])
{
    GaussianOutData out;
    out.valid = false;
    out.position = float4(0.0, 0.0, 0.0, 1.0);

    uint64_t packed = packedKeys[iid];
    uint splatIndex = unpackIndex(packed);
    if (splatIndex == 0xffffffffu) {
        return out;
    }
    const EncodedGaussianSplat splat = splats[splatIndex];

    float2 quad = getCurrentQuadVertex(vid);
    quad = quad * 2.0f - 1.0f;

    float3 centerLocal = splat.position;
    float4 centerClip = uniforms.projectionMatrix *
                        uniforms.modelViewMatrix *
                        float4(centerLocal, 1.0);

    if (centerClip.w <= 0.0f) {
        return out;
    }

    const float projYSign = -1.0f;
    float2 centerNDC = centerClip.xy / centerClip.w;
    float2 centerUV = centerNDC * float2(0.5f, 0.5f * projYSign) + 0.5f;
    out.coordxy = centerUV * viewport;

    float3x3 cov3D = float3x3(
        splat.covA.x, splat.covA.y, splat.covA.z,
        splat.covA.y, splat.covB.x, splat.covB.y,
        splat.covA.z, splat.covB.y, splat.covB.z
    );

    float3 cov2D = computeCov2D(float4(centerLocal, 1.0),
                                cov3D,
                                uniforms.modelViewMatrix,
                                uniforms.projectionMatrix,
                                viewport);

    float extent = 0.0f;
    bool valid = true;
    out.conic = computeInverseCovarianceConic(cov2D, extent, valid);

    if (!valid || extent <= 0.0f) {
        return out;
    }

    float2 ndcOffset = quad * extent * 2.0f / viewport;
    out.position = centerClip;
    out.position.xy += ndcOffset * centerClip.w;
    out.color = gaussianSRGBToLinear(evaluateGaussianSphericalHarmonics(
        splat.color,
        shCoefficients,
        shMetadata,
        splatIndex,
        centerLocal - localCameraPosition
    ));
    out.alpha = splat.opacity;
    out.valid = true;

    return out;
}

fragment GaussianTBDRFragmentStore fragmentGaussianTBDRShader(
    GaussianOutData in [[stage_in]],
    GaussianTBDRFragmentValues previousValues [[imageblock_data]],
    depth2d<float> opaqueDepth [[texture(gaussianTBDRDrawOpaqueDepthTextureIndex)]],
    constant bool &reverseZ [[buffer(gaussianTBDRRenderReverseZIndex)]])
{
    GaussianTBDRFragmentStore out;

    if (!in.valid) {
        discard_fragment();
    }

    // Occlude against opaque geometry already in the depth buffer (a snapshot taken
    // before this pass — see gaussianExecution). in.position.z is already normalized
    // device depth from the same projection the opaque pass used, so it's directly
    // comparable to the stored value with no linearization needed. A small bias avoids
    // a hard cutoff exactly at surface intersections. Background pixels hold the clear
    // value (the farthest depth in either convention), so splats over empty background
    // are never occluded without any special-casing.
    float storedOpaqueDepth = opaqueDepth.read(uint2(in.position.xy));
    float splatDepth = in.position.z;
    const float depthBias = 0.0005f;
    bool occludedByOpaque = reverseZ
        ? (splatDepth + depthBias < storedOpaqueDepth)
        : (splatDepth > storedOpaqueDepth + depthBias);
    if (occludedByOpaque) {
        // discard_fragment() only suppresses standard color/depth attachment writes —
        // it does NOT stop this function from computing and returning a value for the
        // custom imageblock struct below, so relying on it alone here would let an
        // occluded splat's contribution reach the accumulator anyway. Return the
        // accumulator unchanged instead, so an occluded splat contributes nothing.
        out.values = previousValues;
        return out;
    }

    const float projYSign = 1.0f;
    float2 d = calcScreenSpaceDelta(in.position.xy, in.coordxy, projYSign);
    float power = calcPowerFromConic(in.conic, d);

    half alpha = half(saturate(in.alpha * exp(power)));
    if (alpha < half(1.0f / 255.0f)) {
        discard_fragment();
    }

    half oneMinusAccumulatedAlpha = half(1.0h - previousValues.color.a);
    half4 colorWithPremultipliedAlpha = half4(half3(in.color) * alpha, alpha);

    out.values.color = previousValues.color + colorWithPremultipliedAlpha * oneMinusAccumulatedAlpha;
    out.values.weightedDepth = previousValues.weightedDepth + in.position.z * float(alpha * oneMinusAccumulatedAlpha);

    return out;
}

vertex GaussianOutData vertexGaussianTBDRPostprocessShader(uint vertexID [[vertex_id]])
{
    GaussianOutData out;
    out.position.x = (vertexID == 2) ? 3.0 : -1.0;
    out.position.y = (vertexID == 0) ? -3.0 : 1.0;
    out.position.zw = 1.0;
    out.valid = true;
    return out;
}

fragment GaussianTBDRPostOut fragmentGaussianTBDRPostprocessShader(
    GaussianTBDRFragmentValues fragmentValues [[imageblock_data]],
    constant bool &reverseZ [[buffer(gaussianTBDRRenderReverseZIndex)]])
{
    (void)reverseZ;
    GaussianTBDRPostOut out;
    float alpha = float(fragmentValues.color.a);
    if (alpha <= 0.0f) {
        discard_fragment();
    }
    out.color = float4(fragmentValues.color);
    out.depth = fragmentValues.weightedDepth / alpha;
    return out;
}

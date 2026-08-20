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

// Hard ceiling on a splat's screen-space half-extent, in pixels. Without this, radius
// grows roughly as 1/distance as the camera approaches a splat (see the Jacobian in
// computeCov2D), so a single splat can balloon to cover a huge fraction of the screen at
// close range — every one of those extra pixels pays full fragment-shading cost. Trades a
// little softness/tail accuracy at extreme close range for a bounded worst-case overdraw
// cost per splat.
constant float kGaussianMaxScreenRadius = 128.0f;

// How many standard deviations out the rendered quad extends along each principal axis.
// fragmentGaussianTBDRShader discards any fragment whose alpha falls below 1/255 (any dimmer
// than that rounds to nothing in 8-bit output anyway) — so the quad edge needs alpha =
// opacity*exp(-0.5*k^2) to already be under that bar for a fully-opaque splat, i.e. k >
// sqrt(2*ln(255)) ≈ 3.33, or the geometric edge itself becomes a faint but visible boundary
// (most noticeable on large, high-opacity, texturally-flat splats — e.g. sky/cloud splats —
// where there's nothing else nearby to mask a subtle discontinuity). 3.5 clears that with a
// small margin; going further trades quad area (~k^2) for diminishing returns.
constant float kGaussianQuadSigma = 3.5f;

// Hard ceiling on how many splats may blend into a single pixel. [[raster_order_group(0)]]
// forces every fragment touching a given pixel to execute serially (a correct ordered
// read-modify-write into the imageblock), so per-pixel overdraw isn't just extra work — it's
// extra *latency*, since the GPU can't parallelize across fragments fighting over the same
// pixel. The accumulated-alpha early-out already stops this once a pixel is visually opaque,
// but in low-per-splat-opacity regions that can take a while to converge (e.g. opacity ~0.3
// needs ~20 splats to reach 0.999). This caps the worst case directly: trades a small amount
// of accuracy in pathologically dense overlap regions for a hard bound on the serial chain.
constant uchar kGaussianMaxBlendedSplatsPerPixel = 64;

inline uint unpackIndex(uint64_t packed)  { return (uint)(packed & 0xffffffffu); }
inline uint unpackDepthKey(uint64_t packed) { return (uint)(packed >> 32); }

// Dequantizes a byte packed by quantizeGaussianSHCoefficient (Swift) back
// into the fixed [-1, 1] range.
inline float dequantizeGaussianSHCoefficient(uchar packed)
{
    return (float(packed) - 128.0f) / 128.0f;
}

float3 loadGaussianSHCoefficient(
    const device uchar *coefficients,
    constant GaussianSHMetadata &metadata,
    uint splatIndex,
    uint coefficientIndex)
{
    uint perChannel = metadata.coefficientsPerChannel - 1;
    uint splatBase = splatIndex * metadata.higherOrderCoefficientsPerSplat;
    uint offset = coefficientIndex - 1;
    return float3(
        dequantizeGaussianSHCoefficient(coefficients[splatBase + offset]),
        dequantizeGaussianSHCoefficient(coefficients[splatBase + perChannel + offset]),
        dequantizeGaussianSHCoefficient(coefficients[splatBase + 2 * perChannel + offset])
    );
}

float3 evaluateGaussianSphericalHarmonics(
    float3 baseColor,
    const device uchar *coefficients,
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
    const device uchar *coefficients      [[buffer(0)]],
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

// Compute inverse covariance (conic) and the two orthogonal kGaussianQuadSigma-sigma semi-axis
// vectors (in screen pixels) of the projected covariance ellipse, via eigen-decomposition of
// the symmetric 2×2 [[a,b],[b,c]] matrix. axis1/axis2 point along the ellipse's true principal directions —
// used to build a tight, rotated quad instead of an axis-aligned bounding box, which for an
// anisotropic, non-axis-aligned splat (the common case: Gaussians are oriented however the
// surface they came from sits) can be several times larger in area than the ellipse itself,
// costing that many more rasterized/shaded fragments regardless of how cheap the per-fragment
// TBDR blend itself is. Eigenvector formula matches the standard closed-form solution for a
// symmetric 2×2 matrix (as used by e.g. MetalSplatter's decomposeCovariance).
float3 computeInverseCovarianceConic(float3 cov2D,
                                     thread float2 &axis1,
                                     thread float2 &axis2,
                                     thread bool  &valid)
{
    float a  = cov2D.x;
    float b  = cov2D.y;
    float c  = cov2D.z;

    float det = a * c - b * b;
    // cov2D is provably PSD (built from a congruence transform of a PSD 3D covariance, plus a
    // positive diagonal dilation), so its determinant is mathematically always >= 0 — a
    // negative reading can only come from float round-off on a near-singular matrix. Guarding
    // <= 0 (not just == 0) catches that case before it flips the sign of detInv/conic, which
    // would otherwise invert the falloff (alpha growing instead of decaying away from center).
    if (det <= 0.0f) {
        valid = false;
        axis1 = float2(0.0f);
        axis2 = float2(0.0f);
        return float3(0.0f);
    }

    float trace = a + c;
    float mean = 0.5f * trace;
    // Discriminant of the characteristic polynomial — mathematically always >= 0 for a real
    // symmetric matrix; the max() guards only against float round-off near-singular matrices.
    // The 0.1 floor (matching the reference implementation) keeps the eigenvector computation
    // below numerically stable when the ellipse is nearly circular (b~0, a~c).
    float dist = max(0.1f, sqrt(max(mean * mean - det, 0.0f)));
    float lambda1 = mean + dist;
    float lambda2 = max(mean - dist, 0.0f);

    float2 eigenvector1;
    if (b == 0.0f) {
        eigenvector1 = (a > c) ? float2(1.0f, 0.0f) : float2(0.0f, 1.0f);
    } else {
        eigenvector1 = normalize(float2(b, c - (mean - dist)));
    }
    // The second eigenvector of a symmetric 2x2 matrix is always orthogonal to the first.
    float2 eigenvector2 = float2(eigenvector1.y, -eigenvector1.x);

    float radius1 = kGaussianQuadSigma * sqrt(lambda1);
    float radius2 = kGaussianQuadSigma * sqrt(lambda2);

    // A splat whose true kGaussianQuadSigma-sigma extent along either principal axis exceeds
    // kGaussianMaxScreenRadius (very close to the camera — radius grows ~1/distance) needs
    // its rendered quad clamped down for overdraw reasons, but the falloff must be clamped
    // along with it, or the (smaller) quad sits within the Gaussian's near-flat peak and
    // never reaches the part of the curve that actually decays — visually a hard-edged,
    // nearly-opaque block instead of a soft blob.
    //
    // Each axis is clamped independently (not by a single shared ratio) so an elongated
    // splat's short axis isn't shrunk just because its long axis needed clamping — matching
    // how the previous axis-aligned implementation clamped x and y separately. The clamped
    // covariance is then reconstructed from the (independently-scaled) eigenvalues and the
    // unchanged eigenvector directions — M = R·diag(λ1,λ2)·Rᵀ — so conic, radius, and the
    // falloff all agree on the same (possibly non-uniformly-shrunk) ellipse. det(M) = λ1·λ2
    // regardless of rotation, since R is orthogonal (det(R)·det(Rᵀ) = 1).
    float clampedRadius1 = min(radius1, kGaussianMaxScreenRadius);
    float clampedRadius2 = min(radius2, kGaussianMaxScreenRadius);
    if (clampedRadius1 < radius1 || clampedRadius2 < radius2) {
        float scale1 = clampedRadius1 / radius1;
        float scale2 = clampedRadius2 / radius2;
        float clampedLambda1 = lambda1 * scale1 * scale1;
        float clampedLambda2 = lambda2 * scale2 * scale2;

        a = clampedLambda1 * eigenvector1.x * eigenvector1.x + clampedLambda2 * eigenvector2.x * eigenvector2.x;
        b = clampedLambda1 * eigenvector1.x * eigenvector1.y + clampedLambda2 * eigenvector2.x * eigenvector2.y;
        c = clampedLambda1 * eigenvector1.y * eigenvector1.y + clampedLambda2 * eigenvector2.y * eigenvector2.y;
        det = clampedLambda1 * clampedLambda2;

        radius1 = clampedRadius1;
        radius2 = clampedRadius2;
    }

    float detInv = 1.0f / det;

    float3 conic = float3(
        c * detInv,
       -b * detInv,
        a * detInv
    );

    axis1 = eigenvector1 * radius1;
    axis2 = eigenvector2 * radius2;

    valid = true;
    return conic;
}

// Computes conic/axes/color once per visible splat per frame — the same quantities the
// draw vertex shader used to recompute redundantly on every one of its 4 instanced quad
// vertices. Writes into a buffer indexed by original splat index; the vertex shader then
// just reads by index instead of redoing the Jacobian/covariance math and SH evaluation 4x.
kernel void gaussianPreprocess(
    const device EncodedGaussianSplat *splats       [[buffer(gaussianPreprocessSplatIndex)]],
    constant Uniforms                 &uniforms     [[buffer(gaussianPreprocessUniformIndex)]],
    constant uint                     &numOfSplats  [[buffer(gaussianPreprocessNumOfSplatsIndex)]],
    const device uint                 *visibleIndices [[buffer(gaussianPreprocessVisibleIndicesIndex)]],
    const device uint                 *visibleCount [[buffer(gaussianPreprocessVisibleCountIndex)]],
    constant float2                   &viewport     [[buffer(gaussianPreprocessViewportIndex)]],
    const device uchar                 *shCoefficients [[buffer(gaussianPreprocessSHIndex)]],
    constant GaussianSHMetadata       &shMetadata   [[buffer(gaussianPreprocessSHMetadataIndex)]],
    constant float3                   &localCameraPosition [[buffer(gaussianPreprocessLocalCameraIndex)]],
    device GaussianPrecomputedSplat   *precomputed  [[buffer(gaussianPreprocessOutputIndex)]],
    uint                                index        [[thread_position_in_grid]])
{
    if (index >= numOfSplats || index >= visibleCount[0]) {
        return;
    }

    uint splatIndex = visibleIndices[index];
    const EncodedGaussianSplat splat = splats[splatIndex];

    GaussianPrecomputedSplat out;
    out.conic = float3(0.0f);
    out.axis1 = float2(0.0f);
    out.axis2 = float2(0.0f);
    out.color = float3(0.0f);

    float3 centerLocal = splat.position;
    float4 centerClip = uniforms.projectionMatrix *
                        uniforms.modelViewMatrix *
                        float4(centerLocal, 1.0);

    if (centerClip.w <= 0.0f) {
        precomputed[splatIndex] = out;
        return;
    }

    float3x3 cov3D = float3x3(
        float(splat.covA.x), float(splat.covA.y), float(splat.covA.z),
        float(splat.covA.y), float(splat.covB.x), float(splat.covB.y),
        float(splat.covA.z), float(splat.covB.y), float(splat.covB.z)
    );

    float3 cov2D = computeCov2D(float4(centerLocal, 1.0),
                                cov3D,
                                uniforms.modelViewMatrix,
                                uniforms.projectionMatrix,
                                viewport);

    float2 axis1 = float2(0.0f);
    float2 axis2 = float2(0.0f);
    bool valid = true;
    float3 conic = computeInverseCovarianceConic(cov2D, axis1, axis2, valid);

    if (!valid || (axis1.x == 0.0f && axis1.y == 0.0f) || (axis2.x == 0.0f && axis2.y == 0.0f)) {
        precomputed[splatIndex] = out;
        return;
    }

    out.conic = conic;
    out.axis1 = axis1;
    out.axis2 = axis2;
    out.color = gaussianSRGBToLinear(evaluateGaussianSphericalHarmonics(
        float3(splat.colorAndOpacity.xyz),
        shCoefficients,
        shMetadata,
        splatIndex,
        centerLocal - localCameraPosition
    ));

    precomputed[splatIndex] = out;
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
    uchar contributingSplatCount [[raster_order_group(0)]];
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
    values->contributingSplatCount = 0;
}

vertex GaussianOutData vertexGaussianTBDRShader(
    const device uint64_t             *packedKeys [[buffer(gaussianTBDRRenderIndicesIndex)]],
    const device EncodedGaussianSplat *splats     [[buffer(gaussianTBDRRenderSplatIndex)]],
    constant Uniforms                 &uniforms   [[buffer(gaussianTBDRRenderUniformIndex)]],
    constant float2                   &viewport   [[buffer(gaussianTBDRRenderViewPortIndex)]],
    const device GaussianPrecomputedSplat *precomputedSplats [[buffer(gaussianTBDRRenderPrecomputedIndex)]],
    constant float4                   &debugColor [[buffer(gaussianTBDRRenderDebugColorIndex)]],
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
    const GaussianPrecomputedSplat precomputed = precomputedSplats[splatIndex];

    // Zero axis vectors mean gaussianPreprocess found this splat invalid this frame (behind
    // the camera, or a degenerate covariance) — same condition the old inline computation
    // guarded against.
    if ((precomputed.axis1.x == 0.0f && precomputed.axis1.y == 0.0f) ||
        (precomputed.axis2.x == 0.0f && precomputed.axis2.y == 0.0f)) {
        return out;
    }

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

    out.conic = precomputed.conic;

    // Tight, rotated quad along the ellipse's true principal axes (see
    // computeInverseCovarianceConic) instead of an axis-aligned bounding box — avoids
    // rasterizing/shading several times more fragments than necessary for anisotropic,
    // non-axis-aligned splats.
    float2 pixelOffset = quad.x * precomputed.axis1 + quad.y * precomputed.axis2;
    float2 ndcOffset = pixelOffset * 2.0f / viewport;
    out.position = centerClip;
    out.position.xy += ndcOffset * centerClip.w;
    out.color = debugColor.w > 0.0f ? debugColor.xyz : precomputed.color;
    out.alpha = float(splat.colorAndOpacity.w);
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

    // Early-terminate once this pixel is effectively opaque: every splat still to come in
    // sorted order would contribute (1 - accumulatedAlpha) ~ 0 regardless of its own color
    // or occlusion, so there's no need to pay for the opaque-depth read or the power/exp
    // blend math below. This is the same "early stop" reference Gaussian-splat rasterizers
    // use per-pixel, and is what keeps heavily overlapping splats (close-range viewing)
    // from each paying full shading cost for zero visible contribution.
    if (previousValues.color.a >= half(0.999h)) {
        out.values = previousValues;
        return out;
    }

    // Evaluate the Gaussian falloff before touching the opaque-depth texture: this is pure
    // ALU (no memory fetch), and most of a splat's rasterized area — out near the quad edge
    // (kGaussianQuadSigma sigma out) — has negligible alpha. Rejecting those tail fragments
    // here means they never pay for the depth-texture read at all, on top of never reaching
    // the blend math below.
    const float projYSign = 1.0f;
    float2 d = calcScreenSpaceDelta(in.position.xy, in.coordxy, projYSign);
    float power = calcPowerFromConic(in.conic, d);

    half alpha = half(saturate(in.alpha * exp(power)));
    if (alpha < half(1.0f / 255.0f)) {
        // Contribution rounds to nothing — skip the opaque-depth read and blend math below.
        out.values = previousValues;
        return out;
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
        // Return the accumulator unchanged so an occluded splat contributes nothing.
        out.values = previousValues;
        return out;
    }

    // Hard bound on the raster_order_group's serial chain length for this pixel — see
    // kGaussianMaxBlendedSplatsPerPixel. Only counts splats that actually reach the blend
    // below (occluded/negligible-alpha splats above never increment this).
    if (previousValues.contributingSplatCount >= kGaussianMaxBlendedSplatsPerPixel) {
        out.values = previousValues;
        return out;
    }

    half oneMinusAccumulatedAlpha = half(1.0h - previousValues.color.a);
    half4 colorWithPremultipliedAlpha = half4(half3(in.color) * alpha, alpha);

    out.values.color = previousValues.color + colorWithPremultipliedAlpha * oneMinusAccumulatedAlpha;
    out.values.weightedDepth = previousValues.weightedDepth + in.position.z * float(alpha * oneMinusAccumulatedAlpha);
    out.values.contributingSplatCount = previousValues.contributingSplatCount + 1;

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

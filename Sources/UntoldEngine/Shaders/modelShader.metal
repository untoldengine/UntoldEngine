//
//  modelShader.metal
//  UntoldShadersKernels
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

constant ushort lodBayer8x8[64] = {
    0, 48, 12, 60, 3, 51, 15, 63,
    32, 16, 44, 28, 35, 19, 47, 31,
    8, 56, 4, 52, 11, 59, 7, 55,
    40, 24, 36, 20, 43, 27, 39, 23,
    2, 50, 14, 62, 1, 49, 13, 61,
    34, 18, 46, 30, 33, 17, 45, 29,
    10, 58, 6, 54, 9, 57, 5, 53,
    42, 26, 38, 22, 41, 25, 37, 21,
};

static inline float lodBayerThreshold(float2 position) {
    uint2 pixel = uint2(floor(position)) & uint2(7);
    uint index = pixel.y * 8u + pixel.x;
    return (float(lodBayer8x8[index]) + 0.5) / 64.0;
}

// Height convention: 1.0 = surface top (no displacement), 0.0 = maximum depth.
// heightBias mirrors Blender's Displacement node "Midlevel" (default 0.5 = no shift):
// values above 0.5 raise the reference plane (less apparent depth), values below lower it.
//
// heightRemapMin/Max contrast-stretch the raw sample BEFORE heightBias is applied. Many
// real-world displacement maps (Substance/Poliigon exports especially) only use a narrow
// slice of the full [0,1] range — e.g. raw values clustered around 0.51-0.54 — leaving POM
// almost no local (brick-to-brick) contrast to work with even though heightScale is set
// reasonably. Identity remap is (0.0, 1.0).
static inline float pomSampleHeight(
    texture2d<float> heightTexture,
    sampler heightSampler,
    float2 uv,
    float heightBias,
    float heightRemapMin,
    float heightRemapMax
) {
    float raw = heightTexture.sample(heightSampler, uv, level(0.0)).r;
    float remapped = saturate((raw - heightRemapMin) / max(heightRemapMax - heightRemapMin, 1e-5));
    return saturate(remapped + (heightBias - 0.5));
}

// Parallax Occlusion Mapping: ray-marches the height field in tangent space to find the
// UV at which the view ray intersects the surface, so the caller can re-sample the rest of
// the material at a UV that reads as displaced. Geometry itself is untouched — this only
// changes which texel gets sampled. See docs/proposals/HeightMapParallaxOcclusionMapping.md.
//
// Uses explicit level(0.0) height-field samples throughout: the loop's trip count is
// data-dependent (adaptive step count + early-exit on intersection), and implicit-derivative
// sampling is undefined inside non-uniform control flow.
static inline float2 parallaxOcclusionMap(
    texture2d<float> heightTexture,
    sampler heightSampler,
    float2 st,
    float3 viewTangent,
    float heightScale,
    float heightBias,
    float heightRemapMin,
    float heightRemapMax,
    float minSteps,
    float maxSteps,
    thread float &outHeightSample
) {
    // Adaptive step count: fewer samples near-normal (where parallax error is small and
    // mostly hidden by the normal map anyway), more at grazing angles where linear-search
    // undersampling is most visible as layer "popping". minSteps/maxSteps are runtime-tunable
    // (POMQualitySettings) rather than fixed, so XR can default to a cheaper tier.
    float grazing = saturate(1.0 - abs(viewTangent.z));
    float numSteps = mix(minSteps, maxSteps, grazing);

    // Perspective-correct parallax slope: as the view ray descends into the height field
    // by depth d, its lateral (UV) travel is d * (viewTangent.xy / viewTangent.z) — similar
    // triangles in tangent space (Tatarchuk, "Practical Parallax Occlusion Mapping", 2006).
    //
    // Clamping only the divisor is NOT enough to keep this stable: near the clamp threshold,
    // 1/viewTangent.z has a very steep slope, so neighboring pixels on a continuous surface —
    // which naturally have slightly different view angles — get wildly different offset
    // magnitudes. That shows up as a visible radial "vortex" distortion right where per-pixel
    // viewTangent.z crosses near the threshold (e.g. as a surface is viewed near edge-on),
    // not as depth. The fix is to smoothly fade POM's contribution to zero before that
    // unstable region is ever reached, rather than just bounding the divisor.
    float fade = smoothstep(0.1, 0.3, viewTangent.z);
    if (fade <= 0.0) {
        outHeightSample = 1.0;
        return st;
    }

    float slopeZ = max(viewTangent.z, 0.3);
    float2 maxOffset = (viewTangent.xy / slopeZ) * heightScale * fade;
    float layerDepth = 1.0 / numSteps;
    float2 deltaUV = maxOffset / numSteps;

    float2 currentUV = st;
    float currentLayerDepth = 0.0;
    float currentHeight = pomSampleHeight(heightTexture, heightSampler, currentUV, heightBias, heightRemapMin, heightRemapMax);

    float2 prevUV = currentUV;
    float prevLayerDepth = currentLayerDepth;
    float prevHeight = currentHeight;

    // Linear search until the ray's depth passes below the sampled height field.
    for (int i = 0; i < int(maxSteps); i++) {
        if (float(i) >= numSteps) break;
        if (currentLayerDepth >= (1.0 - currentHeight)) break;

        prevUV = currentUV;
        prevLayerDepth = currentLayerDepth;
        prevHeight = currentHeight;

        currentUV -= deltaUV;
        currentLayerDepth += layerDepth;
        currentHeight = pomSampleHeight(heightTexture, heightSampler, currentUV, heightBias, heightRemapMin, heightRemapMax);
    }

    // Intersection refinement: linear interpolation between the last two samples using how
    // far each one's ray depth was from the height field, rather than a full binary search.
    float afterDepthDiff = (1.0 - currentHeight) - currentLayerDepth;
    float beforeDepthDiff = (1.0 - prevHeight) - prevLayerDepth;
    float denom = afterDepthDiff - beforeDepthDiff;
    float weight = (abs(denom) > 1e-5) ? saturate(afterDepthDiff / denom) : 0.0;

    outHeightSample = mix(currentHeight, prevHeight, weight);
    return mix(currentUV, prevUV, weight);
}

vertex VertexOutModel vertexModelShader(
    VertexInModel in [[stage_in]],
    constant Uniforms &uniforms [[buffer(modelPassUniformIndex)]],
    constant bool &hasArmature [[buffer(modelPassHasArmature)]],
    const device simd_float4x4 *jointMatrices [[buffer(modelPassJointTransformIndex)]]
) {
    VertexOutModel out;

    float4 position = in.position;
    float4 normals = in.normals;

    if (hasArmature) {
        float4 weights = in.jointWeights;
        ushort4 joints = in.jointIndices;

        position = (weights.x * (jointMatrices[joints.x] * position) +
                    weights.y * (jointMatrices[joints.y] * position) +
                    weights.z * (jointMatrices[joints.z] * position) +
                    weights.w * (jointMatrices[joints.w] * position));

        normals = (weights.x * (jointMatrices[joints.x] * normals) +
                   weights.y * (jointMatrices[joints.y] * normals) +
                   weights.z * (jointMatrices[joints.z] * normals) +
                   weights.w * (jointMatrices[joints.w] * normals));
    }

    out.vPosition = position;
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.normal = normals.xyz;
    //out.shadowCoords = lightOrthoView * uniforms.modelMatrix * position;
    out.uvCoords = in.uv;

    // Compute TBN
    simd_float3 T = normalize(uniforms.normalMatrix * in.tangent.xyz);
    simd_float3 N = normalize(uniforms.normalMatrix * normals.xyz);
    //simd_float3 B = cross(N, T) * in.tangent.w;

    out.tangent = float4(T, in.tangent.w);
    out.tbNormal = N;

    return out;
}


fragment GBufferOut fragmentModelShader(VertexOutModel in [[stage_in]],
                                        constant Uniforms & uniforms [[ buffer(modelPassFragmentUniformIndex) ]],
                                 texture2d<float> baseColor [[texture(modelPassBaseTextureIndex)]],
                                  texture2d<float> roughnessTexture [[texture(modelPassRoughnessTextureIndex)]],
                                  texture2d<float> metallicTexture [[texture(modelPassMetallicTextureIndex)]],
                                  texture2d<float> normalTexture [[texture(modelPassNormalTextureIndex)]],
                                  texture2d<float> heightTexture [[texture(modelPassHeightTextureIndex)]],
                                        constant bool &hasNormal[[buffer(modelPassFragmentHasNormalTextureIndex)]],
                                        constant MaterialParametersUniform &materialParameter [[buffer(modelPassFragmentMaterialParameterIndex)]],
                                  sampler baseColorSampler [[sampler(modelPassBaseSamplerIndex)]],
                                  sampler normalSampler [[sampler(modelPassNormalSamplerIndex)]],
                                  sampler materialSampler [[sampler(modelPassMaterialSamplerIndex)]],
                                  sampler heightSampler [[sampler(modelPassHeightSamplerIndex)]],
                                        constant float &stScale [[buffer(modelPassFragmentSTScaleIndex)]],
                                        constant POMQualityUniform &pomQuality [[buffer(modelPassFragmentPOMQualityIndex)]])
{

    // Base Color and Normal Maps: Linear filtering, mipmaps, repeat wrapping

//    constexpr sampler normalSampler(min_filter::linear, mag_filter::linear, mip_filter::linear, address::repeat);
//
//    // Roughness and Metallic: Linear filtering, mipmaps, default to repeat wrapping
//    constexpr sampler materialSampler(min_filter::linear, mag_filter::linear, mip_filter::linear,
//                                      s_address::clamp_to_edge, t_address::clamp_to_edge);
    
    /*
     constexpr sampler normalSampler(min_filter::linear, mag_filter::linear, mip_filter::linear,
                                     s_address::clamp_to_edge, t_address::clamp_to_edge);

     */

    GBufferOut gBufferOut;

    float2 st=in.uvCoords*stScale;
    st.y=1.0-st.y;

    // Screen-space derivatives of the ORIGINAL (pre-displacement) uv, computed before any
    // data-dependent branching. Used for explicit-gradient sampling of the final material
    // channels below so mip selection tracks the true surface footprint rather than the
    // parallax-displaced uv, which can change rapidly pixel-to-pixel near the height field's
    // silhouette-like transitions and would otherwise cause mip popping.
    float2 stDx = dfdx(st);
    float2 stDy = dfdy(st);

    float4 verticesInWorldSpace=uniforms.modelMatrix*in.vPosition;
    float3 normalVectorInWorldSpace=uniforms.normalMatrix*in.normal;

    //construct tbn matrix TBN (world-space basis built in the vertex stage)
    simd_float3 N=normalize(in.tbNormal);
    simd_float3 T=normalize(in.tangent.xyz);

    //B = (N x T) * T.w
    simd_float3 B=cross(N, T)*in.tangent.w;
    simd_float3x3 TBN=simd_float3x3(T,B,N);

    // ---- Parallax Occlusion Mapping ----
    // Only runs when the material actually has a height texture and POM hasn't been
    // disabled for it — this branch is uniform across the whole draw call (one material per
    // draw, per static batching), not divergent per-fragment.
    bool hasHeight = (materialParameter.hasTexture.w == 1);
    float2 sampleUV = st;
    float pomHeightSample = 0.0;
    float pomOffsetMagnitude = 0.0;
    if (hasHeight) {
        // Distance-based cutoff: the single highest-leverage performance control, since most
        // height-mapped surfaces in a scene (background walls, distant floors) don't need a
        // per-pixel ray march at all. Computed and gated before anything else in this branch
        // so distant fragments skip the TBN-to-tangent-space work and the ray march entirely,
        // not just fade the visual result. Smooth (smoothstep) so there's no popping at the
        // cutoff distance as the camera moves.
        float distanceToCamera = distance(uniforms.cameraPosition, verticesInWorldSpace.xyz);
        float distanceFade = 1.0 - smoothstep(pomQuality.fadeStartDistance, pomQuality.maxDistance, distanceToCamera);

        if (distanceFade > 0.0) {
            // transpose(TBN) rotates a world-space vector into tangent space — TBN's columns
            // are the orthonormal tangent/bitangent/normal axes expressed in world space.
            float3 viewWorld = normalize(uniforms.cameraPosition - verticesInWorldSpace.xyz);
            float3 viewTangent = normalize(transpose(TBN) * viewWorld);

            // `st` (what POM marches in) is sampled with V flipped (st.y = 1 - uv.y, above) to
            // match texture row order, but the bitangent B — and therefore viewTangent.y — is
            // still expressed in the mesh's original, un-flipped V direction. Flipping which
            // texel a direction-encoding sample reads is equivalent to mirroring that data, so
            // the V-component of the offset needs the same sign flip to stay geometrically
            // consistent with the space `st` actually lives in. Without this, the parallax
            // offset's V-component points the wrong way whenever the view has a V-axis
            // component (visible as depth appearing inverted depending on viewing angle).
            viewTangent.y = -viewTangent.y;

            // Scaling heightScale by distanceFade (rather than lerping the resulting UV
            // afterward) shrinks the whole ray march smoothly as the fade approaches zero, so
            // the transition stays smooth rather than snapping to a coarser result right at
            // the cutoff.
            sampleUV = parallaxOcclusionMap(
                heightTexture, heightSampler, st, viewTangent,
                materialParameter.heightScale * distanceFade, materialParameter.heightBias,
                materialParameter.heightRemapMin, materialParameter.heightRemapMax,
                pomQuality.minSteps, pomQuality.maxSteps,
                pomHeightSample
            );
            pomOffsetMagnitude = length(sampleUV - st) / max(materialParameter.heightScale, 1e-5);
        }
    }

    // Base color
    //
    // Materials without a height map keep sampling at `st` with the original implicit-
    // derivative + bias(0.25f) (unchanged from before POM support, preserves existing look).
    // Height-mapped materials sample at the POM-displaced `sampleUV` with explicit gradients
    // computed from the pre-displacement uv, so mip selection doesn't chase the displaced uv's
    // pixel-to-pixel movement near the height field's silhouette-like transitions. `hasHeight`
    // is uniform across the whole draw call, so branching between the two sampling forms here
    // is safe for the implicit-derivative branch.
    float4 sampledColor = hasHeight
        ? baseColor.sample(baseColorSampler, sampleUV, gradient2d(stDx, stDy))
        : baseColor.sample(baseColorSampler, st, bias(0.25f));

    // Detect if basecolor is all zeros
    bool isBaseColorZero = all(materialParameter.baseColor.rgb < 0.001);

    // Fallback to white if base color is zero
    float3 tint = isBaseColorZero ? float3(1.0) : materialParameter.baseColor.rgb;

    float4 inBaseColor = (materialParameter.hasTexture.x == 1)
        ? float4(sampledColor.rgb * tint, sampledColor.a * materialParameter.baseColor.a)
    : float4(tint, materialParameter.baseColor.a);


    if (materialParameter.alphaMode == 2) {
        discard_fragment();
    }

    if (materialParameter.alphaMode == 1 && inBaseColor.a < materialParameter.alphaCutoff) {
        discard_fragment();
    }

    float lodDitherMode = materialParameter.lodDither.y;
    if (lodDitherMode > 0.5) {
        float threshold = clamp(materialParameter.lodDither.x, 0.0, 1.0);
        float dither = lodBayerThreshold(in.position.xy);

        if (lodDitherMode < 1.5) {
            if (dither >= threshold) {
                discard_fragment();
            }
        } else if (dither < threshold) {
            discard_fragment();
        }
    }

    float passthroughAlpha = clamp(materialParameter.passthroughAlpha, 0.0, 1.0);

    //normal map is in Tangent space
    float4 normalSample = hasHeight
        ? normalTexture.sample(normalSampler, sampleUV, gradient2d(stDx, stDy))
        : normalTexture.sample(normalSampler, st, bias(0.25f));
    float3 normalMap=normalize(normalSample.rgb);
    //[0,1] to [-1,1]
    normalMap=normalMap*2.0-1.0;

    //convert to normal map to world space???
    normalMap=(hasNormal==false)?normalize(normalVectorInWorldSpace):normalize(TBN*normalMap);

    float4 roughnessSample = hasHeight
        ? roughnessTexture.sample(materialSampler, sampleUV, gradient2d(stDx, stDy))
        : roughnessTexture.sample(materialSampler, st, bias(0.25f));
    float roughness=(materialParameter.hasTexture.y==1)
        ? selectTextureChannel(roughnessSample, materialParameter.textureChannels.x) * materialParameter.roughness
        : materialParameter.roughness;
    roughness=clamp(roughness, 0.045, 1.0);

    float4 metallicSample = hasHeight
        ? metallicTexture.sample(materialSampler, sampleUV, gradient2d(stDx, stDy))
        : metallicTexture.sample(materialSampler, st, bias(0.25f));
    float metallic=(materialParameter.hasTexture.z==1)
        ? selectTextureChannel(metallicSample, materialParameter.textureChannels.y) * materialParameter.metallic
        : materialParameter.metallic;
    metallic=clamp(metallic, 0.0, 1.0);

    float4 color=inBaseColor;

    gBufferOut.color = float4(color.rgb, passthroughAlpha);
    gBufferOut.normals=float4(normalMap,0.0);
    gBufferOut.positions=verticesInWorldSpace;
    // .b/.a carry POM debug data (raw height sample, uv-offset magnitude) for
    // RenderDebugViewMode.heightDebug / .pomOffsetDebug — see RenderingSystem.swift.
    gBufferOut.material=float4(roughness, metallic, pomHeightSample, pomOffsetMagnitude);
    gBufferOut.emmisive = float4(materialParameter.emmissive, 1.0);
    return gBufferOut;


}

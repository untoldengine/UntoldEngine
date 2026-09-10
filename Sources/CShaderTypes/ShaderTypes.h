//
//  ShaderTypes.h
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.


//
//  ShaderTypes.h
//  UntoldEngine
//
//  Created by Harold Serrano on 5/17/23.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift source
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

#define BLOCK_SIZE 256

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
    simd_float4 attenuation;
    simd_float3 position;
    simd_float3 color;
    float intensity;
    float radius;
}PointLightUniform;

typedef struct{
    simd_float4 attenuation;
    // Emission direction from the spot light into the scene.
    simd_float3 direction;
    simd_float3 position;
    simd_float3 color;
    float intensity;
    float innerCone;
    float outerCone;
    float radius;
}SpotLightUniform;

typedef struct{
    simd_float3 position;
    simd_float3 color;
    // LTC polygon/front normal used to choose rectangle winding in the area-light shader.
    simd_float3 forward;
    simd_float3 right;
    simd_float3 up;
    simd_float2 bounds;
    float intensity;
    float range;
    float nearSourceSuppressionRadius;
    bool twoSided;
    
}AreaLightUniform;

// Upload 6 planes as float4(nx, ny, nz, d)
struct FrustumPlanes {
    simd_float4 p[6];
};

struct EntityAABB {
    simd_float4 center;
    simd_float4 halfExtent;
    uint index; // upper 32 bits of EntityID
    uint version; // lower 32 bits of EntityID
    uint pad0;
    uint pad1;
};

typedef enum{
    gridPassPositionIndex,
    gridPassUniformIndex,
}GridPassBufferIndices;

typedef enum{
    skyPassPositionIndex,
    skyPassUniformIndex,
}SkyPassBufferIndices;

// Uniforms for the procedural atmospheric sky background pass. invViewMatrix/invProjectionMatrix
// let the vertex shader reconstruct a world-space ray per pixel; sunDirection/sunColor/sunIntensity
// are sourced from the engine's active directional light so the sun position drives the sky's
// appearance. Physical scattering constants (Rayleigh/Mie/ozone coefficients, planet/atmosphere
// radii) live as `constant` values inside SkyShader.metal, not here, so they can later be promoted
// into LUT precompute passes (Transmittance/Sky-View/Aerial Perspective) without changing this struct.
typedef struct
{
    matrix_float4x4 invViewMatrix;
    matrix_float4x4 invProjectionMatrix;
    simd_float3 cameraPosition;
    simd_float3 sunDirection;
    simd_float3 sunColor;
    float sunIntensity;
} SkyUniforms;

typedef enum{
    modelPassVerticesIndex,
    modelPassNormalIndex,
    modelPassUVIndex,
    modelPassTangentIndex,
    modelPassJointIdIndex,
    modelPassJointWeightsIndex,
    modelPassBitangentIndex,
    modelPassUniformIndex,
    modelPassJointTransformIndex,
    modelPassHasArmature,
    modelPassOccluderShrinkIndex,
}ModelPassBufferIndices;
typedef enum{
    modelPassFragmentUniformIndex,
    modelPassFragmentHasNormalTextureIndex,
    modelPassFragmentMaterialParameterIndex,
    modelPassFragmentSTScaleIndex,
    modelPassFragmentPOMQualityIndex,
    modelPassFragmentNormalIsPackedXYIndex,
}ModelPassFragmentBufferIndices;


typedef enum{
    prePassGizmoBufferIndex,
    prePassPassthroughBufferIndex,
    prePassSSAOEnabledIndex
}PrePassBufferIndices;

typedef enum{
    debugPassModeIndex,
    debugPassFrustumPlanesIndex,
    debugPassReverseZIndex
}DebugPassBufferIndices;

typedef enum{
    prePassFinalTextureIndex,
    prePassEnvTextureIndex,
    prePassDepthTextureIndex,
    prePassGizmoTextureIndex,
    prePassGaussianTextureIndex,
    prePassSSAOTextureIndex,
}PrePassTextureIndices;

typedef enum{
    lightPassLightOrthoViewMatrixIndex,
    lightPassCameraPositionIndex,
    lightPassLightParamsIndex,
    lightPassPointLightsIndex,
    lightPassPointLightsCountIndex,
    lightPassIBLParamIndex,
    lightPassIBLRotationAngleIndex,
    lightPassSpotLightsIndex,
    lightPassSpotLightsCountIndex,
    lightPassAreaLightsIndex,
    lightPassAreaLightsCountIndex,
    lightPassGameModeIndex,
    lightPassSSAOEnabledIndex,
    lightPassSpotShadowUniformIndex,
    lightPassPointShadowUniformIndex
}LightPassBufferIndices;

typedef enum{
    modelPassBaseTextureIndex,
    modelPassRoughnessTextureIndex,
    modelPassMetallicTextureIndex,
    modelPassNormalTextureIndex,
    modelPassHeightTextureIndex,
}ModelPassTextureIndices;

typedef enum{
    modelPassBaseSamplerIndex,
    modelPassNormalSamplerIndex,
    modelPassMaterialSamplerIndex,
    modelPassHeightSamplerIndex
}ModelPassSamplerIndices;

typedef enum{
    lightPassAlbedoTextureIndex,
    lightPassNormalTextureIndex,
    lightPassPositionTextureIndex,
    lightPassMaterialTextureIndex,
    lightPassShadowTextureIndex,
    lightPassSSAOTextureIndex,
    lightPassIBLIrradianceTextureIndex,
    lightPassIBLSpecularTextureIndex,
    lightPassIBLBRDFMapTextureIndex,
    lightPassAreaLTCMagTextureIndex,
    lightPassAreaLTCMatTextureIndex,
    lightPassSpotShadowTextureIndex,
    lightPassPointShadowTextureIndex
}LightPassTextureIndices;

typedef enum{
    envPassPositionIndex,
    envPassNormalIndex,
    envPassUVIndex,
    envPassConstantIndex,
    envPassRotationAngleIndex
}EnvironmentPassBufferIndices;

typedef enum{
    toneMapPassColorTextureIndex,
    toneMapPassToneMappingIndex,
    toneMapPassExposureIndex,
    toneMapPassGammaIndex,
}ToneMapPassBufferIndices;

typedef enum{
    colorGradingPassColorTextureIndex,
    colorGradingPassBrightnessIndex,
    colorGradingPassContrastIndex,
    colorGradingPassSaturationIndex,
    colorGradingPassExposureIndex,
    colorGradingWhiteBalanceCoeffsIndex,
    colorGradingPassEnabledIndex
}ColorGradingPassBufferIndices;

typedef enum {
    lookPassColorLUTTextureIndex = 1,    // texture(0) is the look pass's sceneTexture
} LookPassLUTTextureIndices;

typedef enum{
    colorLUTEnabledIndex = 7,    // starts after ColorGradingPassBufferIndices (0-6) — both
                                 // enums bind buffers on the same fragmentLookShader
    colorLUTShaperMinStopsIndex,
    colorLUTShaperMaxStopsIndex,
    colorLUTSizeIndex,
}ColorLUTPassBufferIndices;

typedef enum {
    colorGradeLUTTextureIndex = 2,   // texture(0)=sceneTexture, texture(1)=colorLUTTexture (whole-transform bake)
} LookPassGradeLUTTextureIndices;

typedef enum{
    // An externally-authored .cube LUT (see CubeLUTLoader.swift), applied as a
    // post-tonemap creative grade -- independent of, and composable with,
    // ColorLUTPassBufferIndices above (which replaces the tonemap entirely).
    colorGradeLUTEnabledIndex = 11,   // starts after ColorLUTPassBufferIndices (7-10)
    colorGradeLUTDomainMinIndex,
    colorGradeLUTDomainMaxIndex,
}ColorGradeLUTPassBufferIndices;

// Selects which native tonemap operator the look pass runs when colorLUTEnabled
// (the whole-transform bake) is off. Only meaningful in that branch -- the
// baked LUT and the .cube grade above are unaffected by this selector.
typedef enum {
    tonemapOperatorSelectIndex = 14,   // starts after ColorGradeLUTPassBufferIndices (11-13)
} TonemapSelectBufferIndices;

typedef enum {
    tonemapOperatorACES = 0,
    tonemapOperatorAgX = 1,
} TonemapOperatorID;

typedef enum{
    colorCorrectionPassColorTextureIndex,
    colorCorrectionPassTemperatureIndex,
    colorCorrectionPassTintIndex,
    colorCorrectionPassLiftIndex,
    colorCorrectionPassGammaIndex,
    colorCorrectionPassGainIndex,
    colorCorrectionPassEnabledIndex
}ColorCorrectionPassBufferIndices;

typedef enum{
    blurPassDirectionIndex,
    blurPassRadiusIndex,
    blurPassEnabledIndex
}BlurPassBufferIndices;

typedef enum{
    bloomThresholdPassCutoffIndex,
    bloomThresholdPassIntensityIndex,
    bloomThresholdPassEnabledIndex
}BloomThresholdBufferIndices;

typedef enum{
    bloomCompositePassIntensityIndex,
    bloomCompositePassEnabledIndex
}BloomCompositeBufferIndices;

typedef enum{
    vignettePassIntensityIndex,
    vignettePassRadiusIndex,
    vignettePassSoftnessIndex,
    vignettePassCenterIndex,
    vignettePassEnabledIndex
}VignetteBufferIndices;

typedef enum{
    chromaticAberrationPassIntensityIndex,
    chromaticAberrationPassCenterIndex,
    chromaticAberrationPassEnabledIndex
}ChromaticAberrationBufferIndices;

typedef enum{
    ssaoPassRadiusIndex,
    ssaoPassBiasIndex,
    ssaoPassIntensityIndex,
    ssaoPassEnabledIndex,
    ssaoPassViewPortIndex,
    ssaoPassFrustumIndex,
    ssaoPassReverseZIndex,
}SSAOBufferIndices;

typedef enum{
    ssaoDepthTextureIndex
}SSAOTextureIndices;

typedef enum{
    depthOfFieldPassFocusDistanceIndex,
    depthOfFieldPassFocusRangeIndex,
    depthOfFieldPassMaxBlurIndex,
    depthOfFieldPassFrustumIndex,
    depthOfFieldPassEnabledIndex,
    depthOfFieldPassReverseZIndex
}DepthOfFieldBufferIndices;

typedef enum{
    shadowPassModelPositionIndex,
    shadowPassJointIdIndex,
    shadowPassJointWeightsIndex,
    shadowPassModelUniform,
    shadowPassLightMatrixUniform,
    shadowPassLightPositionUniform,
    shadowPassJointTransformIndex,
    shadowPassHasArmature,
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
    positionTarget,
    materialTarget,
    emissiveTarget
}RenderTargets;


typedef struct{
    simd_float4 baseColor;
    simd_int4 hasTexture; //x=hasbasecolor,y=hasroughmap, z=hasmetalmap, w=hasheightmap
    simd_int4 textureChannels; //x=roughness channel, y=metallic channel; 0=r,1=g,2=b,3=a
    simd_float4 edgeTint;
    simd_float3 emmissive;
    float roughness;
    float specular;
    float subsurface;
    float metallic;
    float specularTint;
    float anisotropic;
    float sheen;
    float sheenTint;
    float clearCoat;
    float clearCoatGloss;
    float ior;
    float alphaCutoff;
    float passthroughAlpha; // mixed passthrough color alpha; depth remains opaque
    int alphaMode; // 0=opaque, 1=mask, 2=blend
    simd_float4 lodDither; // x=threshold, y=mode: 0 off, 1 keep below, 2 keep at/above
    bool interactWithLight;
    // Parallax Occlusion Mapping. heightScale is the total ray-march depth in UV-normalized
    // units — named after Blender's Displacement node "Scale" input, but NOT unit-equivalent:
    // Blender's Scale is a world-space distance, this is a UV-space fraction. A raw Scale
    // value carried through from Blender needs retuning, not a straight copy (see the
    // exporter's ExportedMaterial.height_scale docstring). heightMidlevel matches its
    // "Midlevel" input.
    float heightScale;
    float heightMidlevel;
    // Contrast-stretch applied to the raw height sample before heightMidlevel: many real-world
    // displacement maps only use a narrow slice of [0,1], leaving POM almost no local
    // contrast to work with unless that slice is remapped back out first. Identity is (0,1).
    float heightRemapMin;
    float heightRemapMax;
}MaterialParametersUniform;

// Runtime-tunable Parallax Occlusion Mapping cost controls (global, not per-material — see
// POMQualitySettings in Globals.swift). minSteps/maxSteps bound the adaptive ray-march step
// count; maxDistance/fadeStartDistance fade POM out entirely beyond a configurable distance,
// gating the ray march itself for distant fragments rather than just fading the visual result.
typedef struct{
    float minSteps;
    float maxSteps;
    float maxDistance;
    float fadeStartDistance;
}POMQualityUniform;

typedef struct{
    float ambientIntensity;
    bool applyIBL;
}IBLParamsUniform;

typedef struct{
    simd_float3 direction;
    simd_float3 color;
    float intensity;
}LightParameters;

typedef enum{
    rayModelAccelStructIndex,
    rayModelBufferInstanceIndex,
    rayModelOriginIndex,
    rayModelDirectionIndex,
    rayModelInstanceHitIndex,
}RayModelBufferIndices;

typedef struct{
    int instanceHit;
    float distance;
    unsigned int triangleIndex;
    unsigned int geometryIndex;
    simd_float2 barycentric;
}RayModelPickOutput;

typedef enum{
    lightVisualPassPositionIndex,
    lightVisualPassUVIndex,
    lightVisualPassViewMatrixIndex,
    lightVisualPassProjMatrixIndex,
    lightVisualPassModelMatrixIndex,
}LightVisualBufferIndices;

typedef enum{
    frustumCullingPassPlanesIndex,
    frustumCullingPassVisibilityIndex,
    frustumCullingPassVisibleCountIndex,
    frustumCullingPassObjectIndex,
    frustumCullingPassObjectCountIndex,
    frustumCullingPassFlagIndex
}FrustumCullingBufferIndices;

typedef enum{
    markVisibilityPassFrustumIndex,
    markVisibilityPassEntityAABBIndex,
    markVisibilityPassEntityAABBCountIndex,
    markVisibilityPassFlagIndex
}MarkVisibilityBufferIndices;

typedef enum{
    scanLocalPassFlagIndex,
    scanLocalPassIndicesIndex,
    scanLocalPassBlockSumsIndex,
    scanLocalPassCountIndex
}ScanLocalBufferIndices;

typedef enum{
    scanBlockSumPassSumIndex,
    scanBlockSumPassOffsetIndex,
    scanBlockSumPassNumBlocksIndex
}ScanBlockSumBufferIndices;

typedef enum{
    compactPassFlagsIndex,
    compactPassIndicesIndex,
    compactPassBlockOffsetIndex,
    compactPassEntityAABBIndex,
    compactPassCountIndex,
    compactPassVisibilityIndicesIndex,
    compactPassVisibilityCountIndex
}ScatterCompactBufferIndices;

// HZB build
typedef enum{
    hzbBuildPassMipLevelIndex,
    hzbBuildPassSourceDimensionsIndex,
    hzbBuildPassReverseZIndex
}HZBBuildBufferIndices;

typedef enum{
    hzbBuildPassDepthTextureIndex,
    hzbBuildPassSourceMipTextureIndex,
    hzbBuildPassDestMipTextureIndex
}HZBBuildTextureIndices;

// HZB occlusion culling
typedef enum{
    hzbCullPassFrustumIndex,
    hzbCullPassEntityAABBIndex,
    hzbCullPassEntityAABBCountIndex,
    hzbCullPassVisibilityIndex,
    hzbCullPassVisibleCountIndex,
    hzbCullPassProjectionMatrixIndex,
    hzbCullPassViewportIndex,
    hzbCullPassMipCountIndex,
    hzbCullPassReverseZIndex,
    hzbCullPassOcclusionBiasIndex
}HZBOcclusionCullingBufferIndices;

typedef enum{
    hzbCullPassDepthPyramidTextureIndex
}HZBOcclusionCullingTextureIndices;

typedef enum {
    imagePlaneARPositions    = 0,
} ARBufferIndices;

typedef enum {
    kVertexAttributePosition  = 0,
    kVertexAttributeTexcoord  = 1,
    kVertexAttributeNormal    = 2
} ARVertexAttributes;

typedef enum {
    textureARIndexColor    = 0,
    textureARIndexY        = 1,
    textureARIndexCbCr     = 2
} ARTextureIndices;

typedef enum{
    gaussianEncodedSplatIndex,
    gaussianUniformIndex,
    gaussianNumberOfSplatsIndex,
    gaussianIndicesIndex,
    gaussianVisibleIndicesIndex,
    gaussianVisibleCountIndex,
    gaussianCullHZBReverseZIndex,
    gaussianCullHZBOcclusionBiasIndex,
    gaussianCullHZBValidIndex,
}GaussianDepthBufferIndices;

typedef enum{
    gaussianCullHZBDepthPyramidTextureIndex = 0,
}GaussianCullTextureIndices;

/// Threads per threadgroup for every pass that runs over the visible splat list (depth keys,
/// preprocess, radix histogram and scatter). Fixed so the threadgroup count the GPU writes
/// into GaussianVisibleSet matches what the CPU encodes as threadsPerThreadgroup.
#define gaussianVisibleBlockSize 256

/// Per-entity, per-in-flight-frame record of the splats that survived gaussianFrustumCull.
/// The cull appends into visibleCount atomically; gaussianFinalizeVisibleSet then derives the
/// indirect dispatch and draw arguments from it, so every later stage of the frame (depth
/// keys, preprocess, radix sort, draw) is sized on the GPU from this frame's count. The CPU
/// only ever sees this count through a completed-buffer readback two or three frames later,
/// and a list that grew since then must not be cut to that older size.
///
/// The same record shape describes an entity's visible-chunk list (gaussianChunkCull /
/// gaussianFinalizeVisibleChunks / gaussianComputeChunkQuotas): there threadgroupCount and
/// threadgroupsPerGrid[0] are the number of visible chunks — one threadgroup of
/// gaussianChunkDecodePreprocess per chunk — instanceCount is the sum of the visible chunks'
/// splat counts (what the entity asked of the frame's budget) and visibleCount the sum of their
/// quotas (the most the fused pass can append for this entity), both for readbacks only.
typedef struct{
    uint32_t visibleCount;           // atomic_uint appended by gaussianFrustumCull
    uint32_t threadgroupCount;       // ceil(visibleCount / gaussianVisibleBlockSize)
    uint32_t overflowCount;          // shared set only: splats appended past its capacity (dropped)
    uint32_t _pad0;
    uint32_t threadgroupsPerGrid[3]; // MTLDispatchThreadgroupsIndirectArguments
    uint32_t _pad1;
    uint32_t vertexCount;            // MTLDrawPrimitivesIndirectArguments: 4 (the splat quad)
    uint32_t instanceCount;          //   visibleCount
    uint32_t vertexStart;            //   0
    uint32_t baseInstance;           //   0
}GaussianVisibleSet;

/// Byte offsets of the two indirect-argument blocks inside GaussianVisibleSet.
#define gaussianVisibleSetDispatchArgumentsOffset 16
#define gaussianVisibleSetDrawArgumentsOffset 32

/// Upper bound on splat entities the shared draw addresses per frame (entity slot in each record).
#define gaussianMaxEntitiesPerFrame 256

/// One entry of the frame's shared working set, written by gaussianPreprocess for every splat
/// that survived its entity's cull: everything the splat draw needs. The draw projects
/// `position` with the entity's per-eye constants, so one record serves both eyes.
typedef struct{
    simd_float4 positionAndEntity;  // xyz: entity-local centre; w: entity index as uint bits (index into GaussianEntityDrawConstants)
    simd_float4 conicAndOpacity;    // xyz: inverse 2D covariance, head-centre view; w: opacity
    simd_float4 color;              // xyz: linear colour, spherical harmonics evaluated for the head-centre view; w unused
    simd_float4 axes;               // xy: quad semi-axis 1, zw: semi-axis 2, in pixels
}GaussianWorkingSetSplat;           // 64 bytes; with its 8-byte key, the per-slot cost the removed per-entity buffers had

/// Per-entity constants the shared splat draw reads through GaussianWorkingSetSplat.entityIndex,
/// written per eye by the draw pass.
typedef struct{
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
}GaussianEntityDrawConstants;

/// Per-entity inputs of gaussianPreprocess beyond the splat data.
typedef struct{
    uint32_t entityIndex;
    uint32_t workingSetCapacity;
    uint32_t debugColorEnabled;
    uint32_t _pad0;
    simd_float4 debugColor;
    simd_float4 colorGain;     // xyz: linear multiplier on the splat colour (capture exposure, editor offset, XR tint); w unused
    float opacityScale;        // multiplier on every splat's opacity: 1 normal, 0 hidden (nothing is appended), between for a cross-fade
    float _pad1[3];
}GaussianPreprocessEntityConstants;

typedef struct{
    simd_float4 center;
    simd_float4 scale;
    simd_float4 color;
    simd_float4 quat;
    float opacity;
}GaussianSplat;

// position stays full float precision (fed directly into world/view/clip-space matrix math,
// where half-precision error would visibly drift); covariance and color/opacity are
// half-precision, matching the density another native Metal/simd Gaussian-splat renderer
// (MetalSplatter) uses for the same fields. simd_half3/simd_half4 pack tightly (8 bytes each,
// no padding between them) unlike simd_float3 (16-byte-aligned even for a 3-component vector),
// so this is 48 bytes total per splat vs. the previous 128 — not just "half the bytes" of the
// 3 vector fields, but a ~2.7x reduction overall once the float3 alignment padding that also
// disappears is accounted for. colorAndOpacity folds opacity into color's 4th component
// (again matching MetalSplatter) since a lone scalar field here would otherwise force the
// same kind of alignment padding this change is trying to eliminate.
typedef struct{
    simd_float3 position;
    simd_half3  covA;
    simd_half3  covB;
    simd_half4  colorAndOpacity; // .xyz = SH0 base color, .w = opacity
}EncodedGaussianSplat;

// Higher-order SH coefficients are stored in a separate packed byte buffer,
// quantized to a fixed [-1, 1] range: byte = round(clamp(x,-1,1)*127)+128,
// dequantized on read as (byte-128)/128 — see loadGaussianSHCoefficient.
// Layout per splat: R[1...n], G[1...n], B[1...n]. The DC coefficient remains
// represented by EncodedGaussianSplat.colorAndOpacity.xyz.
typedef struct{
    uint degree;
    uint coefficientsPerChannel;
    uint higherOrderCoefficientsPerSplat;
    uint _pad0;
}GaussianSHMetadata;

// Per-splat conic/axes/color, computed once per splat per frame by the gaussianPreprocess
// compute kernel instead of redundantly 4x per splat (once per instanced quad vertex) in the
// draw vertex shader — see gaussianPreprocess in Gaussians.metal. Indexed by the same
// original splat index as EncodedGaussianSplat.
//
// axis1/axis2 are the projected covariance ellipse's two (orthogonal) semi-axis vectors in
// screen pixels — i.e. eigenvectors of the 2D covariance scaled by sigma*sqrt(eigenvalue),
// where sigma is this splat's opacity-adaptive extent (gaussianAdaptiveSigma in Gaussians.metal,
// which reaches kGaussianQuadSigma exactly at opacity 1 and shrinks below it as opacity drops) —
// used to build a tight, rotated quad instead of an axis-aligned bounding box. An axis-aligned
// box has to cover a rotated ellipse's full extent along screen X/Y, which for an anisotropic
// splat (the common case — Gaussians are oriented however the surface they came from sits) can
// be several times larger in area than the ellipse itself, costing that many more rasterized/
// shaded fragments regardless of how cheap the per-fragment TBDR blend itself is.

typedef enum{
    gaussianPreprocessSplatIndex = 0,
    gaussianPreprocessUniformIndex,
    gaussianPreprocessNumOfSplatsIndex,
    gaussianPreprocessVisibleIndicesIndex,
    gaussianPreprocessVisibleCountIndex,
    gaussianPreprocessViewportIndex,
    gaussianPreprocessSHIndex,
    gaussianPreprocessSHMetadataIndex,
    gaussianPreprocessLocalCameraIndex,
    gaussianPreprocessEntityConstantsIndex,   // GaussianPreprocessEntityConstants
    gaussianPreprocessWorkingSetIndex,        // GaussianWorkingSetSplat[], shared per frame
    gaussianPreprocessSharedKeysIndex,        // uint64_t depth keys, shared per frame
    gaussianPreprocessSharedVisibleSetIndex,  // GaussianVisibleSet, shared per frame
}GaussianPreprocessBufferIndices;

typedef enum{
      gaussianTBDRRenderIndicesIndex = 0,      // sorted shared keys
      gaussianTBDRRenderWorkingSetIndex,       // GaussianWorkingSetSplat[]
      gaussianTBDRRenderEntityConstantsIndex,  // GaussianEntityDrawConstants[] for this eye
      gaussianTBDRRenderViewPortIndex,
      gaussianTBDRRenderReverseZIndex,
      gaussianTBDRRenderDrawDebugIndex,        // GaussianTBDRDrawDebug
  }GaussianTBDRRenderBufferIndices;

/// Per-draw switches for the splat fragment shader, set from GaussianDebugOptions each frame.
typedef struct{
    uint32_t maxBlendedSplatsPerPixel;  // normally kGaussianMaxBlendedSplatsPerPixel (64); 255 lifts the cap
    uint32_t skipOpaqueDepthTest;       // non-zero: never occlude splats by the opaque depth snapshot
}GaussianTBDRDrawDebug;

typedef enum{
      gaussianTBDRDrawOpaqueDepthTextureIndex = 0,
  }GaussianTBDRDrawTextureIndices;

// Per-chunk constants for decoding a .untoldgs v3 chunk on the GPU — see gaussianDecodeChunks
// in Gaussians.metal, gaussianChunkDecodePreprocess in GaussianChunkPreprocess.metal and
// UntoldGSChunkEntry (Swift). Plain floats rather than simd_float3 so the C, Swift and Metal
// layouts agree byte for byte (48 bytes, no alignment padding).
typedef struct{
    float aabbMinX, aabbMinY, aabbMinZ;
    float logScaleMin;
    float aabbMaxX, aabbMaxY, aabbMaxZ;
    float logScaleMax;
    uint  firstSplat;   // index of this chunk's first record in the packed input and the output
    uint  splatCount;
    uint  _pad0;
    uint  _pad1;
}GaussianChunkDecodeConstants;

typedef enum{
    gaussianDecodePackedIndex = 0,   // uint4 per splat: packed position, rotation, scale, rgba
    gaussianDecodeChunksIndex,       // GaussianChunkDecodeConstants[]
    gaussianDecodeChunkCountIndex,   // uint
    gaussianDecodeOutputIndex,       // EncodedGaussianSplat[]
}GaussianDecodeBufferIndices;

// MARK: - Chunk-level cull of .untoldgs entities (GaussianChunkCull.metal)

/// One entry of the per-entity, per-in-flight-frame visible-chunk list gaussianChunkCull appends
/// to: the chunk's index into the entity's GaussianChunkDecodeConstants table, its splat count,
/// and the quota gaussianComputeChunkQuotas grants it from the frame's working-set budget — the
/// number of its first (most important) splats one threadgroup of gaussianChunkDecodePreprocess
/// then decodes, tests and appends. The cull writes quota = splatCount; the quota pass lowers it.
typedef struct{
    uint32_t chunkIndex;
    uint32_t splatCount;
    uint32_t quota;
    uint32_t _pad0;
}GaussianVisibleChunk;   // 16 bytes

/// Per-entity inputs of gaussianChunkCull. Both view-projections already include the entity's
/// model matrix; a chunk is visible when its padded box passes either one (viewCount 2, the two
/// eyes of a stereo frame) or the first (viewCount 1, mono).
typedef struct{
    matrix_float4x4 viewProjection0;
    matrix_float4x4 viewProjection1;
    simd_float2 viewport;        // pixels; picks the HZB mip whose texel covers the chunk's rect
    float clipGuardBand;         // the per-splat cull's guard band (0.25)
    float hzbOcclusionBias;      // the mesh cull's bias (0.02)
    uint32_t chunkCount;
    uint32_t viewCount;          // 1 or 2
    uint32_t hzbValid;           // non-zero: also test the box against the previous frame's HZB
    uint32_t hzbReverseZ;
    uint32_t hzbMipCount;
    uint32_t forceAllVisible;    // GaussianDebugOptions.disableChunkCull: every chunk is appended
    uint32_t _pad0[2];
}GaussianChunkCullConstants;  // 176 bytes

typedef enum{
    gaussianChunkCullChunkTableIndex = 0,  // GaussianChunkDecodeConstants[]
    gaussianChunkCullConstantsIndex,       // GaussianChunkCullConstants
    gaussianChunkCullVisibleChunksIndex,   // GaussianVisibleChunk[] (output, chunkCount entries)
    gaussianChunkCullSplatTotalIndex,      // atomic_uint: the chunk record's visibleCount (sum of appended splat counts), byte offset 0
    gaussianChunkCullChunkTotalIndex,      // atomic_uint: the chunk record's threadgroupCount (appended chunks), byte offset 4
    gaussianChunkCullBudgetStateIndex = 6, // gaussianFinalizeVisibleChunks: GaussianBudgetState whose requestedSplats the entity's total joins (the record itself sits at gaussianVisibleCountIndex, 5)
}GaussianChunkCullBufferIndices;

typedef enum{
    gaussianChunkCullHZBDepthPyramidTextureIndex = 0,
}GaussianChunkCullTextureIndices;

// MARK: - Budgeted working set (GaussianWorkingSetBudget.metal)

/// The frame's working-set budget state, one persistent buffer read and written on the GPU
/// every frame (command buffers on one queue run in order, so frame N+1 sees frame N's scale):
/// gaussianFinalizeVisibleChunks adds each chunked entity's visible splat total to
/// requestedSplats, gaussianReserveBudgetSplats adds each whole-buffer entity's visible count
/// to reservedSplats, gaussianComputeBudgetScale fits the request to what the reservation
/// leaves of the budget as the scale the quotas apply (a fall taken at once, a rise smoothed
/// against the previous frame's), gaussianComputeChunkQuotas adds the quotas it grants to
/// quotaSplats, and gaussianPublishBudgetState copies the record into the frame's in-flight
/// slot for the CPU readback (profiling, tests).
typedef struct{
    uint32_t requestedSplats;   // atomic: Σ over chunked entities of their visible chunks' splat counts
    uint32_t quotaSplats;       // atomic: Σ over chunked entities of the quotas granted
    uint32_t budget;            // records the quotas were fitted to this frame (the shared set's capacity)
    uint32_t frameCount;        // frames the state has been through; 0 means the first frame takes the target as is
    float targetScale;          // min(1, (headroom · budget − reservedSplats) / requestedSplats)
    float scale;                // targetScale, or the previous frame's scale raised by at most one step when the target is above it
    uint32_t reservedSplats;    // atomic: Σ over whole-buffer entities of their visible counts, granted before the quotas
    uint32_t _pad0;
}GaussianBudgetState;           // 32 bytes

/// Inputs of gaussianComputeBudgetScale.
typedef struct{
    uint32_t budget;            // the shared set's capacity this frame
    uint32_t forceUnitScale;    // GaussianDebugOptions.disableWorkingSetBudget: every chunk keeps its whole splat count
    float headroom;             // fraction of the budget the quotas aim for (0.98), leaving room for rounding
    float maxStepFraction;      // largest relative rise of scale per frame (0.1)
    float minStep;              // smallest absolute rise per frame (0.05), so a climb from a low scale does not crawl
    uint32_t resetHysteresis;   // 1: take the target as on the first frame (a frame without splat entities went by)
    uint32_t _pad0[2];
}GaussianBudgetScaleConstants;  // 32 bytes

typedef enum{
    gaussianBudgetStateIndex = 0,        // GaussianBudgetState, persistent
    gaussianBudgetScaleConstantsIndex,   // GaussianBudgetScaleConstants
    gaussianBudgetChunkSetIndex,         // gaussianComputeChunkQuotas: the entity's chunk record (GaussianVisibleSet); gaussianReserveBudgetSplats: the whole-buffer entity's GaussianVisibleSet
    gaussianBudgetVisibleChunksIndex,    // gaussianComputeChunkQuotas: the entity's GaussianVisibleChunk[]
    gaussianBudgetReadbackIndex,         // gaussianPublishBudgetState: this frame slot's copy of the state
    gaussianBudgetQuotaTotalIndex,       // gaussianComputeChunkQuotas: atomic_uint, the state's quotaSplats (byte offset 4)
    gaussianBudgetReservedTotalIndex,    // gaussianReserveBudgetSplats: atomic_uint, the state's reservedSplats (byte offset 24)
}GaussianBudgetBufferIndices;

// MARK: - Fused decode, test, project and compact of .untoldgs entities (GaussianChunkPreprocess.metal)

/// Bindings of gaussianChunkDecodePreprocess: one threadgroup per visible chunk, indirect from
/// the entity's chunk record, reading the resident 16-byte records and writing the frame's
/// shared working set the way gaussianPreprocess does for a whole-buffer entity.
typedef enum{
    gaussianChunkPreprocessPackedIndex = 0,      // uint4 per splat: the resident .untoldgs core records
    gaussianChunkPreprocessChunkTableIndex,      // GaussianChunkDecodeConstants[]
    gaussianChunkPreprocessVisibleChunksIndex,   // GaussianVisibleChunk[] of this frame
    gaussianChunkPreprocessUniformIndex,         // Uniforms: head-centre model-view and projection
    gaussianChunkPreprocessCullConstantsIndex,   // GaussianChunkCullConstants: the eye view-projections and HZB inputs of the per-splat test
    gaussianChunkPreprocessViewportIndex,        // float2
    gaussianChunkPreprocessSHIndex,              // uchar[]: spherical harmonics by original splat index
    gaussianChunkPreprocessSHMetadataIndex,      // GaussianSHMetadata
    gaussianChunkPreprocessLocalCameraIndex,     // float3: camera position in entity space
    gaussianChunkPreprocessEntityConstantsIndex, // GaussianPreprocessEntityConstants
    gaussianChunkPreprocessWorkingSetIndex,      // GaussianWorkingSetSplat[], shared per frame
    gaussianChunkPreprocessSharedKeysIndex,      // uint64_t depth keys, shared per frame
    gaussianChunkPreprocessSharedVisibleSetIndex,// GaussianVisibleSet, shared per frame
}GaussianChunkPreprocessBufferIndices;

typedef enum{
    gaussianChunkPreprocessHZBDepthPyramidTextureIndex = 0,
}GaussianChunkPreprocessTextureIndices;

typedef enum{
      outputTransformPassEncodingModeIndex
  }OutputTransformBufferIndices;

typedef enum{
    radixClearHistogramBuffer = 0,
}RadixClearHistogramBufferIndices;

typedef enum{
    radixHistogramKeysIn    = 0,
    radixHistogramOutput    = 1,
    radixHistogramVisibleSet = 2,  // GaussianVisibleSet: element count for this pass
    radixHistogramPassIndex = 3,
    radixHistogramPerTGOut  = 4,   // per-threadgroup local histogram output
}RadixHistogramBufferIndices;

typedef enum{
    radixScanHistogram  = 0,
    radixScanNumBuckets = 1,
}RadixScanBufferIndices;

typedef enum{
    radixScanPerTGBuffer    = 0,   // in-place: local histogram → per-TG prefix sums
    radixScanPerTGVisibleSet = 1,  // GaussianVisibleSet: threadgroup count for this pass
}RadixScanPerTGBufferIndices;

typedef enum{
    radixScatterKeysIn      = 0,
    radixScatterKeysOut     = 1,
    radixScatterOffsets     = 2,
    radixScatterVisibleSet  = 3,   // GaussianVisibleSet: element count for this pass
    radixScatterPassIdx     = 4,
    radixScatterPerTGStart  = 5,   // per-TG starting offsets per digit
}RadixScatterBufferIndices;

typedef enum{
    fxaaPassTexelSizeIndex,
    fxaaPassEnabledIndex,
    fxaaPassSubpixelIndex,
    fxaaPassEdgeThresholdIndex,
    fxaaPassEdgeThresholdMinIndex
}FXAABufferIndices;

typedef enum{
    smaaPassTexelSizeIndex,
    smaaPassEdgeThresholdIndex
}SMAABufferIndices;

// Transparency
typedef enum{
    transparencyPassFragmentUniformIndex,
    transparencyPassFragmentHasNormalTextureIndex,
    transparencyPassFragmentMaterialParameterIndex,
    transparencyPassFragmentSTScaleIndex,
    transparencyPassFragmentNormalIsPackedXYIndex,
}TransparencyPassFragmentBufferIndices;

typedef enum{
    transparencyPassBaseTextureIndex,
    transparencyPassRoughnessTextureIndex,
    transparencyPassMetallicTextureIndex,
    transparencyPassNormalTextureIndex,
}TransparencyPassTextureIndices;

typedef enum{
    transparencyPassBaseSamplerIndex,
    transparencyPassNormalSamplerIndex,
    transparencyPassMaterialSamplerIndex
}TransparencyPassSamplerIndices;

typedef enum {
    transparencyPassLightOrthoViewMatrixIndex = 5, // starts after TransparencyPassFragmentBufferIndices
    transparencyPassLightParamsIndex,
    transparencyPassCameraPositionIndex,           // simd_float3 (camera position)
    transparencyPassPointLightsIndex,              // PointLightBlock
    transparencyPassSpotLightsIndex,               // SpotLightBlock
    transparencyPassAreaLightsIndex,               // AreaLightBlock
    transparencyPassIBLParamIndex,                 // IBLParamsUniform
    transparencyPassIBLRotationAngleIndex,         // float
} TransparencyPassLightingBufferIndices;

typedef enum {
    transparencyPassAreaLTCMatTextureIndex = 4,    // starts after TransparencyPassTextureIndices
    transparencyPassAreaLTCMagTextureIndex,        // LTC magnitude texture
    transparencyPassIBLIrradianceTextureIndex,     // IBL irradiance map
    transparencyPassIBLSpecularTextureIndex,       // IBL specular map
    transparencyPassIBLBRDFMapTextureIndex,        // IBL BRDF lookup table
    transparencyPassShadowTextureIndex,
} TransparencyPassLightingTextureIndices;

//Ray tracing structs
#define GEOMETRY_MASK_TRIANGLE 1
#define GEOMETRY_MASK_SPHERE   2
#define GEOMETRY_MASK_LIGHT    4


#endif /* ShaderTypes_h */

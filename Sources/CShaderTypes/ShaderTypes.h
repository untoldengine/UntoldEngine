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
}ModelPassBufferIndices;
typedef enum{
    modelPassFragmentUniformIndex,
    modelPassFragmentHasNormalTextureIndex,
    modelPassFragmentMaterialParameterIndex,
    modelPassFragmentSTScaleIndex,
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
    lightPassSSAOEnabledIndex
}LightPassBufferIndices;

typedef enum{
    modelPassBaseTextureIndex,
    modelPassRoughnessTextureIndex,
    modelPassMetallicTextureIndex,
    modelPassNormalTextureIndex,
}ModelPassTextureIndices;

typedef enum{
    modelPassBaseSamplerIndex,
    modelPassNormalSamplerIndex,
    modelPassMaterialSamplerIndex
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
    lightPassAreaLTCMatTextureIndex
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
    simd_int4 hasTexture; //x=hasbasecolor,y=hasroughmap, z=hasmetalmap
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
}MaterialParametersUniform;

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
}GaussianDepthBufferIndices;

typedef struct{
    simd_float4 center;
    simd_float4 scale;
    simd_float4 color;
    simd_float4 quat;
    float opacity;
}GaussianSplat;

typedef struct{
    simd_float3 position;
    float opacity;
    simd_float3 color;
    float _pad0;
    simd_float3 covA;
    float _pad1;
    simd_float3 covB;
    float _pad2;
}EncodedGaussianSplat;

// Higher-order SH coefficients are stored in a separate packed half buffer.
// Layout per splat: R[1...n], G[1...n], B[1...n]. The DC coefficient remains
// represented by EncodedGaussianSplat.color.
typedef struct{
    uint degree;
    uint coefficientsPerChannel;
    uint higherOrderCoefficientsPerSplat;
    uint _pad0;
}GaussianSHMetadata;

typedef enum{
      gaussianTBDRRenderIndicesIndex = 0,
      gaussianTBDRRenderSplatIndex,
      gaussianTBDRRenderUniformIndex,
      gaussianTBDRRenderViewPortIndex,
      gaussianTBDRRenderReverseZIndex,
      gaussianTBDRRenderSHIndex,
      gaussianTBDRRenderSHMetadataIndex,
      gaussianTBDRRenderLocalCameraIndex,
  }GaussianTBDRRenderBufferIndices;

typedef enum{
      outputTransformPassEncodingModeIndex
  }OutputTransformBufferIndices;

typedef enum{
    radixClearHistogramBuffer = 0,
}RadixClearHistogramBufferIndices;

typedef enum{
    radixHistogramKeysIn    = 0,
    radixHistogramOutput    = 1,
    radixHistogramNumElems  = 2,
    radixHistogramPassIndex = 3,
    radixHistogramPerTGOut  = 4,   // per-threadgroup local histogram output
}RadixHistogramBufferIndices;

typedef enum{
    radixScanHistogram  = 0,
    radixScanNumBuckets = 1,
}RadixScanBufferIndices;

typedef enum{
    radixScanPerTGBuffer    = 0,   // in-place: local histogram → per-TG prefix sums
    radixScanPerTGNumGroups = 1,
}RadixScanPerTGBufferIndices;

typedef enum{
    radixScatterKeysIn      = 0,
    radixScatterKeysOut     = 1,
    radixScatterOffsets     = 2,
    radixScatterNumElems    = 3,
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
    transparencyPassLightOrthoViewMatrixIndex = 4, // starts after TransparencyPassFragmentBufferIndices
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

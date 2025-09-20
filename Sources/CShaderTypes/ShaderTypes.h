
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
    simd_float3 forward;
    simd_float3 right;
    simd_float3 up;
    simd_float2 bounds;
    float intensity;
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
    lightPassGameModeIndex
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
    ssaoPassKernelIndex,
    ssaoPassPerspectiveSpaceIndex,
    ssaoPassViewSpaceIndex,
    ssaoPassKernelSizeIndex,
    ssaoPassRadiusIndex,
    ssaoPassBiasIndex,
    ssaoPassIntensityIndex,
    ssaoPassEnabledIndex,
    ssaoPassViewPortIndex,
}SSAOBufferIndices;

typedef enum{
    ssaoNormalMapTextureIndex,
    ssaoPositionMapTextureIndex,
    ssaoNoiseMapTextureIndex
}SSAOTextureIndices;

typedef enum{
    depthOfFieldPassFocusDistanceIndex,
    depthOfFieldPassFocusRangeIndex,
    depthOfFieldPassMaxBlurIndex,
    depthOfFieldPassFrustumIndex,
    depthOfFieldPassEnabledIndex
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

//Ray tracing structs
#define GEOMETRY_MASK_TRIANGLE 1
#define GEOMETRY_MASK_SPHERE   2
#define GEOMETRY_MASK_LIGHT    4


#endif /* ShaderTypes_h */

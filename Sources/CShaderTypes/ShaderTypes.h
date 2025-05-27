
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
    modelPassLightOrthoViewMatrixIndex,
    modelPassLightParamsIndex,
    modelPassPointLightsIndex,
    modelPassPointLightsCountIndex,
    modelPassBaseTextureIndex,
    modelPassRoughnessTextureIndex,
    modelPassMetallicTextureIndex,
    modelPassNormalTextureIndex,
    modelPassShadowTextureIndex,
    modelPassHasNormalTextureIndex,
    modelPassMaterialParameterIndex,
    modelPassIBLIrradianceTextureIndex,
    modelPassIBLSpecularTextureIndex,
    modelPassIBLBRDFMapTextureIndex,
    modelPassIBLParamIndex,
    modelPassIBLRotationAngleIndex,
    modelPassJointTransformIndex,
    modelPassHasArmature,
    modelPassSpotLightsIndex,
    modelPassSpotLightsCountIndex
}ModelPassBufferIndices;

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
}ColorGradingPassBufferIndices;

typedef enum{
    colorCorrectionPassColorTextureIndex,
    colorCorrectionPassTemperatureIndex,
    colorCorrectionPassTintIndex,
    colorCorrectionPassLiftIndex,
    colorCorrectionPassGammaIndex,
    colorCorrectionPassGainIndex
}ColorCorrectionPassBufferIndices;

typedef enum{
    blurPassDirectionIndex,
    blurPassRadiusIndex,
}BlurPassBufferIndices;

typedef enum{
    bloomThresholdPassCutoffIndex,
    bloomThresholdPassIntensityIndex
}BloomThresholdBufferIndices;

typedef enum{
    shadowPassModelPositionIndex,
    shadowPassModelUniform,
    shadowPassLightMatrixUniform,
    shadowPassLightPositionUniform
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
}RenderTargets;


typedef struct{
    simd_float4 baseColor;
    simd_int4 hasTexture; //x=hasbasecolor,y=hasroughmap, z=hasmetalmap
    simd_float4 edgeTint;
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

//Ray tracing structs
#define GEOMETRY_MASK_TRIANGLE 1
#define GEOMETRY_MASK_SPHERE   2
#define GEOMETRY_MASK_LIGHT    4


#endif /* ShaderTypes_h */

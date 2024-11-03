//
////
////  ShaderTypes.h
////  UntoldEngine3D Shared
////
////  Created by Harold Serrano on 5/17/23.
////
//
////
////  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
////
//#ifndef ShaderTypes_h
//#define ShaderTypes_h
//
//#ifdef __METAL_VERSION__
//#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
//typedef metal::int32_t EnumBackingType;
//#else
//#import <Foundation/Foundation.h>
//typedef NSInteger EnumBackingType;
//#endif
//
//#include <simd/simd.h>
//
//typedef struct
//{
//    matrix_float4x4 projectionMatrix;
//    matrix_float4x4 viewMatrix;
//    matrix_float4x4 modelViewMatrix;
//    matrix_float3x3 normalMatrix;
//    matrix_float4x4 modelMatrix;
//    simd_float3 cameraPosition;
//} Uniforms;
//
//
//typedef struct{
//    simd_float4 position;
//    simd_float4 color;
//    simd_float4 attenuation;
//    float intensity;
//    float radius;
//}PointLightUniform;
//
//typedef struct{
//    simd_float4 position;
//    simd_float4 color;
//    simd_float4 forward;
//    simd_float4 up;
//    simd_float4 right;
//}AreaLightUniform;
//
//typedef enum{
//    gridPassPositionIndex,
//    gridPassUniformIndex,
//}GridPassBufferIndices;
//
//typedef enum{
//    modelPassVerticesIndex,
//    modelPassNormalIndex,
//    modelPassUVIndex,
//    modelPassTangentIndex,
//    modelPassBitangentIndex,
//    modelPassUniformIndex,
//    modelPassLightOrthoViewMatrixIndex,
//    modelPassLightDirectionIndex,
//    modelPassLightDirectionColorIndex,
//    modelPassLightIntensityIndex,
//    modelPassPointLightsIndex,
//    modelPassPointLightsCountIndex,
//    modelBaseTextureIndex,
//    modelRoughnessTextureIndex,
//    modelMetallicTextureIndex,
//    modelNormalTextureIndex,
//    shadowTextureIndex,
//    modelHasNormalTextureIndex,
//    modelDisneyParameterIndex,
//    modelIBLIrradianceTextureIndex,
//    modelIBLSpecularTextureIndex,
//    modelIBLBRDFMapTextureIndex,
//    modelPassBRDFIndex,
//    modelPassIBLRotationAngleIndex,
//}ModelPassBufferIndices;
//
//typedef enum{
//    rayAccelStructIndex,
//    rayDirLightStructIndex,
//    rayDestTexIndex,
//    rayPrevTexIndex,
//    rayRandomTexIndex,
//    rayUniformIndex,
//    rayBufferInstanceIndex,
//    rayMaxSampleSizeIndex,
//    rayMaxBouncesIndex,
////    rayLightDirectionColorIndex,
////    rayLightIntensityIndex,
//    rayShadowEnableIndex,
//    rayAreaLightIndex,
//    rayFrameIndex,
//    rayAccumBuffer
//}RayPassIndices;
//
//typedef enum{
//    lightPassCameraSpaceIndex,
//    lightPassLightDirectionIndex,
//    lightPassAlbedoTextureIndex,
//    lightPassNormalTextureIndex,
//    lightPassPositionTextureIndex,
//    lightPassSurfaceReflectionTextureIndex,
//    lightPassSurfaceInteractionTextureIndex,
//    lightPassCoatingLayerTextureIndex,
//    lightPassIBLIrradianceTextureIndex,
//    lightPassIBLSpecularTextureIndex,
//    lightPassIBLBRDFMapTextureIndex,
//    lightPassDepthTextureIndex,
//    lightPassNDFSelectionIndex,
//    lightPassDisneyIndex,
//    lightPassApplyIBLIndex,
//    lightPassAmbientIntensityIndex,
//    lightPassEdgeTintTextureIndex,
//}LightPassBufferIndices;
//
//typedef enum{
//    envPassPositionIndex,
//    envPassNormalIndex,
//    envPassUVIndex,
//    envPassConstantIndex,
//    envPassRotationAngleIndex
//}EnvironmentPassBufferIndices;
//
//typedef enum{
//    toneMapPassColorTextureIndex,
//    toneMapPassToneMappingIndex,
//}ToneMapPassBufferIndices;
//
//
//
////typedef enum{
////    shadowVoxelOriginIndex,
////    shadowVoxelUniform,
////    shadowVoxelLightMatrixUniform,
////    shadowVoxelLightPositionUniform
////}ShadowBufferIndices;
//
//typedef enum{
//    shadowModelPositionIndex,
//    shadowModelUniform,
//    shadowModelLightMatrixUniform,
//    shadowModelLightPositionUniform
//}ShadowBufferIndices;
//
//typedef enum{
//    rayModelAccelStructIndex,
//    rayModelBufferInstanceIndex,
//    rayModelOriginIndex,
//    rayModelDirectionIndex,
//    rayModelInstanceHitIndex,
//}RayModelBufferIndices;
//
//typedef struct{
//
//    matrix_float4x4 projectionMatrix;
//    matrix_float4x4 viewMatrix;
//    matrix_float4x4 modelMatrix;
//    matrix_float4x4 environmentRotation;
//
//}EnvironmentConstants;
//
//typedef enum RenderTargets{
//    colorTarget = 0,
//    normalTarget,
//    positionTarget,
////    surfaceReflectionTarget,
////    complexSurfaceTarget,
////    coatingLayerTarget,
////    edgeTintTarget,
//}RenderTargets;
//
//
//typedef struct{
//    simd_float4 baseColor;
//    simd_int4 hasTexture; //x=hasbasecolor,y=hasroughmap, z=hasmetalmap
//    simd_float4 edgeTint;
//    float roughness;
//    float specular;
//    float subsurface;
//    float metallic;
//    float specularTint;
//    float anisotropic;
//    float sheen;
//    float sheenTint;
//    float clearCoat;
//    float clearCoatGloss;
//    float ior;
//    bool interactWithLight;
//}DisneyParametersUniform;
//
//typedef struct{
//    float ambientIntensity;
//    int brdfSelection;
//    int ndfSelection;
//    int gsSelection;
//    bool applyIBL;
//}BRDFSelectionUniform;
//
//typedef struct{
//    vector_float3 cameraPosition;
//    vector_float3 cameraRight;
//    vector_float3 cameraUp;
//    vector_float3 cameraForward;
//    //unsigned int frameIndex;
//    unsigned int width;
//    unsigned int height;
//}RayTracingUniforms;
//
//typedef struct{
//    simd_float4 baseColor;
//    simd_float4 edgeTint;
//    simd_float4 emit;
//    simd_float2 uv[3];
//    simd_float4 normals[3];
//    float roughness;
//    float metallic;
//    float specular;
//    float specularTint;
//    float anisotropic;
//    float sheen;
//    float sheenTint;
//    float clearCoat;
//    float clearCoatGloss;
//    float ior;
//} PrimitiveData;
//
////Ray tracing structs
//#define GEOMETRY_MASK_TRIANGLE 1
//#define GEOMETRY_MASK_SPHERE   2
//#define GEOMETRY_MASK_LIGHT    4
//
//#define GEOMETRY_MASK_GEOMETRY (GEOMETRY_MASK_TRIANGLE | GEOMETRY_MASK_SPHERE)
//
//#define RAY_MASK_PRIMARY   (GEOMETRY_MASK_GEOMETRY | GEOMETRY_MASK_LIGHT)
//#define RAY_MASK_SHADOW    GEOMETRY_MASK_GEOMETRY
//#define RAY_MASK_SECONDARY GEOMETRY_MASK_GEOMETRY
//
////#ifndef __METAL_VERSION__
////struct packed_float3 {
////#ifdef __cplusplus
////    packed_float3() = default;
////    packed_float3(vector_float3 v) : x(v.x), y(v.y), z(v.z) {}
////#endif
////    float x;
////    float y;
////    float z;
////};
////#endif
////
////struct Camera {
////    vector_float3 position;
////    vector_float3 right;
////    vector_float3 up;
////    vector_float3 forward;
////};
////
////struct AreaLight {
////    vector_float3 position;
////    vector_float3 forward;
////    vector_float3 right;
////    vector_float3 up;
////    vector_float3 color;
////};
////
////struct RayUniforms {
////    unsigned int width;
////    unsigned int height;
////    unsigned int frameIndex;
////    unsigned int lightCount;
////    Camera camera;
////};
////
////struct Triangle {
////    vector_float3 normals[3];
////    vector_float3 colors[3];
////};
//
//#endif /* ShaderTypes_h */

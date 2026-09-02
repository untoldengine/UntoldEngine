//
//  TransparencyShader.metal
//  UntoldEngine
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

fragment float4 fragmentTransparencyShader(
    VertexOutModel in [[stage_in]],
    constant Uniforms &uniforms [[buffer(transparencyPassFragmentUniformIndex)]],
    texture2d<float> baseColor [[texture(transparencyPassBaseTextureIndex)]],
    texture2d<float> roughnessTexture [[texture(transparencyPassRoughnessTextureIndex)]],
    texture2d<float> metallicTexture [[texture(transparencyPassMetallicTextureIndex)]],
    texture2d<float> normalTexture [[texture(transparencyPassNormalTextureIndex)]],
    constant bool &hasNormal [[buffer(transparencyPassFragmentHasNormalTextureIndex)]],
    constant bool &normalIsPackedXY [[buffer(transparencyPassFragmentNormalIsPackedXYIndex)]],
    constant MaterialParametersUniform &materialParameter [[buffer(transparencyPassFragmentMaterialParameterIndex)]],
    sampler baseColorSampler [[sampler(transparencyPassBaseSamplerIndex)]],
    sampler normalSampler [[sampler(transparencyPassNormalSamplerIndex)]],
    sampler materialSampler [[sampler(transparencyPassMaterialSamplerIndex)]],
    constant float &stScale [[buffer(transparencyPassFragmentSTScaleIndex)]],
    constant CSMUniforms &csmUniforms [[buffer(transparencyPassLightOrthoViewMatrixIndex)]],
    constant LightParameters &lights [[buffer(transparencyPassLightParamsIndex)]],
    constant simd_float3 &cameraPosition [[buffer(transparencyPassCameraPositionIndex)]],
    constant PointLightBlock &plBlock [[buffer(transparencyPassPointLightsIndex)]],
    constant SpotLightBlock &slBlock [[buffer(transparencyPassSpotLightsIndex)]],
    constant AreaLightBlock &alBlock [[buffer(transparencyPassAreaLightsIndex)]],
    constant IBLParamsUniform &iblParam [[buffer(transparencyPassIBLParamIndex)]],
    constant float &iblRotationAngle [[buffer(transparencyPassIBLRotationAngleIndex)]],
    texture2d<float> irradianceTexture [[texture(transparencyPassIBLIrradianceTextureIndex)]],
    texture2d<float> specularTexture [[texture(transparencyPassIBLSpecularTextureIndex)]],
    texture2d<float> iblBRDFTexture [[texture(transparencyPassIBLBRDFMapTextureIndex)]],
    depth2d_array<float> csmShadowArray [[texture(transparencyPassShadowTextureIndex)]],
    texture2d<float> ltcMagTexture [[texture(transparencyPassAreaLTCMagTextureIndex)]],
    texture2d<float> ltcMatTexture [[texture(transparencyPassAreaLTCMatTextureIndex)]]
) {
    float2 st = in.uvCoords * stScale;
    st.y = 1.0 - st.y;

    float4 sampledColor = baseColor.sample(baseColorSampler, st);
    float3 tint = all(materialParameter.baseColor.rgb < 0.001)
        ? float3(1.0)
        : materialParameter.baseColor.rgb;

    float4 inBaseColor = (materialParameter.hasTexture.x == 1)
        ? float4(sampledColor.rgb * tint, sampledColor.a * materialParameter.baseColor.a)
        : float4(tint, materialParameter.baseColor.a);

    if (inBaseColor.a <= 0.001) {
        discard_fragment();
    }

    // See modelShader.metal's fragmentModelShader for the packed-XY encoding rationale.
    float4 normalSample = normalTexture.sample(normalSampler, st);
    float3 normalMapStandard = normalize(normalSample.rgb);
    normalMapStandard = normalMapStandard * 2.0 - 1.0;

    float2 packedXY = normalSample.ga * 2.0 - 1.0;
    float3 normalMapPackedXY = float3(packedXY, sqrt(saturate(1.0 - dot(packedXY, packedXY))));

    float3 normalMap = normalIsPackedXY ? normalMapPackedXY : normalMapStandard;

    simd_float3 N = normalize(in.tbNormal);
    simd_float3 T = normalize(in.tangent.xyz);
    simd_float3 B = cross(N, T) * in.tangent.w;
    simd_float3x3 TBN = simd_float3x3(T, B, N);

    float3 normal = hasNormal
        ? normalize(TBN * normalMap)
        : normalize(uniforms.normalMatrix * in.normal);

    float roughness = (materialParameter.hasTexture.y == 1)
        ? selectTextureChannel(roughnessTexture.sample(materialSampler, st), materialParameter.textureChannels.x) * materialParameter.roughness
        : materialParameter.roughness;
    roughness = clamp(roughness, 0.045, 1.0);

    float metallic = (materialParameter.hasTexture.z == 1)
        ? selectTextureChannel(metallicTexture.sample(materialSampler, st), materialParameter.textureChannels.y) * materialParameter.metallic
        : materialParameter.metallic;
    metallic = clamp(metallic, 0.0, 1.0);

    float4 verticesInWorldSpace = uniforms.modelMatrix * in.vPosition;
    float3 viewVector = normalize(cameraPosition - verticesInWorldSpace.xyz);
    float3 lightDirection = normalize(lights.direction);

    LightContribution brdf = computeBRDF(
        lightDirection,
        viewVector,
        normal,
        inBaseColor.rgb,
        float3(1.0),
        roughness,
        metallic
    );

    LightContribution totalLight;
    totalLight.diff = brdf.diff * (half3)lights.color * (half)lights.intensity;
    totalLight.spec = brdf.spec * lights.color * lights.intensity;

    float shadow = computeCSMShadow(csmShadowArray, csmUniforms, verticesInWorldSpace.xyz, cameraPosition, normal, lightDirection);
    totalLight.diff *= (half)shadow;
    totalLight.spec *= shadow;

    uint pointLightCount = min(plBlock.count.x, MAX_POINT_LIGHTS);
    for (uint i = 0; i < pointLightCount; ++i) {
        LightContribution pl = computePointLightContribution(
            plBlock.lights[i],
            verticesInWorldSpace,
            viewVector,
            normal,
            inBaseColor.rgb,
            roughness,
            metallic
        );
        totalLight.diff += pl.diff;
        totalLight.spec += pl.spec;
    }

    uint spotLightCount = min(slBlock.count.x, MAX_POINT_LIGHTS);
    for (uint i = 0; i < spotLightCount; ++i) {
        LightContribution sl = computeSpotLightContribution(
            slBlock.lights[i],
            verticesInWorldSpace,
            viewVector,
            normal,
            inBaseColor.rgb,
            roughness,
            metallic
        );
        totalLight.diff += sl.diff;
        totalLight.spec += sl.spec;
    }

    uint areaLightCount = min(alBlock.count.x, MAX_POINT_LIGHTS);
    for (uint i = 0; i < areaLightCount; ++i) {
        LightContribution al = evaluateAreaLight(
            alBlock.lights[i],
            verticesInWorldSpace,
            viewVector,
            normal,
            ltcMatTexture,
            ltcMagTexture,
            inBaseColor.rgb,
            roughness,
            metallic
        );
        totalLight.diff += al.diff;
        totalLight.spec += al.spec;
    }

    float3 indirectLighting = computeIBLContribution(
        irradianceTexture,
        specularTexture,
        iblBRDFTexture,
        iblRotationAngle,
        iblParam,
        float4(inBaseColor.rgb, 1.0),
        normal,
        viewVector,
        roughness,
        metallic
    );

    indirectLighting *= iblParam.ambientIntensity;
    float3 finalColor = float3(totalLight.diff) + totalLight.spec + indirectLighting;

    // blendEnabled uses premultiplied-alpha blend factors.
    return float4(finalColor * inBaseColor.a, inBaseColor.a);
}

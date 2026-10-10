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

// What the pass hands the blender for a pixel: the light the surface adds to it, and
// the share of what is already there that it lets through. Blending with two sources
// (the pass's pipeline, see InitTransparencyPipeline) keeps that share for each of
// red, green and blue, which is how tinted glass filters what is behind it. Where the
// pipeline falls back to premultiplied alpha, the alpha of the first value stands for
// it: one share for the three, by its brightness.
struct TransparencyOutput {
    float4 color [[color(0), index(0)]];
    float4 through [[color(0), index(1)]];
};

fragment TransparencyOutput fragmentTransparencyShader(
    VertexOutModel in [[stage_in]],
    constant Uniforms &uniforms [[buffer(transparencyPassFragmentUniformIndex)]],
    texture2d<float> baseColor [[texture(transparencyPassBaseTextureIndex)]],
    texture2d<float> roughnessTexture [[texture(transparencyPassRoughnessTextureIndex)]],
    texture2d<float> metallicTexture [[texture(transparencyPassMetallicTextureIndex)]],
    texture2d<float> normalTexture [[texture(transparencyPassNormalTextureIndex)]],
    texture2d<float> emissiveTexture [[texture(transparencyPassEmissiveTextureIndex)]],
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
    constant int &faces [[buffer(transparencyPassFacesIndex)]],
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
    // See fragmentModelShader: zeros mean "untinted" only for a textured material.
    bool isBaseColorUnset = materialParameter.hasTexture.x == 1 && all(materialParameter.baseColor.rgb < 0.001);
    float3 tint = isBaseColorUnset ? float3(1.0) : materialParameter.baseColor.rgb;

    float4 inBaseColor = (materialParameter.hasTexture.x == 1)
        ? float4(sampledColor.rgb * tint, sampledColor.a * materialParameter.baseColor.a)
        : float4(tint, materialParameter.baseColor.a);

    if (inBaseColor.a <= 0.001) {
        discard_fragment();
    }

    float4 verticesInWorldSpace = uniforms.modelMatrix * in.vPosition;
    float3 viewVector = normalize(cameraPosition - verticesInWorldSpace.xyz);

    // Glass is drawn in two goes (see TransparencyPassFaces): this one keeps the faces
    // turned away from the viewer, or the ones turned towards the viewer.
    // Which side of the face is seen is decided by the face itself, not by the shading
    // normal: a smooth normal bends towards the side faces at the edge of a pane, and
    // from a little to the left or to the right (the two eyes of a headset) it would put
    // the same edge pixels on the far side for one eye and on the near side for the
    // other. The derivative normal's sign follows the winding on screen; the vertex
    // normal picks the outward one of the two, so winding and mirrored transforms still
    // do not matter. A degenerate face (no derivatives) falls back to the shading normal.
    float3 shadingNormal = normalize(uniforms.normalMatrix * in.normal);
    float3 faceNormal = cross(dfdx(verticesInWorldSpace.xyz), dfdy(verticesInWorldSpace.xyz));
    faceNormal = dot(faceNormal, shadingNormal) < 0.0 ? -faceNormal : faceNormal;
    float faceLength = length(faceNormal);
    bool turnedAway = dot(faceLength > 0.0 ? faceNormal / faceLength : shadingNormal, viewVector) < 0.0;
    if ((faces == transparencyPassFarFaces && !turnedAway) || (faces == transparencyPassNearFaces && turnedAway)) {
        discard_fragment();
    }

    // See modelShader.metal's fragmentModelShader for the packed-XY encoding rationale.
    float4 normalSample = normalTexture.sample(normalSampler, st);
    float3 normalMapStandard = normalSample.rgb * 2.0 - 1.0;

    float2 packedXY = normalSample.ga * 2.0 - 1.0;
    float3 normalMapPackedXY = float3(packedXY, sqrt(saturate(1.0 - dot(packedXY, packedXY))));

    float3 normalMap = normalIsPackedXY ? normalMapPackedXY : normalMapStandard;
    normalMap = applyNormalStrength(normalMap, materialParameter.normalScale);

    simd_float3 N = normalize(in.tbNormal);
    simd_float3 T = normalize(in.tangent.xyz);
    simd_float3 B = cross(N, T) * in.tangent.w;
    simd_float3x3 TBN = simd_float3x3(T, B, N);

    float3 normal = hasNormal
        ? normalize(TBN * normalMap)
        : normalize(uniforms.normalMatrix * in.normal);
    // A face of glass is lit on the side the viewer sees: the far face of a pane
    // reflects from inside it what its near face reflects from outside.
    // The shading normal of a pane faces the viewer whichever go draws the face: the
    // face's side and the smooth normal can disagree at an edge.
    if (faces != transparencyPassEveryFace && dot(normal, viewVector) < 0.0) {
        normal = -normal;
    }

    float roughness = (materialParameter.hasTexture.y == 1)
        ? selectTextureChannel(roughnessTexture.sample(materialSampler, st), materialParameter.textureChannels.x) * materialParameter.roughness
        : materialParameter.roughness;
    // The roughness as authored. The clamp below keeps the highlights finite.
    float authoredRoughness = saturate(roughness);
    roughness = clamp(roughness, 0.045, 1.0);

    float metallic = (materialParameter.hasTexture.z == 1)
        ? selectTextureChannel(metallicTexture.sample(materialSampler, st), materialParameter.textureChannels.y) * materialParameter.metallic
        : materialParameter.metallic;
    metallic = clamp(metallic, 0.0, 1.0);

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

    float shadow = computeCSMShadow(csmShadowArray, csmUniforms, verticesInWorldSpace.xyz, normal, lightDirection);
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

    EnvironmentLight environment = computeIBLParts(
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

    float3 scattered = float3(totalLight.diff) + environment.diff * iblParam.ambientIntensity;
    float3 reflected = totalLight.spec + environment.spec * iblParam.ambientIntensity;

    // See fragmentModelShader: the emissive color, times the emissive texture when there is one.
    float3 emissive = (materialParameter.hasEmissiveTexture == 1)
        ? materialParameter.emmissive * emissiveTexture.sample(baseColorSampler, st).rgb
        : materialParameter.emmissive;

    // Glass (the material's transmission): the share of the surface that is not metal
    // lets light cross it, tinted by the base color, and scatters none of the light
    // that falls on it. Its reflections and its glow are whole whatever crosses it.
    float glassShare = saturate(materialParameter.transmission);

    // Nothing here bends or blurs what is seen through glass. Polished glass shows
    // what is behind it. Frosted glass shows nothing of it and glows with the light
    // that comes from behind it instead, and a roughness in between gives some of each.
    float sharpness = 1.0 - smoothstep(GLASS_CLEAR_UP_TO_ROUGHNESS, GLASS_FROSTED_FROM_ROUGHNESS, authoredRoughness);
    float clearShare = glassShare * sharpness;
    float frostedShare = glassShare - clearShare;

    // What glass reflects does not cross it: seen at a slant it is a mirror. The glass
    // is the part of the surface that is not metal, and reflects as a non-metal does.
    float NoV = min(abs(dot(normal, viewVector)), 1.0);
    float3 glassReflects = environmentReflectance(float3(0.04), roughness, NoV, iblBRDFTexture);
    // The base color is the tint of a pane seen through both of its faces, the near one
    // and the far one, which are both drawn: each takes its square root (as Blender's
    // Principled BSDF does on the way in and on the way out).
    float3 glassTint = sqrt(max(inBaseColor.rgb, 0.0));
    float3 crossesGlass = (1.0 - metallic) * glassTint * max(1.0 - glassReflects, 0.0);

    // The light that comes from behind the surface, whichever of its faces is seen.
    // From the environment: what lies straight through the glass, blurred, the way
    // frosted glass shows it. It is the environment that is read, not the scene, so
    // an object behind frosted glass does not show in its glow. From the sun: what
    // falls on the far side. The other lights are left out.
    float3 awayFromViewer = dot(normal, viewVector) < 0.0 ? normal : -normal;
    float3 environmentBehind = iblParam.applyIBL
        ? blurredEnvironment(-viewVector, saturate(2.0 * authoredRoughness), specularTexture, float3(0.0, 1.0, 0.0), degreesToRadians(iblRotationAngle))
        : diffuseIBL(awayFromViewer, irradianceTexture, float3(0.0, 1.0, 0.0), degreesToRadians(iblRotationAngle));
    float3 lightBehind = environmentBehind * iblParam.ambientIntensity;
    lightBehind += lights.color * lights.intensity * shadow * max(dot(awayFromViewer, lightDirection), 0.0) / M_PI_F;

    // The alpha is how much of the surface is there at all. The glow fades with the
    // surface like the rest of it: a material half there gives off half the light.
    float coverage = inBaseColor.a;
    float3 added = coverage * (scattered * (1.0 - glassShare) + frostedShare * crossesGlass * lightBehind + reflected + emissive);
    float3 through = (1.0 - coverage) + coverage * clearShare * crossesGlass;

    TransparencyOutput result;
    result.color = float4(added, 1.0 - dot(through, float3(0.2126, 0.7152, 0.0722)));
    result.through = float4(through, 1.0);
    return result;
}

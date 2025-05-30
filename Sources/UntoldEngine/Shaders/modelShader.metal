//
//  modelShader.metal
//  UntoldShadersKernels
//
//  Created by Harold Serrano on 3/4/24.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
#include "ShadersUtils.h"

using namespace metal;

float computeShadow(float4 shadowCoords, depth2d<float> shadowTexture){
    
    float shadow=0.0;
    
    constexpr sampler shadowSampler(coord::normalized, filter::linear, address::clamp_to_edge);

    //project from Clip space to NDC
    float3 proj=shadowCoords.xyz/shadowCoords.w;

    //map NDC space [-1,-1] to [0,1]
    proj.xy=proj.xy*0.5+0.5;

    //flip the texture. Metal's texture coordinate system has its origin in the top left corner, unlike opengl where the origin is the bottom
    //left corner
    proj.y=1.0-proj.y;

    //float closestDepth=shadowTexture.sample(shadowSampler,proj.xy);
    float currenDepthFromLight=proj.z;
    
    for(int i=0;i<9;i++){

        float pcfDepth=shadowTexture.sample(shadowSampler,proj.xy+poissonDisk[i]/700.0);
        shadow+=currenDepthFromLight>pcfDepth?0.3:0.0;

    }
    shadow/=9.0;
    
    return shadow;
}

float3 computeIBLContribution(texture2d<float> irradianceTexture,
                              texture2d<float> specularTexture,
                              texture2d<float> iblBRDFTexture,
                              constant float &iblRotationAngle,
                              constant IBLParamsUniform &iblParam,
                              constant MaterialParametersUniform &materialParameter,
                              float4 inBaseColor,
                              float3 normalMap,
                              float3 viewVector,
                              float roughness,
                              float metallic
                              ){
    
    //compute ibl ambient contribution
    float NoV = max(dot(normalMap.xyz, viewVector), 0.001);
    
    float3 irradiance=diffuseIBL(normalMap.xyz, irradianceTexture, float3(0.0,1.0,0.0),degreesToRadians(iblRotationAngle));
    
    float3 diffuse = irradiance*inBaseColor.rgb;

    float fr=artistFriendlyF0(inBaseColor.r, materialParameter.edgeTint.x, NoV);
    float fg=artistFriendlyF0(inBaseColor.g, materialParameter.edgeTint.y, NoV);
    float fb=artistFriendlyF0(inBaseColor.b, materialParameter.edgeTint.z, NoV);

    float3 f0=float3(fr, fg, fb);

    f0=mix(0.04,f0,metallic);

    float3 F=fresnelSchlick(NoV,f0);

    float3 specular=specularIBL(F, roughness, normalMap.xyz, viewVector, specularTexture, iblBRDFTexture,float3(0.0,1.0,0.0),degreesToRadians(iblRotationAngle));

    float3 ambient=mix(diffuse,specular,metallic);
    
    if(iblParam.applyIBL==false){
        ambient=diffuse.rgb;
    }
    
    return ambient;
}

float4 computePointLightContribution(constant PointLightUniform &light,
                                     float4 verticesInWorldSpace,
                                     float3 viewVector,
                                     float3 normalMap,
                                     float3 ambient,
                                     constant MaterialParametersUniform &materialParameter,
                                     float roughness,
                                     float metallic
                                     ){
    
    float3 lightDirection=normalize(light.position.xyz-verticesInWorldSpace.xyz);
    float lightDistance=length(light.position.xyz-verticesInWorldSpace.xyz);

    float3 lightBRDF=computeBRDF(lightDirection, viewVector, normalMap.xyz, light.color.rgb, float3(1.0), materialParameter,roughness,metallic);

    float attenuation=calculateAttenuation(lightDistance, light.attenuation);

    float4 lightContribution=float4(lightBRDF*attenuation*light.intensity,1.0);
 
    return lightContribution;
}

float4 computeSpotLightContribution(constant SpotLightUniform &light,
                                     float4 verticesInWorldSpace,
                                     float3 viewVector,
                                     float3 normalMap,
                                     float3 ambient,
                                     constant MaterialParametersUniform &materialParameter,
                                     float roughness,
                                     float metallic
                                     ){
    
    float3 lightDirection=normalize(light.position.xyz-verticesInWorldSpace.xyz);
    float3 spotDirection = normalize(light.direction.xyz);
    float lightDistance=length(light.position.xyz-verticesInWorldSpace.xyz);
    
    float attenuation=calculateAttenuation(lightDistance, light.attenuation);
    
    float3 lightBRDF=computeBRDF(lightDirection, viewVector, normalMap.xyz, light.color.rgb, float3(1.0), materialParameter,roughness,metallic);
    
    float theta = dot(-lightDirection, spotDirection); // cosine of angle between light dir and spot dir
    float epsilon = cos(light.innerCone) - cos(light.outerCone);
    float coneFalloff = clamp((theta-cos(light.outerCone))/epsilon, 0.0, 1.0);
    
    float4 lightContribution=float4(lightBRDF*attenuation*coneFalloff*light.intensity,1.0);
 
    return lightContribution;
}


vertex VertexOutModel vertexModelShader(
    VertexInModel in [[stage_in]],
    constant simd_float4x4 &lightOrthoView [[buffer(modelPassLightOrthoViewMatrixIndex)]],
    constant Uniforms &uniforms [[buffer(modelPassUniformIndex)]],
    constant bool &hasArmature [[buffer(modelPassHasArmature)]],
    device simd_float4x4 *jointMatrices [[buffer(modelPassJointTransformIndex)]]
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
    out.shadowCoords = lightOrthoView * uniforms.modelMatrix * position;
    out.uvCoords = in.uv;

    // Compute TBN
    simd_float3 T = normalize(uniforms.normalMatrix * in.tangent.xyz);
    simd_float3 N = normalize(uniforms.normalMatrix * normals.xyz);
    //simd_float3 B = cross(N, T) * in.tangent.w;

    out.tangent = float4(T, in.tangent.w);
    out.tbNormal = N;

    return out;
}


fragment FragmentModelOut fragmentModelShader(VertexOutModel in [[stage_in]],
                                    constant Uniforms & uniforms [[ buffer(modelPassUniformIndex) ]],
                                    constant LightParameters &lights [[buffer(modelPassLightParamsIndex)]],
                                    constant PointLightUniform *pointLights [[buffer(modelPassPointLightsIndex)]],
                                    constant int *pointLightsCount [[buffer(modelPassPointLightsCountIndex)]],
                                    constant SpotLightUniform *spotLights [[buffer(modelPassSpotLightsIndex)]],
                                    constant int *spotLightsCount [[buffer(modelPassSpotLightsCountIndex)]],
                                  depth2d<float> shadowTexture[[texture(modelPassShadowTextureIndex)]],
                                  texture2d<float> baseColor [[texture(modelPassBaseTextureIndex)]],
                                  texture2d<float> roughnessTexture [[texture(modelPassRoughnessTextureIndex)]],
                                  texture2d<float> metallicTexture [[texture(modelPassMetallicTextureIndex)]],
                                  texture2d<float> normalTexture [[texture(modelPassNormalTextureIndex)]],
                                  constant bool &hasNormal[[buffer(modelPassHasNormalTextureIndex)]],
                                  constant MaterialParametersUniform &materialParameter [[buffer(modelPassMaterialParameterIndex)]],
                                  constant IBLParamsUniform &iblParam [[buffer(modelPassIBLParamIndex)]],
                                  texture2d<float> irradianceTexture [[texture(modelPassIBLIrradianceTextureIndex)]],
                                  texture2d<float> specularTexture [[texture(modelPassIBLSpecularTextureIndex)]],
                                  texture2d<float> iblBRDFTexture [[texture(modelPassIBLBRDFMapTextureIndex)]],
                                  constant float &iblRotationAngle [[buffer(modelPassIBLRotationAngleIndex)]],
                                  constant bool &gameMode[[buffer(modelPassGameModeIndex)]]
                                              )
{

    constexpr sampler s(min_filter::linear, mag_filter::linear, s_address::repeat, t_address::repeat); // Use for base color and normal maps
    
    constexpr sampler normalSampler(min_filter::linear, mag_filter::linear);
    
    //sample rougness and metallic
    constexpr sampler materialSampler(min_filter::linear, mag_filter::linear);

    FragmentModelOut fragmentOut;
    
    float2 st=in.uvCoords;
    st.y=1.0-st.y;
    
    float4 verticesInWorldSpace=uniforms.modelMatrix*in.vPosition;
    float3 normalVectorInWorldSpace=uniforms.normalMatrix*in.normal;

    // Base color
    float4 inBaseColor = (materialParameter.hasTexture.x == 1) ? baseColor.sample(s, st) : materialParameter.baseColor;
    
    // Avoid black base color
    inBaseColor = (computeLuma(inBaseColor.rgb)<=0.01)?float4(float3(0.1),1.0):inBaseColor;
   
    fragmentOut.color = inBaseColor;
    
    //normal map is in Tangent space
    float3 normalMap=normalize(normalTexture.sample(normalSampler, st).rgb);
    //[0,1] to [-1,1]
    normalMap=normalMap*2.0-1.0;

    //construct tbn matrix TBN
    simd_float3 N=normalize(in.tbNormal);
    simd_float3 T=normalize(in.tangent.xyz);

    //B = (N x T) * T.w
    simd_float3 B=cross(N, T)*in.tangent.w;
    simd_float3x3 TBN=simd_float3x3(T,B,N);

    //convert to normal map to world space???
    normalMap=(hasNormal==false)?normalize(normalVectorInWorldSpace):normalize(TBN*normalMap);

    float roughness=(materialParameter.hasTexture.y==1)?roughnessTexture.sample(materialSampler,st).r : materialParameter.roughness;
    
    float metallic=(materialParameter.hasTexture.z==1) ? metallicTexture.sample(materialSampler,st).r : materialParameter.metallic;

    float3 lightColor=lights.color;
    float3 lightRayDirection=normalize(lights.direction);
    float3 viewVector=normalize(uniforms.cameraPosition-verticesInWorldSpace.xyz);

    //compute ibl ambient contribution
    float3 ambient=computeIBLContribution(irradianceTexture, 
                                          specularTexture,
                                          iblBRDFTexture,
                                          iblRotationAngle,
                                          iblParam,
                                          materialParameter,
                                          inBaseColor,
                                          normalMap,
                                          viewVector,
                                          roughness,
                                          metallic);

    // Compute BRDF
    float3 brdf=float3(0.0);

    brdf=computeBRDF(lightRayDirection, viewVector, normalMap.xyz, inBaseColor.rgb, float3(1.0), materialParameter,roughness,metallic);

    float4 color=float4(brdf*lightColor*lights.intensity+ambient*iblParam.ambientIntensity,1.0);

    // compute point ligth contribution
    float4 pointColor=simd_float4(0.0);

    for(int i=0; i<pointLightsCount[0];i++){

        pointColor += computePointLightContribution(pointLights[i],
                                                    verticesInWorldSpace,
                                                    viewVector,
                                                    normalMap.xyz,
                                                    ambient,
                                                    materialParameter,
                                                    roughness,
                                                    metallic);
    }

    color+=pointColor;
    
    // Compute spot light contribution
    float4 spotLightColor = simd_float4(0.0);
    
    for(int i=0; i<spotLightsCount[0]; i++){
        spotLightColor += computeSpotLightContribution(spotLights[i],
                                                       verticesInWorldSpace,
                                                       viewVector,
                                                       normalMap.xyz,
                                                       ambient,
                                                       materialParameter,
                                                       roughness,
                                                       metallic);
    }
    
    color += spotLightColor;

    //compute shadow
    float shadow = computeShadow(in.shadowCoords, shadowTexture);
    

    float3 litColor = color.rgb * (1.0 - shadow);
    float3 emissiveColor = materialParameter.emmissive; // no need for simd_float4

    fragmentOut.color = float4(litColor + emissiveColor, 1.0);
    fragmentOut.normals=float4(normalMap,0.0);
    fragmentOut.positions=verticesInWorldSpace;

    return fragmentOut;


}

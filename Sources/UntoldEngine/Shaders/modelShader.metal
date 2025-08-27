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

vertex VertexOutModel vertexModelShader(
    VertexInModel in [[stage_in]],
    //constant simd_float4x4 &lightOrthoView [[buffer(modelPassLightOrthoViewMatrixIndex)]],
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
                                        constant bool &hasNormal[[buffer(modelPassFragmentHasNormalTextureIndex)]],
                                        constant MaterialParametersUniform &materialParameter [[buffer(modelPassFragmentMaterialParameterIndex)]],
                                  sampler baseColorSampler [[sampler(modelPassBaseSamplerIndex)]],
                                  sampler normalSampler [[sampler(modelPassNormalSamplerIndex)]],
                                  sampler materialSampler [[sampler(modelPassMaterialSamplerIndex)]],
                                        constant float &stScale [[buffer(modelPassFragmentSTScaleIndex)]])
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
    
    float4 verticesInWorldSpace=uniforms.modelMatrix*in.vPosition;
    float3 normalVectorInWorldSpace=uniforms.normalMatrix*in.normal;

    // Base color
    
    float4 sampledColor = baseColor.sample(baseColorSampler, st);
    
    // Detect if basecolor is all zeros
    bool isBaseColorZero = all(materialParameter.baseColor.rgb < 0.001);
    
    // Fallback to white if base color is zero
    float3 tint = isBaseColorZero ? float3(1.0) : materialParameter.baseColor.rgb;
    
    float4 inBaseColor = (materialParameter.hasTexture.x == 1)
        ? float4(sampledColor.rgb * tint, sampledColor.a)
    : float4(tint,1.0);
    
    
    // Avoid black base color
    inBaseColor = (computeLuma(inBaseColor.rgb)<=0.01)?float4(float3(0.1),1.0):inBaseColor;
   
    gBufferOut.color = inBaseColor;
    
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

    float roughness=(materialParameter.hasTexture.y==1)
        ? roughnessTexture.sample(materialSampler,st).r * materialParameter.roughness
        : materialParameter.roughness;
    
    float metallic=(materialParameter.hasTexture.z==1) 
        ? metallicTexture.sample(materialSampler,st).r * materialParameter.metallic
        : materialParameter.metallic;

    float4 color=inBaseColor;

    gBufferOut.color = float4(color.rgb, 1.0);
    gBufferOut.normals=float4(normalMap,0.0);
    gBufferOut.positions=verticesInWorldSpace;
    gBufferOut.material=float4(roughness, metallic, 0.0, 0.0);
    gBufferOut.emmisive = float4(materialParameter.emmissive, 1.0);
    return gBufferOut;


}

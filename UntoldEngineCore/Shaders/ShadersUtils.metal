//
//  ShadersUtils.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 11/25/23.
//

#include <metal_stdlib>
using namespace metal;

float3x3 rotation_matrix(float3 axis, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    float oc = 1.0 - c;

    return float3x3(
        float3(oc * axis.x * axis.x + c,         oc * axis.x * axis.y - axis.z * s, oc * axis.x * axis.z + axis.y * s),
        float3(oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c,         oc * axis.y * axis.z - axis.x * s),
        float3(oc * axis.x * axis.z - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c)
    );
}

float degreesToRadians(float degrees) {
    return degrees * (M_PI_F / 180.0);
}


float mod(float x, float y){
    return x-y*floor(x/y);
}

//BRDF
float3 fresnelSchlick(float cosTheta,float3 F0){
    return F0+(1.0-F0)*pow(1.0-cosTheta, 5.0);
}

float D_GGX(float NoH,float roughness){
    
    float alpha=roughness*roughness;
    float alpha2=alpha*alpha;
    float NoH2=NoH*NoH;
    float b=(NoH2*(alpha2-1.0)+1.0);
    return alpha2*(1.0/M_PI_F)/(b*b);
}

float G1_GGX_Schlick(float NoV, float roughness){
    float alpha=roughness*roughness;
    float k=alpha/2.0;
    return max(NoV,0.001)/(NoV*(1.0-k)+k);
}

float G_smith(float NoV, float NoL,float roughness){
    return G1_GGX_Schlick(NoL,roughness)*G1_GGX_Schlick(NoV,roughness);
}

// Cook-Torrance BRDF function
float3 cookTorranceBRDF(float3 incomingLightDir, float3 surfaceNormal, float3 viewDir, float3 diffuseColor, float3 specularColor, float roughness, float metallic, float reflectance){
    
    
    // Compute the half vector between the incoming and view directions
    float3 halfVector = normalize(incomingLightDir + viewDir);

    //1. Calculate the geometric term (Smith's method for visibility)
    float NoV = max(dot(surfaceNormal, viewDir), 0.001);
    float NoL = max(dot(surfaceNormal, incomingLightDir), 0.001);
    
    
    float VoH = max(dot(viewDir, halfVector), 0.001);
    float LoH = max(dot(incomingLightDir, halfVector), 0.001);
    float NoH = max(dot(surfaceNormal, halfVector), 0.001);
    
    float3 f0=float3(0.16*(reflectance*reflectance));
    f0=mix(f0,diffuseColor,metallic);
    
    float3 F=fresnelSchlick(VoH,f0);
    float D=D_GGX(NoH,roughness);
    float G=G_smith(NoV,NoL,roughness);
    
    float3 spec=(F*D*G)/(4.0*max(NoV,0.001)*max(NoL,0.001));
    
    float3 rhoD=diffuseColor;
    
    rhoD*=(1.0-metallic);
    float3 diff=rhoD*(1/M_PI_F);
    
    return float3(max(NoL,0.001)*(diff+spec*specularColor));
    
}

//IBL
float2 directionToSphericalEnvmap(float3 dir) {
//  float s = 1.0 - mod(1.0 / (2.0*M_PI_F) * atan2(dir.z, dir.x), 1.0);
//  float t = 1.0 / (M_PI_F) * acos(dir.y);
//  return float2(s, t);
    float s = 1.0 - mod(1.0 / (2.0*M_PI_F) * atan2(dir.y, dir.x), 1.0);
      float t = 1.0 / (M_PI_F) * acos(-dir.z);
      return float2(s, t);
}

float3x3 getNormalSpace(float3 normal) {
   float3 someVec = float3(1.0, 0.0, 0.0);
   float dd = dot(someVec, normal);
   float3 tangent = float3(0.0, 1.0, 0.0);
   if(abs(dd) > 1e-8) {
     tangent = normalize(cross(someVec, normal));
   }
   float3 bitangent = cross(normal, tangent);
   return float3x3(tangent, bitangent, normal);
}

// from http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
// Hacker's Delight, Henry S. Warren, 2001
float radicalInverse(uint bits) {
  bits = (bits << 16u) | (bits >> 16u);
  bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
  bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
  bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
  bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
  return float(bits) * 2.3283064365386963e-10; // / 0x100000000
}

float2 hammersley(uint n, uint N) {
  return float2(float(n) / float(N), radicalInverse(n));
}

// The origin of the random2 function is probably the paper:
// 'On generating random numbers, with help of y= [(a+x)sin(bx)] mod 1'
// W.J.J. Rey, 22nd European Meeting of Statisticians and the
// 7th Vilnius Conference on Probability Theory and Mathematical Statistics, August 1998
// as discussed here:
// https://stackoverflow.com/questions/12964279/whats-the-origin-of-this-glsl-rand-one-liner
float random2(float2 n) {
    return fract(sin(dot(n, float2(12.9898, 4.1414))) * 43758.5453);
}

float4 diffuseImportanceMap(float2 texCoords, texture2d<float> environmentTexture){
    
    constexpr sampler s(coord::normalized,
                        filter::linear,
                        mip_filter::linear,
                        address::repeat);
    
    int samples=1024;
    
    float thetaN = M_PI_F * (1.0 - texCoords.y);
    float phiN = 2.0 * M_PI_F * (texCoords.x);
    float3 normal = float3(sin(thetaN) * cos(phiN), sin(thetaN) * sin(phiN), cos(thetaN));
    float3x3 rotMatrix = rotation_matrix(float3(0.0,1.0,0.0), degreesToRadians(90.0));
    rotMatrix = rotation_matrix(float3(1.0,0.0,0.0), degreesToRadians(-90.0))*rotMatrix;
    
    normal=rotMatrix*normal;
    
    float3x3 normalSpace = getNormalSpace(normal);

    float3 result = float3(0.0);

    uint N = uint(samples);

//    float r = random2(texCoords);

    for(uint n = 1u; n <= N; n++) {
        float2 p = hammersley(n, N);
        //float2 p = mod(hammersley(n, N) + r, 1.0);
        float theta = asin(sqrt(p.y));
        float phi = 2.0 * M_PI_F * p.x;
        float3 pos = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
        float3 posGlob = normalSpace * pos;
        float2 uv = directionToSphericalEnvmap(posGlob);
        float3 radiance = environmentTexture.sample(s,uv,level(5.0)).rgb;
        result += radiance;
    }
    result = result / float(samples);
    

    
    float4 color;
    color.rgb = float3(result);
    color.a = 1.0;
    
    return color;
}

float4 specularImportanceMap(float2 texCoords, texture2d<float> environmentTexture){
    
    constexpr sampler s(coord::normalized,
                        filter::linear,
                        mip_filter::linear,
                        address::repeat);
    
    float shininess=600;
    int samples=1024;

    float thetaN = M_PI_F * (1.0 - texCoords.y);
    float phiN = 2.0 * M_PI_F * (texCoords.x);
    float3 normal = float3(sin(thetaN) * cos(phiN), sin(thetaN) * sin(phiN), cos(thetaN));
    float3x3 rotMatrix = rotation_matrix(float3(0.0,1.0,0.0), degreesToRadians(90.0));
    rotMatrix = rotation_matrix(float3(1.0,0.0,0.0), degreesToRadians(-90.0))*rotMatrix;
    
    normal=rotMatrix*normal;
    
    float3x3 normalSpace = getNormalSpace(normal);

    float3 result = float3(0.0);

    uint N = uint(samples);

    //float r = random2(texCoords);

    for(uint n = 1u; n <= N; n++) {
      float2 p = hammersley(n, N);
      //float2 p = mod(hammersley(n, N) + r, 1.0);
      float theta = acos(pow(1.0 - p.y, 1.0/(shininess + 1.0)));
      float phi = 2.0 * M_PI_F * p.x;
      float3 pos = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
      float3 posGlob = normalSpace * pos;
      float2 uv = directionToSphericalEnvmap(posGlob);
      float3 radiance = environmentTexture.sample(s,uv,level(3.0)).rgb;
      result += radiance;
    }
    result = result / float(samples) * (shininess + 2.0) / (shininess + 1.0);
    
    float4 color;
    color.rgb = float3(result);
    color.a = 1.0;
    
    return color;
}

// adapted from "Real Shading in Unreal Engine 4", Brian Karis, Epic Games
// https://cdn2.unrealengine.com/Resources/files/2013SiggraphPresentationsNotes-26915738.pdf

float4 BRDFIntegrationMap(float roughness, float NoV){

    uint samples=128;
    float3 V;
    V.x = sqrt(1.0 - NoV * NoV); // sin
    V.y = 0.0;
    V.z = NoV; // cos
    float2 result = float2(0.0);
    uint sampleCount = uint(samples);
    for(uint n = 1u; n <= sampleCount; n++) {
    float2 p = hammersley(n, sampleCount);
    float a = roughness * roughness;
    float theta = acos(sqrt((1.0 - p.y) / (1.0 + (a * a - 1.0) * p.y)));
    float phi = 2.0 * M_PI_F * p.x;
    // sampled h direction in normal space
    float3 H = float3(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta));
    float3 L = 2.0 * dot(V, H) * H - V;

    // because N = float3(0.0, 0.0, 1.0) follows
    float NoL = clamp(L.z, 0.0, 1.0);
    float NoH = clamp(H.z, 0.0, 1.0);
    float VoH = clamp(dot(V, H), 0.0, 1.0);
    if(NoL > 0.0) {
      float G = G_smith(NoV, NoL, roughness);
      float G_Vis = G * VoH / (NoH * NoV);
      float Fc = pow(1.0 - VoH, 5.0);
      result.x += (1.0 - Fc) * G_Vis;
      result.y += Fc * G_Vis;
    }
    }
    result = result / float(sampleCount);
    
    float4 color;
    color=float4(float2(result),0.0,1.0);
    return color;
    
}

// adapted from "Real Shading in Unreal Engine 4", Brian Karis, Epic Games
// https://cdn2.unrealengine.com/Resources/files/2013SiggraphPresentationsNotes-26915738.pdf
float3 specularIBL(float3 F0 , float roughness, float3 N, float3 V, texture2d<float> specularMap, texture2d<float> brdfMap) {
    
    constexpr sampler s(coord::normalized,
                        filter::linear,
                        mip_filter::linear,
                        address::repeat);
    
    int mipCount=5;
    float NoV = clamp(dot(N, V), 0.0, 1.0);
    float3 R = reflect(-V, N);
    float2 uv = directionToSphericalEnvmap(R);

    float3 prefilteredColor=specularMap.sample(s,uv,level(roughness*float(mipCount))).rgb;

    float4 brdfIntegration=brdfMap.sample(s,float2(NoV,roughness));

    return prefilteredColor * ( F0 * float(brdfIntegration.x) + float(brdfIntegration.y) );
    
}

float3 diffuseIBL(float3 normal, texture2d<float> irradianceMap) {
    
    constexpr sampler s(coord::normalized,
                        filter::linear,
                        mip_filter::linear,
                        address::repeat);
    
    float2 uv = directionToSphericalEnvmap(normal);
    return float3(irradianceMap.sample(s,uv).rgb);
}

float calculateAttenuation(float distance, simd_float4 attenuation){
    if(distance>attenuation.w) return 0.0;
    return 1.0/(attenuation.x + attenuation.y*distance + attenuation.z*distance*distance);
}



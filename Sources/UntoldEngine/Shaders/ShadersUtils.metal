//
//  ShadersUtils.metal
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
using namespace metal;

struct LightContribution {
    half3  diff = half3(0.0);   // low-freq, FP16-friendly
    float3 spec = float3(0.0);   // high-freq, keep precision
};


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

float4x4 rotationmatrix4x4(float3 axis, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    float t = 1.0 - c;

    float3 tAxis = normalize(axis);

    return float4x4(
        float4(t * tAxis.x * tAxis.x + c,          t * tAxis.x * tAxis.y - s * tAxis.z,  t * tAxis.x * tAxis.z + s * tAxis.y,  0.0),
        float4(t * tAxis.x * tAxis.y + s * tAxis.z, t * tAxis.y * tAxis.y + c,          t * tAxis.y * tAxis.z - s * tAxis.x,  0.0),
        float4(t * tAxis.x * tAxis.z - s * tAxis.y, t * tAxis.y * tAxis.z + s * tAxis.x, t * tAxis.z * tAxis.z + c,          0.0),
        float4(0.0,                                0.0,                                0.0,                                1.0)
    );
}


float3 rotateDirection(float3 dir, float3 axis, float angle){

    float cosTheta=cos(angle);
    float sinTheta=sin(angle);
    return normalize(dir * cosTheta + cross(axis, dir) * sinTheta + axis * dot(axis, dir) * (1.0 - cosTheta));
}
float degreesToRadians(float degrees) {
    return degrees * (M_PI_F / 180.0);
}


float mod(float x, float y){
    return x-y*floor(x/y);
}

void transformToLogDepth(thread simd_float4 &position, float far){

    float logarithmicDepthScale=100.0;

    position.z=log2(logarithmicDepthScale*position.z+1.0)/log2(logarithmicDepthScale*far + 1);
    position.z*=position.w;

}

float calculateAttenuation(float distance, simd_float4 attenuation){
    
    // Scale the attenuation factors based on the radius
    float scaledConstant = attenuation.x;
    float scaledLinear = attenuation.y;
    float scaledQuadratic = attenuation.z;

    return 1.0 / (scaledConstant + scaledLinear * distance + scaledQuadratic * (distance * distance));
}

//Gulbransen Parametrization
float n_min(float r){
    return (1-r)/(1+r);
}
float n_max(float r){
    return (1+sqrt(r))/(1-sqrt(r));
}
float get_n(float r,float g){
    return n_min(r)*g + (1-g)*n_max(r);
}
float get_k2(float r, float n){
    float nr = (n+1)*(n+1)*r-(n-1)*(n-1);
    return nr/(1-r);
}
float get_r(float n, float k){
    return ((n-1)*(n-1)+k*k)/((n+1)*(n+1)+k*k);
}
float get_g(float n, float k){
    float r = get_r(n,k);
    return (n_max(r)-n)/(n_max(r)-n_min(r));
}

float3 artistFriendlF0Vector(float f0r,float f0g, float f0b){
    return float3(f0r,f0g,f0b);
}

float artistFriendlyF0(float r, float g,float theta){
    //clamp parameters
    float _r = clamp(r,0.0,0.99);
    //compute n and k
    float n = get_n(_r,g);
    float k2 = get_k2(_r,n);

    float c = theta;
    float rs_num = n*n + k2 - 2*n*c + c*c;
    float rs_den = n*n + k2 + 2*n*c + c*c;
    float rs = rs_num/rs_den;

    float rp_num = (n*n + k2)*c*c - 2*n*c + 1;
    float rp_den = (n*n + k2)*c*c + 2*n*c + 1;
    float rp = rp_num/rp_den;

    return 0.5*(rs+rp);
}

// BRDF - If you are new to BRDF implementation, this article provides a great intro: https://boksajak.github.io/files/CrashCourseBRDF.pdf

float3 fresnelSchlick(float cosTheta,float3 F0){
    return F0+(1.0-F0)*pow(1.0-cosTheta, 5.0);
}

float fresnelSchlick(float cosTheta,float F0){
    return F0+(1.0-F0)*pow(1.0-cosTheta, 5.0);
}

float distributionGGX(float NoH,float roughness){

    float alpha=roughness*roughness;
    float alpha2=alpha*alpha;
    float NoH2=NoH*NoH;
    float b=(NoH2*(alpha2-1.0)+1.0);
    return alpha2*(1.0/M_PI_F)/(b*b);
}

float g1GGXSchlick(float NoV, float roughness){
    float alpha=roughness*roughness;
    float k=alpha/2.0;
    return max(NoV,0.001)/(NoV*(1.0-k)+k);
}

float geometricSmith(float NoV, float NoL,float roughness){
    return g1GGXSchlick(NoL,roughness)*g1GGXSchlick(NoV,roughness);
}

// Cook-Torrance BRDF function - Implementation explanation can be found here: https://graphicscompendium.com/gamedev/15-pbr

LightContribution computeBRDF(float3 incomingLightDir, float3 viewDir, float3 surfaceNormal, float3 diffuseColor, float3 specularColor, float roughnessMap, float metallicMap){

    float roughness=roughnessMap;
    float metallic=metallicMap;

    // Compute the half vector between the incoming and view directions
    float3 halfVector = normalize(incomingLightDir + viewDir);

    //1. Calculate the geometric term (Smith's method for visibility)
    float NoV = max(dot(surfaceNormal, viewDir), 0.001);
    float NoL = max(dot(surfaceNormal, incomingLightDir), 0.001);


    float VoH = max(dot(viewDir, halfVector), 0.001);
    //float LoH = max(dot(incomingLightDir, halfVector), 0.001);
    float NoH = max(dot(surfaceNormal, halfVector), 0.001);

    float3 f0 = mix(0.04, diffuseColor.rgb, metallic);

    float3 F=fresnelSchlick(VoH,f0);
    
    float D=distributionGGX(NoH,roughness);

    float G=geometricSmith(NoV,NoL,roughness);

    float3 spec=(F*D*G)/(4.0*max(NoV,0.001)*max(NoL,0.001));
    spec *= specularColor;
    
    // Diffuse (half)
    half3 rhoD = (half3)diffuseColor * (half)(1.0f - metallic);

    half3 diff=rhoD*(half)(1.0f/M_PI_F);

    half hNoL = (half)NoL;
    LightContribution lc;
    lc.diff = hNoL * diff;
    lc.spec = NoL * spec;
    
    return lc;

}

half3 computeDiffuseBRDF(float3 incomingLightDir, float3 viewDir, float3 surfaceNormal, float3 diffuseColor, float3 specularColor, float roughnessMap, float metallicMap)
{
    
    float NoL = max(dot(surfaceNormal, incomingLightDir), 0.001);

    half3 rhoD = (half3)diffuseColor * (half)(1.0 - metallicMap);
    half3 diffuse = rhoD * (half)(1.0f / M_PI_F); // Lambertian BRDF
    
    half hNoL = (half)NoL;
    
    
    return hNoL * diffuse;
}
                  
                  
float3 computeSpecBRDF(float3 incomingLightDir, float3 viewDir, float3 surfaceNormal, float3 diffuseColor, float3 specularColor, float roughnessMap, float metallicMap)
{
    float roughness=roughnessMap;
    float metallic=metallicMap;

    // Compute the half vector between the incoming and view directions
    float3 halfVector = normalize(incomingLightDir + viewDir);

    //1. Calculate the geometric term (Smith's method for visibility)
    float NoV = max(dot(surfaceNormal, viewDir), 0.001);
    float NoL = max(dot(surfaceNormal, incomingLightDir), 0.001);


    float VoH = max(dot(viewDir, halfVector), 0.001);
    //float LoH = max(dot(incomingLightDir, halfVector), 0.001);
    //float NoH = max(dot(surfaceNormal, halfVector), 0.001);

    float3 f0 = mix(0.04, diffuseColor.rgb, (half)metallic);

    float3 F=fresnelSchlick(VoH,f0);
    
    float D=g1GGXSchlick(NoV,roughness);

    float G=geometricSmith(NoV,NoL,roughness);

    float3 spec=(F*D*G)/(4.0*max(NoV,0.001)*max(NoL,0.001));

    return float3(max(NoL,0.001)*(spec*specularColor));
}
                  

float3 phongBRDF(float3 incomingLightDir, float3 viewDir, float3 surfaceNormal, float3 diffuseColor, float3 specularColor, float shininess){

    float3 N=normalize(surfaceNormal);
    float3 V=normalize(viewDir);
    float3 L=normalize(incomingLightDir);
    float3 R=reflect(-L,N);

    //diffuse term
    float3 diffuse=(diffuseColor*(1/M_PI_F))*max(dot(N, L),0.001);

    //specular term
    float3 specular=specularColor*pow(max(dot(R, V),0.001), shininess)*max(dot(N, L),0.001);

    return diffuse+specular;
}

float3 blinnBRDF(float3 incomingLightDir, float3 viewDir, float3 surfaceNormal, float3 diffuseColor, float3 specularColor, float shininess){

    float3 N=normalize(surfaceNormal);
    float3 V=normalize(viewDir);
    float3 L=normalize(incomingLightDir);
    float3 H=normalize(L+V);

    //diffuse term
    float3 diffuse=diffuseColor*(1/M_PI_F)*max(dot(N, L),0.001);

    //specular term
    float3 specular=specularColor*pow(max(dot(N, H),0.001), shininess)*max(dot(N, L),0.001);

    return diffuse+specular;

}

//IBL: Refer to https://www.youtube.com/watch?v=MkFS6lw6aEs&t=1882s and https://www.mathematik.uni-marburg.de/~thormae/lectures/graphics1/graphics_10_2_eng_web.html#24 


float2 equirectUVFromCubeDirection(float3 v){

    const float2 scales {0.1591549f,0.3183099f};
    const float2 biases {0.5f,0.5f};

    //assume +z is forward. for -x forward, use atan2(v.z,v.x)
    float2 uv=float2(atan2(-v.x, v.z),asin(-v.y))*scales+biases;

    return uv;
}

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
    float phiN = 2.0 * M_PI_F * (1.0-texCoords.x);
    float3 normal = float3(sin(thetaN) * cos(phiN), sin(thetaN) * sin(phiN), cos(thetaN));
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
    float phiN = 2.0 * M_PI_F * (1.0-texCoords.x);
    float3 normal = float3(sin(thetaN) * cos(phiN), sin(thetaN) * sin(phiN), cos(thetaN));


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
      float G = geometricSmith(NoV, NoL, roughness);
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
float3 specularIBL(float3 F0 , float roughness, float3 N, float3 V, texture2d<float> specularMap, texture2d<float> brdfMap, float3 rotationAxis, float rotationAngle) {

    constexpr sampler s(coord::normalized,
                        filter::linear,
                        mip_filter::none,
                        address::clamp_to_edge);

    int mipCount=5;
    float NoV = clamp(dot(N, V), 0.0, 1.0);
    float3 R = reflect(-V, N);

    //Rotate the reflection vector
    float3 rotatedR=normalize(rotateDirection(R, rotationAxis, rotationAngle));

    float2 uv = equirectUVFromCubeDirection(rotatedR);
    float mipLevel = roughness * float(mipCount - 1);
    float3 prefilteredColor = specularMap.sample(s, uv, level(mipLevel)).rgb;


    float4 brdfIntegration=brdfMap.sample(s,float2(NoV,roughness));

    return prefilteredColor * ( F0 * float(brdfIntegration.x) + float(brdfIntegration.y) );

}

float3 diffuseIBL(float3 normal, texture2d<float> irradianceMap, float3 rotationAxis, float rotationAngle) {

    constexpr sampler s(coord::normalized,
                        filter::linear,
                        mip_filter::linear,
                        address::repeat);

    //Rotate the normal
    float3 rotatedNormal=rotateDirection(normal, rotationAxis, rotationAngle);
    float2 uv = equirectUVFromCubeDirection(rotatedNormal);
    return float3(irradianceMap.sample(s,uv).rgb);
}

// ACES Filmic Tone Mapping Function
float3 ACESFilmicToneMapping(float3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}

// Filmic/Uncharted 2 Tone Mapping Function
float3 filmicToneMapping(float3 x) {
    float A = 0.15;
    float B = 0.50;
    float C = 0.10;
    float D = 0.20;
    float E = 0.02;
    float F = 0.30;
    return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

// Reinhard Tone Mapping Function
float3 reinhardToneMapping(float3 color) {
    return color / (1.0 + color);
}

float computeLuma(float3 color) {
    return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
}

float linearizeDepthForViewing(float depth, float near, float far){
   
    // Custom values for the scene
    float sceneNear = 0.1;
    float sceneFar = 50.0;
    
    float linear = near * far / (far + depth * (near - far)); // standard Z

    // Normalize to 0–1 for visualization 
    return saturate((linear - sceneNear) / (sceneFar - sceneNear));
    
}

float linearizeDepth(float depth, float near, float far){
    return near * far / (far + depth * (near - far));
}


/*
float3 integrateEdge(float3 v1, float3 v2, float3 n){

    float x = dot(v1,v2);
    float y = abs(x);

    float a = 5.42031 + (3.12829 + 0.0902326*y)*y;
    float b = 3.45068 + (4.18814 + y)*y;
    float theta_sintheta = a/b;
   
    if(x<0.0){
        theta_sintheta = M_PI_F*sqrt(1.0-x*x)-theta_sintheta;
    }
    
    float3 u = cross(v1,v2);
    
    return theta_sintheta*dot(u,n);
}
*/
float integrateEdge(float3 v1, float3 v2){
    float cosTheta = dot(v1,v2);
    float theta = acos(cosTheta);
    float res = cross(v1, v2).z * ((theta > 0.001) ? theta/sin(theta) : 1.0);
    
    return res;
}

float3 LTC_Evaluate(float3 N, float3 V, float3 P, float3x3 Minv, float3 points[4], bool twoSided){
    
    // constuct orthonormal basis around N
    
    float3 T1, T2;
    T1 = normalize(V-N*dot(V,N));
    T2 = cross(N, T1);
    
    //rotate area light in (T1,T2, N) basis
    Minv = Minv*transpose(float3x3(T1,T2,N));
    
    // polygon (allocate 5 vertices for clipping)
    float3 L[5];
    L[0] = Minv*(points[0]-P);
    L[1] = Minv*(points[1]-P);
    L[2] = Minv*(points[2]-P);
    L[3] = Minv*(points[3]-P);
    
    L[0] = normalize(L[0]);
    L[1] = normalize(L[1]);
    L[2] = normalize(L[2]);
    L[3] = normalize(L[3]);
   
    // integrate
    float sum = 0.0;
    
    sum += integrateEdge(L[0], L[1]);
    sum += integrateEdge(L[1], L[2]);
    sum += integrateEdge(L[2], L[3]);
    sum += integrateEdge(L[3], L[0]);
    
    sum = twoSided ? abs(sum): max(0.0, sum);
    
    float3 Lo_i = float3(sum, sum, sum);
    
    //return Lo_i;
    return Lo_i*2.0/M_PI_F;
}

float getLuminance(float3 color){
    return dot(color, float3(0.299, 0.587, 0.114));
}

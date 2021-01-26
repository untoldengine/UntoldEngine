//
//  U4DShaderHelperFunctions.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 10/22/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "U4DShaderHelperFunctions.h"

float4 computeLightColor(float4 uVerticesInMVSpace, float3 uNormalInMVSpace, Material uMaterial, Light uLight){
    
    //2. Compute the direction of the light ray betweent the light position and the vertices of the surface
    float3 lightRayDirection=normalize(uLight.position.xyz-uVerticesInMVSpace.xyz);
    
    //3. Normalize View Vector
    float3 viewVector=normalize(-uVerticesInMVSpace.xyz);
    
    //4. Compute reflection vector
    float3 reflectionVector=reflect(-lightRayDirection,uNormalInMVSpace);
    
    //COMPUTE LIGHTS
    
    //5. compute ambient lighting
    float3 ambientLight=uLight.ambientColor*uMaterial.ambientMaterialColor;
    
    //6. compute diffuse intensity by computing the dot product. We obtain the maximum the value between 0 and the dot product
    float diffuseIntensity=max(0.0,dot(uNormalInMVSpace,lightRayDirection));
    
    //7. compute Diffuse Color
    float3 diffuseLight=diffuseIntensity*uLight.diffuseColor*uMaterial.diffuseMaterialColor;
    
    //8. compute specular lighting
    float3 specularLight=float3(0.0,0.0,0.0);
    
    if(diffuseIntensity>0.0){
        
        specularLight=uLight.specularColor*uMaterial.specularMaterialColor*pow(max(dot(reflectionVector,viewVector),0.0),uMaterial.specularReflectionPower);
        
        specularLight=clamp(specularLight,0.0,1.0);
        
    }
    
    return float4(ambientLight+diffuseLight+specularLight,1.0);
    
}

float4 computePointLightColor(float4 uVerticesInMVSpace, float3 uNormalInMVSpace, Material uMaterial, Light uLight){
    
    float4 lightColor=computeLightColor(uVerticesInMVSpace, uNormalInMVSpace, uMaterial, uLight);
    
    float lightDistance=length(uLight.position.xyz-uVerticesInMVSpace.xyz);
    
    float attenuation=uLight.constantAttenuation+uLight.linearAttenuation*lightDistance+uLight.expAttenuation*lightDistance*lightDistance;
    
    return lightColor/attenuation;
    
}

float random(float u){
    
    return fract(sin(u));
    
}

float random(float2 st){
    
    return fract(sin(dot(st.xy,float2(12.9898,78.233)))*43.5453123);
}

float valueNoise(float2 st){
    
    float2 i=floor(st);
    float2 f=fract(st);
    
    //four corners in 2D of a tile
    float a=random(i);
    float b=random(i+float2(1.0,0.0));
    float c=random(i+float2(0.0,1.0));
    float d=random(i+float2(1.0,1.0));
    
    //smooth interpolation
    float2 u=f*f*(3.0-2.0*f);
    
    //Mix the four corners
    return mix(a,b,u.x)+(c-a)*u.y*(1.0-u.x)+(d-b)*u.x*u.y;
    
}

float noise(float2 st)
{
    float2 i = floor(st);
    float2 f = fract(st);
    
    float2 u = f*f*(3.0-2.0*f);
    
    return mix( mix( dot( hash( i + float2(0.0,0.0) ), f - float2(0.0,0.0) ),
                    dot( hash( i + float2(1.0,0.0) ), f - float2(1.0,0.0) ), u.x),
               mix( dot( hash( i + float2(0.0,1.0) ), f - float2(0.0,1.0) ),
                   dot( hash( i + float2(1.0,1.0) ), f - float2(1.0,1.0) ), u.x), u.y);
}

float2 hash(float2 u)  
{
    const float2 k = float2( 0.3183099, 0.3678794 );
    u = u*k + k.yx;
    return -1.0 + 2.0*fract( 16.0 * k*fract( u.x*u.y*(u.x+u.y)) );
}

float mod(float x, float y){

    return x-y*floor(x/y);
    
}

float sharpen(float d, float w, float2 resolution){
    float e = 1. / min(resolution.y , resolution.x);
    return 1. - smoothstep(-e, e, d - w);
}

float sdfCircle(float2 p,float r){

    return length(p)-r;
    
}

float sdfRing(float2 p, float2 c, float r){
    return abs(r - length(p - c));
}

float sdfLine( float2 p, float2 a, float2 b){
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa,ba) / dot(ba,ba), 0., 1.);
    return length(pa - ba * h);
}

float sdfTriangle(float2 p ){
    
    const float k = sqrt(3.0);
    p.x = abs(p.x) - 1.0;
    p.y = p.y + 1.0/k;
    if( p.x+k*p.y>0.0 ) p = float2(p.x-k*p.y,-k*p.x-p.y)/2.0;
    p.x -= clamp( p.x, -2.0, 0.0 );
    return -length(p)*sign(p.y);
}

float sdfBox( float2 p, float2 b ){
    float2 d = abs(p)-b;
    return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}

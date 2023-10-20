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
    float diffuseIntensity=uLight.energy*max(0.0,dot(uNormalInMVSpace,lightRayDirection)); 
    
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



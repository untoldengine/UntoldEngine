#version 300 es

#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif


uniform sampler2D DiffuseTexture;
uniform vec4 DiffuseMaterialColor[10];
uniform vec4 SpecularMaterialColor[10];
uniform float DiffuseMaterialIntensity[10];
uniform float SpecularMaterialIntensity[10];
uniform float SpecularMaterialHardness[10];

uniform sampler2D ShadowMap;
uniform float ShadowCurrentPass;
uniform float HasTexture;


in mediump vec3 normalInViewSpace;
in mediump vec4 positionInViewSpace;
in mediump vec2 vVaryingTexCoords;
in highp vec4 shadowCoord;
in mediump vec4 lightPosition;
flat in highp int colorIndex;

out vec4 fragmentColor;

float ShadowCalculation(vec4 uShadowCoord){

    //float bias = 0.005;

    //use this bias when you have normal and light direction data
    float bias = max(0.05 * (1.0 - dot(normalInViewSpace, lightPosition.xyz)), 0.005);

    // perform perspective divide
    vec3 projCoords=uShadowCoord.xyz/uShadowCoord.w;

    // Transform to [0,1] range
    projCoords=projCoords*0.5+0.5;

    // Get closest depth value from light's perspective (using [0,1] range fragPosLight as coords)
    float closestDepth=texture(ShadowMap,projCoords.xy).r;

    // Get depth of current fragment from light's perspective
    float currentDepth = projCoords.z;

    // Check whether current frag pos is in shadow
    float shadow = currentDepth-bias > closestDepth  ? 0.2 : 0.0;

    if(projCoords.z > 1.0){
        shadow = 0.0;
    }

    return shadow;

}

vec4 computeMaterialColor(vec3 surfaceNormal, vec4 surfacePosition, vec4 lightPosition){

    //CD=iL*max(0,dot(L,N))*LD*MD

    //compute the diffuse component
    vec3 n=normalize(surfaceNormal);
    vec3 s=normalize(vec3(lightPosition));

    vec4 diffuseComponent=vec4(DiffuseMaterialColor[colorIndex].xyz*max(0.0,dot(n,s)),1.0)*DiffuseMaterialIntensity[colorIndex];

    //compute the specular component
    vec3 v=normalize(-surfacePosition.xyz);
    vec3 h=normalize(v+s);

    vec4 specularComponent=vec4(SpecularMaterialColor[colorIndex].xyz*pow(max(dot(h,n),0.0),SpecularMaterialHardness[colorIndex]),1.0)*SpecularMaterialIntensity[colorIndex];

    vec4 finalMaterialColor=diffuseComponent+specularComponent;

    return finalMaterialColor;

}


void main(void)
{

    if(ShadowCurrentPass==0.0){

    fragmentColor=vec4(gl_FragCoord.z);

    }else{

        vec4 finalColor=vec4(0.0);

        finalColor=computeMaterialColor(normalInViewSpace, positionInViewSpace, lightPosition);

        float shadow = ShadowCalculation(shadowCoord);

        if(HasTexture==1.0){

            mediump vec4 textureColor=texture(DiffuseTexture,vVaryingTexCoords.st);

            finalColor=vec4(mix(textureColor,finalColor,0.2));

        }

        fragmentColor=finalColor*(1.0-shadow);

    }

}
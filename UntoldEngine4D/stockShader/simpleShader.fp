
#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif

varying mediump vec3 normalInViewSpace;
varying mediump vec4 positionInViewSpace;

varying mediump vec2 vVaryingTexCoords;
uniform sampler2D DiffuseTexture;
uniform vec4 DiffuseMaterialColor[1];

uniform sampler2D ShadowMap;
varying highp vec4 shadowCoord;
uniform float ShadowCurrentPass;
varying mediump vec4 lightPosition;

uniform float HasTexture;
varying float nDotVP;

float ShadowCalculation(vec4 uShadowCoord){

    float bias = 0.005;

    //use this bias when you have normal and light direction data
    //float bias = max(0.05 * (1.0 - dot(normalInViewSpace, lightPosition.xyz)), 0.005);

    // perform perspective divide
    vec3 projCoords=uShadowCoord.xyz/uShadowCoord.w;

    // Transform to [0,1] range
    projCoords=projCoords*0.5+0.5;

    // Get closest depth value from light's perspective (using [0,1] range fragPosLight as coords)
    float closestDepth=texture2D(ShadowMap,projCoords.xy).r;

    // Get depth of current fragment from light's perspective
    float currentDepth = projCoords.z;

    // Check whether current frag pos is in shadow
    float shadow = currentDepth-bias > closestDepth  ? 0.2 : 0.0;

    if(projCoords.z > 1.0){
        shadow = 0.0;
    }

    return shadow;

}

vec4 computeDiffuseComponent(vec3 surfaceNormal, vec4 lightPosition){

    //CD=iL*max(0,dot(L,N))*LD*MD
    //return light.iL*(light.lightColor*light.lightAmbDiffSpec.y)*DiffuseMaterialColor.rgb*max(0.0,dot(surfaceNormal,light.L));

    vec3 n=normalize(surfaceNormal);
    vec3 s=normalize(vec3(lightPosition));
    return vec4(DiffuseMaterialColor[0].xyz*max(0.5,dot(n,s)),1.0);

}


void main(void)
{

    if(ShadowCurrentPass==0.0){

    gl_FragColor=vec4(gl_FragCoord.z);

    }else{

        vec4 finalColor=vec4(0.0);

        finalColor=computeDiffuseComponent(normalInViewSpace, lightPosition);

        float shadow = ShadowCalculation(shadowCoord);

        if(HasTexture==1.0){

            mediump vec4 textureColor=texture2D(DiffuseTexture,vVaryingTexCoords.st);

            finalColor=vec4(mix(textureColor,finalColor,0.2));

        }

        gl_FragColor=finalColor*(1.0-shadow);


    }

}
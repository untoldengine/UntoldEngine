#version 300 es

#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif


uniform sampler2D DiffuseTexture;


uniform sampler2D ShadowMap;
uniform float ShadowCurrentPass;
uniform float HasTexture;
uniform float SelfShadowBias;
in mediump vec3 normalInViewSpace;
in mediump vec4 positionInViewSpace;
in mediump vec2 vVaryingTexCoords;
in highp vec4 shadowCoord;
in mediump vec4 lightPosition;
in highp vec4 colorVarying;

out vec4 fragmentColor;

float ShadowCalculation(vec4 uShadowCoord){

    //float bias = 0.005;

    //use this bias when you have normal and light direction data
    float bias = max(0.05 * (1.0 - dot(normalInViewSpace, lightPosition.xyz)), SelfShadowBias);

    // perform perspective divide
    vec3 projCoords=uShadowCoord.xyz/uShadowCoord.w;

    // Transform to [0,1] range
    projCoords=projCoords*0.5+0.5;

    // Get closest depth value from light's perspective (using [0,1] range fragPosLight as coords)
    float closestDepth=texture(ShadowMap,projCoords.xy).r;

    // Get depth of current fragment from light's perspective
    float currentDepth = projCoords.z;

    // Check whether current frag pos is in shadow
    float shadow = currentDepth-bias > closestDepth  ? 0.1 : 0.0;

    if(projCoords.z > 1.0){
        shadow = 0.0;
    }

    return shadow;

}

void main(void)
{

    if(ShadowCurrentPass==0.0){

    fragmentColor=vec4(gl_FragCoord.z);

    }else{

        vec4 finalColor=colorVarying;

        float shadow = ShadowCalculation(shadowCoord);

        if(HasTexture==1.0){

            mediump vec4 textureColor=texture(DiffuseTexture,vVaryingTexCoords.st);

            finalColor=vec4(mix(textureColor,finalColor,0.2));

        }

        fragmentColor=finalColor*(1.0-shadow);

    }

}

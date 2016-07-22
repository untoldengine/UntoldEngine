
#extension GL_EXT_shadow_samplers : require
#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif



uniform sampler2D ShadowMap;
varying highp vec4 shadowCoord;
uniform float ShadowCurrentPass;


float ShadowCalculation(vec4 uShadowCoord){

    float bias = 0.005;

    //use this bias when you have normal and light direction data
    //float bias = max(0.05 * (1.0 - dot(normal, lightDir)), 0.005);

    // perform perspective divide
    vec3 projCoords=uShadowCoord.xyz/uShadowCoord.w;

    // Transform to [0,1] range
    projCoords=projCoords*0.5+0.5;

    // Get closest depth value from light's perspective (using [0,1] range fragPosLight as coords)
    float closestDepth=texture2D(ShadowMap,projCoords.xy).r;

    // Get depth of current fragment from light's perspective
    float currentDepth = projCoords.z;

    // Check whether current frag pos is in shadow
    float shadow = currentDepth-bias > closestDepth  ? 0.5 : 0.0;

    if(projCoords.z > 1.0)
    shadow = 0.0;

return shadow;

}

void main()
{

    if(ShadowCurrentPass==0.0){
    
    gl_FragColor=vec4(gl_FragCoord.z);

    }else{

    vec4 finalColor=vec4(1.0,0.0,0.0,1.0);

    float shadow = ShadowCalculation(shadowCoord);

    gl_FragColor=finalColor*(1.0-shadow);

    }
}

#extension GL_EXT_shadow_samplers : require
#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif



uniform sampler2D ShadowMap;
varying highp vec4 shadowCoord;
uniform float ShadowCurrentPass;


void main()
{

    if(ShadowCurrentPass==0.0){
    
   // gl_FragColor=vec4(gl_FragCoord.z);

    }else{

    vec4 finalColor=vec4(1.0,0.0,0.0,1.0);

    vec3 projCoords=shadowCoord.xyz/shadowCoord.w;

    projCoords=projCoords*0.5+0.5;

   //float depthValue = texture2D( ShadowMap, projCoords.xy).r;

    float closestDepth=texture2D(ShadowMap,projCoords.xy).r;

    float currentDepth = projCoords.z;

    float shadow = currentDepth > closestDepth  ? 1.0 : 0.0;

    gl_FragColor=finalColor*(1.0-shadow);

     //gl_FragColor=vec4(vec3(depthValue),1.0);
    }
}
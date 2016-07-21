
#extension GL_EXT_shadow_samplers : require
#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif


uniform sampler2D ShadowMap;
varying highp vec4 shadowCoord;
uniform float ShadowCurrentPass;

varying mediump vec2 vVaryingTexCoords;


void main()
{

    if(ShadowCurrentPass==0.0){
    
   // gl_FragColor=vec4(gl_FragCoord.z);

    }else{

    float depthValue = texture2D( ShadowMap, shadowCoord.xy).r;

    gl_FragColor=vec4(vec3(depthValue),1.0);

    }
}
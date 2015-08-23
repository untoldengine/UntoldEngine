
#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif

uniform sampler2D ShadowMap;
varying vec4 shadowCoord;

void main(void)
{

    float visibility = 1.0;
    if ( texture2D( ShadowMap, shadowCoord.xy ).z  <  shadowCoord.z){
        visibility = 0.5;
        gl_FragColor=vec4(1.0,0.0,0.0,1.0);

    }else{
    
        gl_FragColor=vec4(0.0,0.0,1.0,1.0);
    
    }


}
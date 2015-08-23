
#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif

varying mediump vec4 axisColor;

void main(void)
   {

    gl_FragColor=axisColor;

   }
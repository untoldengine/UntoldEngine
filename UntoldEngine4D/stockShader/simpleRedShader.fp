
#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif

varying lowp vec4 colorVarying;

void main(void)
   {

   gl_FragColor = colorVarying;

   }
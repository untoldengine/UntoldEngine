
#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif

varying vec4 vVaryingColor;

varying mediump vec2 vVaryingTexCoords;
uniform sampler2D DiffuseTexture;

void main(void)
   { 

   gl_FragColor=texture2D(DiffuseTexture,vVaryingTexCoords.st);
   

   }
#version 300 es

#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif

in vec4 vVaryingColor;
in mediump vec2 vVaryingTexCoords;

uniform sampler2D DiffuseTexture;

out vec4 fragmentColor;

void main(void)
   { 

   fragmentColor=texture(DiffuseTexture,vVaryingTexCoords.st);
   

   }
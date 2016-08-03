#version 300 es

#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif

in mediump vec4 axisColor;

out vec4 fragmentColor;

void main(void)
   {

    fragmentColor=axisColor;

   }
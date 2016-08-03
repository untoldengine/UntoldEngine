#version 300 es

#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif

uniform vec4 Color;

out vec4 fragmentColor;

void main(void)
{
      fragmentColor = Color;
}
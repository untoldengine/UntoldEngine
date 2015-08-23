
#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif

uniform vec4 Color;

void main(void)
{
      gl_FragColor = Color;
}
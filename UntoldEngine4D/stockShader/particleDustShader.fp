#version 300 es

#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif

in highp vec4 colorVarying;

out vec4 fragmentColor;
in float transperancy;

void main(void)
{

fragmentColor=vec4(0.5,0.5,0.5,1.0);
fragmentColor.a*=transperancy;

}

#version 300 es

#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif


in mediump vec2 vVaryingTexCoords;
in mediump vec3 outPosition;
in mediump vec3 outNormal;
in mediump float shininess;


uniform sampler2D DiffuseTexture;
uniform vec4 DiffuseMaterialColor;
uniform vec4 AmbientMaterialColor;
uniform vec4 SpecularMaterialColor;
uniform float Shininess;
uniform vec4 PointLight;


out vec4 fragmentColor;

mediump vec3 ads(){


mediump vec3 lightIntensity=vec3(1.0,1.0,1.0);

mediump vec3 n=normalize(outNormal);
mediump vec3 s=normalize(vec3(PointLight)-outPosition);

mediump vec3 v=normalize(vec3(-outPosition));
mediump vec3 h=normalize(v+s);

return lightIntensity*(AmbientMaterialColor.xyz+DiffuseMaterialColor.xyz*max(dot(s,n),0.0)+SpecularMaterialColor.xyz*pow(max(dot(h,n),0.0),Shininess));


}

void main(void)
   {

   mediump vec4 color0=texture(DiffuseTexture,vVaryingTexCoords.st);

   mediump vec4 adsValue=vec4(ads(),1.0);
   mediump vec3 texColor=vec3(mix(color0,adsValue,0.5));
   
   fragmentColor=color0;

}
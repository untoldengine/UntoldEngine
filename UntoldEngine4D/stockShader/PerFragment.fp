
#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif

varying mediump vec2 vVaryingTexCoords;
uniform sampler2D DiffuseTexture;

varying mediump vec3 outPosition;
varying mediump vec3 outNormal;
varying mediump float shininess;
varying mediump vec4 lightPosition;

uniform vec4 DiffuseMaterialColor;
uniform vec4 AmbientMaterialColor;
uniform vec4 SpecularMaterialColor;
uniform float Shininess;

mediump vec3 ads(){


mediump vec3 lightIntensity=vec3(1.0,1.0,1.0);

mediump vec3 n=normalize(outNormal);
mediump vec3 s=normalize(vec3(lightPosition)-outPosition);

mediump vec3 v=normalize(vec3(-outPosition));
mediump vec3 h=normalize(v+s);

return lightIntensity*(AmbientMaterialColor.xyz+DiffuseMaterialColor.xyz*max(dot(s,n),0.0)+SpecularMaterialColor.xyz*pow(max(dot(h,n),0.0),Shininess));


}

void main(void)
   {

   //gl_FragColor=texture2D(DiffuseTexture,vVaryingTexCoords.st);

   mediump vec4 color0=texture2D(DiffuseTexture,vVaryingTexCoords.st);

   mediump vec4 adsValue=vec4(ads(),1.0);
   mediump vec3 texColor=vec3(mix(color0,adsValue,0.5));
   
   gl_FragColor=vec4(texColor,1.0);

    //gl_FragColor=vec4(color0);
   }
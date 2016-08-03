#version 300 es

#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif

uniform sampler2D DiffuseTexture;
uniform sampler2D NormalBumpTexture;
uniform vec4 DiffuseMaterialColor;
uniform vec4 AmbientMaterialColor;
uniform vec4 SpecularMaterialColor;
uniform float Shininess;

in mediump vec2 vVaryingTexCoords;
in mediump vec4 LightPosition;
in mediump vec3 LightDir;
in mediump vec3 ViewDir;

mediump vec3 LightIntensity=vec3(1.0,1.0,1.0);

out vec4 fragmentColor;

mediump vec3 phongModel(vec3 norm,vec3 diffR){

    mediump vec3 r=reflect(-LightDir,norm);

    mediump vec3 ambient=LightIntensity*vec3(AmbientMaterialColor);

    mediump float sDotN=max(dot(LightDir,norm),0.0);

    mediump vec3 diffuse=vec3(DiffuseMaterialColor)*LightIntensity*diffR*sDotN;

    mediump vec3 spec=vec3(0.0,0.0,0.0);

        if(sDotN>0.0){

            spec=LightIntensity*vec3(SpecularMaterialColor)*pow(max(dot(r,ViewDir),0.0),Shininess);
        }

    return ambient+diffuse+spec;

}

void main(void)
   {

   //gl_FragColor=texture2D(Color0Map,vVaryingTexCoords.st);

    //look up the normal from the normal map
    mediump vec4 normalMap=texture(NormalBumpTexture,vVaryingTexCoords.st);
   
    //Color map
    mediump vec4 texColor=texture(DiffuseTexture,vVaryingTexCoords.st);


    fragmentColor=vec4(phongModel(normalMap.xyz,texColor.rgb),0.5);
   
   }
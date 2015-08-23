
#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif

varying mediump vec2 vVaryingTexCoords;
uniform sampler2D DiffuseTexture;
uniform sampler2D NormalBumpTexture;

uniform vec4 DiffuseMaterialColor;
uniform vec4 AmbientMaterialColor;
uniform vec4 SpecularMaterialColor;
uniform float Shininess;

varying mediump vec4 LightPosition;
varying mediump vec3 LightDir;
varying mediump vec3 ViewDir;

mediump vec3 LightIntensity=vec3(1.0,1.0,1.0);


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
    mediump vec4 normalMap=texture2D(NormalBumpTexture,vVaryingTexCoords.st);
   
    //Color map
    mediump vec4 texColor=texture2D(DiffuseTexture,vVaryingTexCoords.st);


    gl_FragColor=vec4(phongModel(normalMap.xyz,texColor.rgb),0.5);
   
   }
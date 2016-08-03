#version 300 es

#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif

in vec4 vVaryingColor;

in mediump vec2 vVaryingTexCoords;
uniform sampler2D DiffuseTexture;
uniform sampler2D AmbientTexture;
uniform float ChangeImage;

out vec4 fragmentColor;

void main(void)
{
    
    if(ChangeImage==1.0){
    
    fragmentColor=texture(AmbientTexture,vVaryingTexCoords.st);

    }else{
    
    fragmentColor=texture(DiffuseTexture,vVaryingTexCoords.st);

    }
   

    
}
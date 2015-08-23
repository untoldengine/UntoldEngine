
#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif

varying vec4 vVaryingColor;

varying mediump vec2 vVaryingTexCoords;
uniform sampler2D DiffuseTexture;
uniform sampler2D AmbientTexture;
uniform float ChangeImage;

void main(void)
{
    
    if(ChangeImage==1.0){
    
    gl_FragColor=texture2D(AmbientTexture,vVaryingTexCoords.st);

    }else{
    
    gl_FragColor=texture2D(DiffuseTexture,vVaryingTexCoords.st);

    }
   

    
}
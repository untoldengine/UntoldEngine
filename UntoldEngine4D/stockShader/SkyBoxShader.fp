#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif

//varying vec4 vVaryingColor;

varying mediump vec3 vVaryingTexCoords;
uniform samplerCube DiffuseTexture;

void main(void)
    { 
    gl_FragColor=textureCube(DiffuseTexture,vVaryingTexCoords);
    }
    
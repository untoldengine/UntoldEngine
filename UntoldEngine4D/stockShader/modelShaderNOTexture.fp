
#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif

varying mediump vec2 vVaryingTexCoords;
uniform sampler2D DiffuseTexture;

varying mediump vec4 positionInViewSpace;
varying mediump vec3 normalInViewSpace;

uniform vec4 DiffuseMaterialColor;
mediump vec4 AmbientMaterialColor=vec4(0.1,0.1,0.1,1.0);
uniform vec4 SpecularMaterialColor;
uniform float Shininess;
uniform vec4 PointLight;

//USE FOR SHADOWS
uniform float ShadowPass;
uniform sampler2D ShadowMap;
varying vec4 shadowCoord;


varying mediump vec4 light0Position;
varying mediump vec4 light1Position;
varying mediump vec4 light2Position;

struct Lights{
   mediump vec3 L;
   lowp float iL;
   float pointLightIntensity;
   vec3 pointLightAttenuation;
   vec3 lightAmbDiffSpec;
   vec3 lightColor;
   vec4 lightPosition;
};


Lights light[10];


void computePointLightValues(in mediump vec4 surfacePosition,in int i);
mediump vec3 computeAmbientComponent(in int i);
mediump vec3 computeLitColor(in mediump vec4 surfacePosition,in mediump vec3 surfaceNormal,in int i);
mediump vec3 computeDiffuseComponent(in mediump vec3 surfaceNormal,in int i);
mediump vec3 computeSpecularComponent(in mediump vec3 surfaceNormal,in mediump vec4 surfacePosition, in int i);


void computePointLightValues(in mediump vec4 surfacePosition,in int i){


   light[i].L=light[i].lightPosition.xyz-surfacePosition.xyz;
   mediump float dist=length(light[i].L);
   light[i].L=light[i].L/dist; //Normalize

   //Dot computes the 3-term attenuation in one operation
   //k_c*1.0+K_1*dist+K_q*dist*dist
   mediump float distAtten=dot(light[i].pointLightAttenuation,vec3(1.0,dist,dist*dist));

   light[i].iL=light[i].pointLightIntensity/distAtten;

}

mediump vec3 computeAmbientComponent(in int i){
   
   //CA=iL*LightAmbientColor*MaterialAmbientColor
   return light[i].iL*(light[i].lightColor*light[i].lightAmbDiffSpec.x)*AmbientMaterialColor.xyz;
}

mediump vec3 computeLitColor(in mediump
 vec4 surfacePosition,in mediump vec3 surfaceNormal,in int i){

   return computeAmbientComponent(i)+computeDiffuseComponent(surfaceNormal,i)+computeSpecularComponent(surfaceNormal,surfacePosition,i);
}

mediump vec3 computeDiffuseComponent(in mediump vec3 surfaceNormal,in int i){

   //CD=iL*max(0,dot(L,N))*LD*MD
   return light[i].iL*(light[i].lightColor*light[i].lightAmbDiffSpec.y)*DiffuseMaterialColor.rgb*max(0.0,dot(surfaceNormal,light[i].L));

}

mediump vec3 computeSpecularComponent(in mediump vec3 surfaceNormal,in mediump vec4 surfacePosition,in int i){

   mediump vec3 viewVector=normalize(-surfacePosition.xyz);

   mediump vec3 reflectionVector=2.0*dot(light[i].L,surfaceNormal)*surfaceNormal-light[i].L;
   
   return (dot(surfaceNormal,light[i].L)<=0.0)?vec3(0.0,0.0,0.0):(light[i].iL*(light[i].lightColor*light[i].lightAmbDiffSpec.z)*SpecularMaterialColor.rgb*pow(max(0.0,dot(reflectionVector,viewVector)),Shininess));

}

void main()
{
float depth;
   mediump vec4 finalColor=vec4(0.0);
   float visibility = 1.0;

   finalColor.a=1.0;

   int numOfLights=1;
   int i;


    
   if(ShadowPass==0.0){
   
   gl_FragColor=vec4(gl_FragCoord.z);
   
   }else{
   

   light[0].lightPosition=PointLight;
   light[0].pointLightIntensity=1.0;
   light[0].pointLightAttenuation=vec3(1.0,0.0,0.0);
   light[0].lightAmbDiffSpec=vec3(1.0,0.9,0.7);
   light[0].lightColor=vec3(1.0,1.0,1.0);
   
   /*
    for(i=0;i<1;i++){
    
        computePointLightValues(positionInViewSpace,i);
        finalColor.rgb+=vec3(computeLitColor(positionInViewSpace,normalInViewSpace,i));

        }
    */
    
    finalColor.rgb=vec3(1.0,0.0,0.0);

    if(texture2D(ShadowMap,shadowCoord.st).s<shadowCoord.z){
    
    visibility=0.5;

    }else{
    
    visibility=1.0;
    
    }

    gl_FragColor=visibility*finalColor;
   }

}
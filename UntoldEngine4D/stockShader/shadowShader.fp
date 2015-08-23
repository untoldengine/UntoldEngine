
#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif
#extension GL_EXT_shadow_samplers : require


uniform sampler2DShadow ShadowMap;
varying highp vec4 shadowCoord;
uniform float ShadowCurrentPass;

varying mediump vec2 vVaryingTexCoords;
uniform sampler2D DiffuseTexture;

varying mediump vec4 positionInViewSpace;
varying mediump vec3 normalInViewSpace;

uniform vec4 DiffuseMaterialColor;
mediump vec4 AmbientMaterialColor=vec4(0.0,0.0,0.0,1.0);
uniform vec4 SpecularMaterialColor;
uniform float Shininess;
uniform vec4 PointLight;


varying mediump vec4 light0Position;


struct Lights{
   mediump vec3 L;
   lowp float iL;
   float pointLightIntensity;
   vec3 pointLightAttenuation;
   vec3 lightAmbDiffSpec;
   vec3 lightColor;
   vec4 lightPosition;
};


Lights light;


void computePointLightValues(in mediump vec4 surfacePosition);
mediump vec3 computeAmbientComponent();
mediump vec3 computeLitColor(in mediump vec4 surfacePosition,in mediump vec3 surfaceNormal);
mediump vec3 computeDiffuseComponent(in mediump vec3 surfaceNormal);
mediump vec3 computeSpecularComponent(in mediump vec3 surfaceNormal,in mediump vec4 surfacePosition);


void computePointLightValues(in mediump vec4 surfacePosition){


   light.L=light.lightPosition.xyz-surfacePosition.xyz;
   mediump float dist=length(light.L);
   light.L=light.L/dist; //Normalize

   //Dot computes the 3-term attenuation in one operation
   //k_c*1.0+K_1*dist+K_q*dist*dist
   mediump float distAtten=dot(light.pointLightAttenuation,vec3(1.0,dist,dist*dist));

   light.iL=light.pointLightIntensity/distAtten;

}

mediump vec3 computeAmbientComponent(){
   
   //CA=iL*LightAmbientColor*MaterialAmbientColor
   return light.iL*(light.lightColor*light.lightAmbDiffSpec.x)*AmbientMaterialColor.xyz;
}

mediump vec3 computeLitColor(in mediump
 vec4 surfacePosition,in mediump vec3 surfaceNormal){

   return computeAmbientComponent()+computeDiffuseComponent(surfaceNormal)+computeSpecularComponent(surfaceNormal,surfacePosition);
}

mediump vec3 computeDiffuseComponent(in mediump vec3 surfaceNormal){

   //CD=iL*max(0,dot(L,N))*LD*MD
   return light.iL*(light.lightColor*light.lightAmbDiffSpec.y)*DiffuseMaterialColor.rgb*max(0.0,dot(surfaceNormal,light.L));

}

mediump vec3 computeSpecularComponent(in mediump vec3 surfaceNormal,in mediump vec4 surfacePosition){

   mediump vec3 viewVector=normalize(-surfacePosition.xyz);

   mediump vec3 reflectionVector=2.0*dot(light.L,surfaceNormal)*surfaceNormal-light.L;
   
   return (dot(surfaceNormal,light.L)<=0.0)?vec3(0.0,0.0,0.0):(light.iL*(light.lightColor*light.lightAmbDiffSpec.z)*SpecularMaterialColor.rgb*pow(max(0.0,dot(reflectionVector,viewVector)),Shininess));

}

const highp vec2 madd=vec2(0.5,0.5);

lowp float kShadowAmount = 0.4;

highp vec4 scaledShadowCoord;

void main()
{

    if(ShadowCurrentPass==0.0){
    
    gl_FragColor=vec4(gl_FragCoord.z);

    }else{

    mediump vec4 finalColor=vec4(0.0);

    finalColor.a=1.0;

    light.lightPosition=light0Position;

    light.pointLightIntensity=6.0;
   
    light.pointLightAttenuation=vec3(1.0,0.0,0.0);
   
    light.lightAmbDiffSpec=vec3(1.0,0.5,0.5);

    light.lightColor=vec3(1.0,1.0,1.0);
    
    computePointLightValues(positionInViewSpace);
   
    finalColor.rgb+=vec3(computeLitColor(positionInViewSpace,normalInViewSpace));

    mediump vec4 textureColor=texture2D(DiffuseTexture,vVaryingTexCoords.st);
    
    finalColor=vec4(mix(textureColor,finalColor,0.2));

    scaledShadowCoord=shadowCoord;

    scaledShadowCoord.xy=scaledShadowCoord.xy*madd+madd;

    float visibility = ((1.0 - kShadowAmount) + kShadowAmount * shadow2DProjEXT(ShadowMap, scaledShadowCoord));

    gl_FragColor=visibility*finalColor;

    }
}
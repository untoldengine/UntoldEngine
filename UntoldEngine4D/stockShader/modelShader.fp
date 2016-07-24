
#ifdef GL_ES
// define default precision for float, vec, mat.
precision highp float;
#endif


varying mediump vec2 vVaryingTexCoords;
uniform sampler2D DiffuseTexture;

varying mediump vec4 positionInViewSpace;
varying mediump vec3 normalInViewSpace;

uniform vec4 DiffuseMaterialColor;
mediump vec4 AmbientMaterialColor=vec4(0.0,0.0,0.0,1.0);
uniform vec4 SpecularMaterialColor;
uniform float Shininess;
uniform vec4 PointLight;

uniform float HasTexture;

varying mediump vec4 light0Position;

uniform sampler2D ShadowMap;
varying highp vec4 shadowCoord;
uniform float ShadowCurrentPass;

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

float ShadowCalculation(vec4 uShadowCoord){

    float bias = 0.005;

    //use this bias when you have normal and light direction data
    //float bias = max(0.05 * (1.0 - dot(normal, lightDir)), 0.005);

    // perform perspective divide
    vec3 projCoords=uShadowCoord.xyz/uShadowCoord.w;

    // Transform to [0,1] range
    projCoords=projCoords*0.5+0.5;

    // Get closest depth value from light's perspective (using [0,1] range fragPosLight as coords)
    float closestDepth=texture2D(ShadowMap,projCoords.xy).r;

    // Get depth of current fragment from light's perspective
    float currentDepth = projCoords.z;

    // Check whether current frag pos is in shadow
    float shadow = currentDepth-bias > closestDepth  ? 0.5 : 0.0;

    if(projCoords.z > 1.0)
    shadow = 0.0;

    return shadow;

}

void main()
{
    if(ShadowCurrentPass==0.0){


    }else{
        mediump vec4 finalColor=vec4(0.0);

       finalColor.a=1.0;

       light.lightPosition=light0Position;

       light.pointLightIntensity=3.0;
       
       light.pointLightAttenuation=vec3(1.0,0.0,0.0);
       
       light.lightAmbDiffSpec=vec3(1.0,0.5,0.5);

       light.lightColor=vec3(1.0,1.0,1.0);
        
       computePointLightValues(positionInViewSpace);
       
       finalColor.rgb+=vec3(computeLitColor(positionInViewSpace,normalInViewSpace));

       //check if the model has a texture

       if(HasTexture==1.0){
       mediump vec4 textureColor=texture2D(DiffuseTexture,vVaryingTexCoords.st);
        
       finalColor=vec4(mix(textureColor,finalColor,0.2));
       }

       float shadow = ShadowCalculation(shadowCoord);

       gl_FragColor=finalColor*(1.0-shadow);

    }

}
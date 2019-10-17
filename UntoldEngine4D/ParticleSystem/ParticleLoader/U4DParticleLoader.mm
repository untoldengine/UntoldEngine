//
//  U4DParticleLoader.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/1/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DParticleLoader.h"
#include <vector>
#include <string>
#include "Constants.h"


namespace U4DEngine {
    
    U4DParticleLoader::U4DParticleLoader(){
        
    }
    
    U4DParticleLoader::~U4DParticleLoader(){
        
    }
    
    bool U4DParticleLoader::loadParticleAssetFile(std::string uParticleAssetFile){
        
        const char * particleFile = uParticleAssetFile.c_str();
        
        bool loadOk=doc.LoadFile(particleFile);
        
        if (!loadOk) {
            
            std::cout<<"Particle Asset file "<<uParticleAssetFile<<" loaded successfully"<<std::endl;
            
            loadParticleData();
        
            loadOk=true;
            
        }else{
            std::cout<<"Particle Asset file "<<uParticleAssetFile<<"was not found. Loading failed"<<std::endl;
            
            loadOk=false;
        }
        
        return loadOk;
        
    }
    
    void U4DParticleLoader::loadParticleData(){
        
        tinyxml2::XMLElement* particleConfig = doc.FirstChildElement("particleEmitterConfig");
        
        //speed
        tinyxml2::XMLElement* speedElement = particleConfig->FirstChildElement("speed");
        
        const char* particleSpeedAttribute=speedElement->Attribute("value");
        
        particleSystemData.particleSpeed=atof(particleSpeedAttribute);
        
        //speed variance
        tinyxml2::XMLElement* speedVarianceElement = particleConfig->FirstChildElement("speedVariance");
        
        const char* particleSpeedVarianceAttribute=speedVarianceElement->Attribute("value");
        
        particleSystemData.particleSpeedVariance=atof(particleSpeedVarianceAttribute);
        
        //life
        tinyxml2::XMLElement* lifeSpanElement = particleConfig->FirstChildElement("particleLifeSpan");
        
        const char* particleLifeAttribute=lifeSpanElement->Attribute("value");
        
        particleSystemData.particleLife=atof(particleLifeAttribute);
        
        //maximum number of particles
        tinyxml2::XMLElement* maxNumberOfParticlesElement = particleConfig->FirstChildElement("maxParticles");
        
        const char* maxNumberOfParticlesAttribute=maxNumberOfParticlesElement->Attribute("value");
        
        particleSystemData.maxNumberOfParticles=atof(maxNumberOfParticlesAttribute);
        
        //angle
        tinyxml2::XMLElement* angleElement = particleConfig->FirstChildElement("angle");
        
        const char* angleAttribute=angleElement->Attribute("value");
        
        particleSystemData.particleEmitAngle=atof(angleAttribute);
        
        //angle variance
        tinyxml2::XMLElement* angleVarianceElement = particleConfig->FirstChildElement("angleVariance");
        
        const char* angleVarianceAttribute=angleVarianceElement->Attribute("value");
        
        particleSystemData.particleEmitAngleVariance=atof(angleVarianceAttribute);
        
        //start color
        
        tinyxml2::XMLElement* startColorElement = particleConfig->FirstChildElement("startColor");
        
        const char* colorRedAttribute=startColorElement->Attribute("red");
        const char* colorGreenAttribute=startColorElement->Attribute("green");
        const char* colorBlueAttribute=startColorElement->Attribute("blue");
        const char* colorAlphaAttribute=startColorElement->Attribute("alpha");
        
        float startColorRed=atof(colorRedAttribute);
        float startColorGreen=atof(colorGreenAttribute);
        float startColorBlue=atof(colorBlueAttribute);
        float startColorAlpha=atof(colorAlphaAttribute);
        
        particleSystemData.particleStartColor=U4DVector4n(startColorRed,startColorGreen,startColorBlue,startColorAlpha);
        
        //start color variance
        
        tinyxml2::XMLElement* startColorVarianceElement = particleConfig->FirstChildElement("startColorVariance");
        
        colorRedAttribute=startColorVarianceElement->Attribute("red");
        colorGreenAttribute=startColorVarianceElement->Attribute("green");
        colorBlueAttribute=startColorVarianceElement->Attribute("blue");
        colorAlphaAttribute=startColorVarianceElement->Attribute("alpha");
        
        float startColorRedVariance=atof(colorRedAttribute);
        float startColorGreenVariance=atof(colorGreenAttribute);
        float startColorBlueVariance=atof(colorBlueAttribute);
        float startColorAlphaVariance=atof(colorAlphaAttribute);
        
        particleSystemData.particleStartColorVariance=U4DVector4n(startColorRedVariance,startColorGreenVariance,startColorBlueVariance,startColorAlphaVariance);
        
        //end color
        tinyxml2::XMLElement* endColorElement = particleConfig->FirstChildElement("finishColor");
        
        colorRedAttribute=endColorElement->Attribute("red");
        colorGreenAttribute=endColorElement->Attribute("green");
        colorBlueAttribute=endColorElement->Attribute("blue");
        colorAlphaAttribute=endColorElement->Attribute("alpha");
        
        float endColorRed=atof(colorRedAttribute);
        float endColorGreen=atof(colorGreenAttribute);
        float endColorBlue=atof(colorBlueAttribute);
        float endColorAlpha=atof(colorAlphaAttribute);
        
        particleSystemData.particleEndColor=U4DVector4n(endColorRed,endColorGreen,endColorBlue,endColorAlpha);
        
        //end color variance
        tinyxml2::XMLElement* endColorVarianceElement = particleConfig->FirstChildElement("finishColorVariance");
        
        colorRedAttribute=endColorVarianceElement->Attribute("red");
        colorGreenAttribute=endColorVarianceElement->Attribute("green");
        colorBlueAttribute=endColorVarianceElement->Attribute("blue");
        colorAlphaAttribute=endColorVarianceElement->Attribute("alpha");
        
        float endColorRedVariance=atof(colorRedAttribute);
        float endColorGreenVariance=atof(colorGreenAttribute);
        float endColorBlueVariance=atof(colorBlueAttribute);
        float endColorAlphaVariance=atof(colorAlphaAttribute);
        
        particleSystemData.particleEndColorVariance=U4DVector4n(endColorRedVariance,endColorGreenVariance,endColorBlueVariance,endColorAlphaVariance);
        
        //gravity
        tinyxml2::XMLElement* gravityElement = particleConfig->FirstChildElement("gravity");
        const char* gravityXDirectionAttribute=gravityElement->Attribute("x");
        const char* gravityYDirectionAttribute=gravityElement->Attribute("y");
        
        float gravityXValue=atof(gravityXDirectionAttribute);
        float gravityYValue=atof(gravityYDirectionAttribute);
        
        particleSystemData.gravity=U4DVector3n(gravityXValue,gravityYValue,0.0);
        
        //start size
        tinyxml2::XMLElement* particleStartSizeElement = particleConfig->FirstChildElement("startParticleSize");
        
        const char* particleStartSizeAttribute=particleStartSizeElement->Attribute("value");
        
        particleSystemData.startParticleSize=atof(particleStartSizeAttribute);
       
        //start size variance
        tinyxml2::XMLElement* particleStartSizeVarianceElement = particleConfig->FirstChildElement("startParticleSizeVariance");
        
        const char* particleStartSizeVarianceAttribute=particleStartSizeVarianceElement->Attribute("value");
        
        particleSystemData.startParticleSizeVariance=atof(particleStartSizeVarianceAttribute);
        
        //end size
        tinyxml2::XMLElement* particleEndSizeElement = particleConfig->FirstChildElement("finishParticleSize");
        
        const char* particleEndSizeAttribute=particleEndSizeElement->Attribute("value");
        
        particleSystemData.endParticleSize=atof(particleEndSizeAttribute);
        
        //end size variance
        tinyxml2::XMLElement* particleEndSizeVarianceElement = particleConfig->FirstChildElement("finishParticleSizeVariance");
        
        const char* particleEndSizeVarianceAttribute=particleEndSizeVarianceElement->Attribute("value");
        
        particleSystemData.endParticleSizeVariance=atof(particleEndSizeVarianceAttribute);
        
        //position variance
        tinyxml2::XMLElement* particlePosVarianceElement = particleConfig->FirstChildElement("sourcePositionVariance");
        
        const char* particlePosXVarianceAttribute=particlePosVarianceElement->Attribute("x");
        const char* particlePosYVarianceAttribute=particlePosVarianceElement->Attribute("y");
        
        float posXVariance=atof(particlePosXVarianceAttribute);
        float posYVariance=atof(particlePosYVarianceAttribute);
        
        particleSystemData.particlePositionVariance=U4DVector3n(posXVariance,posYVariance,0.0);
        
        //duration
        tinyxml2::XMLElement* emitterDurationRateElement = particleConfig->FirstChildElement("duration");
        
        const char* emitterDurationRateAttribute=emitterDurationRateElement->Attribute("value");
        
        particleSystemData.emitterDurationRate=atof(emitterDurationRateAttribute);
        
        //radial acceleration
        tinyxml2::XMLElement* particleRadialAccelerationElement = particleConfig->FirstChildElement("radialAcceleration");
        
        const char* particleRadialAccelerationAttribute=particleRadialAccelerationElement->Attribute("value");
        
        particleSystemData.particleRadialAcceleration=atof(particleRadialAccelerationAttribute);
        
        //radial acceleration variance
        tinyxml2::XMLElement* particleRadialAccelerationVarianceElement = particleConfig->FirstChildElement("radialAccelVariance");
        
        const char* particleRadialAccelerationVarianceAttribute=particleRadialAccelerationVarianceElement->Attribute("value");
        
        particleSystemData.particleRadialAccelerationVariance=atof(particleRadialAccelerationVarianceAttribute);
        
        //tangent acceleration
        tinyxml2::XMLElement* particleTangentAccelerationElement = particleConfig->FirstChildElement("tangentialAcceleration");
        
        const char* particleTangentAccelerationAttribute=particleTangentAccelerationElement->Attribute("value");
        
        particleSystemData.particleTangentialAcceleration=atof(particleTangentAccelerationAttribute);
        
        //tangent acceleration variance
        tinyxml2::XMLElement* particleTangentAccelerationVarianceElement = particleConfig->FirstChildElement("tangentialAccelVariance");
        
        const char* particleTangentAccelerationVarianceAttribute=particleTangentAccelerationVarianceElement->Attribute("value");
        
        particleSystemData.particleTangentialAccelerationVariance=atof(particleTangentAccelerationVarianceAttribute);
        
        //rotation start
        tinyxml2::XMLElement* particleStartRotationElement = particleConfig->FirstChildElement("rotationStart");
        
        const char* particleStartRotationAttribute=particleStartRotationElement->Attribute("value");
        
        particleSystemData.startParticleRotation=atof(particleStartRotationAttribute);
        
        //rotation start variance
        tinyxml2::XMLElement* particleStartRotationVarianceElement = particleConfig->FirstChildElement("rotationStartVariance");
        
        const char* particleStartRotationVarianceAttribute=particleStartRotationVarianceElement->Attribute("value");
        
        particleSystemData.startParticleRotationVariance=atof(particleStartRotationVarianceAttribute);
        
        //rotation end
        tinyxml2::XMLElement* particleEndRotationElement = particleConfig->FirstChildElement("rotationEnd");
        
        const char* particleEndRotationAttribute=particleEndRotationElement->Attribute("value");
        
        particleSystemData.endParticleRotation=atof(particleEndRotationAttribute);
        
        //rotation start variance
        tinyxml2::XMLElement* particleEndRotationVarianceElement = particleConfig->FirstChildElement("rotationEndVariance");
        
        const char* particleEndRotationVarianceAttribute=particleEndRotationVarianceElement->Attribute("value");
        
        particleSystemData.endParticleRotationVariance=atof(particleEndRotationVarianceAttribute);
        
        //blending source
        tinyxml2::XMLElement* blendingFactorSourceElement = particleConfig->FirstChildElement("blendFuncSource");
        
        const char* blendingFactorSourceAttribute=blendingFactorSourceElement->Attribute("value");
        
        int blendingFactorSource=blendingFactorMapping(atoi(blendingFactorSourceAttribute));
        
        particleSystemData.blendingFactorSource=blendingFactorSource;
        
        //blending dest
        tinyxml2::XMLElement* blendingFactorDestElement = particleConfig->FirstChildElement("blendFuncDestination");
        
        const char* blendingFactorDestAttribute=blendingFactorDestElement->Attribute("value");
        
        int blendingFactorDest=blendingFactorMapping(atoi(blendingFactorDestAttribute));
        
        particleSystemData.blendingFactorDest=blendingFactorDest;
        
        //defaults
        particleSystemData.particleSystemType=LINEAREMITTER;
        particleSystemData.numberOfParticlesPerEmission=1;
        particleSystemData.emissionRate=U4DEngine::particleEmissionRate;
        particleSystemData.emitContinuously=true;
    
    }
    
    int U4DParticleLoader::blendingFactorMapping(int uBlending){
        
        int blendingFactor=0;
        
        switch (uBlending) {
            
            //GL_ZERO=MTLBlendFactorZero
            case 0:
                blendingFactor=0;
                break;
            
            //GL_ONE=MTLBlendFactorOne
            case 1:
                blendingFactor=1;
                break;
            
            //GL_DST_COLOR=MTLBlendFactorDestinationColor
            case 774:
                blendingFactor=6;
                break;
            
            //GL_ONE_MINUS_DST_COLOR=MTLBlendFactorOneMinusDestinationColor
            case 775:
                blendingFactor=7;
                break;
                
            //GL_SRC_ALPHA=MTLBlendFactorSourceAlpha
            case 770:
                blendingFactor=4;
                break;
                
            //GL_ONE_MINUS_SRC_ALPHA=MTLBlendFactorOneMinusSourceAlpha
            case 771:
                blendingFactor=5;
                break;
                
            //GL_DST_ALPHA=MTLBlendFactorDestinationAlpha
            case 772:
                blendingFactor=8;
                break;
                
            //GL_ONE_MINUS_DST_ALPHA=MTLBlendFactorOneMinusDestinationAlpha
            case 773:
                blendingFactor=9;
                break;
                
            //GL_SOURCE_ALPHA_SATURATED=MTLBlendFactorSourceAlphaSaturated
            case 776:
                blendingFactor=10;
                break;
                
            default:
                break;
        }
        
        return blendingFactor;
        
    }
    
}

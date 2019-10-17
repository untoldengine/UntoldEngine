//
//  U4DParticleEmitter.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/23/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DParticleEmitter.h"
#include "U4DTrigonometry.h"
#include "U4DNumerical.h"
#include "U4DParticle.h"
#include "U4DTrigonometry.h"
#include "Constants.h"


namespace U4DEngine {
    
    U4DParticleEmitter::U4DParticleEmitter():emittedNumberOfParticles(0),numberOfParticlesPerEmission(1),emissionRate(1.0),emitContinuously(true),emitterDurationFlag(false),emitterDurationRate(1.0){
        
        // set the emitter rate scheduler
        emitterRateScheduler=new U4DCallback<U4DParticleEmitter>;
        
        emitterRateTimer=new U4DTimer(emitterRateScheduler);
        
        //set the emitter duration scheduler
        emitterDurationScheduler=new U4DCallback<U4DParticleEmitter>;
        
        emitterDurationTimer=new U4DTimer(emitterDurationScheduler);
        
    }
    
    U4DParticleEmitter::~U4DParticleEmitter(){
        
        emitterRateScheduler->unScheduleTimer(emitterRateTimer);
        
        delete emitterRateTimer;
        
        delete emitterRateScheduler;
        
        emitterDurationScheduler->unScheduleTimer(emitterDurationTimer);
        
        delete emitterDurationTimer;
        
        delete emitterDurationScheduler;
        
    }
    
    void U4DParticleEmitter::setParticleSystem(U4DParticleSystem *uParticleSystem){
        
        particleSystem=uParticleSystem;
        
    }
    
    void U4DParticleEmitter::setParticleData(U4DParticleData &uParticleData){
        
        particleData=uParticleData;
    }
    
    void U4DParticleEmitter::setEmitContinuously(bool uValue){
        
        emitContinuously=uValue;
    
    }
    
    void U4DParticleEmitter::play(){
        
        //emitter rate scheduler
        emitterRateScheduler->scheduleClassWithMethodAndDelay(this, &U4DParticleEmitter::emitParticles, emitterRateTimer,emissionRate, emitContinuously);
        
        //emitter duration
        emitterDurationScheduler->scheduleClassWithMethodAndDelay(this, &U4DParticleEmitter::negateEmitterDurationFlag, emitterDurationTimer,emitterDurationRate, true);
        
        emitterDurationFlag=true;
        
    }
    
    void U4DParticleEmitter::stop(){
        
        //reset the number of emitted particles back to zero
        emittedNumberOfParticles=0;
        
        //stop the emitter duration
        emitterDurationFlag=false;
        
        //stop all timers
        emitterRateScheduler->unScheduleTimer(emitterRateTimer);
        
        emitterDurationScheduler->unScheduleTimer(emitterDurationTimer);
        
        
    }
    
    void U4DParticleEmitter::setNumberOfParticlesPerEmission(int uNumberOfParticles){
        
        numberOfParticlesPerEmission=uNumberOfParticles;
        
    }
    
    void U4DParticleEmitter::setParticleEmissionRate(float uEmissionRate){
        
        emissionRate=uEmissionRate;
        
    }
    
    float U4DParticleEmitter::getRandomNumberBetween(float uMinValue, float uMaxValue){
        
        U4DNumerical numerical;
        
        return numerical.getRandomNumberBetween(uMinValue, uMaxValue);
        
    }
    
    void U4DParticleEmitter::computeVariance(U4DVector3n &uVector, U4DVector3n &uVectorVariance){
        
        uVectorVariance.x=uVectorVariance.x*getRandomNumberBetween(-1.0, 1.0);
        uVectorVariance.y=uVectorVariance.y*getRandomNumberBetween(-1.0, 1.0);
        uVectorVariance.z=uVectorVariance.z*getRandomNumberBetween(-1.0, 1.0);
        
        uVector=uVector+uVectorVariance;
        
    }
    
    void U4DParticleEmitter::computeVariance(U4DVector4n &uVector, U4DVector4n &uVectorVariance){
        
        uVectorVariance.x=uVectorVariance.x*getRandomNumberBetween(-1.0, 1.0);
        uVectorVariance.y=uVectorVariance.y*getRandomNumberBetween(-1.0, 1.0);
        uVectorVariance.z=uVectorVariance.z*getRandomNumberBetween(-1.0, 1.0);
        uVectorVariance.w=uVectorVariance.w*getRandomNumberBetween(-1.0, 1.0);
        
        uVector=uVector+uVectorVariance;
        
    }
    
    void U4DParticleEmitter::computeVariance(float &uValue, float &uValueVariance){
        
        uValueVariance=uValueVariance*getRandomNumberBetween(-1.0, 1.0);
       
        uValue=uValue+uValueVariance;
    }
    
    void U4DParticleEmitter::decreaseNumberOfEmittedParticles(){
        
        emittedNumberOfParticles--;
        
    }
    
    int U4DParticleEmitter::getNumberOfEmittedParticles(){
        
        return emittedNumberOfParticles;
        
    }
    
    void U4DParticleEmitter::computePosition(U4DParticle *uParticle){
        
        U4DVector3n vectorVariance;
        
        U4DVector3n positionVariance=particleData.positionVariance/U4DEngine::particlePositionDivider;
        
        vectorVariance.x=positionVariance.x*getRandomNumberBetween(-1.0, 1.0);
        vectorVariance.y=positionVariance.y*getRandomNumberBetween(-1.0, 1.0);
        vectorVariance.z=positionVariance.z*getRandomNumberBetween(-1.0, 1.0);
        
        uParticle->translateBy(vectorVariance);
        
    }
    
    void U4DParticleEmitter::computeColors(U4DParticle *uParticle){
        
        //set start color and end color
        U4DVector4n startColor=particleData.startColor;
        U4DVector4n startColorVariance=particleData.startColorVariance;
        
        
        U4DVector4n endColor=particleData.endColor;
        U4DVector4n endColorVariance=particleData.endColorVariance;
        
        //set starting color
        computeVariance(startColor, startColorVariance);
        
        //set ending color
        computeVariance(endColor, endColorVariance);
        
        U4DVector4n deltaColor;
        
        deltaColor.x=(endColor.x-startColor.x)/particleData.life;
        deltaColor.y=(endColor.y-startColor.y)/particleData.life;
        deltaColor.z=(endColor.z-startColor.z)/particleData.life;
        
        //add information to the particle node
        uParticle->particleData.startColor=startColor;
        uParticle->particleData.endColor=endColor;
        uParticle->particleData.deltaColor=deltaColor;
        uParticle->particleData.color=startColor;
        
    }
    
    void U4DParticleEmitter::computeScale(U4DParticle *uParticle){
        
        //set start scale and end Scale
        float startParticleSize=particleData.startParticleSize;
        float startParticleSizeVariance=particleData.startParticleSizeVariance;
        
        float endParticleSize=particleData.endParticleSize;
        float endParticleSizeVariance=particleData.endParticleSizeVariance;
        
        //set starting scale
        computeVariance(startParticleSize, startParticleSizeVariance);
        
        //set ending scale
        computeVariance(endParticleSize, endParticleSizeVariance);
        
        float deltaParticleSize;
        
        deltaParticleSize=(endParticleSize-startParticleSize)/particleData.life;
        
        //add information to the particle node
        uParticle->particleData.startParticleSize=startParticleSize;
        uParticle->particleData.endParticleSize=endParticleSize;
        uParticle->particleData.deltaParticleSize=deltaParticleSize;
        uParticle->particleData.particleSize=startParticleSize;
        
    }
    
    void U4DParticleEmitter::computeRotation(U4DParticle *uParticle){
        
        //set start rotation and end rotation
        float startParticleRotation=particleData.startParticleRotation;
        float startParticleRotationVariance=particleData.startParticleRotationVariance;
        
        float endParticleRotation=particleData.endParticleRotation;
        float endParticleRotationVariance=particleData.endParticleRotationVariance;
        
        //set starting rotation
        computeVariance(startParticleRotation, startParticleRotationVariance);
        
        //set ending rotation
        computeVariance(endParticleRotation, endParticleRotationVariance);
        
        float deltaParticleRotation;
        
        deltaParticleRotation=(endParticleRotation-startParticleRotation)/particleData.life;
        
        //add information to the particle node
        uParticle->particleData.startParticleRotation=startParticleRotation;
        uParticle->particleData.endParticleRotation=endParticleRotation;
        uParticle->particleData.deltaParticleRotation=deltaParticleRotation;
        uParticle->particleData.particleRotation=startParticleRotation;
        
    }
    
    void U4DParticleEmitter::emitParticles(){
        
        if(emitterDurationFlag){
            
            U4DTrigonometry trig;
            
            int maxNumberOfParticles=particleSystem->getMaxNumberOfParticles();
            
            int allowedNumberOfParticles=maxNumberOfParticles-emittedNumberOfParticles;
            
            allowedNumberOfParticles=std::min(allowedNumberOfParticles, numberOfParticlesPerEmission);
            
            if((emittedNumberOfParticles+allowedNumberOfParticles)<=particleSystem->getMaxNumberOfParticles()){
                
                for (int i=0; i<allowedNumberOfParticles; i++) {
                    
                    U4DParticle *particle=new U4DParticle();
                    
                    //compute position
                    computePosition(particle);
                    
                    //compute colors
                    computeColors(particle);
                    
                    //compute size
                    computeScale(particle);
                    
                    //compute rotation
                    computeRotation(particle);
                    
                    //compute radial acceleration
                    computeRadialAcceleration(particle);
                    
                    //compute tangential acceleration
                    computeTangentialAcceleration(particle);
                    
                    //set gravity
                    particle->setGravity(particleData.gravity);
                    
                    //compute velocity
                    computeVelocity(particle);
                    
                    particle->particleData.life=particleData.life;
                    
                    //add child to scenegraph
                    particleSystem->addChild(particle);
                    
                    emittedNumberOfParticles++;
                    
                }
                
            }
            
        }
        
    }
    
    float U4DParticleEmitter::mix(float x, float y, float a){
        
        return (x*(1-a) + y*a);
    }
    
    void U4DParticleEmitter::negateEmitterDurationFlag(){
        emitterDurationFlag=!emitterDurationFlag;
    }
    
    void U4DParticleEmitter::setEmitterDurationRate(float uEmitterDurationRate){
        emitterDurationRate=uEmitterDurationRate;
    }
    
}

//
//  U4DParticleEmitter.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/23/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DParticleEmitter.h"
#include "U4DTrigonometry.h"
#include "U4DNumerical.h"
#include "U4DParticle.h"
#include "U4DTrigonometry.h"


namespace U4DEngine {
    
    U4DParticleEmitter::U4DParticleEmitter():emittedNumberOfParticles(0),numberOfParticlesPerEmission(1),emissionRate(1.0),emitContinuously(true){
        
    }
    
    U4DParticleEmitter::~U4DParticleEmitter(){
        
        scheduler->unScheduleTimer(timer);
        
        delete timer;
        
        delete scheduler;
        
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
    
    void U4DParticleEmitter::initialize(){
        
        scheduler=new U4DCallback<U4DParticleEmitter>;
        
        timer=new U4DTimer(scheduler);
        
        scheduler->scheduleClassWithMethodAndDelay(this, &U4DParticleEmitter::emitParticles, timer,emissionRate, emitContinuously);
        
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
    
    void U4DParticleEmitter::decreaseNumberOfEmittedParticles(){
        
        emittedNumberOfParticles--;
        
    }
    
    int U4DParticleEmitter::getNumberOfEmittedParticles(){
        
        return emittedNumberOfParticles;
        
    }
    
    void U4DParticleEmitter::computePosition(U4DParticle *uParticle){
        
        U4DVector3n vectorVariance;
        
        vectorVariance.x=particleData.positionVariance.x*getRandomNumberBetween(-1.0, 1.0);
        vectorVariance.y=particleData.positionVariance.y*getRandomNumberBetween(-1.0, 1.0);
        vectorVariance.z=particleData.positionVariance.z*getRandomNumberBetween(-1.0, 1.0);
        
        uParticle->translateBy(vectorVariance);
        
    }
    
    void U4DParticleEmitter::computeColors(U4DParticle *uParticle){
        
        //set start color and end color
        U4DVector3n startColor=particleData.startColor;
        U4DVector3n startColorVariance=particleData.startColorVariance;
        
        
        U4DVector3n endColor=particleData.endColor;
        U4DVector3n endColorVariance=particleData.endColorVariance;
        
        //set starting color
        computeVariance(startColor, startColorVariance);
        
        //set ending color
        computeVariance(endColor, endColorVariance);
        
        U4DVector3n deltaColor;
        
        deltaColor.x=(endColor.x-startColor.x)/particleData.life;
        deltaColor.y=(endColor.y-startColor.y)/particleData.life;
        deltaColor.z=(endColor.z-startColor.z)/particleData.life;
        
        //add information to the particle node
        uParticle->particleData.startColor=startColor;
        uParticle->particleData.endColor=endColor;
        uParticle->particleData.deltaColor=deltaColor;
        uParticle->particleData.color=startColor;
        
    }
    
    void U4DParticleEmitter::emitParticles(){
        
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
                
                //compute velocity
                computeVelocity(particle);
                
                particle->particleData.life=particleData.life;
                
                //add child to scenegraph
                particleSystem->addChild(particle);
                
                emittedNumberOfParticles++;
                
            }
            
        }
        
    }
    
    float U4DParticleEmitter::mix(float x, float y, float a){
        
        return (x*(1-a) + y*a);
    }
    
}

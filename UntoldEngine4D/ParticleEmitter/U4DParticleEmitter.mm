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
    
    U4DParticleEmitter::U4DParticleEmitter():emittedNumberOfParticles(0){
        
    }
    
    U4DParticleEmitter::~U4DParticleEmitter(){
        
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
    
    void U4DParticleEmitter::computePosition(U4DParticle *uParticle, U4DParticleSystem *uParticleSystem, U4DParticleData *uParticleData){
        
        U4DVector3n position=uParticleSystem->getAbsolutePosition();
        
        computeVariance(position, uParticleData->positionVariance);
        
        uParticle->translateTo(position);
        
    }
    
    void U4DParticleEmitter::computeColors(U4DParticle *uParticle, U4DParticleData *uParticleData){
        
        //set start color and end color
        U4DVector3n startColor=uParticleData->startColor;
        U4DVector3n startColorVariance=uParticleData->startColorVariance;
        
        
        U4DVector3n endColor=uParticleData->endColor;
        U4DVector3n endColorVariance=uParticleData->endColorVariance;
        
        //set starting color
        computeVariance(startColor, startColorVariance);
        
        //set ending color
        computeVariance(endColor, endColorVariance);
        
        U4DVector3n deltaColor;
        
        deltaColor.x=(endColor.x-startColor.x)/uParticleData->life;
        deltaColor.y=(endColor.y-startColor.y)/uParticleData->life;
        deltaColor.z=(endColor.z-startColor.z)/uParticleData->life;
        
        //add information to the particle node
        uParticle->particleData.startColor=startColor;
        uParticle->particleData.endColor=endColor;
        uParticle->particleData.deltaColor=deltaColor;
        uParticle->particleData.color=startColor;
        
    }
    
    void U4DParticleEmitter::emitParticles(U4DParticleSystem *uParticleSystem, U4DParticleData *uParticleData){
        
        U4DTrigonometry trig;
        
        if(emittedNumberOfParticles<=uParticleSystem->getMaxNumberOfParticles()){
            
            U4DParticle *particle=new U4DParticle();
            
            //compute position
            computePosition(particle, uParticleSystem ,uParticleData);
            
            //compute colors
            computeColors(particle, uParticleData);
            
            //compute velocity
            computeVelocity(particle, uParticleData);
            
            particle->particleData.life=uParticleData->life;
            
            //add child to scenegraph
            uParticleSystem->addChild(particle);
            
            emittedNumberOfParticles++;
            
        }
        
    }
    
}

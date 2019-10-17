//
//  U4DParticle.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DParticle.h"
#include "Constants.h"
#include "U4DVector3n.h"
#include "U4DDirector.h"
#include "U4DCamera.h"

namespace U4DEngine {
    
    U4DParticle::U4DParticle():mass(1.0),gravity(0.0,-10.0,0.0){
    }
    
    U4DParticle::~U4DParticle(){
    }
    
    void U4DParticle::addForce(U4DVector3n& uForce){
        
        force+=uForce;
    }
    
    void U4DParticle::clearForce(){
        
        force.zero();
    }
    
    U4DVector3n U4DParticle::getForce(){
        
        return force;
        
    }
    
    void U4DParticle::setVelocity(U4DVector3n &uVelocity){
        
        velocity=uVelocity;
    }
    
    U4DVector3n U4DParticle::getVelocity(){
        
        return velocity;
    }
    
    void U4DParticle::initMass(float uMass){
        
        mass=uMass;
        
    }
    
    float U4DParticle::getMass(){
        
        return mass;
    }
    
    U4DVector3n U4DParticle::getGravity(){
        
        return gravity;
        
    }
    
    void U4DParticle::setGravity(U4DVector3n &uGravity){
        gravity=uGravity/U4DEngine::particleSpeedDivider;
    }
    
    void U4DParticle::setParticleRadialAcceleration(float uParticleRadialAcceleration){
        particleRadialAcceleration=uParticleRadialAcceleration;
    }
    
    
    void U4DParticle::setParticleTangentialAcceleration(float uParticleTangentialAcceleration){
        particleTangentialAcceleration=uParticleTangentialAcceleration;
    }
    
    
    float U4DParticle::getParticleRadialAcceleration(){
        return particleRadialAcceleration;
    }
    
    
    float U4DParticle::getParticleTangentialAcceleration(){
        return particleTangentialAcceleration;
    }
    
}


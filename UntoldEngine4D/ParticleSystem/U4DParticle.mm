//
//  U4DParticle.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DParticle.h"

#include "U4DVector3n.h"
#include "U4DDirector.h"

namespace U4DEngine {
    
    U4DParticle::U4DParticle():mass(1.0){
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
    
}


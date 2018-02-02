//
//  U4DParticlePhysics.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/22/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DParticlePhysics.h"
#include "U4DParticle.h"
#include "Constants.h"

namespace U4DEngine {
    
    U4DParticlePhysics::U4DParticlePhysics(){
        
    }
    
    U4DParticlePhysics::~U4DParticlePhysics(){
        
    }
    
    void U4DParticlePhysics::updateForce(U4DParticle *uParticle, U4DVector3n &uGravity, float dt){
        
        U4DVector3n force=uGravity*uParticle->getMass();
        
        uParticle->addForce(force);
        
    }
    
    void U4DParticlePhysics::integrate(U4DParticle *uParticle,float dt){
        
        U4DVector3n velocityNew(0,0,0);
        U4DVector3n displacementNew(0,0,0);
        
        //calculate the acceleration
        U4DVector3n linearAcceleration=(uParticle->getForce())*(1/uParticle->getMass());
        
        //CALCULATE LINEAR POSITION
        evaluateLinearAspect(uParticle,linearAcceleration, dt, velocityNew, displacementNew);
        
        //update old velocity and displacement with the new ones
        
        uParticle->translateTo(displacementNew);
        uParticle->setVelocity(velocityNew);
        
        
    }
    
    void U4DParticlePhysics::evaluateLinearAspect(U4DParticle *uParticle,U4DVector3n &uLinearAcceleration,float dt,U4DVector3n &uVnew,U4DVector3n &uSnew){
        
        U4DVector3n k1,k2,k3,k4;
        
        k1=(uLinearAcceleration)*dt;
        k2=(uLinearAcceleration+k1*0.5)*dt;
        k3=(uLinearAcceleration+k2*0.5)*dt;
        k4=(uLinearAcceleration+k3)*dt;
        
        //calculate new velocity
        uVnew=uParticle->getVelocity()+(k1+k2*2+k3*2+k4)*(U4DEngine::rungaKuttaCorrectionCoefficient/6);
        
        //calculate new position
        uSnew=uParticle->getLocalPosition()+uVnew*dt;
        
    }
    
}

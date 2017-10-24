//
//  U4DParticleEmitterLinear.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/23/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DParticleEmitterLinear.h"
#include "U4DTrigonometry.h"

namespace U4DEngine {
    
    U4DParticleEmitterLinear::U4DParticleEmitterLinear(){
        
    }
    
    U4DParticleEmitterLinear::~U4DParticleEmitterLinear(){
        
    }
    
    void U4DParticleEmitterLinear::computeVelocity(U4DParticle *uParticle, U4DParticleData *uParticleData){
        
        U4DTrigonometry trig;
        
        U4DVector3n emitAngle=uParticleData->emitAngle;
        U4DVector3n emitAngleVariance=uParticleData->emitAngleVariance;
        float speed=uParticleData->speed;
        
        //compute velocity
        
        computeVariance(emitAngle, emitAngleVariance);
        
        U4DVector3n emitAxis(cos(trig.degreesToRad(emitAngle.x)),cos(trig.degreesToRad(emitAngle.y)),cos(trig.degreesToRad(emitAngle.z)));
        
        emitAxis.normalize();
        
        U4DVector3n emitVelocity=emitAxis*speed;
        
        uParticle->setVelocity(emitVelocity);
        
    }
    
}

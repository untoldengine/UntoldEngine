//
//  U4DParticleEmitterLinear.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/23/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DParticleEmitterLinear.h"
#include "U4DTrigonometry.h"
#include "Constants.h"

namespace U4DEngine {
    
    U4DParticleEmitterLinear::U4DParticleEmitterLinear(){
        
    }
    
    U4DParticleEmitterLinear::~U4DParticleEmitterLinear(){
        
    }
    
    void U4DParticleEmitterLinear::computeVelocity(U4DParticle *uParticle){
        
        U4DTrigonometry trig;
        
        float emitAngle=particleData.emitAngle;
        float emitAngleVariance=particleData.emitAngleVariance;
        
        float speed=particleData.speed/U4DEngine::particleSpeedDivider;
        float speedVariance=particleData.speedVariance/U4DEngine::particleSpeedDivider;
        
        //compute emit angle
        computeVariance(emitAngle, emitAngleVariance);
        
        //compute speed
        computeVariance(speed, speedVariance);
        
        U4DVector3n emitAxis(cos(trig.degreesToRad(emitAngle)),sin(trig.degreesToRad(emitAngle)),0.0);
        
        emitAxis.normalize();
        
        U4DVector3n emitVelocity=emitAxis*(speed);
        
        uParticle->setVelocity(emitVelocity);
        
    }
    
    void U4DParticleEmitterLinear::computeRadialAcceleration(U4DParticle *uParticle){
        
        float radialAcceleration=particleData.particleRadialAcceleration/U4DEngine::particleAngularAccelDivider;
        float radialAccelerationVariance=particleData.particleRadialAccelerationVariance/U4DEngine::particleAngularAccelDivider;
        
        computeVariance(radialAcceleration, radialAccelerationVariance);
        
        uParticle->setParticleRadialAcceleration(radialAcceleration);
        
    }
    
    void U4DParticleEmitterLinear::computeTangentialAcceleration(U4DParticle *uParticle){
        
        float tangentAcceleration=particleData.particleTangentialAcceleration/U4DEngine::particleAngularAccelDivider;
        float tangentAccelerationVariance=particleData.particleTangentialAccelerationVariance/U4DEngine::particleAngularAccelDivider;
        
        computeVariance(tangentAcceleration, tangentAccelerationVariance);
        
        uParticle->setParticleTangentialAcceleration(tangentAcceleration);
    }
    
}

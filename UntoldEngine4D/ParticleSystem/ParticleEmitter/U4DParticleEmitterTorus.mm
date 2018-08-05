//
//  U4DParticleEmitterTorus.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/25/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DParticleEmitterTorus.h"

#include "U4DTrigonometry.h"

namespace U4DEngine {
    
    U4DParticleEmitterTorus::U4DParticleEmitterTorus(){
        
    }
    
    U4DParticleEmitterTorus::~U4DParticleEmitterTorus(){
        
    }
    
    void U4DParticleEmitterTorus::computeVelocity(U4DParticle *uParticle){
        
        U4DTrigonometry trig;
        float theta, phi;
        U4DVector3n emitVelocity;
        
        float majorRadius=particleData.torusMajorRadius;
        float minorRadius=particleData.torusMinorRadius;
        
        //Pick the direction of the velocity
        theta=mix(0.0, M_PI, arc4random() / (double)UINT32_MAX);
        phi=mix(0.0,M_PI,arc4random() / (double)UINT32_MAX);
        
        theta=trig.radToDegrees(theta);
        phi=trig.radToDegrees(phi);
        
        emitVelocity.x=(majorRadius+minorRadius*std::cosf(theta))*std::cosf(phi);;
        emitVelocity.y=(majorRadius+minorRadius*std::cosf(theta))*std::sinf(phi);
        emitVelocity.z=minorRadius*std::sinf(theta);
        
        float speed=particleData.speed;
        
        emitVelocity=emitVelocity*speed;
        
        uParticle->setVelocity(emitVelocity);
        
    }
    
}

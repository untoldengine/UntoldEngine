//
//  U4DParticleEmitterSphere.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/25/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DParticleEmitterSphere.h"
#include "U4DTrigonometry.h"

namespace U4DEngine {
    
    U4DParticleEmitterSphere::U4DParticleEmitterSphere(){
        
    }
    
    U4DParticleEmitterSphere::~U4DParticleEmitterSphere(){
        
    }
    
    void U4DParticleEmitterSphere::computeVelocity(U4DParticle *uParticle){
        
        U4DTrigonometry trig;
        float theta, phi;
        U4DVector3n emitVelocity;
        
        float radius=particleData.sphereRadius;
        
        //Pick the direction of the velocity
        theta=mix(0.0, M_PI, arc4random() / (double)UINT32_MAX);
        phi=mix(0.0,M_PI,arc4random() / (double)UINT32_MAX);
        
        theta=trig.radToDegrees(theta);
        phi=trig.radToDegrees(phi);
        
        emitVelocity.x=radius*std::cosf(phi)*std::sinf(theta);;
        emitVelocity.y=radius*std::sinf(phi)*std::sinf(theta);
        emitVelocity.z=radius*std::cosf(theta);
        
        float speed=particleData.speed;
        
        emitVelocity=emitVelocity*speed;
        
        uParticle->setVelocity(emitVelocity);
        
    }
    
}

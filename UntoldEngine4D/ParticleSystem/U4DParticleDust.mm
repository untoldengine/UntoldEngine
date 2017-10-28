//
//  U4DParticleDust.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/11/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DParticleDust.h"

#include "Constants.h"
#include "U4DTrigonometry.h"
#include <stdlib.h>

namespace U4DEngine {
    
    U4DParticleDust::U4DParticleDust(){
        
        scheduler=new U4DEngine::U4DCallback<U4DParticleDust>;
        
        animationTimer=new U4DEngine::U4DTimer(scheduler);
        
    }
    
    U4DParticleDust::~U4DParticleDust(){
        
    }
    
    void U4DParticleDust::createParticles(float uMajorRadius, float uMinorRadius, int uParticleNumber, float uAnimationDelay, const char *uTexture){
        
        //set number of particles
        setNumberOfParticles(uParticleNumber);
        
        //set particle vertices
        setParticlesVertices();
        
        //create particle properties
        
        //set particles initial velocities
        float theta, phi;
        
        U4DVector3n v;
        
        U4DTrigonometry trig;
        
        for(int i=0;i<getNumberOfParticles();i++){
            
            //Pick the direction of the velocity
            theta=mix(0.0, M_PI, arc4random() / (double)UINT32_MAX);
            phi=mix(0.0,M_PI,arc4random() / (double)UINT32_MAX);
            
            theta=trig.radToDegrees(theta);
            phi=trig.radToDegrees(phi);
            
            v.x=(uMajorRadius+uMinorRadius*std::cosf(theta))*std::cosf(phi);;
            v.y=(uMajorRadius+uMinorRadius*std::cosf(theta))*std::sinf(phi);
            v.z=uMinorRadius*std::sinf(theta);
            
            particleData.velocityContainer.push_back(v);
            
        }
        
        //set initial start time
        float time=0.0;
        float rate=0.00075;
        
        for (unsigned int i=0; i<getNumberOfParticles(); i++) {
            
            particleData.startTimeContainer.push_back(time);
            
            time+=rate;
            
        }
        
        //load texture if it exists
        if(uTexture!=nullptr){
            renderManager->setDiffuseTexture(uTexture);
        }
        
        //load rendering information
        loadRenderingInformation();
        
        //start the timer
        scheduler->scheduleClassWithMethodAndDelay(this, &U4DParticleDust::updateParticleAnimationTime, animationTimer, uAnimationDelay,true);
        
    }
    
    void U4DParticleDust::updateParticleAnimationTime(){
        
        particleAnimationElapsedTime+=1.0;
    
    }
    
    float U4DParticleDust::mix(float x, float y, float a){
        
        return (x*(1-a) + y*a);
    }
    
}

//
//  U4DParticleDust.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DParticleDust.h"
#include "U4DOpenGLParticleDust.h"
#include "Constants.h"
#include "U4DTrigonometry.h"
#include <stdlib.h>

namespace U4DEngine {
    
    U4DParticleDust::U4DParticleDust(){
        
        openGlManager=new U4DOpenGLParticleDust(this);
        
        openGlManager->setShader("particleDustShader");
        
        scheduler=new U4DEngine::U4DCallback<U4DParticleDust>;
        
        animationElapseTimer=new U4DEngine::U4DTimer(scheduler);
        
    }
    
    U4DParticleDust::~U4DParticleDust(){
        
    }
    
    void U4DParticleDust::createParticles(float uMajorRadius, float uMinorRadius, int uParticleNumber, float uAnimationElapseTime){
        
        //set number of particles
        setNumberOfParticles(uParticleNumber);
        
        //set animation time
        setAnimationElapseTime(uAnimationElapseTime);
        
        //set particle vertices
        setParticlesVertices();
        
        //create particle properties
        
        //set particles initial velocities
        float theta, phi;
        
        U4DVector3n v;
        
        U4DTrigonometry trig;
        
        for(int i=0;i<getNumberOfParticles();i++){
            
            //Pick the direction of the velocity
            theta=mix(0.0, PI, (std::rand()%10)/10.0);
            phi=mix(0.0,PI,(std::rand()%10)/10.0);
            
            theta=trig.radToDegrees(theta);
            phi=trig.radToDegrees(phi);
            
            v.x=(uMajorRadius+uMinorRadius*std::cosf(theta))*std::cosf(phi);;
            v.y=(uMajorRadius+uMinorRadius*std::cosf(theta))*std::sinf(phi);
            v.z=uMinorRadius*std::sinf(theta);
            
            particleCoordinates.velocityContainer.push_back(v);
            
        }
        
        //set initial start time
        float time=0.0;
        float rate=0.00075;
        
        for (unsigned int i=0; i<getNumberOfParticles(); i++) {
            
            particleCoordinates.startTimeContainer.push_back(time);
            
            time+=rate;
            
        }
        
        //load rendering information
        loadRenderingInformation();
        
        //set custom uniforms
        std::vector<float> data{animationElapseTime};
        
        addCustomUniform("Time", data);
        
        //start the timer
        scheduler->scheduleClassWithMethodAndDelay(this, &U4DParticleDust::animationTimer, animationElapseTimer, uAnimationElapseTime,true);
        
    }
    
    void U4DParticleDust::animationTimer(){
        
        animationElapseTime+=1.0;
        
        std::vector<float> data{animationElapseTime};
        
        openGlManager->updateCustomUniforms("Time", data);
        
    }
    
}

//
//  Agent.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/23/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "Agent.h"
#include "UserCommonProtocols.h"
#include "U4DNumerical.h"
#include "U4DSeek.h"
#include "U4DSeparation.h"
#include "U4DAlign.h"
#include "U4DCohesion.h"
#include "U4DFlock.h"

Agent::Agent(){
    
}

Agent::~Agent(){
    
}

bool Agent::init(const char* uModelName){
    
    if(loadModel(uModelName)){
        
        //enable shadow
        setEnableShadow(true);
        
        //set the default state
        setState(idle);
        
        animationManager=new U4DEngine::U4DAnimationManager();
        
        //create anim object
        walkAnimation=new U4DEngine::U4DAnimation(this);
        
        //load animation
        if(loadAnimationToModel(walkAnimation, "running")){
            
        }
        
        //create shoot animaiton
//        shootAnimation=new U4DEngine::U4DAnimation(this);
//
//        if (loadAnimationToModel(shootAnimation, "aiming")) {
//            shootAnimation->setPlayContinuousLoop(false);
//        }
        
        //enable the physics engine
        enableKineticsBehavior();
        
        //set gravity to zero
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        setGravity(zero);
        
        //set default view
        
        U4DEngine::U4DVector3n viewDirectionVector(0.0,0.0,-1.0);
        setEntityForwardVector(viewDirectionVector);
        
        //set mass
        initMass(1.0);
        
        //send data to GPU
        loadRenderingInformation();
        
        
        return true;
    }
    
    return false;
    
}

void Agent::update(double dt){
    
    if (state==walking) {
        
        //apply a force
        applyForce(3.0, dt);
        
    }else if(state==seeking){
        
        //seek
        U4DEngine::U4DSeek seekBehavior;
        
        U4DEngine::U4DVector3n desiredVelocity=seekBehavior.getSteering(this, targetPosition);
        
        applyVelocity(desiredVelocity, dt);
        
        setViewDirection(desiredVelocity);
        
    }else if(state==separation){
        
        U4DEngine::U4DSeparation separationBehavior;
        
        std::vector<U4DDynamicModel*> tempNeighbors;
        for(const auto &n:neighbors){
            tempNeighbors.push_back(n);
        }
        U4DEngine::U4DVector3n desiredVelocity=separationBehavior.getSteering(this, tempNeighbors);

        if(!(desiredVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
            desiredVelocity.y=0.0;
            applyVelocity(desiredVelocity, dt);
            setViewDirection(desiredVelocity);
        }
        
    }else if(state==align){
        
        U4DEngine::U4DAlign alignBehavior;
        
        std::vector<U4DDynamicModel*> tempNeighbors;
        for(const auto &n:neighbors){
            tempNeighbors.push_back(n);
        }
        
        U4DEngine::U4DVector3n desiredVelocity=alignBehavior.getSteering(this, tempNeighbors);

        if(!(desiredVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
            desiredVelocity.y=0.0;
            applyVelocity(desiredVelocity, dt);
            setViewDirection(desiredVelocity);
        }
    
        
        
    }else if(state==cohesion){
        
        U4DEngine::U4DCohesion cohesionBehavior; 
        
        std::vector<U4DDynamicModel*> tempNeighbors;
        for(const auto &n:neighbors){
            tempNeighbors.push_back(n);
        }
        
        U4DEngine::U4DVector3n desiredVelocity=cohesionBehavior.getSteering(this, tempNeighbors);

        if(!(desiredVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
            desiredVelocity.y=0.0;
            applyVelocity(desiredVelocity, dt);
            setViewDirection(desiredVelocity);
        }
    
        
        
    }else if(state==flocking){
        
        U4DEngine::U4DFlock flockBehavior;

        std::vector<U4DDynamicModel*> tempNeighbors;
        for(const auto &n:neighbors){
            tempNeighbors.push_back(n);
        }

        
        U4DEngine::U4DVector3n desiredVelocity=flockBehavior.getSteering(this, tempNeighbors);

        if(!(desiredVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
        
            desiredVelocity.y=0.0;
            applyVelocity(desiredVelocity, dt);
            setViewDirection(desiredVelocity);
        }
        
    }else if (state==idle){

        //remove velocities

        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);

        setVelocity(zero);
        setAngularVelocity(zero);

    }
    
}

void Agent::setTargetPosition(U4DEngine::U4DVector3n &uTargetPosition){
    
    targetPosition=uTargetPosition;
    
}

void Agent::setState(int uState){
    
    state=uState;
    
}

int Agent::getState(){
    
    return state;
}

void Agent::changeState(int uState){
    
    //set state
    setState(uState);
    
    animationManager->stopAnimation();
    
    U4DEngine::U4DAnimation *currentAnimation=nullptr;
    
    switch (uState) {
            
        case idle:
            
            //stop animation
            
            break;
            
        case walking:
            
            //play animation
            currentAnimation=walkAnimation;
            
            break;
            
        case align:
        
        //play animation
        currentAnimation=walkAnimation;
        
        break;
            
        case flocking:
        
        //play animation
        currentAnimation=walkAnimation;
        
        break;
            
            
        case shooting:
            
            currentAnimation=shootAnimation;
            
            break;
            
        default:
            break;
    }
    
    if (currentAnimation!=nullptr) {
        animationManager->setAnimationToPlay(currentAnimation);
        animationManager->playAnimation();
    }
    
}


void Agent::applyForce(float uFinalVelocity, double dt){
    
    //force=m*(vf-vi)/dt
    
    //get the force direction
    forceDirection.normalize();
    
    //get mass
    float mass=getMass();
    
    //calculate force
    U4DEngine::U4DVector3n force=(forceDirection*uFinalVelocity*mass)/dt;
    
    //apply force to the character
    addForce(force);
    
    //set inital velocity to zero
    
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    setVelocity(zero);
    
}


void Agent::setForceDirection(U4DEngine::U4DVector3n &uForceDirection){
    
    forceDirection=uForceDirection;
    
}


void Agent::applyVelocity(U4DEngine::U4DVector3n &uFinalVelocity, double dt){
    
    //force=m*(vf-vi)/dt
    
    //get mass
    float mass=getMass();
    
    //calculate force
    U4DEngine::U4DVector3n force=(uFinalVelocity*mass)/dt;
    
    //apply force to the character
    addForce(force);
    
    //set inital velocity to zero
    
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    setVelocity(zero);

}

void Agent::setViewDirection(U4DEngine::U4DVector3n &uViewDirection){
    
    U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
    
    //smooth out the motion of the camera by using a Recency Weighted Average.
    //The RWA keeps an average of the last few values, with more recent values being more
    //significant. The bias parameter controls how much significance is given to previous values.
    //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
    //A bias of 1 ignores the new value altogether.
    float biasMotionAccumulator=0.9;
    //uViewDirection.normalize();
    motionAccumulator=motionAccumulator*biasMotionAccumulator+uViewDirection*(1.0-biasMotionAccumulator);
    
    motionAccumulator.normalize();
    
    U4DEngine::U4DVector3n viewDir=getEntityForwardVector();
    
    U4DEngine::U4DMatrix3n m=getAbsoluteMatrixOrientation();
    
    //transform up vector
    upVector=m*upVector;
    
    U4DEngine::U4DVector3n posDir=viewDir.cross(upVector);
    
    float angle=motionAccumulator.angle(viewDir);
    
    if(motionAccumulator.dot(posDir)>0.0){
        angle*=-1.0;
        
    }
    
    U4DEngine::U4DQuaternion q(angle,upVector);
    
    rotateTo(q);
    
}

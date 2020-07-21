//
//  Ball.cpp
//  Dribblr
//
//  Created by Harold Serrano on 5/31/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "Ball.h"

Ball* Ball::instance=0;

Ball::Ball():kickVelocity(0.0){
    
}

Ball::~Ball(){
    
}

Ball* Ball::sharedInstance(){
    
    if (instance==0) {
        
        instance=new Ball();
        
    }
    
    return instance;
}

//init method. It loads all the rendering information among other things.
bool Ball::init(const char* uModelName){
    
    if (loadModel(uModelName)) {
        
        //set enable shadows
        setEnableShadow(true);
        
        setNormalMapTexture("Ball_Normal_Map.png");
        
        //enable kinetic behavior
        enableKineticsBehavior();
        
        //set gravity to zero
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
        setGravity(zero);
        
        //enable collision detection
        enableCollisionBehavior();
        
        //send info to the GPU
        loadRenderingInformation();
        
        return true;
        
    }
    
    return false;
    
}

void Ball::update(double dt){
    
    setAwake(true);
    
    //check if collision is happening
    
    if(state==rolling){
        
        applyRoll(2.0,dt);

    }else if (state==stopped){

        //remove all velocities from the character
        U4DEngine::U4DVector3n zero(0.0,0.0,0.0);

        setVelocity(zero);
        setAngularVelocity(zero);

    }
    
    if (getModelHasCollided()) {
        applyForce(kickVelocity, dt);
        changeState(rolling);
    }
    
}


void Ball::setForceDirection(U4DEngine::U4DVector3n &uForceDirection){
    
    forceDirection=uForceDirection;
    
}

void Ball::applyForce(float uFinalVelocity, double dt){
    
    //force =m*(vf-vi)/dt
    
    //get the force direction and normalize
    forceDirection.normalize();
    
    //get mass
    float mass=getMass();
    
    //calculate force
    U4DEngine::U4DVector3n force=(forceDirection*uFinalVelocity*mass)/dt;
    
    //apply force to the character
    addForce(force);
    
    //set initial velocity to zero
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    setVelocity(zero);
    setAngularVelocity(zero);
    
}

void Ball::setKickVelocity(float uKickVelocity){
    
    kickVelocity=uKickVelocity;
}

void Ball::applyRoll(float uFinalVelocity, double dt){
    
    //get the force direction and normalize
    forceDirection.normalize();
    
    //get mass
    float mass=getMass();
    
    //calculate force
    U4DEngine::U4DVector3n force=(forceDirection*uFinalVelocity*mass)/dt;
    
    //apply moment to ball
    U4DEngine::U4DVector3n upAxis(0.0,getModelDimensions().z/2.0,0.0);
    
    U4DEngine::U4DVector3n groundPassMoment=upAxis.cross(force);
    
    addMoment(groundPassMoment);
    
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    
    setAngularVelocity(zero);
    
}

void Ball::setState(int uState){
    state=uState;
}

int Ball::getState(){
    return state;
}

int Ball::getPreviousState(){
    return previousState;
}

void Ball::changeState(int uState){
    
    previousState=state;
    
    //set new state
    setState(uState);
    
    
    switch (uState) {
         
        case stopped:
            //nothing happens
            
            break;
        
        
        case rolling:
            
            
            break;
        
            
        default:
            break;
    }
}

//void Ball::applyVelocity(U4DEngine::U4DVector3n &uFinalVelocity, double dt){
//
//    //force=m*(vf-vi)/dt
//
//    //get mass
//    float mass=getMass();
//
//    //calculate force
//    U4DEngine::U4DVector3n force=(uFinalVelocity*mass)/dt;
//
//    //apply force
//    addForce(force);
//
//    //set initial velocity to zero
//    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
//    setVelocity(zero);
//
//}
//
//void Ball::setViewDirection(U4DEngine::U4DVector3n &uViewDirection){
//
//    //declare an up vector
//    U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
//
//    float biasMotionAccumulator=0.9;
//
//    motionAccumulator=motionAccumulator*biasMotionAccumulator+uViewDirection*(1.0-biasMotionAccumulator);
//
//    motionAccumulator.normalize();
//
//    U4DEngine::U4DVector3n viewDir=getEntityForwardVector();
//
//    U4DEngine::U4DMatrix3n m=getAbsoluteMatrixOrientation();
//
//    //transform the upvector
//    upVector=m*upVector;
//
//    U4DEngine::U4DVector3n posDir=viewDir.cross(upVector);
//
//    float angle=motionAccumulator.angle(viewDir);
//
//    if(motionAccumulator.dot(posDir)>0.0){
//
//        angle*=-1.0;
//
//    }
//
//    U4DEngine::U4DQuaternion q(angle,upVector);
//
//    rotateTo(q);
//
//}

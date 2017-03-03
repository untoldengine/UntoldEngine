//
//  SoccerBall.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerBall.h"
#include "U4DNumerical.h"
#include "SoccerBallStateManager.h"
#include "SoccerBallStateInterface.h"
#include "SoccerBallGroundState.h"
#include "SoccerBallAirState.h"

SoccerBall::SoccerBall(){
 
    stateManager=new SoccerBallStateManager(this);
}

SoccerBall::~SoccerBall(){
    
    delete stateManager;
    
}

void SoccerBall::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        initInertiaTensorType(U4DEngine::sphericalInertia);
        initCoefficientOfRestitution(0.7);
        initMass(5.0);
        
        //initialize everything else here
        enableCollisionBehavior();
        enableKineticsBehavior();
        
        ballRadius=getModelDimensions().z/2.0;
        
        setCollisionFilterCategory(kSoccerBall);
        setCollisionFilterMask(kSoccerField|kSoccerPostSensor|kSoccerGoalSensor);
        setCollisionFilterGroupIndex(kNegativeGroupIndex);
        
        U4DEngine::U4DVector2n dragCoefficients(0.25,0.05);
        setDragCoefficient(dragCoefficients);
        
        stateManager->safeChangeState(SoccerBallGroundState::sharedInstance());
        translateBy(-10.0, 0.0, 0.0);
        loadRenderingInformation();
        
    }
    
}

void SoccerBall::update(double dt){
    
    stateManager->update(dt);
    
}

void SoccerBall::changeState(SoccerBallStateInterface* uState){
    
    stateManager->safeChangeState(uState);
}

bool SoccerBall::isBallWithinRange(){
 
    float epsilonValue=1.0e-1f;
    
    U4DEngine::U4DNumerical compareValues;
    
    return compareValues.areEqual(ballRadius, getAbsolutePosition().y, epsilonValue);
    
}

void SoccerBall::moveBallWithinRange(double dt){
    
    float offset=ballRadius-getAbsolutePosition().y;
    
    translateBy(0.0,offset*dt, 0.0);
    
}


void SoccerBall::setKickDirection(U4DEngine::U4DVector3n &uDirection){
    
    kickDirection=uDirection;
}

float SoccerBall::getBallRadius(){
    return ballRadius;
}

void SoccerBall::kickBallToAir(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt){
    
    stateManager->changeState(SoccerBallAirState::sharedInstance());
    
    uDirection.normalize();
    
    uDirection.y=0.5;
    
    //awake the ball
    setAwake(true);
    
    //apply force to ball
    
    U4DEngine::U4DVector3n forceToBall=(uDirection*uVelocity*getMass())/dt;
    
    addForce(forceToBall);
    
    //apply moment to ball
    U4DEngine::U4DVector3n upAxis(0.0,1.0,0.0);
    
    U4DEngine::U4DVector3n groundPassMoment=upAxis.cross(forceToBall);
    
    addMoment(groundPassMoment);
    
    //zero out the velocities
    U4DEngine::U4DVector3n initialVelocity(0.0,0.0,0.0);
    
    setVelocity(initialVelocity);
    setAngularVelocity(initialVelocity);
    
}

void SoccerBall::kickBallToGround(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt){
    
    stateManager->changeState(SoccerBallGroundState::sharedInstance());
    
    uDirection.normalize();
    
    //awake the ball
    setAwake(true);
    
    //turn off gravity
    U4DEngine::U4DVector3n gravityForce(0,0,0);
    setGravity(gravityForce);
    
    //apply force to ball
    
    U4DEngine::U4DVector3n forceToBall=(uDirection*uVelocity*getMass())/dt;
    
    addForce(forceToBall);
    
    //apply moment to ball
    U4DEngine::U4DVector3n upAxis(0.0,1.0,0.0);
    
    U4DEngine::U4DVector3n groundPassMoment=upAxis.cross(forceToBall);
    
    addMoment(groundPassMoment);
    
    //zero out the velocities
    U4DEngine::U4DVector3n initialVelocity(0.0,0.0,0.0);
    
    setVelocity(initialVelocity);
    setAngularVelocity(initialVelocity);
}

void SoccerBall::removeKineticForces(){
    
    clearForce();
    clearMoment();
    
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    setVelocity(zero);
    setAngularVelocity(zero);
    
}

void SoccerBall::removeAllVelocities(){
    
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    
    setVelocity(zero);
    setAngularVelocity(zero);
}

void SoccerBall::decelerate(float uScale, double dt){
    
    //awake the ball
    setAwake(true);
    
    U4DEngine::U4DVector3n ballVelocity=getVelocity();
    
    ballVelocity*=uScale;
    
    U4DEngine::U4DVector3n forceToBall=(ballVelocity*getMass())/dt;
    
    addForce(forceToBall);
    
    //apply moment to ball
    U4DEngine::U4DVector3n upAxis(0.0,1.0,0.0);
    
    U4DEngine::U4DVector3n groundPassMoment=upAxis.cross(forceToBall);
    
    addMoment(groundPassMoment);
    
    //zero out the velocities
    U4DEngine::U4DVector3n initialVelocity(0.0,0.0,0.0);

    setVelocity(initialVelocity);
    setAngularVelocity(initialVelocity);
    
}


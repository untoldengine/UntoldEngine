//
//  U11Ball.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11Ball.h"
#include "U4DNumerical.h"
#include "U11BallStateManager.h"
#include "U11BallStateInterface.h"
#include "U11BallGroundState.h"
#include "U11BallAirState.h"

U11Ball::U11Ball(){
 
    stateManager=new U11BallStateManager(this);
}

U11Ball::~U11Ball(){
    
    delete stateManager;
    
}

void U11Ball::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //setEntityType(U4DEngine::MODELNOSHADOWS);
        initInertiaTensorType(U4DEngine::sphericalInertia);
        initCoefficientOfRestitution(0.7);
        initMass(5.0);
        
        //initialize everything else here
        enableCollisionBehavior();
        enableKineticsBehavior();
        
        //setNormalMapTexture("Ball_Normal_Map.png");
        
        ballRadius=getModelDimensions().z/2.0;
        
        setCollisionFilterCategory(kU11Ball);
        setCollisionFilterMask(kU11Field|kSoccerPostSensor|kSoccerGoalSensor|kU11PlayerExtremity);
        setCollisionFilterGroupIndex(kNegativeGroupIndex);
        
        U4DEngine::U4DVector2n dragCoefficients(0.25,0.05);
        setDragCoefficient(dragCoefficients);
        
        loadRenderingInformation();
        
        stateManager->safeChangeState(U11BallGroundState::sharedInstance());

    }
    
}

void U11Ball::update(double dt){
    
    stateManager->update(dt);
    
}

void U11Ball::changeState(U11BallStateInterface* uState){
    
    stateManager->safeChangeState(uState);
}

bool U11Ball::isBallWithinRange(){
 
    float epsilonValue=1.0e-1f;
    
    U4DEngine::U4DNumerical compareValues;
    
    return compareValues.areEqual(ballRadius, getAbsolutePosition().y, epsilonValue);
    
}

void U11Ball::moveBallWithinRange(double dt){
    
    float offset=ballRadius-getAbsolutePosition().y;
    
    translateBy(0.0,offset*dt, 0.0);
    
}


void U11Ball::setKickDirection(U4DEngine::U4DVector3n &uDirection){
    
    kickDirection=uDirection;
}

float U11Ball::getBallRadius(){
    return ballRadius;
}

void U11Ball::kickBallToAir(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt){
    
    stateManager->changeState(U11BallAirState::sharedInstance());
    
    uDirection.normalize();
    
    uDirection.y=0.5;
    
    //awake the ball
    setAwake(true);
    
    //apply force to ball
    
    U4DEngine::U4DVector3n forceToBall=(uDirection*uVelocity*getMass())/dt;
    
    addForce(forceToBall);
    
    //apply moment to ball
    U4DEngine::U4DVector3n upAxis(0.0,1.0,0.0);
    
    U4DEngine::U4DVector3n groundPassMoment=forceToBall.cross(upAxis);
    
    addMoment(groundPassMoment);
    
    //zero out the velocities
    U4DEngine::U4DVector3n initialVelocity(0.0,0.0,0.0);
    
    setVelocity(initialVelocity);
    setAngularVelocity(initialVelocity);
    
}

void U11Ball::kickBallToGround(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt){
    
    //stateManager->changeState(U11BallGroundState::sharedInstance());
    
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
    
    U4DEngine::U4DVector3n groundPassMoment=forceToBall.cross(upAxis);
    
    addMoment(groundPassMoment);
    
    //zero out the velocities
    U4DEngine::U4DVector3n initialVelocity(0.0,0.0,0.0);
    
    setVelocity(initialVelocity);
    setAngularVelocity(initialVelocity);
}

void U11Ball::removeKineticForces(){
    
    clearForce();
    clearMoment();
    
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    setVelocity(zero);
    setAngularVelocity(zero);
    
}

void U11Ball::removeAllVelocities(){
    
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    
    setVelocity(zero);
    setAngularVelocity(zero);
}

void U11Ball::decelerate(float uScale, double dt){
    
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


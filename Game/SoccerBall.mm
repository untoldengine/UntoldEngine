//
//  SoccerBall.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerBall.h"
#include "U4DNumerical.h"

void SoccerBall::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        initInertiaTensorType(U4DEngine::sphericalInertia);
        initCoefficientOfRestitution(0.9);
        initMass(1.0);
        
        //initialize everything else here
        enableCollisionBehavior();
        enableKineticsBehavior();
        
    
        setState(kNull);
        
        ballRadius=getModelDimensions().z/2.0;
        
        setCollisionFilterCategory(kSoccerBall);
        setCollisionFilterMask(kSoccerField|kSoccerPostSensor|kSoccerGoalSensor);
        setCollisionFilterGroupIndex(kNegativeGroupIndex);
        
        //turn off gravity
        U4DEngine::U4DVector3n gravityForce(0,0,0);
        setGravity(gravityForce);
        
        U4DEngine::U4DVector2n dragCoefficients(0.25,0.05);
        setDragCoefficient(dragCoefficients);
        
        
        loadRenderingInformation();
        
    }
    
    
}

void SoccerBall::update(double dt){
    
    setEquilibrium(true);
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    
    moveBallWithinRange(dt);
  /*
    if (getState()==kStabilize) {
        
        if (isBallWithinRange()) {
            
            changeState(kStopped);
            
        }else{
            
            moveBallWithinRange(dt);
            
        }
        
    }
    
    //check if the ball is sleeping
    if (getAwake()==false && getState()==kNull) {
        
        //set collision with ground not to occur
        setCollisionFilterGroupIndex(kNegativeGroupIndex);
        
        //turn off all forces
        clearForce();
        clearMoment();
        
        changeState(kStabilize);
    }
    
    if (getState()==kGoal) {
        
        changeState(kNull);
    }
    
    if (getState()==kBallHitGround) {
        
        //Turn on drag
        U4DEngine::U4DVector2n drag(5.0,5.0);
        setDragCoefficient(drag);
        
        changeState(kNull);
        
    }
    
    if (getState()==kBallHitPostSensor){
        
        //reset drag
        
        resetDragCoefficient();
        
        changeState(kNull);
        
    }
    
    if (getState()==kGroundPass){
        
        //zero out the velocities
        setAngularVelocity(zero);
        setVelocity(zero);
        
        //move ball to proper position
        float offset=ballRadius-getAbsolutePosition().y;
        
        translateBy(0.0,offset, 0.0);
        
        //set kick force
        float forceMagnitude=4000.0;
        
        U4DEngine::U4DVector3n forceDirection=kickDirection*forceMagnitude;
   
        //awake the ball
        setAwake(true);
        
        //set collision with field not to occur
        setCollisionFilterGroupIndex(kNegativeGroupIndex);
        
        //turn off drag
        U4DEngine::U4DVector2n drag(0.1,0.2);
        setDragCoefficient(drag);
        
        //turn off gravity
        U4DEngine::U4DVector3n gravityForce(0,0,0);
        setGravity(gravityForce);
        
        //apply force to ball
        
        U4DEngine::U4DVector3n groundPassForce(forceDirection.x,0.0,-forceDirection.y);
        
        addForce(groundPassForce);
        
        //apply moment to ball
        U4DEngine::U4DVector3n upAxis(0.0,1.0,0.0);
        
        U4DEngine::U4DVector3n groundPassMoment=upAxis.cross(groundPassForce);
        
        addMoment(groundPassMoment);
        
        changeState(kNull);
        
    }else if (getState()==kAirPass){
        
        //zero out the velocities
        setAngularVelocity(zero);
        setVelocity(zero);
        
        //set kick force
        float forceMagnitude=8000.0;
        
        U4DEngine::U4DVector3n forceDirection=kickDirection*forceMagnitude;
        
        //awake the ball
        setAwake(true);
        
        //set collision with the ground to occur
        setCollisionFilterGroupIndex(kZeroGroupIndex);
        
        //turn on gravity
        resetGravity();
        
        //turn off drag
        U4DEngine::U4DVector2n drag(0.1,0.2);
        setDragCoefficient(drag);
        
        //apply force to ball
        
        U4DEngine::U4DVector3n airPassForce(forceDirection.x,forceMagnitude/1.5,-forceDirection.y);
        
        addForce(airPassForce);
        
        //apply moment to ball
        U4DEngine::U4DVector3n upAxis(0.0,1.0,0.0);
        
        U4DEngine::U4DVector3n airPassMoment=upAxis.cross(airPassForce);
        
        addMoment(airPassMoment);
        
        changeState(kNull);
        
    }else if (getState()==kStopped){
        
        changeState(kNull);
    
    }
    
*/
    
}

void SoccerBall::changeState(GameEntityState uState){
    
    setState(uState);
    
    switch (uState) {
            
            
        default:
            
            break;
    }
    
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

void SoccerBall::setState(GameEntityState uState){
    entityState=uState;
}

GameEntityState SoccerBall::getState(){
    return entityState;
}

void SoccerBall::setKickDirection(U4DEngine::U4DVector3n &uDirection){
    
    kickDirection=uDirection;
}

float SoccerBall::getBallRadius(){
    return ballRadius;
}

void SoccerBall::kickBallToGround(float uVelocity, U4DEngine::U4DVector3n uDirection, double dt){
    
    uDirection.normalize();
    
    //move ball to proper position
    float offset=ballRadius-getAbsolutePosition().y;
    
    translateBy(0.0,offset, 0.0);
    
    //awake the ball
    setAwake(true);
    
    //set collision with field not to occur
    setCollisionFilterGroupIndex(kNegativeGroupIndex);
    
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


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
        
        loadRenderingInformation();
    }
    
    
}

void SoccerBall::update(double dt){
    
    float forceMagnitude=6000.0;
    
    U4DEngine::U4DVector3n forceDirection=joyStickData*forceMagnitude;
    
    setEquilibrium(true);
    
    if (getState()==kStabilize) {
        
        if (isBallWithinRange()) {
            
            changeState(kStopped);
            
        }else{
            
            moveBallWithinRange(dt);
            
        }
        
    }
    
    //check if the ball is sleeping
    if (getAwake()==false && getState()==kNull) {
        
        //turn on filter with ground
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
        
        //awake the ball
        setAwake(true);
        
        //turn on the collision filter with the ground
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
        
        //awake the ball
        setAwake(true);
        
        //turn off the collisin filter with the ground
        setCollisionFilterGroupIndex(kZeroGroupIndex);
        
        //turn on gravity
        resetGravity();
        
        //turn off drag
        U4DEngine::U4DVector2n drag(0.1,0.2);
        setDragCoefficient(drag);
        
        //apply force to ball
        
        U4DEngine::U4DVector3n airPassForce(forceDirection.x,forceMagnitude,-forceDirection.y);
        
        addForce(airPassForce);
        
        //apply moment to ball
        U4DEngine::U4DVector3n upAxis(0.0,1.0,0.0);
        
        U4DEngine::U4DVector3n airPassMoment=upAxis.cross(airPassForce);
        
        addMoment(airPassMoment);
        
        changeState(kNull);
        
    }else if (getState()==kStopped){
        
        changeState(kNull);
    
    }
    

    
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

void SoccerBall::setJoystickData(U4DEngine::U4DVector3n& uData){
    
    joyStickData=uData;
}

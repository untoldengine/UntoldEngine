//
//  U11BallRollingState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11BallRollingState.h"
#include "U11Ball.h"

U11BallRollingState* U11BallRollingState::instance=0;

U11BallRollingState::U11BallRollingState(){
    
}

U11BallRollingState::~U11BallRollingState(){
    
}

U11BallRollingState* U11BallRollingState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11BallRollingState();
    }
    
    return instance;
    
}

void U11BallRollingState::enter(U11Ball *uBall){
    
    //set collision with field not to occur
    uBall->setCollisionFilterGroupIndex(kNegativeGroupIndex);
    
    //turn off gravity
    U4DEngine::U4DVector3n gravityForce(0,0,0);
    uBall->setGravity(gravityForce);
    
    //reset drag
    U4DEngine::U4DVector2n dragCoefficients(0.5,0.05);
    uBall->setDragCoefficient(dragCoefficients);
    
}

void U11BallRollingState::execute(U11Ball *uBall, double dt){
    
    U4DEngine::U4DVector3n forceToBall=(uBall->getVelocity()*uBall->getMass())/dt;
    
    forceToBall=forceToBall-forceToBall*0.99;
    
     //apply moment to ball
    U4DEngine::U4DVector3n contactAxis(0.0,1.0,0.0);
    
    contactAxis*=uBall->getBallRadius();
    
    U4DEngine::U4DVector3n groundPassMoment=contactAxis.cross(forceToBall);
    
    uBall->addMoment(groundPassMoment);

    
    //keep the ball above the field
    if (!uBall->isBallWithinRange()) {
        
        uBall->moveBallWithinRange(dt);
        
    }
    
}

void U11BallRollingState::exit(U11Ball *uBall){
    
}

bool U11BallRollingState::isSafeToChangeState(U11Ball *uBall){
    
    return true;
}

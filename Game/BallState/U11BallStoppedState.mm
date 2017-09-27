//
//  U11BallStoppedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11BallStoppedState.h"

U11BallStoppedState* U11BallStoppedState::instance=0;

U11BallStoppedState::U11BallStoppedState(){
    
}

U11BallStoppedState::~U11BallStoppedState(){
    
}

U11BallStoppedState* U11BallStoppedState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11BallStoppedState();
    }
    
    return instance;
    
}

void U11BallStoppedState::enter(U11Ball *uBall){
    
    uBall->removeKineticForces();
    uBall->removeAllVelocities();
    
    //set collision with field not to occur
    uBall->setCollisionFilterGroupIndex(kNegativeGroupIndex);
    
    //turn off gravity
    U4DEngine::U4DVector3n gravityForce(0,0,0);
    uBall->setGravity(gravityForce);
}

void U11BallStoppedState::execute(U11Ball *uBall, double dt){
    
    
}

void U11BallStoppedState::exit(U11Ball *uBall){
    
    uBall->setEntityType(U4DEngine::MODELNOSHADOWS);
}

bool U11BallStoppedState::isSafeToChangeState(U11Ball *uBall){
    
    return true;
}

//
//  U11BallAirState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11BallAirState.h"

U11BallAirState* U11BallAirState::instance=0;

U11BallAirState::U11BallAirState(){
    
}

U11BallAirState::~U11BallAirState(){
    
}

U11BallAirState* U11BallAirState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11BallAirState();
    }
    
    return instance;
    
}

void U11BallAirState::enter(U11Ball *uBall){
    
    //set collision with the ground to occur
    uBall->setCollisionFilterGroupIndex(kZeroGroupIndex);
    
    //turn on gravity
    uBall->resetGravity();
    
    uBall->setAwake(true);
    
    uBall->setEntityType(U4DEngine::MODEL);
}

void U11BallAirState::execute(U11Ball *uBall, double dt){
    
   
}

void U11BallAirState::exit(U11Ball *uBall){
 
    uBall->setEntityType(U4DEngine::MODELNOSHADOWS);
}

bool U11BallAirState::isSafeToChangeState(U11Ball *uBall){
    
    return true;
}

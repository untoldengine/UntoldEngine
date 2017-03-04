//
//  U11BallBounceState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/2/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11BallBounceState.h"
#include "U11Ball.h"

U11BallBounceState* U11BallBounceState::instance=0;

U11BallBounceState::U11BallBounceState(){
    
}

U11BallBounceState::~U11BallBounceState(){
    
}

U11BallBounceState* U11BallBounceState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11BallBounceState();
    }
    
    return instance;
    
}

void U11BallBounceState::enter(U11Ball *uBall){
    
    U4DEngine::U4DVector2n dragCoefficients(2.0,2.0);
    uBall->setDragCoefficient(dragCoefficients);
    
}

void U11BallBounceState::execute(U11Ball *uBall, double dt){
    
    
}

void U11BallBounceState::exit(U11Ball *uBall){
    
}

bool U11BallBounceState::isSafeToChangeState(U11Ball *uBall){
    
    return true;
}

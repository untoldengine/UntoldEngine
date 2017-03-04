//
//  U11BallGroundState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11BallGroundState.h"
#include "U11Ball.h"

U11BallGroundState* U11BallGroundState::instance=0;

U11BallGroundState::U11BallGroundState(){
    
}

U11BallGroundState::~U11BallGroundState(){
    
}

U11BallGroundState* U11BallGroundState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11BallGroundState();
    }
    
    return instance;
    
}

void U11BallGroundState::enter(U11Ball *uBall){
    
    //set collision with field not to occur
    uBall->setCollisionFilterGroupIndex(kNegativeGroupIndex);
    
    //turn off gravity
    U4DEngine::U4DVector3n gravityForce(0,0,0);
    uBall->setGravity(gravityForce);
    
    //reset drag
    U4DEngine::U4DVector2n dragCoefficients(0.25,0.05);
    uBall->setDragCoefficient(dragCoefficients);
    
}

void U11BallGroundState::execute(U11Ball *uBall, double dt){
    
    //keep the ball above the field
    if (!uBall->isBallWithinRange()) {
        
        uBall->moveBallWithinRange(dt);
        
    }
    
}

void U11BallGroundState::exit(U11Ball *uBall){
    
}

bool U11BallGroundState::isSafeToChangeState(U11Ball *uBall){
    
    return true;
}

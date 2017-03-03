//
//  SoccerBallGroundState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerBallGroundState.h"
#include "SoccerBall.h"

SoccerBallGroundState* SoccerBallGroundState::instance=0;

SoccerBallGroundState::SoccerBallGroundState(){
    
}

SoccerBallGroundState::~SoccerBallGroundState(){
    
}

SoccerBallGroundState* SoccerBallGroundState::sharedInstance(){
    
    if (instance==0) {
        instance=new SoccerBallGroundState();
    }
    
    return instance;
    
}

void SoccerBallGroundState::enter(SoccerBall *uBall){
    
    //set collision with field not to occur
    uBall->setCollisionFilterGroupIndex(kNegativeGroupIndex);
    
    //turn off gravity
    U4DEngine::U4DVector3n gravityForce(0,0,0);
    uBall->setGravity(gravityForce);
    
    //reset drag
    U4DEngine::U4DVector2n dragCoefficients(0.25,0.05);
    uBall->setDragCoefficient(dragCoefficients);
    
}

void SoccerBallGroundState::execute(SoccerBall *uBall, double dt){
    
    //keep the ball above the field
    if (!uBall->isBallWithinRange()) {
        
        uBall->moveBallWithinRange(dt);
        
    }
    
}

void SoccerBallGroundState::exit(SoccerBall *uBall){
    
}

bool SoccerBallGroundState::isSafeToChangeState(SoccerBall *uBall){
    
    return true;
}

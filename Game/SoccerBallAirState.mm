//
//  SoccerBallAirState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerBallAirState.h"

SoccerBallAirState* SoccerBallAirState::instance=0;

SoccerBallAirState::SoccerBallAirState(){
    
}

SoccerBallAirState::~SoccerBallAirState(){
    
}

SoccerBallAirState* SoccerBallAirState::sharedInstance(){
    
    if (instance==0) {
        instance=new SoccerBallAirState();
    }
    
    return instance;
    
}

void SoccerBallAirState::enter(SoccerBall *uBall){
    
    //set collision with the ground to occur
    uBall->setCollisionFilterGroupIndex(kZeroGroupIndex);
    
    //turn on gravity
    uBall->resetGravity();
    
    uBall->setAwake(true);
}

void SoccerBallAirState::execute(SoccerBall *uBall, double dt){
    
   
}

void SoccerBallAirState::exit(SoccerBall *uBall){
    
}

bool SoccerBallAirState::isSafeToChangeState(SoccerBall *uBall){
    
    return true;
}

//
//  SoccerPlayerReceiveBallState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/2/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerReceiveBallState.h"
#include "SoccerPlayerTakeBallControlState.h"

SoccerPlayerReceiveBallState* SoccerPlayerReceiveBallState::instance=0;

SoccerPlayerReceiveBallState::SoccerPlayerReceiveBallState(){
    
}

SoccerPlayerReceiveBallState::~SoccerPlayerReceiveBallState(){
    
}

SoccerPlayerReceiveBallState* SoccerPlayerReceiveBallState::sharedInstance(){
    
    if (instance==0) {
        instance=new SoccerPlayerReceiveBallState();
    }
    
    return instance;
    
}

void SoccerPlayerReceiveBallState::enter(SoccerPlayer *uPlayer){
    
   
}

void SoccerPlayerReceiveBallState::execute(SoccerPlayer *uPlayer, double dt){
    
    
}

void SoccerPlayerReceiveBallState::exit(SoccerPlayer *uPlayer){
    
}

bool SoccerPlayerReceiveBallState::isSafeToChangeState(SoccerPlayer *uPlayer){
    
    return true;
}

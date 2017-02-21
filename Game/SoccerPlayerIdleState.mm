//
//  SoccerPlayerIdleState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/18/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerIdleState.h"

SoccerPlayerIdleState* SoccerPlayerIdleState::instance=0;

SoccerPlayerIdleState::SoccerPlayerIdleState(){
    
}

SoccerPlayerIdleState::~SoccerPlayerIdleState(){
    
}

SoccerPlayerIdleState* SoccerPlayerIdleState::sharedInstance(){
    
    if (instance==0) {
        instance=new SoccerPlayerIdleState();
    }
    
    return instance;
    
}

void SoccerPlayerIdleState::enter(SoccerPlayer *uPlayer){
    
    //set the standing animation
    uPlayer->setNextAnimationToPlay(uPlayer->getIdleAnimation());
}

void SoccerPlayerIdleState::execute(SoccerPlayer *uPlayer, double dt){
    
    //track the ball
    uPlayer->trackBall();
    
}

void SoccerPlayerIdleState::exit(SoccerPlayer *uPlayer){
    
}

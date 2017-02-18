//
//  SoccerPlayerChaseBallState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerChaseBallState.h"
#include "SoccerPlayerDribbleState.h"

SoccerPlayerChaseBallState* SoccerPlayerChaseBallState::instance=0;

SoccerPlayerChaseBallState::SoccerPlayerChaseBallState(){
    
}

SoccerPlayerChaseBallState::~SoccerPlayerChaseBallState(){
    
}

SoccerPlayerChaseBallState* SoccerPlayerChaseBallState::sharedInstance(){
    
    if (instance==0) {
        instance=new SoccerPlayerChaseBallState();
    }
    
    return instance;
}

void SoccerPlayerChaseBallState::enter(SoccerPlayer *uPlayer){
 
    //set run animation
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    
}

void SoccerPlayerChaseBallState::execute(SoccerPlayer *uPlayer, double dt){
    
    //track the ball
    uPlayer->trackBall();
    
    //has the player reached the ball
    if (!uPlayer->hasReachedTheBall()) {
        
        //chase the ball
        uPlayer->applyForceToPlayer(10.0, dt);
        
    }else{
        
        SoccerPlayerStateInterface *dribbleState=SoccerPlayerDribbleState::sharedInstance();
        
        uPlayer->changeState(dribbleState);
        
        
    }
}

void SoccerPlayerChaseBallState::exit(SoccerPlayer *uPlayer){
    
}

//
//  SoccerPlayerChaseBallState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerChaseBallState.h"
#include "SoccerPlayerTakeBallControlState.h"
#include "UserCommonProtocols.h"

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
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);
}

void SoccerPlayerChaseBallState::execute(SoccerPlayer *uPlayer, double dt){
    
    //track the ball
    uPlayer->trackBall();
    
    
    //has the player reached the ball
    if (!uPlayer->hasReachedTheBall()) {
        
        //chase the ball
        uPlayer->applyForceToPlayer(chasingSpeed, dt);
        
        
    }else{
        
        uPlayer->removeKineticForces();
        
        SoccerPlayerStateInterface *takeBallControlState=SoccerPlayerTakeBallControlState::sharedInstance();
        
        uPlayer->changeState(takeBallControlState);
        
        
    }
     
}

void SoccerPlayerChaseBallState::exit(SoccerPlayer *uPlayer){
    
}

bool SoccerPlayerChaseBallState::isSafeToChangeState(SoccerPlayer *uPlayer){
    return true;
}

//
//  SoccerPlayerForwardKickState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/22/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerForwardKickState.h"
#include "SoccerPlayerChaseBallState.h"
#include "SoccerPlayerIdleState.h"

SoccerPlayerForwardKickState* SoccerPlayerForwardKickState::instance=0;

SoccerPlayerForwardKickState::SoccerPlayerForwardKickState(){
    
}

SoccerPlayerForwardKickState::~SoccerPlayerForwardKickState(){
    
}

SoccerPlayerForwardKickState* SoccerPlayerForwardKickState::sharedInstance(){
    
    if (instance==0) {
        instance=new SoccerPlayerForwardKickState();
    }
    
    return instance;
    
}

void SoccerPlayerForwardKickState::enter(SoccerPlayer *uPlayer){
    
    //set the forward kick animation
    
    if (uPlayer->isBallOnRightSidePlane()) {
        
        uPlayer->setNextAnimationToPlay(uPlayer->getRightFootForwardKickAnimation());
        
    }else{
        
        uPlayer->setNextAnimationToPlay(uPlayer->getLeftFootForwardKickAnimation());
        
    }
    uPlayer->setPlayNextAnimationContinuously(false);
    uPlayer->setPlayBlendedAnimation(true);
}

void SoccerPlayerForwardKickState::execute(SoccerPlayer *uPlayer, double dt){
    
    //track the ball
    if(uPlayer->getRightFootCollidedWithBall() || uPlayer->getLeftFootCollidedWithBall()){
        
        U4DEngine::U4DVector3n direction=uPlayer->getPlayerHeading();
        
        uPlayer->kickBallToGround(70.0, direction,dt);
        
        uPlayer->removeKineticForces();
        
        SoccerPlayerIdleState *idleState=SoccerPlayerIdleState::sharedInstance();
        
        uPlayer->changeState(idleState);
    }
    
    uPlayer->trackBall();
    
}

void SoccerPlayerForwardKickState::exit(SoccerPlayer *uPlayer){
    
}

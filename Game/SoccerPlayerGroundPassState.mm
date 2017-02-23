//
//  SoccerPlayerGroundPassState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerGroundPassState.h"
#include "SoccerPlayerChaseBallState.h"
#include "SoccerPlayerIdleState.h"

SoccerPlayerGroundPassState* SoccerPlayerGroundPassState::instance=0;

SoccerPlayerGroundPassState::SoccerPlayerGroundPassState(){
    
}

SoccerPlayerGroundPassState::~SoccerPlayerGroundPassState(){
    
}

SoccerPlayerGroundPassState* SoccerPlayerGroundPassState::sharedInstance(){
    
    if (instance==0) {
        instance=new SoccerPlayerGroundPassState();
    }
    
    return instance;
    
}

void SoccerPlayerGroundPassState::enter(SoccerPlayer *uPlayer){
    
    //set the ground pass animation
    
    if (uPlayer->isBallOnRightSidePlane()) {
        
        uPlayer->setNextAnimationToPlay(uPlayer->getRightFootSidePassAnimation());
        
    }else{
        
        uPlayer->setNextAnimationToPlay(uPlayer->getLeftFootSidePassAnimation());
        
    }
    uPlayer->setPlayNextAnimationContinuously(false);
    uPlayer->setPlayBlendedAnimation(true);
    
}

void SoccerPlayerGroundPassState::execute(SoccerPlayer *uPlayer, double dt){
    
    if(uPlayer->getRightFootCollidedWithBall() || uPlayer->getLeftFootCollidedWithBall()){
        
        U4DEngine::U4DVector3n direction=uPlayer->getPlayerHeading();
        
        uPlayer->kickBallToGround(50.0, direction,dt);
        
        uPlayer->removeKineticForces();
        
        SoccerPlayerIdleState *idleState=SoccerPlayerIdleState::sharedInstance();
        
        uPlayer->changeState(idleState);
    }

    uPlayer->trackBall();
    
}

void SoccerPlayerGroundPassState::exit(SoccerPlayer *uPlayer){
    
}

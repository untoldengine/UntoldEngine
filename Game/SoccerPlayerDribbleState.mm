//
//  SoccerPlayerDribbleState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerDribbleState.h"
#include "SoccerPlayerChaseBallState.h"

SoccerPlayerDribbleState* SoccerPlayerDribbleState::instance=0;

SoccerPlayerDribbleState::SoccerPlayerDribbleState(){
    
}

SoccerPlayerDribbleState::~SoccerPlayerDribbleState(){
    
}

SoccerPlayerDribbleState* SoccerPlayerDribbleState::sharedInstance(){
    
    if (instance==0) {
        instance=new SoccerPlayerDribbleState();
    }
    
    return instance;
    
}

void SoccerPlayerDribbleState::enter(SoccerPlayer *uPlayer){
    
    //set dribble animation
    uPlayer->setNextAnimationToPlay(uPlayer->getForwardCarryAnimation());
    uPlayer->setPlayNextAnimationContinuously(false);
    uPlayer->setPlayBlendedAnimation(true);
    
}

void SoccerPlayerDribbleState::execute(SoccerPlayer *uPlayer, double dt){
    
    if (uPlayer->getIsAnimationUpdatingKeyframe()) {
        
        //set the kick pass at this keyframe and interpolation time
        if (uPlayer->getAnimationCurrentKeyframe()==3 && uPlayer->getAnimationCurrentInterpolationTime()==0) {
            
            uPlayer->kickBallToGround(4000.0, uPlayer->getViewInDirection());
            
            SoccerPlayerStateInterface *chaseBallState=SoccerPlayerChaseBallState::sharedInstance();
            
            uPlayer->changeState(chaseBallState);
        }
    }
    
}

void SoccerPlayerDribbleState::exit(SoccerPlayer *uPlayer){
    
}

//
//  SoccerPlayerTakeBallControlState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerTakeBallControlState.h"
#include "SoccerPlayerDribbleState.h"
#include "SoccerBall.h"

SoccerPlayerTakeBallControlState* SoccerPlayerTakeBallControlState::instance=0;

SoccerPlayerTakeBallControlState::SoccerPlayerTakeBallControlState(){
    
}

SoccerPlayerTakeBallControlState::~SoccerPlayerTakeBallControlState(){
    
}

SoccerPlayerTakeBallControlState* SoccerPlayerTakeBallControlState::sharedInstance(){
    
    if (instance==0) {
        instance=new SoccerPlayerTakeBallControlState();
    }
    
    return instance;
    
}

void SoccerPlayerTakeBallControlState::enter(SoccerPlayer *uPlayer){
    
    //set the control ball animation
    uPlayer->setNextAnimationToPlay(uPlayer->getTakingBallControlAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(false);
}

void SoccerPlayerTakeBallControlState::execute(SoccerPlayer *uPlayer, double dt){
    
    if (uPlayer->getIsAnimationUpdatingKeyframe()) {
        
        //set the kick pass at this keyframe and interpolation time
        if (uPlayer->getAnimationCurrentKeyframe()==3 && uPlayer->getAnimationCurrentInterpolationTime()==0) {
            
            //adjust the ball to a good location to start dribbling
            
            U4DEngine::U4DVector3n playerHeading=uPlayer->getPlayerHeading();
            
            playerHeading.normalize();
            
            uPlayer->kickBallToGround(5.0, playerHeading,dt);
            
            
        }
    }
    
    //wait until the ball is this distance away from the player before it can go into dribble state.
    if (uPlayer->distanceToBall()>3.0) {
        
        SoccerPlayerStateInterface *dribbleState=SoccerPlayerDribbleState::sharedInstance();
        
        uPlayer->changeState(dribbleState);
        
    }
    
    
}

void SoccerPlayerTakeBallControlState::exit(SoccerPlayer *uPlayer){
    
}

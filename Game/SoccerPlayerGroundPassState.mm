//
//  SoccerPlayerGroundPassState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerGroundPassState.h"
#include "SoccerPlayerChaseBallState.h"

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
    uPlayer->setNextAnimationToPlay(uPlayer->getGroundPassAnimation());
    uPlayer->setPlayNextAnimationContinuously(false);
    uPlayer->setPlayBlendedAnimation(true);
}

void SoccerPlayerGroundPassState::execute(SoccerPlayer *uPlayer, double dt){
    
    if (uPlayer->getIsAnimationUpdatingKeyframe()) {
        
        //set the kick pass at this keyframe and interpolation time
        if (uPlayer->getAnimationCurrentKeyframe()==3) {
            
            U4DEngine::U4DVector3n direction=uPlayer->getPlayerHeading();
            
            uPlayer->kickBallToGround(300.0, direction,dt);
            
            SoccerPlayerChaseBallState *chaseBallState=SoccerPlayerChaseBallState::sharedInstance();
            
            uPlayer->changeState(chaseBallState);
            
        }
    }

}

void SoccerPlayerGroundPassState::exit(SoccerPlayer *uPlayer){
    
}

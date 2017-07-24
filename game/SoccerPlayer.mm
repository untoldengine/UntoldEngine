//
//  SoccerPlayer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayer.h"

SoccerPlayer::SoccerPlayer(){
    
}

SoccerPlayer::~SoccerPlayer(){
    
}

void SoccerPlayer::init(const char* uModelName, const char* uBlenderFile){
    
    if (loadModel(uModelName, uBlenderFile)) {
        
        setEnableShadow(false);
        /*
        walkingAnimation=new U4DEngine::U4DAnimation(this);
        
        if (loadAnimationToModel(walkingAnimation, "walking", "walkinganimation.u4d")) {
        
            
        }
        */
        
    }
    
    loadRenderingInformation();
}

void SoccerPlayer::update(double dt){
    
}

void SoccerPlayer::playAnimation(){
    
    walkingAnimation->play();
    //walkingAnimation->setPlayContinuousLoop(false);
}

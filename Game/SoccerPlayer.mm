//
//  SoccerPlayer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/30/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayer.h"
#include "UserCommonProtocols.h"

void SoccerPlayer::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        walking=new U4DEngine::U4DAnimation(this);
        loadRenderingInformation();
        
        if (loadAnimationToModel(walking, "ArmatureAction", uBlenderFile)) {

            
            
        }
        
    }
    
    
}

void SoccerPlayer::update(double dt){
    
    
    
}

void SoccerPlayer::changeState(GameEntityState uState){
    
    removeAnimation();
    
    setState(uState);
    
    switch (uState) {
            
        case kWalking:
            
            setAnimation(walking);
            
            break;
            
        case kRunning:
            
            
            break;
            
        case kAirPass:
            
            break;
            
        case kGroundPass:
            
            break;
            
        default:
            
            break;
    }
    
    if (getAnimation()!=NULL) {
        
        playAnimation();
        
    }
    
}

void SoccerPlayer::setState(GameEntityState uState){
    entityState=uState;
}

GameEntityState SoccerPlayer::getState(){
    return entityState;
}

//
//  SoccerPlayer.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/30/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayer.h"

void SoccerPlayer::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        initCoefficientOfRestitution(0.9);
        initMass(100.0);
        enableCollisionBehavior();
        //setBroadPhaseBoundingVolumeVisibility(true);
        //setNarrowPhaseBoundingVolumeVisibility(true);
        loadRenderingInformation();
    }
    
    
}

void SoccerPlayer::update(double dt){
    
    
    
}

void SoccerPlayer::changeState(GameEntityState uState){
    
    setState(uState);
    
    switch (uState) {
            
        case kPass:
            
            
            break;
            
        case kVolley:
            
            break;
            
        case kShoot:
            
            break;
            
        default:
            
            break;
    }
    
}

void SoccerPlayer::setState(GameEntityState uState){
    entityState=uState;
}

GameEntityState SoccerPlayer::getState(){
    return entityState;
}

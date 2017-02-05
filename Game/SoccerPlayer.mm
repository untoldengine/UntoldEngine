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
        
        kick=new U4DEngine::U4DAnimation(this);
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,1);
        
        setEntityForwardVector(viewDirectionVector);
        
        if (loadAnimationToModel(kick, "ArmatureAction", uBlenderFile)) {

            
            
        }
        
        
        loadRenderingInformation();
        
        translateBy(0.0, getModelDimensions().y/2.0, 0.0);
        
    }
    
    
}

void SoccerPlayer::update(double dt){
    
    
    
    if (getState()==kGroundPass) {
        
        if (getIsAnimationUpdatingKeyframe()) {
            
            if (getAnimationCurrentKeyframe()==1 && getAnimationCurrentInterpolationTime()==0) {
                
                soccerBallEntity->changeState(kGroundPass);
                soccerBallEntity->setKickDirection(joyStickData);
                
                
            }
        }
        
    }
    
}

void SoccerPlayer::changeState(GameEntityState uState){
    
    removeAnimation();
    
    setState(uState);
    
    switch (uState) {
            
        case kWalking:
            
            
            
            break;
            
        case kRunning:
            
            
            break;
            
        case kAirPass:
            
            break;
            
        case kGroundPass:
        {
            setAnimation(kick);
            setPlayAnimationContinuously(false);
        }
            
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

void SoccerPlayer::setBallEntity(SoccerBall *uSoccerBall){
    
    soccerBallEntity=uSoccerBall;
}

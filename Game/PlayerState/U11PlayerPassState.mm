//
//  U11PlayerPassState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/26/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerPassState.h"

#include "U11PlayerChaseBallState.h"
#include "U11PlayerRunPassState.h"
#include "U11PlayerTurnPassState.h"

U11PlayerPassState* U11PlayerPassState::instance=0;

U11PlayerPassState::U11PlayerPassState(){
    
}

U11PlayerPassState::~U11PlayerPassState(){
    
}

U11PlayerPassState* U11PlayerPassState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerPassState();
    }
    
    return instance;
    
}

void U11PlayerPassState::enter(U11Player *uPlayer){
    
    uPlayer->setNextAnimationToPlay(uPlayer->getIdleAnimation());
}

void U11PlayerPassState::execute(U11Player *uPlayer, double dt){
    
    U4DEngine::U4DVector3n passDirection=uPlayer->getBallKickDirection();
    U4DEngine::U4DVector3n playerHeading=uPlayer->getPlayerHeading();
    
    playerHeading.y=0.0;
    
    passDirection.normalize();
    playerHeading.normalize();
    
    if (passDirection.dot(playerHeading)>0.90) {
        
        uPlayer->changeState(U11PlayerRunPassState::sharedInstance());
        
    }else{
        
        uPlayer->changeState(U11PlayerTurnPassState::sharedInstance());
        
    }
    
}

void U11PlayerPassState::exit(U11Player *uPlayer){
    
}

bool U11PlayerPassState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerPassState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    
    return false;
}

//
//  U11PlayerRunToSupportState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/20/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerRunToSupportState.h"
#include "U11PlayerDribbleState.h"
#include "U11PlayerSupportState.h"
#include "U11PlayerIdleState.h"
#include "U11PlayerReceiveBallState.h"
#include "U11Team.h"

U11PlayerRunToSupportState* U11PlayerRunToSupportState::instance=0;

U11PlayerRunToSupportState::U11PlayerRunToSupportState(){
    
}

U11PlayerRunToSupportState::~U11PlayerRunToSupportState(){
    
}

U11PlayerRunToSupportState* U11PlayerRunToSupportState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerRunToSupportState();
    }
    
    return instance;
    
}

void U11PlayerRunToSupportState::enter(U11Player *uPlayer){
    
    //set run animation
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);
    
}

void U11PlayerRunToSupportState::execute(U11Player *uPlayer, double dt){
    
    U4DEngine::U4DPoint3n supportPosition=uPlayer->getSupportPosition();
    
    uPlayer->seekPosition(supportPosition);
    
    if (!uPlayer->hasReachedPosition(supportPosition,withinSupportDistance)) {
    
        //make the player run
        uPlayer->applyForceToPlayer(chasingSpeed, dt);
        
    }else{
        
        uPlayer->removeAllVelocities();
        uPlayer->removeKineticForces();
        
        //uPlayer->changeState(U11PlayerIdleState::sharedInstance());
        uPlayer->changeState(U11PlayerSupportState::sharedInstance());
        
    }
    
}

void U11PlayerRunToSupportState::exit(U11Player *uPlayer){
    
}

bool U11PlayerRunToSupportState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerRunToSupportState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        case msgReceiveBall:
            
            //change state to receive ball
            uPlayer->changeState(U11PlayerReceiveBallState::sharedInstance());
            
            break;
            
        case msgPassToMe:
            
            break;
        
            
        default:
            break;
    }
    
    return false;
}
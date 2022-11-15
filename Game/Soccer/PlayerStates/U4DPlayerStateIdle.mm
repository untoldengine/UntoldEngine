//
//  U4DPlayerStateIdle.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/17/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateIdle.h"
#include "U4DGameConfigs.h"
#include "U4DPlayerStateDribbling.h"
#include "U4DPlayerStateIntercept.h"
#include "U4DPlayerStateFree.h"
#include "U4DPlayerStateFlock.h"
#include "U4DPlayerStateMark.h"
#include "U4DPlayerStateGoHome.h"
#include "U4DPlayerStateShooting.h"
#include "U4DPlayerStatePass.h"

namespace U4DEngine {

U4DPlayerStateIdle* U4DPlayerStateIdle::instance=0;

U4DPlayerStateIdle::U4DPlayerStateIdle(){
    name="idle";
}

U4DPlayerStateIdle::~U4DPlayerStateIdle(){
    
}

U4DPlayerStateIdle* U4DPlayerStateIdle::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DPlayerStateIdle();
    }
    
    return instance;
    
}

void U4DPlayerStateIdle::enter(U4DPlayer *uPlayer){ 
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->idleAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
    //remove all velocities from the character
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    
    uPlayer->kineticAction->setVelocity(zero);
    uPlayer->kineticAction->setAngularVelocity(zero);
    uPlayer->kineticAction->clearForce();
    
    
    uPlayer->resetAllFlags();
}

void U4DPlayerStateIdle::execute(U4DPlayer *uPlayer, double dt){
    
    
    if (uPlayer->dribbleBall==true) {
        uPlayer->changeState(U4DPlayerStateDribbling::sharedInstance());
        
    }else if(uPlayer->shootBall==true){
        
        uPlayer->changeState(U4DPlayerStateShooting::sharedInstance());

    }else if(uPlayer->passBall==true){
        uPlayer->changeState(U4DPlayerStatePass::sharedInstance());
    }else if(uPlayer->freeToRun==true){
        uPlayer->changeState(U4DPlayerStateFree::sharedInstance());
    }
}

void U4DPlayerStateIdle::exit(U4DPlayer *uPlayer){
    
}

bool U4DPlayerStateIdle::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStateIdle::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgChaseBall:
        {
            uPlayer->changeState(U4DPlayerStateDribbling::sharedInstance());
        }
            
        break;
        
        case msgInterceptBall:
        {
            uPlayer->changeState(U4DPlayerStateIntercept::sharedInstance());
        }
        break;
            
        case msgSupport:
        {
            uPlayer->changeState(U4DPlayerStateFlock::sharedInstance());
            
        }
            break;
            
        case msgMark:
        {
            uPlayer->changeState(U4DPlayerStateMark::sharedInstance());
        }
            break;
            
        case msgGoHome:
        {
            uPlayer->changeState(U4DPlayerStateGoHome::sharedInstance());
        }
        
        break;
            
        default:
            break;
    }
    
    return false;
    
}

}


//
//  U4DPlayerStateShooting.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/17/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateShooting.h"
#include "U4DPlayerStateIdle.h"
#include "U4DPlayerStateGoHome.h"
#include "U4DGameConfigs.h"
#include "U4DBall.h"

namespace U4DEngine {

U4DPlayerStateShooting* U4DPlayerStateShooting::instance=0;

U4DPlayerStateShooting::U4DPlayerStateShooting(){
    name="shooting";
}

U4DPlayerStateShooting::~U4DPlayerStateShooting(){
    
}

U4DPlayerStateShooting* U4DPlayerStateShooting::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DPlayerStateShooting();
    }
    
    return instance;
    
}

void U4DPlayerStateShooting::enter(U4DPlayer *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->shootingAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
    uPlayer->allowedToKick=true;
}

void U4DPlayerStateShooting::execute(U4DPlayer *uPlayer, double dt){
    
    U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
    
    U4DBall *ball=U4DBall::sharedInstance();
    
    U4DVector3n v=uPlayer->getViewInDirection();
    
    ball->setKickBallParameters(gameConfigs->getParameterForKey("shootingBallSpeed"),v);
        
    
    //if animation has stopped, the switch to idle
    if (uPlayer->shootingAnimation->getAnimationIsPlaying()==false) {
        uPlayer->changeState(uPlayer->getPreviousState());
    }
}

void U4DPlayerStateShooting::exit(U4DPlayer *uPlayer){
    uPlayer->shootBall=false;
    uPlayer->dribbleBall=false;
    uPlayer->haltBall=false;
    
    uPlayer->allowedToKick=false;
}

bool U4DPlayerStateShooting::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStateShooting::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
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



//
//  U4DPlayerStateShooting.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/17/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateShooting.h"
#include "U4DPlayerStateIdle.h"
#include "U4DGameConfigs.h"
#include "U4DFoot.h"

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
    
}

void U4DPlayerStateShooting::execute(U4DPlayer *uPlayer, double dt){
    
    uPlayer->updateFootSpaceWithAnimation(uPlayer->shootingAnimation);
    
    uPlayer->shootBall=false;

    uPlayer->foot->kineticAction->resumeCollisionBehavior();
    
    if (uPlayer->foot->kineticAction->getModelHasCollided()) {

        U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
        uPlayer->foot->setKickBallParameters(gameConfigs->getParameterForKey("shootingBallSpeed"),uPlayer->dribblingDirection);
        uPlayer->changeState(U4DPlayerStateIdle::sharedInstance());
        
    }

    //if animation has stopped, the switch to idle
    if (uPlayer->shootingAnimation->getAnimationIsPlaying()==false) {
        //uPlayer->changeState(U4DPlayerStateIdle::sharedInstance());
    }
}

void U4DPlayerStateShooting::exit(U4DPlayer *uPlayer){
    
}

bool U4DPlayerStateShooting::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStateShooting::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}

}



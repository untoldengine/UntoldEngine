//
//  U4DPlayerStateIdle.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/17/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateIdle.h"
#include "U4DGameConfigs.h"

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
    
}

void U4DPlayerStateIdle::execute(U4DPlayer *uPlayer, double dt){
    
    uPlayer->updateFootSpaceWithAnimation(uPlayer->idleAnimation);
    
}

void U4DPlayerStateIdle::exit(U4DPlayer *uPlayer){
    
}

bool U4DPlayerStateIdle::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}
}


//
//  PlayerStateIdle.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/11/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateIdle.h"
#include "U4DGameConfigs.h"

PlayerStateIdle* PlayerStateIdle::instance=0;

PlayerStateIdle::PlayerStateIdle(){
    name="idle";
}

PlayerStateIdle::~PlayerStateIdle(){
    
}

PlayerStateIdle* PlayerStateIdle::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateIdle();
    }
    
    return instance;
    
}

void PlayerStateIdle::enter(Player *uPlayer){
    
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

void PlayerStateIdle::execute(Player *uPlayer, double dt){
    
    uPlayer->updateFootSpaceWithAnimation(uPlayer->idleAnimation);
    
}

void PlayerStateIdle::exit(Player *uPlayer){
    
}

bool PlayerStateIdle::isSafeToChangeState(Player *uPlayer){
    
    return true;
}



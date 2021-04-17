//
//  PlayerStateDefend.cpp
//  Footballer
//
//  Created by Harold Serrano on 11/5/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateDefend.h"
#include "Foot.h"
#include "PlayerStateIdle.h"
#include "PlayerStateChase.h"
#include "PlayerStateIntercept.h"

PlayerStateDefend* PlayerStateDefend::instance=0;

PlayerStateDefend::PlayerStateDefend(){
    name="defend";
}

PlayerStateDefend::~PlayerStateDefend(){
    
}

PlayerStateDefend* PlayerStateDefend::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateDefend();
    }
    
    return instance;
    
}

void PlayerStateDefend::enter(Player *uPlayer){
    
    
    
}

void PlayerStateDefend::execute(Player *uPlayer, double dt){
    
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    
    
}

void PlayerStateDefend::exit(Player *uPlayer){
    
}

bool PlayerStateDefend::isSafeToChangeState(Player *uPlayer){
    
    return true;
}

bool PlayerStateDefend::handleMessage(Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}

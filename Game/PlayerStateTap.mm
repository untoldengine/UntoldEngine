//
//  PlayerStateTap.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/31/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateTap.h"

#include "Foot.h"
#include "PlayerStateIdle.h"
#include "PlayerStateChase.h"
#include "PlayerStateDribble.h"
#include "PlayerStatePass.h"
#include "PlayerStateHalt.h"
#include "PlayerStateTap.h"

PlayerStateTap* PlayerStateTap::instance=0;

PlayerStateTap::PlayerStateTap(){
    
}

PlayerStateTap::~PlayerStateTap(){
    
}

PlayerStateTap* PlayerStateTap::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateTap();
    }
    
    return instance;
    
}

void PlayerStateTap::enter(Player *uPlayer){
    
    uPlayer->rightFoot->resumeCollisionBehavior();
    
    //play the tap animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    if (currentAnimation!=nullptr) {
        uPlayer->getAnimationManager()->setAnimationToPlay(currentAnimation);
    }
    
}

void PlayerStateTap::execute(Player *uPlayer, double dt){
    
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    uPlayer->rightFoot->setKickBallParameters(15.0,uPlayer->dribblingDirection);
    
    if (currentAnimation->getAnimationIsPlaying()==false || uPlayer->rightFoot->getModelHasCollided()) {
        
        uPlayer->changeState(PlayerStateDribble::sharedInstance());
        
    }
}

void PlayerStateTap::exit(Player *uPlayer){
    
}

bool PlayerStateTap::isSafeToChangeState(Player *uPlayer){
    
    return true;
}

bool PlayerStateTap::handleMessage(Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
            
        default:
            break;
    }
    
    return false;
    
}

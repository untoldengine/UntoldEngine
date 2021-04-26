//
//  PlayerStateShoot.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/30/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateShoot.h"

#include "Foot.h"
#include "PlayerStateIdle.h"
#include "PlayerStateChase.h"
#include "PlayerStateDribble.h"
#include "PlayerStatePass.h"
#include "PlayerStateHalt.h"
#include "PlayerStateTap.h"
#include "PlayerStateGoHome.h"

PlayerStateShoot* PlayerStateShoot::instance=0;

PlayerStateShoot::PlayerStateShoot(){
    name="shoot";
}

PlayerStateShoot::~PlayerStateShoot(){
    
}

PlayerStateShoot* PlayerStateShoot::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateShoot();
    }
    
    return instance;
    
}

void PlayerStateShoot::enter(Player *uPlayer){
    
    //play the pass animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    if (currentAnimation!=nullptr) {
        uPlayer->getAnimationManager()->setAnimationToPlay(currentAnimation);
    }
    
}

void PlayerStateShoot::execute(Player *uPlayer, double dt){
    
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    //apply a force
    uPlayer->shootBall=false;
    
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    //if animation has stopped, the switch to idle
    if (currentAnimation->getAnimationIsPlaying()==true && currentAnimation->getCurrentKeyframe()==1) {
        
        uPlayer->rightFoot->setKickBallParameters(shootBallSpeed,uPlayer->dribblingDirection);
        
        uPlayer->rightFoot->resumeCollisionBehavior();
        
    }
    
    if (currentAnimation->getAnimationIsPlaying()==false) {
        uPlayer->changeState(PlayerStateIdle::sharedInstance());
    }
}

void PlayerStateShoot::exit(Player *uPlayer){
    
    uPlayer->shootBall=false;
}

bool PlayerStateShoot::isSafeToChangeState(Player *uPlayer){
    
    return true;
}

bool PlayerStateShoot::handleMessage(Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgGoHome:
        {
            uPlayer->changeState(PlayerStateGoHome::sharedInstance());
        }
            break;
            
        default:
            break;
    }
    
    return false;
    
}

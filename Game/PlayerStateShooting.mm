//
//  PlayerStateShooting.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/11/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateShooting.h"
#include "PlayerStateIdle.h"
#include "U4DGameConfigs.h"

PlayerStateShooting* PlayerStateShooting::instance=0;

PlayerStateShooting::PlayerStateShooting(){
    name="shooting";
}

PlayerStateShooting::~PlayerStateShooting(){
    
}

PlayerStateShooting* PlayerStateShooting::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateShooting();
    }
    
    return instance;
    
}

void PlayerStateShooting::enter(Player *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->shootingAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
}

void PlayerStateShooting::execute(Player *uPlayer, double dt){
    
    uPlayer->updateFootSpaceWithAnimation(uPlayer->shootingAnimation);
    
    uPlayer->shootBall=false;

    uPlayer->foot->kineticAction->resumeCollisionBehavior();
    
    if (uPlayer->shootingAnimation->getAnimationIsPlaying()==true && uPlayer->foot->kineticAction->getModelHasCollided()) {

        uPlayer->foot->setKickBallParameters(80.0,uPlayer->dribblingDirection);

    }

    //if animation has stopped, the switch to idle
    if (uPlayer->shootingAnimation->getAnimationIsPlaying()==false) {
        uPlayer->changeState(PlayerStateIdle::sharedInstance());
    }
}

void PlayerStateShooting::exit(Player *uPlayer){
    
}

bool PlayerStateShooting::isSafeToChangeState(Player *uPlayer){
    
    return true;
}



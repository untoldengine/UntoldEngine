//
//  PlayerStateStandTackle.cpp
//  Footballer
//
//  Created by Harold Serrano on 11/4/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateStandTackle.h"
#include "Foot.h"
#include "PlayerStateIdle.h"
#include "PlayerStateMark.h"
#include "PlayerStateIntercept.h"
#include "PlayerStateFormation.h"

PlayerStateStandTackle* PlayerStateStandTackle::instance=0;

PlayerStateStandTackle::PlayerStateStandTackle(){
    name="stand tackle";
}

PlayerStateStandTackle::~PlayerStateStandTackle(){
    
}

PlayerStateStandTackle* PlayerStateStandTackle::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateStandTackle();
    }
    
    return instance;
    
}

void PlayerStateStandTackle::enter(Player *uPlayer){
    
    
    
    //play the stand tackle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    if (currentAnimation!=nullptr) {
        uPlayer->getAnimationManager()->setAnimationToPlay(currentAnimation);
    }
    
    //remove all velocities from the character
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    
    uPlayer->setVelocity(zero);
    uPlayer->setAngularVelocity(zero);
    
}

void PlayerStateStandTackle::execute(Player *uPlayer, double dt){
    
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    U4DEngine::U4DVector3n dir=uPlayer->getViewInDirection();
    
    if (currentAnimation->getAnimationIsPlaying()==true && currentAnimation->getCurrentKeyframe()>0) {
        uPlayer->rightFoot->resumeCollisionBehavior();
        uPlayer->rightFoot->setKickBallParameters(slidingTackleKick,dir);
    }
    
    if (currentAnimation->getAnimationIsPlaying()==false) {
        
        uPlayer->changeState(PlayerStateFormation::sharedInstance());
    
    }
    
}

void PlayerStateStandTackle::exit(Player *uPlayer){
    
}

bool PlayerStateStandTackle::isSafeToChangeState(Player *uPlayer){
    
    return true;
}

bool PlayerStateStandTackle::handleMessage(Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}

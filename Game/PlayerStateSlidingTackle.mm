//
//  PlayerStateSlidingTackle.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/11/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateSlidingTackle.h"
#include "Foot.h"
#include "PlayerStateIdle.h"
#include "PlayerStateMark.h"
#include "PlayerStateIntercept.h"
#include "PlayerStateGroupNav.h"
#include "PlayerStateFormation.h"
#include "PlayerStateGoHome.h"

PlayerStateSlidingTackle* PlayerStateSlidingTackle::instance=0;

PlayerStateSlidingTackle::PlayerStateSlidingTackle(){
    name="sliding tackle";
}

PlayerStateSlidingTackle::~PlayerStateSlidingTackle(){
    
}

PlayerStateSlidingTackle* PlayerStateSlidingTackle::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateSlidingTackle();
    }
    
    return instance;
    
}

void PlayerStateSlidingTackle::enter(Player *uPlayer){
    
    
    
    //play the stand tackle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    if (currentAnimation!=nullptr) {
        uPlayer->getAnimationManager()->setAnimationToPlay(currentAnimation);
    }
    
    //remove all velocities from the character
//    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
//
//    uPlayer->setVelocity(zero);
//    uPlayer->setAngularVelocity(zero);
    
    
    
    
}

void PlayerStateSlidingTackle::execute(Player *uPlayer, double dt){
    
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    
    if(!(uPlayer->slidingVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
        
        uPlayer->applyVelocity(uPlayer->slidingVelocity, dt);
        uPlayer->setMoveDirection(uPlayer->slidingVelocity);
        
    }
   
    uPlayer->rightFoot->resumeCollisionBehavior();
    if (currentAnimation->getAnimationIsPlaying()==true) {
        
        uPlayer->rightFoot->setKickBallParameters(slidingTackleKick,uPlayer->slidingVelocity);
    }

    if (currentAnimation->getAnimationIsPlaying()==false) {
        
        uPlayer->changeState(PlayerStateIdle::sharedInstance());

    }
    
}

void PlayerStateSlidingTackle::exit(Player *uPlayer){
    
}

bool PlayerStateSlidingTackle::isSafeToChangeState(Player *uPlayer){
    
    return true;
}

bool PlayerStateSlidingTackle::handleMessage(Player *uPlayer, Message &uMsg){
    
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

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
    
    U4DEngine::U4DVector3n dir=uPlayer->getViewInDirection();
    
    U4DEngine::U4DVector3n ballPosition=uPlayer->getBallPositionOffset();
    
    //change the y-position of the ball to be the same as the player
    ballPosition.y=uPlayer->getAbsolutePosition().y;
    
    //compute the final velocity
    U4DEngine::U4DVector3n finalVelocity=ballPosition-uPlayer->getAbsolutePosition();
    
    
    //set the final y-component to zero
    finalVelocity.y=0.0;
    
    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
        
        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setMoveDirection(finalVelocity);
        
    }
    
    if (currentAnimation->getAnimationIsPlaying()==true && currentAnimation->getCurrentKeyframe()>0) {
        uPlayer->rightFoot->resumeCollisionBehavior();
        uPlayer->rightFoot->setKickBallParameters(slidingTackleKick,dir);
    }

    if (currentAnimation->getAnimationIsPlaying()==false) {

        uPlayer->changeState(PlayerStateFormation::sharedInstance());

    }
    
}

void PlayerStateSlidingTackle::exit(Player *uPlayer){
    
}

bool PlayerStateSlidingTackle::isSafeToChangeState(Player *uPlayer){
    
    return true;
}

bool PlayerStateSlidingTackle::handleMessage(Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}

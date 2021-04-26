//
//  PlayerStateWander.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateWander.h"
#include "PlayerStateChase.h"
#include "PlayerStateDribble.h"
#include "PlayerStateHalt.h"
#include "PlayerStatePass.h"
#include "PlayerStateShoot.h"
#include "PlayerStateTap.h"
#include "PlayerStateIntercept.h"
#include "PlayerStateMark.h"
#include "PlayerStateIdle.h"
#include "PlayerStateFormation.h"
#include "PlayerStateGoHome.h"
#include "U4DDynamicModel.h"
#include "UserCommonProtocols.h"
#include "Team.h"

PlayerStateWander* PlayerStateWander::instance=0;

PlayerStateWander::PlayerStateWander(){
    name="wander";
}

PlayerStateWander::~PlayerStateWander(){
    
}

PlayerStateWander* PlayerStateWander::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateWander();
    }
    
    return instance;
    
}

void PlayerStateWander::enter(Player *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    if (currentAnimation!=nullptr) {
        uPlayer->getAnimationManager()->setAnimationToPlay(currentAnimation);
    }
    
    
    uPlayer->wanderBehavior.setWanderOffset(3.0);
    
    uPlayer->wanderBehavior.setWanderRadius(3.0);
    
    uPlayer->wanderBehavior.setWanderRate(2.0);
    
}

void PlayerStateWander::execute(Player *uPlayer, double dt){
    
    //set the target entity to approach
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    //check the distance between the player and the ball
    U4DEngine::U4DVector3n ballPosition=uPlayer->getBallPositionOffset();
    ballPosition.y=uPlayer->getAbsolutePosition().y;
    
    U4DEngine::U4DVector3n finalVelocity=uPlayer->wanderBehavior.getSteering(uPlayer, ballPosition);
    
    
        
    //set the final y-component to zero
    finalVelocity.y=0.0;
    
    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){

        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setMoveDirection(finalVelocity);

    }
    
}

void PlayerStateWander::exit(Player *uPlayer){
    
}

bool PlayerStateWander::isSafeToChangeState(Player *uPlayer){
    
    return true;
}
 
bool PlayerStateWander::handleMessage(Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgFormation:
        {
            uPlayer->changeState(PlayerStateFormation::sharedInstance()); 
        }
            break;
            
        case msgMark:
        {
            uPlayer->changeState(PlayerStateMark::sharedInstance());
        }
            break;
            
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

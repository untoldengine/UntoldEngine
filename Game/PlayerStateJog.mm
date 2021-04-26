//
//  PlayerStateJog.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/10/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateJog.h"
#include "Team.h"

#include "PlayerStateHalt.h"
#include "PlayerStateGoHome.h"

PlayerStateJog* PlayerStateJog::instance=0;

PlayerStateJog::PlayerStateJog(){
    name="jog";
}

PlayerStateJog::~PlayerStateJog(){
    
}

PlayerStateJog* PlayerStateJog::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateJog();
    }
    
    return instance;
    
}

void PlayerStateJog::enter(Player *uPlayer){
    
    //play the running animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();

    if (currentAnimation!=nullptr) {
        uPlayer->getAnimationManager()->setAnimationToPlay(currentAnimation);
    }

    //set speed
    uPlayer->arriveBehavior.setMaxSpeed(arriveJogMaxSpeed);

    //set the distance to stop
    uPlayer->arriveBehavior.setTargetRadius(arriveJogStopRadius);

    //set the distance to start slowing down
    uPlayer->arriveBehavior.setSlowRadius(arriveJogSlowRadius);


}

void PlayerStateJog::execute(Player *uPlayer, double dt){
    
    //set the target entity to approach
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();

    uPlayer->updateFootSpaceWithAnimation(currentAnimation);

    U4DEngine::U4DVector3n ballPosition=uPlayer->getBallPositionOffset();

    //change the y-position of the ball to be the same as the player
    ballPosition.y=uPlayer->getAbsolutePosition().y;

    //compute the final velocity
    U4DEngine::U4DVector3n finalVelocity=uPlayer->arriveBehavior.getSteering(uPlayer, ballPosition);

    //set the final y-component to zero
    finalVelocity.y=0.0;

    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){

        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setMoveDirection(finalVelocity);

    }else{
        
        uPlayer->changeState(PlayerStateHalt::sharedInstance());
    }
}

void PlayerStateJog::exit(Player *uPlayer){
    
}

bool PlayerStateJog::isSafeToChangeState(Player *uPlayer){
    
    return true;
}

bool PlayerStateJog::handleMessage(Player *uPlayer, Message &uMsg){
    
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

//
//  PlayerStateGoHome.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/20/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateGoHome.h"
#include "PlayerStateChase.h"
#include "PlayerStateIdle.h"
#include "U4DDynamicModel.h"
#include "UserCommonProtocols.h"


PlayerStateGoHome* PlayerStateGoHome::instance=0;

PlayerStateGoHome::PlayerStateGoHome(){
    name="go home";
}

PlayerStateGoHome::~PlayerStateGoHome(){
    
}

PlayerStateGoHome* PlayerStateGoHome::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateGoHome();
    }
    
    return instance;
    
}

void PlayerStateGoHome::enter(Player *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    if (currentAnimation!=nullptr) {
        uPlayer->getAnimationManager()->setAnimationToPlay(currentAnimation);
    }
    
    //set speed
    uPlayer->arriveBehavior.setMaxSpeed(arriveMaxSpeed);

    //set the distance to stop
    uPlayer->arriveBehavior.setTargetRadius(arriveStopRadius);

    //set the distance to start slowing down
    uPlayer->arriveBehavior.setSlowRadius(arriveSlowRadius);
    
    //remove all flags
    uPlayer->resetAllFlags();
    
}

void PlayerStateGoHome::execute(Player *uPlayer, double dt){
    
    //set the target entity to approach
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    U4DEngine::U4DVector3n homePosition=uPlayer->homePosition;
    
    //compute the final velocity
    U4DEngine::U4DVector3n finalVelocity=uPlayer->arriveBehavior.getSteering(uPlayer, homePosition);
    
    //set the final y-component to zero
    finalVelocity.y=0.0;

    
    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
        
        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setMoveDirection(finalVelocity);
        
    }else{
        uPlayer->atHome=true;
        uPlayer->changeState(PlayerStateIdle::sharedInstance());
        
    }
    
}

void PlayerStateGoHome::exit(Player *uPlayer){
    
}

bool PlayerStateGoHome::isSafeToChangeState(Player *uPlayer){
    
    return true;
}
 
bool PlayerStateGoHome::handleMessage(Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
            
        default:
            break;
    }
    
    return false;
    
}

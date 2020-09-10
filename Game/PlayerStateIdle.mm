//
//  PlayerStateIdle.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/30/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateIdle.h"
#include "Ball.h"

#include "PlayerStateChase.h"
#include "PlayerStateDribble.h"
#include "PlayerStateHalt.h"
#include "PlayerStatePass.h"
#include "PlayerStateShoot.h"
#include "PlayerStateTap.h"
#include "PlayerStateIntercept.h"
#include "PlayerStateGroupNav.h"

PlayerStateIdle* PlayerStateIdle::instance=0;

PlayerStateIdle::PlayerStateIdle(){
    
}

PlayerStateIdle::~PlayerStateIdle(){
    
}

PlayerStateIdle* PlayerStateIdle::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateIdle();
    }
    
    return instance;
    
}

void PlayerStateIdle::enter(Player *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay(); 
    
    if (currentAnimation!=nullptr) {
        uPlayer->getAnimationManager()->setAnimationToPlay(currentAnimation);
    }
    
    //remove all velocities from the character
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    
    uPlayer->setVelocity(zero);
    uPlayer->setAngularVelocity(zero);
    
}

void PlayerStateIdle::execute(Player *uPlayer, double dt){
    
    if (uPlayer->dribbleBall==true) {
        
        //check the distance between the player and the ball
        U4DEngine::U4DVector3n ballPosition=uPlayer->getBallPositionOffset();
        ballPosition.y=uPlayer->getAbsolutePosition().y;
        
        float distanceToBall=(ballPosition-uPlayer->getAbsolutePosition()).magnitude();
        
        if (distanceToBall<0.8) {
            
            uPlayer->changeState(PlayerStateTap::sharedInstance());
        
        }else{
            uPlayer->changeState(PlayerStateDribble::sharedInstance());
        }
        
        
    }else if(uPlayer->passBall==true){
        
        uPlayer->changeState(PlayerStatePass::sharedInstance());
    
    }else if(uPlayer->shootBall==true){
        
        uPlayer->changeState(PlayerStateShoot::sharedInstance());
        
    }
}

void PlayerStateIdle::exit(Player *uPlayer){
    
}

bool PlayerStateIdle::isSafeToChangeState(Player *uPlayer){
    
    return true;
}

bool PlayerStateIdle::handleMessage(Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgInterceptBall:
        {
            uPlayer->changeState(PlayerStateIntercept::sharedInstance());
        }
            break;
            
        case msgSupport:
        {
            uPlayer->changeState(PlayerStateGroupNav::sharedInstance()); 
        }
            break;
            
        default:
            break;
    }
    
    return false;
    
}

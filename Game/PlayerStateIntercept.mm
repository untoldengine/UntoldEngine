//
//  PlayerStateIntercept.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/3/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateIntercept.h"
#include "Ball.h"
#include "Team.h"
#include "UserCommonProtocols.h"
#include "PlayerStateChase.h"
#include "PlayerStateDribble.h"
#include "PlayerStateHalt.h"
#include "PlayerStatePass.h"
#include "PlayerStateShoot.h"
#include "PlayerStateTap.h"
#include "PlayerStateJog.h"

PlayerStateIntercept* PlayerStateIntercept::instance=0;

PlayerStateIntercept::PlayerStateIntercept(){
    name="intercept";
}

PlayerStateIntercept::~PlayerStateIntercept(){
    
}

PlayerStateIntercept* PlayerStateIntercept::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateIntercept();
    }
    
    return instance;
    
}

void PlayerStateIntercept::enter(Player *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    if (currentAnimation!=nullptr) {
        uPlayer->getAnimationManager()->setAnimationToPlay(currentAnimation);
    }
    
    //set max speed for pursuit
    uPlayer->pursuitBehavior.setMaxSpeed(pursuitMaxSpeed);
    
    //set the avoidance max speed
    uPlayer->avoidanceBehavior.setMaxSpeed(avoidanceMaxSpeed);
    
}

void PlayerStateIntercept::execute(Player *uPlayer, double dt){
    
       U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
       uPlayer->updateFootSpaceWithAnimation(currentAnimation);

       Ball *ball=Ball::sharedInstance();

       U4DEngine::U4DVector3n finalVelocity=uPlayer->pursuitBehavior.getSteering(uPlayer, ball);

       U4DEngine::U4DVector3n avoidanceBehavior=uPlayer->avoidanceBehavior.getSteering(uPlayer);
        
       if (uPlayer->getModelHasCollidedBroadPhase()) {
            finalVelocity=finalVelocity*0.75+avoidanceBehavior*0.25;
       }
    
       //set the final y-component to zero
       finalVelocity.y=0.0;

       if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){

           uPlayer->applyVelocity(finalVelocity, dt);
           uPlayer->setViewDirection(finalVelocity);

       }

       //check the distance between the player and the ball
       U4DEngine::U4DVector3n ballPosition=uPlayer->getBallPositionOffset();
       ballPosition.y=uPlayer->getAbsolutePosition().y;

       float distanceToBall=(ballPosition-uPlayer->getAbsolutePosition()).magnitude();

       if (distanceToBall<1.0) {

           uPlayer->changeState(PlayerStateJog::sharedInstance());

       }
    
}

void PlayerStateIntercept::exit(Player *uPlayer){
    
}

bool PlayerStateIntercept::isSafeToChangeState(Player *uPlayer){
    
    return true;
}

bool PlayerStateIntercept::handleMessage(Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
            
        default:
            break;
    }
    
    return false;
    
}

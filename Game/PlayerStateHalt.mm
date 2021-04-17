//
//  PlayerStateHalt.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/30/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateHalt.h"

#include "Foot.h"
#include "Team.h"
#include "PlayerStateIdle.h"
#include "PlayerStateChase.h"
#include "PlayerStateDribble.h"
#include "PlayerStatePass.h"
#include "PlayerStateShoot.h"
#include "PlayerStateTap.h"
#include "PlayerStateJog.h"

PlayerStateHalt* PlayerStateHalt::instance=0;

PlayerStateHalt::PlayerStateHalt(){
    name="halt";
}

PlayerStateHalt::~PlayerStateHalt(){
    
}

PlayerStateHalt* PlayerStateHalt::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateHalt();
    }
    
    return instance;
    
}

void PlayerStateHalt::enter(Player *uPlayer){
    
    //play the halt animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    if (currentAnimation!=nullptr) {
        uPlayer->getAnimationManager()->setAnimationToPlay(currentAnimation);
    }
    
    //set as the controlling Player
//    Team *team=uPlayer->getTeam();
//    team->setControllingPlayer(uPlayer);
    
}

void PlayerStateHalt::execute(Player *uPlayer, double dt){
    
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    uPlayer->haltBall=false;
    
    //check the distance between the player and the ball
    U4DEngine::U4DVector3n ballPosition=uPlayer->getBallPositionOffset();
    ballPosition.y=uPlayer->getAbsolutePosition().y;
    
    float distanceToBall=(ballPosition-uPlayer->getAbsolutePosition()).magnitude();
    
    if (currentAnimation->getAnimationIsPlaying()==false) {
        
        if (distanceToBall>0.5) {
        
            uPlayer->setEnableHalt(true);

            uPlayer->changeState(PlayerStateJog::sharedInstance()); 
            
        }else{
        
            uPlayer->changeState(PlayerStateIdle::sharedInstance());
        }
        
    }
    
    if(currentAnimation->getAnimationIsPlaying()==true && currentAnimation->getCurrentKeyframe()>1){
        
        uPlayer->rightFoot->setKickBallParameters(0.0,uPlayer->dribblingDirection);
        
        uPlayer->rightFoot->resumeCollisionBehavior();
        
        
        
    }
    
    //remove all velocities from the character
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);

    uPlayer->applyVelocity(zero, dt);
    
}

void PlayerStateHalt::exit(Player *uPlayer){
    
}

bool PlayerStateHalt::isSafeToChangeState(Player *uPlayer){
    
    return true;
}

bool PlayerStateHalt::handleMessage(Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
            
        default:
            break;
    }
    
    return false;
    
}

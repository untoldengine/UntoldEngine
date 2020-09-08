//
//  PlayerStateChase.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/30/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateChase.h"

#include "Team.h"
#include "PlayerStateIdle.h"
#include "PlayerStateDribble.h"
#include "PlayerStateHalt.h"
#include "PlayerStatePass.h"
#include "PlayerStateShoot.h"
#include "PlayerStateTap.h"

#include "MessageDispatcher.h"

PlayerStateChase* PlayerStateChase::instance=0;

PlayerStateChase::PlayerStateChase(){
    
}

PlayerStateChase::~PlayerStateChase(){
    
}

PlayerStateChase* PlayerStateChase::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateChase();
    }
    
    return instance;
    
}

void PlayerStateChase::enter(Player *uPlayer){
    
    //play the running animation
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
    
    //set the avoidance max speed
    uPlayer->avoidanceBehavior.setMaxSpeed(avoidanceMaxSpeed);
    
    //set as the controlling Player
    Team *team=uPlayer->getTeam();
    team->setControllingPlayer(uPlayer);
    
    //get teammates and ask for support
    MessageDispatcher *messageDispatcher=MessageDispatcher::sharedInstance();
    
    std::vector<Player *> teammates=team->getTeammatesForPlayer(uPlayer);
    
    for(const auto &n:teammates){
        
        messageDispatcher->sendMessage(0.0, uPlayer, n, msgSupport);
    
    }

    
}

void PlayerStateChase::execute(Player *uPlayer, double dt){
    
    //set the target entity to approach
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    U4DEngine::U4DVector3n ballPosition=uPlayer->getBallPositionOffset();
    
    //change the y-position of the ball to be the same as the player
    ballPosition.y=uPlayer->getAbsolutePosition().y;
    
    //compute the final velocity
    U4DEngine::U4DVector3n finalVelocity=uPlayer->arriveBehavior.getSteering(uPlayer, ballPosition);
    
    U4DEngine::U4DVector3n avoidanceBehavior=uPlayer->avoidanceBehavior.getSteering(uPlayer);
    
    if (uPlayer->getModelHasCollidedBroadPhase()) {
        finalVelocity=finalVelocity*0.75+avoidanceBehavior*0.25;
    }
    
    //set the final y-component to zero
    finalVelocity.y=0.0;
    
    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
        
        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setMoveDirection(finalVelocity);
        
    }else{
        //player is within range
        if(uPlayer->passBall==true){
            
            uPlayer->changeState(PlayerStatePass::sharedInstance());
            
        }else if(uPlayer->shootBall==true){
            
            uPlayer->changeState(PlayerStateShoot::sharedInstance());
            
        }else if(uPlayer->standTackleOpponent==true){
            
            //changeState(standtackle);
            
        }else if(uPlayer->dribbleBall==true && uPlayer->haltBall==false){
            
            uPlayer->changeState(PlayerStateDribble::sharedInstance());
            
        }else{
            
            uPlayer->changeState(PlayerStateHalt::sharedInstance());
            
        }
        
    }
}

void PlayerStateChase::exit(Player *uPlayer){
    
}

bool PlayerStateChase::isSafeToChangeState(Player *uPlayer){
    
    return true;
}

bool PlayerStateChase::handleMessage(Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
            
        default:
            break;
    }
    
    return false;
    
}

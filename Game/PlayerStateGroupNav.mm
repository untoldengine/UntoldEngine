//
//  PlayerStateGroupNav.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/5/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateGroupNav.h"
#include "PlayerStateChase.h"
#include "PlayerStateDribble.h"
#include "PlayerStateHalt.h"
#include "PlayerStatePass.h"
#include "PlayerStateShoot.h"
#include "PlayerStateTap.h"
#include "PlayerStateIntercept.h"

#include "U4DDynamicModel.h"
#include "UserCommonProtocols.h"
#include "Team.h"

PlayerStateGroupNav* PlayerStateGroupNav::instance=0;

PlayerStateGroupNav::PlayerStateGroupNav(){
    
}

PlayerStateGroupNav::~PlayerStateGroupNav(){
    
}

PlayerStateGroupNav* PlayerStateGroupNav::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateGroupNav();
    }
    
    return instance;
    
}

void PlayerStateGroupNav::enter(Player *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    if (currentAnimation!=nullptr) {
        uPlayer->getAnimationManager()->setAnimationToPlay(currentAnimation);
    }
    
    uPlayer->flockBehavior.setMaxSpeed(arriveMaxSpeed);
    
    //set the avoidance max speed
    uPlayer->avoidanceBehavior.setMaxSpeed(avoidanceMaxSpeed);
    
    //set speed
    uPlayer->arriveBehavior.setMaxSpeed(arriveMaxSpeed);

    //set the distance to stop
    uPlayer->arriveBehavior.setTargetRadius(arriveStopRadius);

    //set the distance to start slowing down
    uPlayer->arriveBehavior.setSlowRadius(arriveSlowRadius);
    
}

void PlayerStateGroupNav::execute(Player *uPlayer, double dt){
    
    //set the target entity to approach
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    //compute the final velocity
    Team *team=uPlayer->getTeam();
    
    std::vector<U4DEngine::U4DDynamicModel*> neighbors;
    
    std::vector<Player *> teammates=team->getTeammatesForPlayer(uPlayer);
    
    for (const auto &n:teammates) {
        neighbors.push_back(n);
    }
    
    U4DEngine::U4DVector3n flockVelocity=uPlayer->flockBehavior.getSteering(uPlayer, neighbors);

    //get player formation position
    U4DEngine::U4DVector3n formationPosition=team->getFormationPositionAtIndex(uPlayer->getPlayerIndex());
    
    U4DEngine::U4DVector3n formationVelocity=uPlayer->arriveBehavior.getSteering(uPlayer, formationPosition);
    
    U4DEngine::U4DVector3n avoidanceBehavior=uPlayer->avoidanceBehavior.getSteering(uPlayer);

    U4DEngine::U4DVector3n finalVelocity;
    
    if (uPlayer->getModelHasCollidedBroadPhase()) {
        finalVelocity=flockVelocity*0.40+avoidanceBehavior*0.60;
    }else{
        finalVelocity=flockVelocity*0.50+formationVelocity*0.50;
    }
    
    //set the final y-component to zero
    finalVelocity.y=0.0;

    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){

        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setMoveDirection(finalVelocity);

    }

}

void PlayerStateGroupNav::exit(Player *uPlayer){
    
}

bool PlayerStateGroupNav::isSafeToChangeState(Player *uPlayer){
    
    return true;
}

bool PlayerStateGroupNav::handleMessage(Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgInterceptBall:
        {
            uPlayer->changeState(PlayerStateIntercept::sharedInstance());
        }
            
        default:
            break;
    }
    
    return false;
    
}

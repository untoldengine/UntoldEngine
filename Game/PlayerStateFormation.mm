//
//  PlayerStateFormation.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateFormation.h"
#include "PlayerStateChase.h"
#include "PlayerStateDribble.h"
#include "PlayerStateHalt.h"
#include "PlayerStatePass.h"
#include "PlayerStateShoot.h"
#include "PlayerStateTap.h"
#include "PlayerStateIntercept.h"
#include "PlayerStateMark.h"
#include "PlayerStateIdle.h"
#include "PlayerStateWander.h"
#include "U4DDynamicModel.h"
#include "UserCommonProtocols.h"
#include "Team.h"

PlayerStateFormation* PlayerStateFormation::instance=0;

PlayerStateFormation::PlayerStateFormation(){
    name="formation";
}

PlayerStateFormation::~PlayerStateFormation(){
    
}

PlayerStateFormation* PlayerStateFormation::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateFormation();
    }
    
    return instance;
    
}

void PlayerStateFormation::enter(Player *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    if (currentAnimation!=nullptr) {
        uPlayer->getAnimationManager()->setAnimationToPlay(currentAnimation);
    }
    
    uPlayer->flockBehavior.setMaxSpeed(arriveMaxSpeed);
    
    uPlayer->flockBehavior.setNeighborsDistance(neighborPlayerSeparationDistance, neighborPlayerAlignmentDistance, neighborPlayerCohesionDistance);
    
    //set the avoidance max speed
    uPlayer->avoidanceBehavior.setMaxSpeed(avoidanceMaxSpeed);
    
    //set speed
    uPlayer->arriveBehavior.setMaxSpeed(arriveMaxSpeed);

    //set the distance to stop
    uPlayer->arriveBehavior.setTargetRadius(arriveStopRadius);

    //set the distance to start slowing down
    uPlayer->arriveBehavior.setSlowRadius(arriveSlowRadius);
    
    uPlayer->wanderBehavior.setWanderOffset(1.0);
    
    uPlayer->wanderBehavior.setWanderRadius(3.0);
    
    uPlayer->wanderBehavior.setWanderRate(1.0);
    
}

void PlayerStateFormation::execute(Player *uPlayer, double dt){
    
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
    U4DEngine::U4DVector3n formationPosition=team->formationManager.getFormationPositionAtIndex(uPlayer->getPlayerIndex());
    
    U4DEngine::U4DVector3n formationVelocity=uPlayer->arriveBehavior.getSteering(uPlayer, formationPosition);
    
    U4DEngine::U4DVector3n wanderVelocity=uPlayer->wanderBehavior.getSteering(uPlayer, formationPosition);
    
    U4DEngine::U4DVector3n avoidanceBehavior=uPlayer->avoidanceBehavior.getSteering(uPlayer);
    
    U4DEngine::U4DVector3n finalVelocity=flockVelocity*0.50+formationVelocity*0.50;
    
//    if (uPlayer->getModelHasCollidedBroadPhase()) {
//        finalVelocity=finalVelocity*0.7+avoidanceBehavior*0.3;
//    }
    
    //set the final y-component to zero
    finalVelocity.y=0.0;
    
    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){

        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setMoveDirection(finalVelocity);

    }
    
}

void PlayerStateFormation::exit(Player *uPlayer){
    
}

bool PlayerStateFormation::isSafeToChangeState(Player *uPlayer){
    
    return true;
}
 
bool PlayerStateFormation::handleMessage(Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgInterceptBall:
        {
            uPlayer->changeState(PlayerStateIntercept::sharedInstance());
        }
           
            break;
            
        case msgMark:
        {
            uPlayer->changeState(PlayerStateMark::sharedInstance());
        }
            break;
            
        case msgIdle:
        {
            uPlayer->changeState(PlayerStateIdle::sharedInstance());
        }
            break;
            
        case msgWander:
        {
            uPlayer->changeState(PlayerStateWander::sharedInstance());
        }
            break;
            
        default:
            break;
    }
    
    return false;
    
}

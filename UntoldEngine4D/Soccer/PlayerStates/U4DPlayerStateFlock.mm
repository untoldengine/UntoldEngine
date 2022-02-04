//
//  U4DPlayerStateFlock.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/7/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateFlock.h"
#include "U4DGameConfigs.h"
#include "U4DPlayerStateDribbling.h"
#include "U4DPlayerStateIntercept.h"
#include "U4DPlayerStateFree.h"
#include "U4DPlayerStateIdle.h"
#include "U4DPlayerStateWander.h"
#include "U4DPlayerStateMark.h"
#include "U4DPlayerStateGoHome.h"
#include "U4DTeam.h"

namespace U4DEngine {

U4DPlayerStateFlock* U4DPlayerStateFlock::instance=0;

U4DPlayerStateFlock::U4DPlayerStateFlock(){
    name="flock";
}

U4DPlayerStateFlock::~U4DPlayerStateFlock(){
    
}

U4DPlayerStateFlock* U4DPlayerStateFlock::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DPlayerStateFlock();
    }
    
    return instance;
    
}

void U4DPlayerStateFlock::enter(U4DPlayer *uPlayer){
    
    U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
    
    //play the formation animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->runningAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
    uPlayer->flockBehavior.setMaxSpeed(gameConfigs->getParameterForKey("arriveMaxSpeed"));
    
    uPlayer->flockBehavior.setNeighborsDistance(gameConfigs->getParameterForKey("neighborPlayerSeparationDistance"), gameConfigs->getParameterForKey("neighborPlayerAlignmentDistance"), gameConfigs->getParameterForKey("neighborPlayerCohesionDistance"));
    
    
    //set the avoidance max speed
    uPlayer->avoidanceBehavior.setMaxSpeed(gameConfigs->getParameterForKey("avoidanceMaxSpeed"));
    
    //set speed
    uPlayer->arriveBehavior.setMaxSpeed(gameConfigs->getParameterForKey("arriveMaxSpeed"));

    //set the distance to stop
    uPlayer->arriveBehavior.setTargetRadius(gameConfigs->getParameterForKey("arriveStopRadius"));

    //set the distance to start slowing down
    uPlayer->arriveBehavior.setSlowRadius(gameConfigs->getParameterForKey("arriveSlowRadius"));
    
}

void U4DPlayerStateFlock::execute(U4DPlayer *uPlayer, double dt){
    
    //set the target entity to approach
    uPlayer->updateFootSpaceWithAnimation(uPlayer->runningAnimation);
    
    //compute the final velocity
    U4DTeam *team=uPlayer->getTeam();
    
    std::vector<U4DEngine::U4DDynamicAction*> neighbors;
    
    std::vector<U4DPlayer *> teammates=team->getTeammatesForPlayer(uPlayer);
    
    for (const auto &n:teammates) {
        neighbors.push_back(n->kineticAction);
    }
    
    U4DEngine::U4DVector3n flockVelocity=uPlayer->flockBehavior.getSteering(uPlayer->kineticAction, neighbors);
    
    
    //get player formation position
    U4DEngine::U4DVector3n formationPosition=team->formationManager.getFormationPositionAtIndex(uPlayer->getPlayerIndex());
    
    U4DEngine::U4DVector3n formationVelocity=uPlayer->arriveBehavior.getSteering(uPlayer->kineticAction, formationPosition);
    
    //U4DEngine::U4DVector3n avoidanceBehavior=uPlayer->avoidanceBehavior.getSteering(uPlayer->kineticAction);

    U4DEngine::U4DVector3n finalVelocity=formationVelocity*0.3+flockVelocity*0.7;
    
    
//    if (uPlayer->kineticAction->getModelHasCollidedBroadPhase()) {
//        finalVelocity=finalVelocity*0.7;
//    }
    
    //set the final y-component to zero
    finalVelocity.y=0.0;

    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){

        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setMoveDirection(finalVelocity);

    }
    
    
}

void U4DPlayerStateFlock::exit(U4DPlayer *uPlayer){
    
}

bool U4DPlayerStateFlock::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStateFlock::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgInterceptBall:
        {
            uPlayer->changeState(U4DPlayerStateIntercept::sharedInstance());
        }
        break;
            
        case msgIdle:
        {
            uPlayer->changeState(U4DPlayerStateIdle::sharedInstance());
        }
            
        break;
            
        case msgWander:
        {
            uPlayer->changeState(U4DPlayerStateWander::sharedInstance());
        }
            
        case msgMark:
        {
            uPlayer->changeState(U4DPlayerStateMark::sharedInstance());
        }
            break;
            
        case msgGoHome:
        {
            uPlayer->changeState(U4DPlayerStateGoHome::sharedInstance());
        }
        
        break;
            
        default:
            break;
    }
    
    return false;
    
}

}

//
//  U4DPlayerStateAiDribbling.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/10/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateAiDribbling.h"
#include "U4DGameConfigs.h"
#include "U4DPlayerStateDribbling.h"
#include "U4DPlayerStateIntercept.h"
#include "U4DPlayerStateFree.h"
#include "U4DPlayerStateFlock.h"
#include "U4DPlayerStateMark.h"
#include "U4DTeam.h"
#include "U4DPathAnalyzer.h"
#include "U4DBall.h"
#include "U4DFoot.h"
#include "U4DAABB.h"
#include "U4DMessageDispatcher.h"
#include "U4DTeamStateAttacking.h"
#include "U4DTeamStateDefending.h"
#include "U4DPlayerStateGoHome.h"


namespace U4DEngine {

U4DPlayerStateAiDribbling* U4DPlayerStateAiDribbling::instance=0;

U4DPlayerStateAiDribbling::U4DPlayerStateAiDribbling(){
    name="Ai Dribbling";
}

U4DPlayerStateAiDribbling::~U4DPlayerStateAiDribbling(){
    
}

U4DPlayerStateAiDribbling* U4DPlayerStateAiDribbling::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DPlayerStateAiDribbling();
    }
    
    return instance;
    
}

void U4DPlayerStateAiDribbling::enter(U4DPlayer *uPlayer){
    
    U4DGameConfigs *gameConfigs=U4DGameConfigs::sharedInstance();
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->runningAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
    
    //set speed
    uPlayer->arriveBehavior.setMaxSpeed(gameConfigs->getParameterForKey("arriveMaxSpeed"));

    //set the distance to stop
    uPlayer->arriveBehavior.setTargetRadius(gameConfigs->getParameterForKey("arriveStopRadius"));

    //set the distance to start slowing down
    uPlayer->arriveBehavior.setSlowRadius(gameConfigs->getParameterForKey("arriveSlowRadius"));
    
    //set the avoidance max speed
//    uPlayer->avoidanceBehavior.setMaxSpeed(gameConfigs->getParameterForKey("markAvoidanceMaxSpeed"));
//
//    uPlayer->avoidanceBehavior.setTimeParameter(gameConfigs->getParameterForKey("markAvoidanceTimeParameter"));
    
    
    U4DTeam *team=uPlayer->getTeam();
    if(team!=nullptr){
        team->setActivePlayer(uPlayer);
        
        U4DTeam *oppositeTeam=team->getOppositeTeam();
        
        team->changeState(U4DTeamStateAttacking::sharedInstance());
        oppositeTeam->changeState(U4DTeamStateDefending::sharedInstance());
        
        //inform teammates to flock
        std::vector<U4DPlayer*> teammates=team->getTeammatesForPlayer(uPlayer);
        U4DMessageDispatcher *messageDispatcher=U4DMessageDispatcher::sharedInstance();
        
        for(auto n: teammates){
            messageDispatcher->sendMessage(0.0, uPlayer, n, msgSupport);
        }
    }
    
    uPlayer->foot->kineticAction->pauseCollisionBehavior();
    uPlayer->foot->allowedToKick=true;
}

void U4DPlayerStateAiDribbling::execute(U4DPlayer *uPlayer, double dt){
    
    U4DGameConfigs *gameConfigs=U4DGameConfigs::sharedInstance();
    
    U4DBall *ball=U4DBall::sharedInstance();
    
    U4DVector3n ballPosition=ball->getAbsolutePosition();
    ballPosition.y=uPlayer->getAbsolutePosition().y;
    
    U4DEngine::U4DVector3n steerToBallVelocity=uPlayer->arriveBehavior.getSteering(uPlayer->kineticAction, ballPosition);
    
    //compute the final velocity
    U4DEngine::U4DVector3n finalVelocity=uPlayer->arriveBehavior.getSteering(uPlayer->kineticAction, uPlayer->navDribbling);
    
    finalVelocity=steerToBallVelocity*0.8+finalVelocity*0.2;
    
//    U4DEngine::U4DVector3n avoidanceBehavior=uPlayer->avoidanceBehavior.getSteering(uPlayer->kineticAction);
//
//    if (uPlayer->kineticAction->getModelHasCollidedBroadPhase()) {
//        finalVelocity=finalVelocity*0.8+avoidanceBehavior*0.2;
//    }
    //set the final y-component to zero
    finalVelocity.y=0.0;
    
    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
        
        uPlayer->applyVelocity(finalVelocity, dt);
        
        uPlayer->setViewDirection(finalVelocity);
        
    }
    
    //uPlayer->foot->kineticAction->resumeCollisionBehavior();
    
    //if the player is facing the opposite way, then make the kick
    //go the opposite way to force the player to turn around
    U4DEngine::U4DVector3n viewDir=uPlayer->getViewInDirection();
    float d=viewDir.dot(uPlayer->navDribbling);
    
    if (d<-0.75) {
        
        //Ideally, in this scenario, I should have another state which makes the player do a kick-back move. However, for now, I'm just rotating the final velocity for the ball
        U4DVector3n upAxis(0.0,1.0,0.0);
        finalVelocity=finalVelocity.rotateVectorAboutAngleAndAxis(90.0, upAxis);
    }
    
    //if (uPlayer->foot->kineticAction->getModelHasCollided()) {
        
    finalVelocity.normalize();
    uPlayer->foot->setKickBallParameters(gameConfigs->getParameterForKey("dribblingBallSpeed"),finalVelocity);

    //}
}

void U4DPlayerStateAiDribbling::exit(U4DPlayer *uPlayer){
    uPlayer->foot->allowedToKick=false;
}

bool U4DPlayerStateAiDribbling::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStateAiDribbling::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
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

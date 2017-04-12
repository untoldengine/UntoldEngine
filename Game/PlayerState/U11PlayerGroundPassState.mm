//
//  U11PlayerGroundPassState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerGroundPassState.h"
#include "U11PlayerChaseBallState.h"
#include "U11PlayerIdleState.h"
#include "UserCommonProtocols.h"
#include "U11Team.h"
#include "U11MessageDispatcher.h"
#include "U11TeamIdleState.h"

U11PlayerGroundPassState* U11PlayerGroundPassState::instance=0;

U11PlayerGroundPassState::U11PlayerGroundPassState(){
    
}

U11PlayerGroundPassState::~U11PlayerGroundPassState(){
    
}

U11PlayerGroundPassState* U11PlayerGroundPassState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerGroundPassState();
    }
    
    return instance;
    
}

void U11PlayerGroundPassState::enter(U11Player *uPlayer){
    
    //set the ground pass animation
    
    if (uPlayer->isBallOnRightSidePlane()) {
        
        uPlayer->setNextAnimationToPlay(uPlayer->getRightFootSidePassAnimation());
        
        uPlayer->setActiveExtremity(uPlayer->getRightFoot());
        
    }else{
        
        uPlayer->setNextAnimationToPlay(uPlayer->getLeftFootSidePassAnimation());
        uPlayer->setActiveExtremity(uPlayer->getLeftFoot());
        
    }
    uPlayer->setPlayNextAnimationContinuously(false);
    uPlayer->setPlayBlendedAnimation(true);
    
    uPlayer->getTeam()->changeState(U11TeamIdleState::sharedInstance());
    
}

void U11PlayerGroundPassState::execute(U11Player *uPlayer, double dt){
    
    if(uPlayer->getActiveExtremityCollidedWithBall()){
        
        if (uPlayer->getAnimationCurrentKeyframe()==3) {
            
            U4DEngine::U4DVector3n direction=uPlayer->getPlayerHeading();
            
            uPlayer->kickBallToGround(ballPassingSpeed, direction,dt);
            
            uPlayer->removeKineticForces();
            
            U11PlayerIdleState *idleState=U11PlayerIdleState::sharedInstance();
            
            uPlayer->changeState(idleState);
            
        }
        
    }
    
}

void U11PlayerGroundPassState::exit(U11Player *uPlayer){
    
    //get supporting player and send him a message
    U11Player* supportPlayer=uPlayer->getTeam()->analyzeClosestPlayersAlongPassLine().at(0);
    
    //prepare message
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
    messageDispatcher->sendMessage(0.0, uPlayer, supportPlayer, msgReceiveBall);
    
}

bool U11PlayerGroundPassState::isSafeToChangeState(U11Player *uPlayer){
    
    //check if animation can be interrupted or if the animation has stopped
    if (uPlayer->getCurrentPlayingAnimation()->getIsAllowedToBeInterrupted()==true || !uPlayer->getCurrentPlayingAnimation()->getAnimationIsPlaying()) {
        
        return true;
    }
    
    return false;
}

bool U11PlayerGroundPassState::handleMessage(U11Player *uPlayer, Message &uMsg){
    return false;
}

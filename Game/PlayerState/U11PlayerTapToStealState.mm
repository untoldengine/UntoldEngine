//
//  U11PlayerTapToStealState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerTapToStealState.h"
#include "U11PlayerDefendState.h"
#include "U11Team.h"
#include "U11MessageDispatcher.h"

U11PlayerTapToStealState* U11PlayerTapToStealState::instance=0;

U11PlayerTapToStealState::U11PlayerTapToStealState(){
    
}

U11PlayerTapToStealState::~U11PlayerTapToStealState(){
    
}

U11PlayerTapToStealState* U11PlayerTapToStealState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerTapToStealState();
    }
    
    return instance;
    
}

void U11PlayerTapToStealState::enter(U11Player *uPlayer){
    
    uPlayer->setNextAnimationToPlay(uPlayer->getStealingAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(false);
    uPlayer->setActiveExtremity(uPlayer->getRightFoot());
}

void U11PlayerTapToStealState::execute(U11Player *uPlayer, double dt){
    
    uPlayer->seekBall();
    
    if(uPlayer->getActiveExtremityCollidedWithBall()){
        
        U4DEngine::U4DVector3n direction=uPlayer->getPlayerHeading();
        
        uPlayer->kickBallToGround(ballStealingSpeed, direction,dt);
    
        //change the states of the teams
        U11Team *team=uPlayer->getTeam();
        
        U11Team *oppositeTeam=team->getOppositeTeam();
        
        U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
        
        messageDispatcher->sendMessage(0.0, team, msgBallRelinquished);
        
        messageDispatcher->sendMessage(0.0, oppositeTeam, msgBallRelinquished);
        
        //uPlayer->changeState(U11PlayerDefendState::sharedInstance());
        
    }
    
    if (!uPlayer->getCurrentPlayingAnimation()->isAnimationPlaying()) {
        
        uPlayer->changeState(U11PlayerDefendState::sharedInstance());
        
    }
}

void U11PlayerTapToStealState::exit(U11Player *uPlayer){
    
}

bool U11PlayerTapToStealState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerTapToStealState::handleMessage(U11Player *uPlayer, Message &uMsg){

    
    return false;
    
}

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
#include "U11PlayerDribblePassState.h"
#include "U11PlayerTakeBallControlState.h"
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
            
            float ballPassSpeed=uPlayer->getBallKickSpeed();
            
            uPlayer->kickBallToGround(ballPassSpeed, direction,dt);
            
            uPlayer->removeKineticForces();
            
            uPlayer->setMissedTheBall(false);
            
            U11PlayerIdleState *idleState=U11PlayerIdleState::sharedInstance();
            
            uPlayer->changeState(idleState);
            
        }
        
    }
    
    //if missed the kick, go get the ball
    if (!uPlayer->getCurrentPlayingAnimation()->isAnimationPlaying()) {
        
        uPlayer->setMissedTheBall(true);
        uPlayer->changeState(U11PlayerTakeBallControlState::sharedInstance());
        
    }
    
}

void U11PlayerGroundPassState::exit(U11Player *uPlayer){
    
    if (uPlayer->getMissedTheBall()==false) {
     
        //get controlling player position
        U4DEngine::U4DPoint3n pointA=uPlayer->getAbsolutePosition().toPoint();
        
        //get ball heading
        U4DEngine::U4DVector3n ballVelocity=uPlayer->getSoccerBall()->getVelocity();
        
        ballVelocity.normalize();
        
        U4DEngine::U4DPoint3n ballDirection=ballVelocity.toPoint();
        
        //get ball kick speed
        float t=uPlayer->getBallKickSpeed();
        
        //get the destination point
        U4DEngine::U4DVector3n pointB=(pointA+ballDirection*t).toVector();
        
        //get receiving player and send him a message
        U11Team *team=uPlayer->getTeam();
        
        U11Player* receivingPlayer=team->analyzeClosestPlayersToPosition(pointB).at(0);
        
        //prepare message
        U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
        
        messageDispatcher->sendMessage(0.0, uPlayer, receivingPlayer, msgReceiveBall);
        
        //send message to opposite team
        U11Team *oppositeTeam=team->getOppositeTeam();
        
        messageDispatcher->sendMessage(0.0, oppositeTeam, msgBallPassed);
        
    }
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

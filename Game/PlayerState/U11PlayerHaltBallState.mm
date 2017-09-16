//
//  U11PlayerHaltBallState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerHaltBallState.h"
#include "U11PlayerDribbleState.h"
#include "U11PlayerGroundPassState.h"
#include "U11PlayerGroundShotState.h"
#include "U11PlayerAirShotState.h"
#include "U11PlayerReverseKickState.h"
#include "U11PlayerRunPassState.h"
#include "U11BallGroundState.h"
#include "U11PlayerChaseBallState.h"
#include "U11PlayerAttackState.h"
#include "U11Ball.h"
#include "U11Team.h"
#include "UserCommonProtocols.h"
#include "U11MessageDispatcher.h"


U11PlayerHaltBallState* U11PlayerHaltBallState::instance=0;

U11PlayerHaltBallState::U11PlayerHaltBallState(){
    
}

U11PlayerHaltBallState::~U11PlayerHaltBallState(){
    
}

U11PlayerHaltBallState* U11PlayerHaltBallState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerHaltBallState();
    }
    
    return instance;
    
}

void U11PlayerHaltBallState::enter(U11Player *uPlayer){
    
    //determine the direction of the ball
    U4DEngine::U4DVector3n playerHeading=uPlayer->getPlayerHeading();
    playerHeading.normalize();
    
    U4DEngine::U4DVector3n ballHeading=uPlayer->getSoccerBall()->getVelocity();
    ballHeading.normalize();
    
    float relHeading=playerHeading.dot(ballHeading);
    
    if (relHeading>0.90) {
        //if ball is coming towards player around 18 degrees
        
        //set the control ball animation
        if (uPlayer->isBallOnRightSidePlane()) {
            
            uPlayer->setNextAnimationToPlay(uPlayer->getRightSoleHaltAnimation());
            uPlayer->setActiveExtremity(uPlayer->getRightFoot());
        }else{
            
            uPlayer->setNextAnimationToPlay(uPlayer->getLeftSoleHaltAnimation());
            uPlayer->setActiveExtremity(uPlayer->getLeftFoot());
        }
        
    }else if(relHeading<-0.90){
        //if ball is ahead of player around 18 degrees
        
        //set the control ball animation
        if (uPlayer->isBallOnRightSidePlane()) {
            
            uPlayer->setNextAnimationToPlay(uPlayer->getRightInsideHaltAnimation());
            uPlayer->setActiveExtremity(uPlayer->getRightFoot());
        }else{
            
            uPlayer->setNextAnimationToPlay(uPlayer->getLeftInsideHaltAnimation());
            uPlayer->setActiveExtremity(uPlayer->getLeftFoot());
        }
        
    }else{
        
        std::cout<<"Side halt animation"<<std::endl;
        //set the control ball animation
        if (!uPlayer->isBallComingFromRightSidePlane()) {
            
            uPlayer->setNextAnimationToPlay(uPlayer->getLeftSideHaltAnimation());
            uPlayer->setActiveExtremity(uPlayer->getLeftFoot());
            
        }else{
            
            uPlayer->setNextAnimationToPlay(uPlayer->getRightSideHaltAnimation());
            uPlayer->setActiveExtremity(uPlayer->getRightFoot());
            
        }
        
    }
    
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(false);
    
    U11Team *team=uPlayer->getTeam();
    
    team->setControllingPlayer(uPlayer);
    
}

void U11PlayerHaltBallState::execute(U11Player *uPlayer, double dt){
    
    
    uPlayer->computePlayerDribblingSpeed();
    
    int keyframe;
    
    if (uPlayer->getCurrentPlayingAnimation()==uPlayer->getRightSoleHaltAnimation() || uPlayer->getCurrentPlayingAnimation()==uPlayer->getLeftSoleHaltAnimation() ) {
        
        keyframe=2;
        
        //track the ball
        uPlayer->seekBall();
        
    }
    
    if (uPlayer->getCurrentPlayingAnimation()==uPlayer->getRightInsideHaltAnimation() || uPlayer->getCurrentPlayingAnimation()==uPlayer->getLeftInsideHaltAnimation() ) {
        
        keyframe=0;
        
    }
    
    if (uPlayer->getCurrentPlayingAnimation()==uPlayer->getRightSideHaltAnimation() || uPlayer->getCurrentPlayingAnimation()==uPlayer->getLeftSideHaltAnimation() ) {
        
        keyframe=2;
        
        //track the ball
        uPlayer->seekBall();
    }
   
    //stop ball motion if the feet collide with the ball and if it matches a keyframe
    if (uPlayer->getActiveExtremityCollidedWithBall() && uPlayer->getAnimationCurrentKeyframe()==keyframe) {
        
        uPlayer->getCurrentPlayingAnimation()->play();
        
        uPlayer->removeKineticForces();
    
        U11Ball *ball=uPlayer->getSoccerBall();
        
        ball->removeKineticForces();
        
        ball->removeAllVelocities();
    
        U11Team *team=uPlayer->getTeam();
        
        U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
        
        messageDispatcher->sendMessage(0.0, team, msgBallInPossession);
    
        ball->changeState(U11BallGroundState::sharedInstance());
        
        uPlayer->changeState(U11PlayerAttackState::sharedInstance());
        
    }else if (!uPlayer->getActiveExtremityCollidedWithBall() && uPlayer->getAnimationCurrentKeyframe()==keyframe){
        
        uPlayer->applyForceToPlayer(uPlayer->getPlayerDribblingSpeed(), dt);
        
        uPlayer->getCurrentPlayingAnimation()->pause();
        
        if (uPlayer->distanceToBall()>0.8) {
            
            //chase the ball
            uPlayer->changeState(U11PlayerChaseBallState::sharedInstance());
            
        }
        
    }else{
            
        //uPlayer->applyForceToPlayer(uPlayer->getPlayerDribblingSpeed(), dt);
        
    }
    
   
    
}

void U11PlayerHaltBallState::exit(U11Player *uPlayer){
    
}

bool U11PlayerHaltBallState::isSafeToChangeState(U11Player *uPlayer){
    
    //check if animation can be interrupted or if the animation has stopped
    if (uPlayer->getCurrentPlayingAnimation()->getIsAllowedToBeInterrupted()==true || !uPlayer->getCurrentPlayingAnimation()->getAnimationIsPlaying()) {
        
        return true;
    }
    
    return false;
    
}

bool U11PlayerHaltBallState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
            
        case msgButtonAPressed:
        {
            int passBallSpeed=*((int*)uMsg.extraInfo);
            
            uPlayer->setBallKickSpeed(passBallSpeed);
            
            uPlayer->changeState(U11PlayerRunPassState::sharedInstance());
        }
            break;
            
        case msgButtonBPressed:
        {
            int passBallSpeed=*((int*)uMsg.extraInfo);
            
            uPlayer->setBallKickSpeed(passBallSpeed);
            
            uPlayer->changeState(U11PlayerAirShotState::sharedInstance());
        }
            break;
            
        case msgJoystickActive:
        {
            JoystickMessageData joystickMessageData=*((JoystickMessageData*)uMsg.extraInfo);
            
            if (joystickMessageData.changedDirection) {
                
                uPlayer->changeState(U11PlayerReverseKickState::sharedInstance());
                
            }
            
            uPlayer->changeState(U11PlayerDribbleState::sharedInstance());
            
            
        }
            break;
        
        case msgDribble:
            
            uPlayer->changeState(U11PlayerDribbleState::sharedInstance());
            
            break;
            
        default:
            break;
    }
    
    return false;
}

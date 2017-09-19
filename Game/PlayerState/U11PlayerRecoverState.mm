//
//  U11PlayerRecoverState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerRecoverState.h"

#include "U11BallRollingState.h"
#include "U11PlayerChaseBallState.h"
#include "U11AIAttackState.h"
#include "U11AIDefenseState.h"
#include "U11Ball.h"
#include "U11Team.h"
#include "U11AISystem.h"
#include "UserCommonProtocols.h"
#include "U11PlayerInterceptState.h"

U11PlayerRecoverState* U11PlayerRecoverState::instance=0;

U11PlayerRecoverState::U11PlayerRecoverState(){
    
}

U11PlayerRecoverState::~U11PlayerRecoverState(){
    
}

U11PlayerRecoverState* U11PlayerRecoverState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerRecoverState();
    }
    
    return instance;
    
}

void U11PlayerRecoverState::enter(U11Player *uPlayer){
    
    //determine the direction of the ball
    U4DEngine::U4DVector3n playerHeading=uPlayer->getPlayerHeading();
    playerHeading.normalize();
    
    U4DEngine::U4DVector3n ballHeading=uPlayer->getSoccerBall()->getVelocity();
    ballHeading.normalize();
    
    float relHeading=playerHeading.dot(ballHeading);
    
    if (ballHeading.magnitudeSquare()==0) {
        
        //set the control ball animation
        if (uPlayer->isBallOnRightSidePlane()) {
            
            uPlayer->setNextAnimationToPlay(uPlayer->getRightSoleHaltAnimation());
            uPlayer->setActiveExtremity(uPlayer->getRightFoot());
        }else{
            
            uPlayer->setNextAnimationToPlay(uPlayer->getLeftSoleHaltAnimation());
            uPlayer->setActiveExtremity(uPlayer->getLeftFoot());
        }
        
    }else{
        
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
            
            //set the control ball animation
            if (uPlayer->isBallComingFromRightSidePlane()) {
                
                uPlayer->setNextAnimationToPlay(uPlayer->getLeftSideHaltAnimation());
                uPlayer->setActiveExtremity(uPlayer->getLeftFoot());
                
            }else{
                
                uPlayer->setNextAnimationToPlay(uPlayer->getRightSideHaltAnimation());
                uPlayer->setActiveExtremity(uPlayer->getRightFoot());
            }
            
        }
        
    }
    
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(false);
    
}

void U11PlayerRecoverState::execute(U11Player *uPlayer, double dt){
    
    U11Ball *ball=uPlayer->getSoccerBall();
    
    //stop ball motion if the feet collide with the ball and if it matches a keyframe
    if (uPlayer->getActiveExtremityCollidedWithBall()) {
        /*
        if (uPlayer->getCurrentPlayingAnimation()==uPlayer->getForwardHaltBallWithLeftFootAnimation() || uPlayer->getCurrentPlayingAnimation()==uPlayer->getForwardHaltBallWithRightFootAnimation()) {
            
            if (uPlayer->getAnimationCurrentKeyframe()==3) {
                
                ball->removeKineticForces();
                
                ball->removeAllVelocities();
                
                ball->changeState(U11BallRollingState::sharedInstance());
             
                //get team
                U11Team *team=uPlayer->getTeam();
                
                team->setControllingPlayer(uPlayer);
                
                //change state to attacking
                team->changeState(U11AIAttackState::sharedInstance());
                
                //inform the opposite team to change to defending state
                team->getOppositeTeam()->changeState(U11AIDefenseState::sharedInstance());
            }
            
        }else{
            */
            ball->removeKineticForces();
            
            ball->removeAllVelocities();
            
            ball->changeState(U11BallRollingState::sharedInstance());
            
            //get team
            U11Team *team=uPlayer->getTeam();
            
            team->setControllingPlayer(uPlayer);
            
            //change state to attacking
            team->changeState(U11AIAttackState::sharedInstance());
            
            //inform the opposite team to change to defending state
            team->getOppositeTeam()->changeState(U11AIDefenseState::sharedInstance());
        //}
        
    }
    
    if (ball->getVelocity().magnitude()>ballMaxSpeed) {
        uPlayer->decelerateBall(ballDeceleration, dt);
    }
    
}

void U11PlayerRecoverState::exit(U11Player *uPlayer){

    
}

bool U11PlayerRecoverState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerRecoverState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    return false;
}

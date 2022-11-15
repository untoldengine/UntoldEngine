//
//  U4DPlayerStateSlidingTackle.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/9/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateSlidingTackle.h"
#include "U4DGameConfigs.h"
#include "U4DPlayerStateDribbling.h"
#include "U4DPlayerStateIntercept.h"
#include "U4DPlayerStateFree.h"
#include "U4DPlayerStateFlock.h"
#include "U4DPlayerStateGoHome.h"
#include "U4DPlayerStateMark.h"
#include "U4DPlayerStateIdle.h"
#include "U4DTeam.h"
#include "U4DBall.h"
#include "U4DMatchManager.h"

namespace U4DEngine {

U4DPlayerStateSlidingTackle* U4DPlayerStateSlidingTackle::instance=0;

U4DPlayerStateSlidingTackle::U4DPlayerStateSlidingTackle(){
    name="sliding tackle";
}

U4DPlayerStateSlidingTackle::~U4DPlayerStateSlidingTackle(){
    
}

U4DPlayerStateSlidingTackle* U4DPlayerStateSlidingTackle::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DPlayerStateSlidingTackle();
    }
    
    return instance;
    
}

void U4DPlayerStateSlidingTackle::enter(U4DPlayer *uPlayer){
    
    U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
    
    //play the idle animation
    U4DAnimation *currentAnimation=uPlayer->slidingTackleAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
    //set max speed for pursuit
    uPlayer->pursuitBehavior.setMaxSpeed(gameConfigs->getParameterForKey("pursuitMaxSpeed"));
    
    uPlayer->allowedToKick=true;
}

void U4DPlayerStateSlidingTackle::execute(U4DPlayer *uPlayer, double dt){
    
    U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
    
    U4DAnimation *currentAnimation=uPlayer->slidingTackleAnimation;

    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    U4DTeam *team=uPlayer->getTeam();
    
    U4DBall *ball=U4DBall::sharedInstance();
    
    U4DEngine::U4DVector3n ballPosition=ball->getAbsolutePosition();
    ballPosition.y=uPlayer->getAbsolutePosition().y;
    
    U4DVector3n finalVelocity=uPlayer->pursuitBehavior.getSteering(uPlayer->kineticAction, ball->kineticAction);
    
    //set the final y-component to zero
    finalVelocity.y=0.0;
    //finalVelocity*=gameConfigs->getParameterForKey("slidingTackleVelocity");
    
    if(!(finalVelocity==U4DVector3n(0.0,0.0,0.0))){
        
        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setMoveDirection(finalVelocity);
        
    }
   
    //TEMP IMPLEMENTATION START
//    U4DMatchManager *matchManager=U4DMatchManager::sharedInstance();
//
//    U4DGoalPost *goalPost=matchManager->getTeamBGoalPost();
//
//    U4DEngine::U4DAABB aabb=goalPost->goalBoxAABB;
//
//    U4DEngine::U4DPoint3n pos=uPlayer->getAbsolutePosition().toPoint();
//
//    U4DEngine::U4DPoint3n closestPoint;
//
//    aabb.closestPointOnAABBToPoint(pos, closestPoint);
//
//    finalVelocity=closestPoint.toVector();
//    finalVelocity.y=0.0;
//    finalVelocity.normalize();
    
    //TEMP IMPLEMENTATION ENDS
    //if (uPlayer->foot->kineticAction->getModelHasCollided()) {
        //finalVelocity.normalize();
    
        ball->setKickBallParameters(gameConfigs->getParameterForKey("slidingTackleKick"),finalVelocity);
        //NOTE: READ THIS changing thes tate from intercept to idle just for this game version. HERE WE MAY WANT TO EARN THE GAME, SINCE THE OPPOSITE PLAYER TOUCH THE BALL
        //uPlayer->changeState(U4DPlayerStateIdle::sharedInstance());

   // }


    if (currentAnimation->getAnimationIsPlaying()==false) {

        if (team->aiTeam) {
            
            //NOTE: READ THIS changing thes tate from intercept to idle just for this game version
            uPlayer->changeState(U4DPlayerStateIdle::sharedInstance());
        }else{
            uPlayer->changeState(U4DPlayerStateFree::sharedInstance());
        }

    }
}

void U4DPlayerStateSlidingTackle::exit(U4DPlayer *uPlayer){
    uPlayer->slidingTackle=false;
    uPlayer->allowedToKick=false;
}

bool U4DPlayerStateSlidingTackle::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStateSlidingTackle::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgSupport:
        {
            //uPlayer->changeState(U4DPlayerStateFlock::sharedInstance());
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

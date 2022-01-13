//
//  U4DPlayerStateMark.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/9/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateMark.h"
#include "U4DGameConfigs.h"
#include "U4DPlayerStateDribbling.h"
#include "U4DPlayerStateIntercept.h"
#include "U4DPlayerStateStandTackle.h" 
#include "U4DPlayerStateSlidingTackle.h"
#include "U4DPlayerStateFlock.h"
#include "U4DMessageDispatcher.h"
#include "U4DBall.h"
#include "U4DPlane.h"
#include "U4DRay.h"
#include "U4DFoot.h"
#include "U4DTeam.h"

namespace U4DEngine {

U4DPlayerStateMark* U4DPlayerStateMark::instance=0;

U4DPlayerStateMark::U4DPlayerStateMark(){
    name="mark";
}

U4DPlayerStateMark::~U4DPlayerStateMark(){
    
}

U4DPlayerStateMark* U4DPlayerStateMark::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DPlayerStateMark();
    }
    
    return instance;
    
}

void U4DPlayerStateMark::enter(U4DPlayer *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->runningAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
    U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
    
    //set speed
    uPlayer->arriveBehavior.setMaxSpeed(gameConfigs->getParameterForKey("arriveMaxSpeed"));
    
    //set the distance to stop
    uPlayer->arriveBehavior.setTargetRadius(gameConfigs->getParameterForKey("markArriveStopRadius"));
    
    //set the distance to start slowing down
    uPlayer->arriveBehavior.setSlowRadius(gameConfigs->getParameterForKey("markArriveSlowRadius"));
    
    //set the avoidance max speed
    uPlayer->avoidanceBehavior.setMaxSpeed(gameConfigs->getParameterForKey("markAvoidanceMaxSpeed"));
    
    uPlayer->avoidanceBehavior.setTimeParameter(gameConfigs->getParameterForKey("markAvoidanceTimeParameter"));
    
    
    uPlayer->pursuitBehavior.setMaxSpeed(gameConfigs->getParameterForKey("markPursuitMaxSpeed"));
    
    //set as the controlling Player
    U4DTeam *team=uPlayer->getTeam();
    team->setActivePlayer(uPlayer);
    

    
    uPlayer->foot->kineticAction->resumeCollisionBehavior(); 
    
    //inform teammates to flock
    std::vector<U4DPlayer*> teammates=team->getTeammatesForPlayer(uPlayer);
    U4DMessageDispatcher *messageDispatcher=U4DMessageDispatcher::sharedInstance();
    
    for(auto n: teammates){
        messageDispatcher->sendMessage(0.0, uPlayer, n, msgSupport);
    }
    
}

void U4DPlayerStateMark::execute(U4DPlayer *uPlayer, double dt){
    
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->runningAnimation;
    
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    U4DBall *ball=U4DBall::sharedInstance();
     
  
    //compute the final velocity
    U4DEngine::U4DVector3n finalVelocity=uPlayer->pursuitBehavior.getSteering(uPlayer->kineticAction, ball->kineticAction);
    U4DEngine::U4DVector3n ballPosition=ball->getAbsolutePosition();
    ballPosition.y=uPlayer->getAbsolutePosition().y;
    
  
  //U4DEngine::U4DVector3n finalVelocity=uPlayer->arriveBehavior.getSteering(uPlayer, ballPosition);
  
     //U4DEngine::U4DVector3n avoidanceBehavior=uPlayer->avoidanceBehavior.getSteering(uPlayer->kineticAction);

     //if (uPlayer->kineticAction->getModelHasCollidedBroadPhase()) {
//         finalVelocity=finalVelocity*0.5+avoidanceBehavior*0.5;
         
     //}
     
     //set the final y-component to zero
     finalVelocity.y=0.0;
     
     if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
         
         uPlayer->applyVelocity(finalVelocity, dt);
         uPlayer->setViewDirection(finalVelocity);
         
     }
     
      uPlayer->foot->kineticAction->resumeCollisionBehavior();
      if (uPlayer->foot->kineticAction->getModelHasCollided()) {

          uPlayer->changeState(U4DPlayerStateIntercept::sharedInstance());
      }
  
//      U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
//
//      if((ball->getAbsolutePosition()-uPlayer->getAbsolutePosition()).magnitude()<gameConfigs->getParameterForKey("interceptMinRadius")){
//
//          //create a plane with ball position and direction
//          U4DEngine::U4DPoint3n ballPosition=ball->getAbsolutePosition().toPoint();
//          U4DEngine::U4DVector3n ballNormalVector=ball->getViewInDirection();
//          ballNormalVector.normalize();
//
//          U4DEngine::U4DPlane ballPlane(ballNormalVector,ballPosition);
//
//          //create a ray with players position and direction
//          U4DEngine::U4DPoint3n playerPosition=uPlayer->getAbsolutePosition().toPoint();
//          U4DEngine::U4DVector3n playerDirection=uPlayer->dribblingDirection;
//          playerDirection.normalize();
//
//          U4DEngine::U4DPoint3n intersectionPoint;
//          float intersectionTime;
//
//          U4DEngine::U4DRay playerRay(playerPosition,playerDirection);
//
//          if (playerRay.intersectPlane(ballPlane, intersectionPoint, intersectionTime)) {
//
//              if (intersectionTime<0.5) {
//                  uPlayer->slidingVelocity=finalVelocity*gameConfigs->getParameterForKey("slidingTackleVelocity");
//                  uPlayer->changeState(U4DPlayerStateSlidingTackle::sharedInstance());
//              }
//          }
//     }
}

void U4DPlayerStateMark::exit(U4DPlayer *uPlayer){
    
}

bool U4DPlayerStateMark::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStateMark::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgSupport:
        {
            uPlayer->changeState(U4DPlayerStateFlock::sharedInstance());
        }
            break;
            
            
        default:
            break;
    }
    
    return false;
    
}

}

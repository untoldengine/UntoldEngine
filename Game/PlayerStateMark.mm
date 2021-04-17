//
//  PlayerStateMark.cpp
//  Footballer
//
//  Created by Harold Serrano on 11/5/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateMark.h"
#include "Foot.h"
#include "Team.h"
#include "PlayerStateIdle.h"
#include "PlayerStateStandTackle.h"
#include "PlayerStateSlidingTackle.h"
#include "PlayerStateGroupNav.h"
#include "PlayerStateFormation.h"
#include "MessageDispatcher.h"
#include "Ball.h"
#include "U4DPlane.h"
#include "U4DRay.h"

PlayerStateMark* PlayerStateMark::instance=0;

PlayerStateMark::PlayerStateMark(){
    name="mark";
}

PlayerStateMark::~PlayerStateMark(){
    
}

PlayerStateMark* PlayerStateMark::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateMark();
    }
    
    return instance;
    
}

void PlayerStateMark::enter(Player *uPlayer){
    
    //play the running animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    if (currentAnimation!=nullptr) {
        uPlayer->getAnimationManager()->setAnimationToPlay(currentAnimation);
    }

    //set speed
    uPlayer->arriveBehavior.setMaxSpeed(markArrivingMaxSpeed);

    //set the distance to stop
    uPlayer->arriveBehavior.setTargetRadius(markArriveStopRadius);

    //set the distance to start slowing down
    uPlayer->arriveBehavior.setSlowRadius(markArriveSlowRadius);
    
    //set the avoidance max speed
    uPlayer->avoidanceBehavior.setMaxSpeed(markAvoidanceMaxSpeed);
    
    uPlayer->avoidanceBehavior.setTimeParameter(markAvoidanceTimeParameter);
    
    //set as the controlling Player
    Team *team=uPlayer->getTeam();
    team->setMarkingPlayer(uPlayer);
    
//    //get teammates and ask for support
//    MessageDispatcher *messageDispatcher=MessageDispatcher::sharedInstance();
//
//    std::vector<Player *> teammates=team->getTeammatesForPlayer(uPlayer);
//
//    for(const auto &n:teammates){
//
//        messageDispatcher->sendMessage(0.0, uPlayer, n, msgSupport);
//
//    }
    
}

void PlayerStateMark::execute(Player *uPlayer, double dt){
    
      Ball *ball=Ball::sharedInstance();
    
       //set the target entity to approach
       U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
       
       uPlayer->updateFootSpaceWithAnimation(currentAnimation);
       
       
       //compute the final velocity
       U4DEngine::U4DVector3n finalVelocity=uPlayer->pursuitBehavior.getSteering(uPlayer, ball);
       
       U4DEngine::U4DVector3n avoidanceBehavior=uPlayer->avoidanceBehavior.getSteering(uPlayer);
       
//       if (uPlayer->getModelHasCollidedBroadPhase()) {
//           finalVelocity=finalVelocity*0.7+avoidanceBehavior*0.3;
//       }
       
       //set the final y-component to zero
       finalVelocity.y=0.0;
       
       if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
           
           uPlayer->applyVelocity(finalVelocity, dt);
           uPlayer->setMoveDirection(finalVelocity);
           
       }
       
        if((ball->getAbsolutePosition()-uPlayer->getAbsolutePosition()).magnitude()<1.0){
            
            //create a plane with ball position and direction
            U4DEngine::U4DPoint3n ballPosition=ball->getAbsolutePosition().toPoint();
            U4DEngine::U4DVector3n ballNormalVector=ball->getViewInDirection();
            ballNormalVector.normalize();
            
            U4DEngine::U4DPlane ballPlane(ballNormalVector,ballPosition);
            
            //create a ray with players position and direction
            U4DEngine::U4DPoint3n playerPosition=uPlayer->getAbsolutePosition().toPoint();
            U4DEngine::U4DVector3n playerDirection=uPlayer->forceDirection;
            playerDirection.normalize();
            
            U4DEngine::U4DPoint3n intersectionPoint;
            float intersectionTime;
            
            U4DEngine::U4DRay playerRay(playerPosition,playerDirection);
            
            if (playerRay.intersectPlane(ballPlane, intersectionPoint, intersectionTime)) {
                
                if (intersectionTime<0.5) {
                    uPlayer->changeState(PlayerStateSlidingTackle::sharedInstance());
                }
            }
       }
 
    
}

void PlayerStateMark::exit(Player *uPlayer){
    
}

bool PlayerStateMark::isSafeToChangeState(Player *uPlayer){
    
    return true;
}

bool PlayerStateMark::handleMessage(Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgSupport:
        {
            uPlayer->changeState(PlayerStateGroupNav::sharedInstance());
        }
            break;
            
        case msgFormation:
        {
            uPlayer->changeState(PlayerStateFormation::sharedInstance());
        }
            break;
            
        default:
            break;
    }
    
    return false;
    
}

//
//  PlayerStateDribble.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/30/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateDribble.h"
#include "Foot.h"
#include "Team.h"
#include "PlayerStateIdle.h"
#include "PlayerStateChase.h"
#include "PlayerStateHalt.h"
#include "PlayerStatePass.h"
#include "PlayerStateShoot.h"
#include "PlayerStateTap.h"
#include "PlayerStateGoHome.h"
#include "MessageDispatcher.h"

PlayerStateDribble* PlayerStateDribble::instance=0;

PlayerStateDribble::PlayerStateDribble(){
    name="dribble";
}

PlayerStateDribble::~PlayerStateDribble(){
    
}

PlayerStateDribble* PlayerStateDribble::sharedInstance(){
    
    if (instance==0) {
        instance=new PlayerStateDribble();
    }
    
    return instance;
    
}

void PlayerStateDribble::enter(Player *uPlayer){
    
    //play the running animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    if (currentAnimation!=nullptr) {
        uPlayer->getAnimationManager()->setAnimationToPlay(currentAnimation);
    }
    
    //set speed
    uPlayer->arriveBehavior.setMaxSpeed(arriveMaxSpeed);

    //set the distance to stop
    uPlayer->arriveBehavior.setTargetRadius(arriveStopRadius);

    //set the distance to start slowing down
    uPlayer->arriveBehavior.setSlowRadius(arriveSlowRadius);
    
    //set the avoidance max speed
    uPlayer->avoidanceBehavior.setMaxSpeed(avoidanceMaxSpeed);
    
    uPlayer->avoidanceBehavior.setTimeParameter(20.0);
    
    //set as the controlling Player
    Team *team=uPlayer->getTeam();
    team->setControllingPlayer(uPlayer);
    
    //get teammates and ask for support
    MessageDispatcher *messageDispatcher=MessageDispatcher::sharedInstance();
    
    std::vector<Player *> teammates=team->getTeammatesForPlayer(uPlayer);
    
    for(const auto &n:teammates){
        
        messageDispatcher->sendMessage(0.0, uPlayer, n, msgSupport);
    
    }
}

void PlayerStateDribble::execute(Player *uPlayer, double dt){
    
    //play the dribble animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->getAnimationToPlay();
    
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    
    
    //compute the final velocity
    U4DEngine::U4DVector3n ballPosition=uPlayer->getBallPositionOffset();
    
    //change the y-position of the ball to be the same as the player
    ballPosition.y=uPlayer->getAbsolutePosition().y;
    
    U4DEngine::U4DVector3n finalVelocity=uPlayer->arriveBehavior.getSteering(uPlayer, ballPosition);
    
//    U4DEngine::U4DVector3n avoidanceBehavior=uPlayer->avoidanceBehavior.getSteering(uPlayer);
//
//    if (uPlayer->getModelHasCollidedBroadPhase()) {
//        finalVelocity=finalVelocity*0.7+avoidanceBehavior*0.3;
//    }
    
    //set the final y-component to zero
    finalVelocity.y=0.0;
    
    
    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
        
        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setMoveDirection(finalVelocity);
        
    }else{
        
        if(uPlayer->passBall==true){

            uPlayer->changeState(PlayerStatePass::sharedInstance());

        }else if(uPlayer->shootBall==true){

            uPlayer->changeState(PlayerStateShoot::sharedInstance());

        }
        else if(uPlayer->haltBall==true){

            uPlayer->changeState(PlayerStateHalt::sharedInstance());

        }
         
    }
    
    
    
    if (currentAnimation->getAnimationIsPlaying()==true && currentAnimation->getCurrentKeyframe()>1) {
        
        uPlayer->rightFoot->resumeCollisionBehavior();
        uPlayer->rightFoot->setKickBallParameters(dribbleBallSpeed,uPlayer->dribblingDirection);
        
        
    }
}

void PlayerStateDribble::exit(Player *uPlayer){
    
    uPlayer->dribbleBall=false;
    
}

bool PlayerStateDribble::isSafeToChangeState(Player *uPlayer){
    
    return true;
}

bool PlayerStateDribble::handleMessage(Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgGoHome:
        {
            uPlayer->changeState(PlayerStateGoHome::sharedInstance());
        }
            break;
            
        default:
            break;
    }
    
    return false;
    
}

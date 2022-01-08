//
//  U4DPlayerStateDribbling.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/17/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateDribbling.h"
#include "U4DGameConfigs.h"
#include "U4DBall.h"
#include "U4DFoot.h"
#include "U4DPlayerStateShooting.h"
#include "U4DPlayerStatePass.h"
#include "U4DPlayerStateHalt.h"
#include "U4DPlayerStateFlock.h"
#include "U4DMessageDispatcher.h"
#include "U4DTeam.h"

namespace U4DEngine {

U4DPlayerStateDribbling* U4DPlayerStateDribbling::instance=0;

U4DPlayerStateDribbling::U4DPlayerStateDribbling(){
    name="dribbling";
}

U4DPlayerStateDribbling::~U4DPlayerStateDribbling(){
    
}

U4DPlayerStateDribbling* U4DPlayerStateDribbling::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DPlayerStateDribbling();
    }
    
    return instance;
    
}

void U4DPlayerStateDribbling::enter(U4DPlayer *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->runningAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
    U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
    
    uPlayer->arriveBehavior.setMaxSpeed(gameConfigs->getParameterForKey("arriveMaxSpeed"));
    uPlayer->arriveBehavior.setTargetRadius(gameConfigs->getParameterForKey("arriveStopRadius"));
    uPlayer->arriveBehavior.setSlowRadius(gameConfigs->getParameterForKey("arriveSlowRadius"));
    
    //set player as controlling player
    U4DTeam *team=uPlayer->getTeam();
    team->setControllingPlayer(uPlayer);
    
    uPlayer->setEnableDribbling(false);
    
    std::vector<U4DPlayer*> teammates=team->getTeammatesForPlayer(uPlayer);
    U4DMessageDispatcher *messageDispatcher=U4DMessageDispatcher::sharedInstance();
    
    for(auto n: teammates){
        messageDispatcher->sendMessage(0.0, uPlayer, n, msgSupport);
    }
}

void U4DPlayerStateDribbling::execute(U4DPlayer *uPlayer, double dt){
    
    uPlayer->updateFootSpaceWithAnimation(uPlayer->runningAnimation);
    
    U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();

    U4DBall *ball=U4DBall::sharedInstance();
    
    U4DEngine::U4DVector3n ballPosition=ball->getAbsolutePosition();
    ballPosition.y=uPlayer->getAbsolutePosition().y;


    U4DEngine::U4DVector3n finalVelocity=uPlayer->arriveBehavior.getSteering(uPlayer->kineticAction, ballPosition);
    
    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setViewDirection(finalVelocity);

    }else{

        if(uPlayer->shootBall==true){

            uPlayer->changeState(U4DPlayerStateShooting::sharedInstance());

        }else if(uPlayer->passBall==true){
            uPlayer->changeState(U4DPlayerStatePass::sharedInstance());
        }else if(uPlayer->haltBall==true){
            ball->changeState(stopped);
            uPlayer->changeState(U4DPlayerStateHalt::sharedInstance());
            
        }

    }

    
    uPlayer->foot->kineticAction->resumeCollisionBehavior();

    uPlayer->foot->setKickBallParameters(gameConfigs->getParameterForKey("dribblingBallSpeed"), uPlayer->dribblingDirection);
    
    uPlayer->previousPosition=uPlayer->getAbsolutePosition();
}

void U4DPlayerStateDribbling::exit(U4DPlayer *uPlayer){
    
}

bool U4DPlayerStateDribbling::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStateDribbling::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}

}


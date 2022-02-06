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
#include "U4DTeam.h"
#include "U4DFoot.h"

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
    
    //play the idle animation
    U4DAnimation *currentAnimation=uPlayer->slidingTackleAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
    
}

void U4DPlayerStateSlidingTackle::execute(U4DPlayer *uPlayer, double dt){
    
    U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
    
    U4DAnimation *currentAnimation=uPlayer->slidingTackleAnimation;
    
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    U4DTeam *team=uPlayer->getTeam();
    
    U4DVector3n finalVelocity=uPlayer->dribblingDirection;
    
    finalVelocity*=gameConfigs->getParameterForKey("slidingTackleVelocity");
    
    if(!(uPlayer->slidingVelocity==U4DVector3n(0.0,0.0,0.0))){
        
        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setMoveDirection(finalVelocity);
        
    }
   
    uPlayer->foot->kineticAction->resumeCollisionBehavior();

    if (uPlayer->foot->kineticAction->getModelHasCollided()) {
        finalVelocity.normalize();
        
        uPlayer->foot->setKickBallParameters(gameConfigs->getParameterForKey("slidingTackleKick"),finalVelocity);

        uPlayer->changeState(U4DPlayerStateIntercept::sharedInstance());

    }


    if (currentAnimation->getAnimationIsPlaying()==false) {

        if (team->aiTeam) {
            uPlayer->changeState(U4DPlayerStateIntercept::sharedInstance());
        }else{
            uPlayer->changeState(U4DPlayerStateFree::sharedInstance());
        }

    }
}

void U4DPlayerStateSlidingTackle::exit(U4DPlayer *uPlayer){
    uPlayer->slidingTackle=false;
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

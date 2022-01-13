//
//  U4DPlayerStateStandTackle.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/9/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateStandTackle.h"
#include "U4DGameConfigs.h"
#include "U4DPlayerStateDribbling.h"
#include "U4DPlayerStateIntercept.h"
#include "U4DPlayerStateFree.h"
#include "U4DPlayerStateFlock.h"
#include "U4DFoot.h"

namespace U4DEngine {

U4DPlayerStateStandTackle* U4DPlayerStateStandTackle::instance=0;

U4DPlayerStateStandTackle::U4DPlayerStateStandTackle(){
    name="tackle";
}

U4DPlayerStateStandTackle::~U4DPlayerStateStandTackle(){
    
}

U4DPlayerStateStandTackle* U4DPlayerStateStandTackle::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DPlayerStateStandTackle();
    }
    
    return instance;
    
}

void U4DPlayerStateStandTackle::enter(U4DPlayer *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->standTackleAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
    //remove all velocities from the character
    U4DVector3n zero(0.0,0.0,0.0);
    
    uPlayer->kineticAction->setVelocity(zero);
    uPlayer->kineticAction->setAngularVelocity(zero);
    
}

void U4DPlayerStateStandTackle::execute(U4DPlayer *uPlayer, double dt){
    
    U4DAnimation *currentAnimation=uPlayer->standTackleAnimation;
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    U4DEngine::U4DVector3n dir=uPlayer->getViewInDirection();
    
    if (currentAnimation->getAnimationIsPlaying()==true && currentAnimation->getCurrentKeyframe()>0) {
        
        U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
        
        uPlayer->foot->kineticAction->resumeCollisionBehavior();
        uPlayer->foot->setKickBallParameters(gameConfigs->getParameterForKey("slidingTackleKick"),dir);
    }
    
    if (currentAnimation->getAnimationIsPlaying()==false) {
        
        uPlayer->changeState(U4DPlayerStateFlock::sharedInstance());
    
    }
}

void U4DPlayerStateStandTackle::exit(U4DPlayer *uPlayer){
    
}

bool U4DPlayerStateStandTackle::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStateStandTackle::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
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

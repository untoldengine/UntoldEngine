//
//  U4DPlayerStateFalling.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/2/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateFalling.h"
#include "U4DGameConfigs.h"
#include "U4DPlayerStateDribbling.h"
#include "U4DPlayerStateIntercept.h"
#include "U4DPlayerStateFree.h"
#include "U4DPlayerStateFlock.h"
#include "U4DPlayerStateMark.h"
#include "U4DPlayerStateGoHome.h"

#include "U4DPlayerStateIdle.h"

namespace U4DEngine {

U4DPlayerStateFalling* U4DPlayerStateFalling::instance=0;

U4DPlayerStateFalling::U4DPlayerStateFalling(){
    name="falling";
}

U4DPlayerStateFalling::~U4DPlayerStateFalling(){
    
}

U4DPlayerStateFalling* U4DPlayerStateFalling::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DPlayerStateFalling();
    }
    
    return instance;
    
}

void U4DPlayerStateFalling::enter(U4DPlayer *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->idleAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
  
    //reset gravity
    uPlayer->kineticAction->resetGravity();
    
    uPlayer->kineticAction->resumeCollisionBehavior();
    
}

void U4DPlayerStateFalling::execute(U4DPlayer *uPlayer, double dt){
    
    uPlayer->updateFootSpaceWithAnimation(uPlayer->idleAnimation);
    
    
//    if(uPlayer->kineticAction->getModelHasCollided()){
//
//        std::vector<U4DStaticAction*> n=uPlayer->kineticAction->getCollisionList();
//        if(n.size()>0){
//
//            U4DModel *model=n.at(0)->model;
//            std::cout<<"model name: "<<model->getName()<<std::endl;
//            uPlayer->setIntersectingObstacle(model);
//
//            if (uPlayer->testObstacleIntersection()) {
//
//                U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
//                uPlayer->kineticAction->setGravity(zero);
//                uPlayer->kineticAction->setVelocity(zero);
//                uPlayer->kineticAction->setAngularVelocity(zero);
//
//                uPlayer->changeState(U4DPlayerStateIdle::sharedInstance());
//
//            }
//        }
//
//    }
    
}

void U4DPlayerStateFalling::exit(U4DPlayer *uPlayer){
    
    
}

bool U4DPlayerStateFalling::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStateFalling::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}

}

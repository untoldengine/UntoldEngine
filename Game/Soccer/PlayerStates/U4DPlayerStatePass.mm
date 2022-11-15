//
//  U4DPlayerStatePass.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/14/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStatePass.h"
#include "U4DGameConfigs.h"
#include "U4DPlayerStateIdle.h"
#include "U4DPlayAnalyzer.h"
#include "U4DMessageDispatcher.h"
#include "U4DTeam.h"
#include "U4DBall.h"

namespace U4DEngine {

U4DPlayerStatePass* U4DPlayerStatePass::instance=0;

U4DPlayerStatePass::U4DPlayerStatePass(){
    name="passing";
}

U4DPlayerStatePass::~U4DPlayerStatePass(){
    
}

U4DPlayerStatePass* U4DPlayerStatePass::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DPlayerStatePass();
    }
    
    return instance;
    
}

void U4DPlayerStatePass::enter(U4DPlayer *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->passingAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
    uPlayer->allowedToKick=true;
    passedBallSuccessfull=false;
    
}

void U4DPlayerStatePass::execute(U4DPlayer *uPlayer, double dt){
    
    U4DBall *ball=U4DBall::sharedInstance();
    
    U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
    
    U4DVector3n v=uPlayer->getViewInDirection();
    
    ball->setKickBallParameters(gameConfigs->getParameterForKey("passBallSpeed"),v);
    
    passedBallSuccessfull=true;
        
        
    if (uPlayer->passingAnimation->getAnimationIsPlaying()==false && passedBallSuccessfull==false) {

        std::cout<<"Missed the ball"<<std::endl;
        uPlayer->setEnableDribbling(true);
        uPlayer->changeState(U4DPlayerStateIdle::sharedInstance());
        
    }else if(uPlayer->passingAnimation->getAnimationIsPlaying()==false && passedBallSuccessfull==true){
        uPlayer->changeState(U4DPlayerStateIdle::sharedInstance());
    }
    
    
}

void U4DPlayerStatePass::exit(U4DPlayer *uPlayer){
    
    uPlayer->passBall=false;
    uPlayer->dribbleBall=false;
    uPlayer->allowedToKick=false;
    
    //set player as controlling player
    U4DTeam *team=uPlayer->getTeam();
    
    if(passedBallSuccessfull && team!=nullptr){
        //get closest player to intersect the ball
        U4DPlayAnalyzer *playAnalyzer=U4DPlayAnalyzer::sharedInstance();

        U4DPlayer *teammate=playAnalyzer->closestTeammateToIntersectBall(uPlayer);
        
        team->setActivePlayer(teammate);
        
        //send message to player
        U4DMessageDispatcher *messageDispatcher=U4DMessageDispatcher::sharedInstance();

        messageDispatcher->sendMessage(0.0, uPlayer, teammate, msgInterceptBall);
            
    }
    
    
}

bool U4DPlayerStatePass::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStatePass::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}

}

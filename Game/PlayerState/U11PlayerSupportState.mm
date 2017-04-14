//
//  U11PlayerSupportState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/18/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerSupportState.h"

#include "U11PlayerIdleState.h"
#include "U11PlayerDribbleState.h"
#include "U11PlayerRunToSupportState.h"
#include "U11PlayerReceiveBallState.h"
#include "U11PlayerReverseRunState.h"
#include "U11PlayerLateralRunState.h"
#include "UserCommonProtocols.h"
#include "U11Team.h"

U11PlayerSupportState* U11PlayerSupportState::instance=0;

U11PlayerSupportState::U11PlayerSupportState(){
    
}

U11PlayerSupportState::~U11PlayerSupportState(){
    
}

U11PlayerSupportState* U11PlayerSupportState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerSupportState();
    }
    
    return instance;
}

void U11PlayerSupportState::enter(U11Player *uPlayer){
    
    //set run animation
    uPlayer->setNextAnimationToPlay(uPlayer->getIdleAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    
}

void U11PlayerSupportState::execute(U11Player *uPlayer, double dt){
    
    //get the team
    
    U11Team *team=uPlayer->getTeam();
    
    U11Player *controllingPlayer=team->getControllingPlayer();
    
    //check if the controlling player is dribbling
    if(controllingPlayer->getCurrentState()==U11PlayerDribbleState::sharedInstance()) {
    
        U4DEngine::U4DVector3n controllingPlayerHeading=controllingPlayer->getPlayerHeading();
        
        U4DEngine::U4DVector3n distanceVector=controllingPlayer->getAbsolutePosition()-uPlayer->getAbsolutePosition();
        
        float distanceMagnitude=distanceVector.magnitude();
        
        controllingPlayerHeading.normalize();
        
        distanceVector.normalize();
        
        float headingDotDistance=controllingPlayerHeading.dot(distanceVector);
        
        //Run to support
        
        if (distanceMagnitude<=supportMinimumDistanceToPlayer) {
            
            //Run to support
            //uPlayer->changeState(U11PlayerRunToSupportState::sharedInstance());
            
        }else if (distanceMagnitude>supportMinimumDistanceToPlayer && distanceMagnitude<supportMaximumDistanceToPlayer){
            
            if (headingDotDistance<-0.5 && headingDotDistance>-0.95) {
                
                //run in reverse
                uPlayer->changeState(U11PlayerReverseRunState::sharedInstance());
                
            }else if (headingDotDistance<0.0 && headingDotDistance>=-0.5){
                
                //run laterally
                uPlayer->changeState(U11PlayerLateralRunState::sharedInstance());
                
            }else if(headingDotDistance>=0){
                
                //Run to support
                //uPlayer->changeState(U11PlayerRunToSupportState::sharedInstance());
                
            }
            
        }
        
    }
    
    //faceball
    uPlayer->seekBall();
}

void U11PlayerSupportState::exit(U11Player *uPlayer){
    
}

bool U11PlayerSupportState::isSafeToChangeState(U11Player *uPlayer){
    return true;
}

bool U11PlayerSupportState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        case msgReceiveBall:
            
            //change state to receive ball
            uPlayer->changeState(U11PlayerReceiveBallState::sharedInstance());
            
            break;
            
        case msgPassToMe:
            
            break;
        
        case msgRunToSupport:
            
            if (!uPlayer->hasReachedPosition(uPlayer->getSupportPosition(),withinSupportDistance)) {
                uPlayer->changeState(U11PlayerRunToSupportState::sharedInstance());
            }
            
            break;
            
        default:
            break;
    }
    
    return false;
}

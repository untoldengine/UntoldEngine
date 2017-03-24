//
//  U11PlayerReverseRunState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/21/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerReverseRunState.h"
#include "U11Team.h"
#include "U11PlayerSupportState.h"
#include "U11PlayerDribbleState.h"
#include "U11PlayerLateralRunState.h"
#include "U11PlayerRunToSupportState.h"

U11PlayerReverseRunState* U11PlayerReverseRunState::instance=0;

U11PlayerReverseRunState::U11PlayerReverseRunState(){
    
}

U11PlayerReverseRunState::~U11PlayerReverseRunState(){
    
}

U11PlayerReverseRunState* U11PlayerReverseRunState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerReverseRunState();
    }
    
    return instance;
    
}

void U11PlayerReverseRunState::enter(U11Player *uPlayer){
    
    //set reverse run animation
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);

}

void U11PlayerReverseRunState::execute(U11Player *uPlayer, double dt){
    
    U11Team *team=uPlayer->getTeam();
    
    U11Player *controllingPlayer=team->getControllingPlayer();
    
    if(controllingPlayer->getCurrentState()==U11PlayerDribbleState::sharedInstance()) {
        
        U4DEngine::U4DVector3n controllingPlayerHeading=controllingPlayer->getPlayerHeading();
        
        U4DEngine::U4DVector3n distanceVector=controllingPlayer->getAbsolutePosition()-uPlayer->getAbsolutePosition();
        
        float distanceMagnitude=distanceVector.magnitude();
        
        controllingPlayerHeading.normalize();
        
        distanceVector.normalize();
        
        float headingDotDistance=controllingPlayerHeading.dot(distanceVector);
        
        
        if (distanceMagnitude<=supportMinimumDistanceToPlayer || headingDotDistance>=-0.5) {
            
            uPlayer->changeState(U11PlayerRunToSupportState::sharedInstance());
            
        }else{
            
            U4DEngine::U4DVector3n playerHeading=controllingPlayer->getPlayerHeading()*-1.0;
            
            playerHeading.y=controllingPlayer->getAbsolutePosition().y;
            
            uPlayer->setPlayerHeading(playerHeading);
            
            //chase the ball
            uPlayer->applyForceToPlayer(-reverseRunningSpeed, dt);
            
        }
        
    }else{
        
        uPlayer->removeAllVelocities();
        uPlayer->removeKineticForces();
        
        uPlayer->changeState(U11PlayerSupportState::sharedInstance());
    }
    
}

void U11PlayerReverseRunState::exit(U11Player *uPlayer){
    
}

bool U11PlayerReverseRunState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerReverseRunState::handleMessage(U11Player *uPlayer, Message &uMsg){
    

    
    return false;
}

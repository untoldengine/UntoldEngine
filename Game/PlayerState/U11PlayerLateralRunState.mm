//
//  U11PlayerLateralRunState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/21/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerLateralRunState.h"
#include "U11PlayerDribbleState.h"
#include "U11PlayerRunToSupportState.h"
#include "U11PlayerSupportState.h"
#include "U11Team.h"

U11PlayerLateralRunState* U11PlayerLateralRunState::instance=0;

U11PlayerLateralRunState::U11PlayerLateralRunState(){
    
}

U11PlayerLateralRunState::~U11PlayerLateralRunState(){
    
}

U11PlayerLateralRunState* U11PlayerLateralRunState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerLateralRunState();
    }
    
    return instance;
    
}

void U11PlayerLateralRunState::enter(U11Player *uPlayer){
    
    U11Team *team=uPlayer->getTeam();
    
    U4DEngine::U4DVector3n controllingPlayerHeading=team->getControllingPlayer()->getPlayerHeading();
    
    U4DEngine::U4DVector3n supportPlayerHeading=uPlayer->getPlayerHeading();
    
    U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);
    
    U4DEngine::U4DVector3n supportRightHand=supportPlayerHeading.cross(upVector);
    
    if (supportRightHand.dot(controllingPlayerHeading)>0.0) {
        
        //play right lateral movement
        uPlayer->setNextAnimationToPlay(uPlayer->getLateralRightRunAnimation());
        
    }else{
        
        //play left lateral movement
        uPlayer->setNextAnimationToPlay(uPlayer->getLateralLeftRunAnimation());
    }
    
    
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);
    
}

void U11PlayerLateralRunState::execute(U11Player *uPlayer, double dt){
    
    U11Team *team=uPlayer->getTeam();
    
    U11Player *controllingPlayer=team->getControllingPlayer();
    
    U4DEngine::U4DVector3n controllingPlayerHeading=controllingPlayer->getPlayerHeading();
    
    U4DEngine::U4DVector3n distanceVector=controllingPlayer->getAbsolutePosition()-uPlayer->getAbsolutePosition();
    
    float distanceMagnitude=distanceVector.magnitude();
    
    controllingPlayerHeading.normalize();
    
    distanceVector.normalize();
    
    float headingDotDistance=controllingPlayerHeading.dot(distanceVector);
        
    if(controllingPlayer->getCurrentState()==U11PlayerDribbleState::sharedInstance()) {
        
        if (distanceMagnitude<=supportMinimumDistanceToPlayer || headingDotDistance>=0) {
            
            uPlayer->changeState(U11PlayerRunToSupportState::sharedInstance());
            
        }else{
            
            //run lateraly
            uPlayer->applyForceToPlayerInDirection(lateralRunningSpeed, controllingPlayerHeading , dt);
            
        }
        
    }else{
        
        uPlayer->removeAllVelocities();
        uPlayer->removeKineticForces();
        
        uPlayer->changeState(U11PlayerSupportState::sharedInstance());
    }
    
}

void U11PlayerLateralRunState::exit(U11Player *uPlayer){
    
}

bool U11PlayerLateralRunState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerLateralRunState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    
    
    return false;
}

//
//  GuardianIdleState.c
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "GuardianIdleState.h"
#include "GuardianRunState.h"

GuardianIdleState* GuardianIdleState::instance=0;

GuardianIdleState::GuardianIdleState(){
    
}

GuardianIdleState::~GuardianIdleState(){
    
}

GuardianIdleState* GuardianIdleState::sharedInstance(){
    
    if (instance==0) {
        instance=new GuardianIdleState();
    }
    
    return instance;
    
}

void GuardianIdleState::enter(GuardianModel *uGuardian){
    
    U4DEngine::U4DVector3n grav(0.0,0.0,0.0);
    uGuardian->setGravity(grav);
    
    //set the idle animation
    U4DEngine::U4DVector3n zero(0.0,0.0,0.0);
    
    uGuardian->setVelocity(zero);
    uGuardian->setAngularVelocity(zero);
    
}

void GuardianIdleState::execute(GuardianModel *uGuardian, double dt){
    
}

void GuardianIdleState::exit(GuardianModel *uGuardian){
    
}

bool GuardianIdleState::isSafeToChangeState(GuardianModel *uGuardian){
    
    return true;
}

bool GuardianIdleState::handleMessage(GuardianModel *uGuardian, Message &uMsg){
    
    switch (uMsg.msg) {
            
        case msgJoystickActive:
        {
            
            uGuardian->changeState(GuardianRunState::sharedInstance());
        }
            break;
       
        default:
            break;
    }
    
    return false;
}

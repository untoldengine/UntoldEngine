//
//  GuardianRunState.c
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "GuardianRunState.h"
#include "GuardianIdleState.h"

GuardianRunState* GuardianRunState::instance=0;

GuardianRunState::GuardianRunState(){
    
}

GuardianRunState::~GuardianRunState(){
    
}

GuardianRunState* GuardianRunState::sharedInstance(){
    
    if (instance==0) {
        instance=new GuardianRunState();
    }
    
    return instance;
    
}

void GuardianRunState::enter(GuardianModel *uGuardian){
    
    U4DEngine::U4DVector3n grav(0.0,0.0,0.0);
    uGuardian->setGravity(grav);
    
    uGuardian->playAnimation();
    
}

void GuardianRunState::execute(GuardianModel *uGuardian, double dt){
    
    uGuardian->applyForceToPlayer(5.0, dt);
    
}

void GuardianRunState::exit(GuardianModel *uGuardian){
    uGuardian->stopAnimation();
}

bool GuardianRunState::isSafeToChangeState(GuardianModel *uGuardian){
    
    return true;
}

bool GuardianRunState::handleMessage(GuardianModel *uGuardian, Message &uMsg){
    
    switch (uMsg.msg) {
            
        case msgJoystickNotActive:
        {
            uGuardian->changeState(GuardianIdleState::sharedInstance());
        }
            break;
            
        default:
            break;
    }
    
    return false;
}

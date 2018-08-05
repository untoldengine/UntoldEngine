//
//  GuardianJumpState.c
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "GuardianJumpState.h"

GuardianJumpState* GuardianJumpState::instance=0;

GuardianJumpState::GuardianJumpState(){
    
}

GuardianJumpState::~GuardianJumpState(){
    
}

GuardianJumpState* GuardianJumpState::sharedInstance(){
    
    if (instance==0) {
        instance=new GuardianJumpState();
    }
    
    return instance;
    
}

void GuardianJumpState::enter(GuardianModel *uGuardian){
    
    //set the idle animation
    
}

void GuardianJumpState::execute(GuardianModel *uGuardian, double dt){
    
}

void GuardianJumpState::exit(GuardianModel *uGuardian){
    
}

bool GuardianJumpState::isSafeToChangeState(GuardianModel *uGuardian){
    
    return true;
}

bool GuardianJumpState::handleMessage(GuardianModel *uGuardian, Message &uMsg){
    
    switch (uMsg.msg) {
            
            
            
        default:
            break;
    }
    
    return false;
}

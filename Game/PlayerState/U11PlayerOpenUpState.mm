//
//  U11PlayerOpenUpState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/21/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerOpenUpState.h"
U11PlayerOpenUpState* U11PlayerOpenUpState::instance=0;

U11PlayerOpenUpState::U11PlayerOpenUpState(){
    
}

U11PlayerOpenUpState::~U11PlayerOpenUpState(){
    
}

U11PlayerOpenUpState* U11PlayerOpenUpState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerOpenUpState();
    }
    
    return instance;
    
}

void U11PlayerOpenUpState::enter(U11Player *uPlayer){
    
    
}

void U11PlayerOpenUpState::execute(U11Player *uPlayer, double dt){
    
    
    
}

void U11PlayerOpenUpState::exit(U11Player *uPlayer){
    
}

bool U11PlayerOpenUpState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerOpenUpState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    
    
    return false;
}

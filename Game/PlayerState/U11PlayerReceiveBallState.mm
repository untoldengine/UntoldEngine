//
//  U11PlayerReceiveBallState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/2/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerReceiveBallState.h"
#include "U11PlayerTakeBallControlState.h"

U11PlayerReceiveBallState* U11PlayerReceiveBallState::instance=0;

U11PlayerReceiveBallState::U11PlayerReceiveBallState(){
    
}

U11PlayerReceiveBallState::~U11PlayerReceiveBallState(){
    
}

U11PlayerReceiveBallState* U11PlayerReceiveBallState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerReceiveBallState();
    }
    
    return instance;
    
}

void U11PlayerReceiveBallState::enter(U11Player *uPlayer){
    
   
}

void U11PlayerReceiveBallState::execute(U11Player *uPlayer, double dt){
    
    
}

void U11PlayerReceiveBallState::exit(U11Player *uPlayer){
    
}

bool U11PlayerReceiveBallState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerReceiveBallState::handleMessage(U11Player *uPlayer, Message &uMsg){
    return false;
}

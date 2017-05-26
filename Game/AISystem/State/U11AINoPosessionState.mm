//
//  U11AINoPosessionState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/23/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11AINoPosessionState.h"
#include "U11AISystem.h"

U11AINoPosessionState* U11AINoPosessionState::instance=0;

U11AINoPosessionState::U11AINoPosessionState(){
    
}

U11AINoPosessionState::~U11AINoPosessionState(){
    
}

U11AINoPosessionState* U11AINoPosessionState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11AINoPosessionState();
    }
    
    return instance;
    
}

void U11AINoPosessionState::enter(U11AISystem *uAISystem){

    std::cout<<"No Posession"<<std::endl;
}

void U11AINoPosessionState::execute(U11AISystem *uAISystem, double dt){
    
    
}

void U11AINoPosessionState::exit(U11AISystem *uAISystem){

    
}

bool U11AINoPosessionState::handleMessage(U11AISystem *uAISystem, Message &uMsg){
    
    return false;
    
}

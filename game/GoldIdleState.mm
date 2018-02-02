//
//  GoldIdleState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "GoldIdleState.h"
#include "GoldEatenState.h"
GoldIdleState* GoldIdleState::instance=0;

GoldIdleState::GoldIdleState(){
    
}

GoldIdleState::~GoldIdleState(){
    
}

GoldIdleState* GoldIdleState::sharedInstance(){
    
    if (instance==0) {
        instance=new GoldIdleState();
    }
    
    return instance;
    
}

void GoldIdleState::enter(GoldAsset *uGold){
    
    //set the idle animation
    
}

void GoldIdleState::execute(GoldAsset *uGold, double dt){
    
    uGold->rotateBy(0.0, 1.0, 0.0);
    
    if (uGold->getModelHasCollided()) {
        
        uGold->changeState(GoldEatenState::sharedInstance());
        
    }
}

void GoldIdleState::exit(GoldAsset *uGold){
    
}

bool GoldIdleState::isSafeToChangeState(GoldAsset *uGold){
    
    return true;
}

bool GoldIdleState::handleMessage(GoldAsset *uGold, Message &uMsg){
    
    switch (uMsg.msg) {
            
        default:
            break;
    }
    
    return false;
}

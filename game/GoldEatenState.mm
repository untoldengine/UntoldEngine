//
//  GoldEatenState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "GoldEatenState.h"
GoldEatenState* GoldEatenState::instance=0;

GoldEatenState::GoldEatenState(){
    
}

GoldEatenState::~GoldEatenState(){
    
}

GoldEatenState* GoldEatenState::sharedInstance(){
    
    if (instance==0) {
        instance=new GoldEatenState();
    }
    
    return instance;
    
}

void GoldEatenState::enter(GoldAsset *uGold){
    
    //remove from scenegraph
    uGold->createParticle();
    uGold->removeFromScenegraph();
}

void GoldEatenState::execute(GoldAsset *uGold, double dt){
    
}

void GoldEatenState::exit(GoldAsset *uGold){
    
}

bool GoldEatenState::isSafeToChangeState(GoldAsset *uGold){
    
    return true;
}

bool GoldEatenState::handleMessage(GoldAsset *uGold, Message &uMsg){
    
    switch (uMsg.msg) {
            
        default:
            break;
    }
    
    return false;
}

//
//  Tank.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/6/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "Tank.h"
#include "TankHead.h"
#include "U4DCamera.h"
#include "U4DDigitalAssetLoader.h"
#include "U4DAnimation.h"
#include "GameAsset.h"
#include "U4DWorld.h"

void Tank::init(const char* uName, const char* uBlenderFile){
    
    
    if (loadModel(uName, uBlenderFile)) {
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,1);
        setEntityForwardVector(viewDirectionVector);
        
        tankHead=new TankHead();
        
        tankHead->init("tankhead", "blenderscript.u4d");
        
        addChild(tankHead);
    }
    
    
}

void Tank::update(double dt){
    
    if (getState()==kRotating) {
        
        
    }
    
}

void Tank::setState(GameEntityState uState){
    entityState=uState;
}

GameEntityState Tank::getState(){
    return entityState;
}

void Tank::changeState(GameEntityState uState){
    
    
    setState(uState);
    
    switch (uState) {
        case kRotating:
            
            break;
            
        case kWalking:
            
            
            break;
            
        case kJump:
            
            
            break;
            
        default:
            
            break;
    }
    
}

TankHead* Tank::getTankHead(){
    return tankHead;
}


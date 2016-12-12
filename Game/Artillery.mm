//
//  Artillery.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/7/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "Artillery.h"

#include "U4DCamera.h"
#include "U4DDigitalAssetLoader.h"
#include "U4DAnimation.h"
#include "GameAsset.h"
#include "U4DWorld.h"


Artillery::Artillery():joyStickData(0.0,0.0,0.0),world(NULL),isDestroyed(false){

}

Artillery::~Artillery(){
    
    world->removeChild(this);
}

void Artillery::init(const char* uName, const char* uBlenderFile){
    
    
    if (loadModel(uName, uBlenderFile)) {
    
        
    }
    
    
}

void Artillery::update(double dt){
    
    
}

void Artillery::setWorld(U4DEngine::U4DWorld *uWorld){
    
    world=uWorld;
}

void Artillery::setState(GameEntityState uState){
    entityState=uState;
}

GameEntityState Artillery::getState(){
    return entityState;
}

void Artillery::shoot(){
    
    changeState(kShooting);
}

void Artillery::changeState(GameEntityState uState){
    
    
    setState(uState);
    
    switch (uState) {
        case kAiming:
            
            break;
            
        case kShooting:
            
            
            break;
            
        default:
            
            break;
    }
    
}

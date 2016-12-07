//
//  TankHead.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/6/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "TankHead.h"
#include "U4DDigitalAssetLoader.h"
#include "U4DAnimation.h"
#include "GameAsset.h"
#include "U4DWorld.h"

void TankHead::init(const char* uName, const char* uBlenderFile){
    
    
    if (loadModel(uName, uBlenderFile)) {
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,1);
        setEntityForwardVector(viewDirectionVector);
        
    }
    
}

void TankHead::update(double dt){
    
    if (getState()==kRotating) {
        
        U4DEngine::U4DVector3n setView(joyStickData.x,getAbsolutePosition().y,0.0);
        
        viewInDirection(setView);
        
        
    }
    
}

void TankHead::setState(GameEntityState uState){
    entityState=uState;
}

GameEntityState TankHead::getState(){
    return entityState;
}

void TankHead::changeState(GameEntityState uState){
    
    
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

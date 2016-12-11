//
//  AirplaneParts.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/10/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "AirplanePart.h"

void AirplanePart::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        
    }
    
    
}

void AirplanePart::update(double dt){
    
    
}

void AirplanePart::setState(GameEntityState uState){
    entityState=uState;
}

GameEntityState AirplanePart::getState(){
    return entityState;
}

void AirplanePart::changeState(GameEntityState uState){
    
    
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

//
//  AirplaneRotor.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/10/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "AirplaneRotor.h"
#include "UserCommonProtocols.h"

AirplaneRotor::AirplaneRotor():rotorAngle(0){

}

AirplaneRotor::~AirplaneRotor(){

}

void AirplaneRotor::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        
        changeState(kFlying);
    }
    
    
}

void AirplaneRotor::update(double dt){
    
    if (getState()==kFlying) {
        
        rotateTo(0.0,0.0,rotorAngle);
        
        rotorAngle+=10;
        
        if (rotorAngle>360) {
            rotorAngle=0;
        }
        
        
    }
    
}


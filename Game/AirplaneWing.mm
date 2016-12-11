//
//  AirplaneWing.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/10/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "AirplaneWing.h"
#include "UserCommonProtocols.h"

AirplaneWing::AirplaneWing(){
    
}

AirplaneWing::~AirplaneWing(){
    
}

void AirplaneWing::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        
        changeState(kFlying);
    }
    
    
}

void AirplaneWing::update(double dt){
    
    if (getState()==kFlying) {
    
        
        
    }
    
}

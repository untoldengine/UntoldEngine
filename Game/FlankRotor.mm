//
//  FlankRotor.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/8/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "FlankRotor.h"
#include "AimLeftRight.h"


FlankRotor::FlankRotor(){
    
    WeaponBehavior* aimLeftRight=new AimLeftRight();
    
    setWeaponBehavior(aimLeftRight);
    
}

FlankRotor::~FlankRotor(){
    
}

void FlankRotor::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        changeState(kNull);
        
    }
    
    
}

void FlankRotor::update(double dt){
    
    if (getState()==kAiming) {
        
        
        aim(joyStickData);
        
    }
    
}

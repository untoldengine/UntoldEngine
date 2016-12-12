//
//  AntiAircraftRotor.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/8/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "AntiAircraftRotor.h"
#include "AimLeftRight.h"


AntiAircraftRotor::AntiAircraftRotor(){
    
    WeaponBehavior* aimLeftRight=new AimLeftRight();
    
    setWeaponBehavior(aimLeftRight);
    
}

AntiAircraftRotor::~AntiAircraftRotor(){
    
}

void AntiAircraftRotor::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        changeState(kNull);
        
    }
    
    
}

void AntiAircraftRotor::update(double dt){
    
    if (getState()==kAiming) {
        
        
        aim(joyStickData);
        
    }
    
}

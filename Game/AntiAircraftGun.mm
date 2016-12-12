//
//  AntiAircraftGun.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/8/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "AntiAircraftGun.h"
#include "AimUpDown.h"


AntiAircraftGun::AntiAircraftGun(){
    
    WeaponBehavior* aimLeftRight=new AimUpDown();
    
    setWeaponBehavior(aimLeftRight);
    
}

AntiAircraftGun::~AntiAircraftGun(){
    
}

void AntiAircraftGun::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        changeState(kNull);
        
    }
    
    
}

void AntiAircraftGun::update(double dt){
    
    if (getState()==kAiming) {
        
        aim(joyStickData);
        
    }
    
}

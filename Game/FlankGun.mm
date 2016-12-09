//
//  FlankGun.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/8/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "FlankGun.h"
#include "AimUpDown.h"


FlankGun::FlankGun(){
    
    WeaponBehavior* aimLeftRight=new AimUpDown();
    
    setWeaponBehavior(aimLeftRight);
    
}

FlankGun::~FlankGun(){
    
}

void FlankGun::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        changeState(kNull);
        
    }
    
    
}

void FlankGun::update(double dt){
    
    if (getState()==kAiming) {
        
        aim(joyStickData);
        
    }
    
}

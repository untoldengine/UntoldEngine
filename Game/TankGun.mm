//
//  TankGun.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/7/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "TankGun.h"
#include "AimLeftRight.h"


TankGun::TankGun(){
    
    WeaponBehavior* aimLeftRight=new AimLeftRight();
    
    setWeaponBehavior(aimLeftRight);
    
}

TankGun::~TankGun(){
    
}

void TankGun::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        enableCollisionBehavior();
        
        initCoefficientOfRestitution(0.0);
        
        initMass(10.0);
        
        changeState(kNull);
        
    }
    
    
}

void TankGun::update(double dt){
    
    if (getState()==kAiming) {
        
        aim(joyStickData);
        
    }else if (getState()==kHit){
        
        enableKineticsBehavior();
        
        U4DEngine::U4DVector3n upForce(0.0,1000.0,0.0);
        
        applyForce(upForce);
        
        rotateBy(5.0, 0.0, 10.0);
        
        changeState(kNull);
    }
}

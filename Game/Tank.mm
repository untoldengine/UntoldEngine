//
//  Tank.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/6/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "Tank.h"
#include "TankGun.h"

Tank::Tank(){
    
    
}

Tank::~Tank(){
    
    
}


void Tank::init(const char* uName, const char* uBlenderFile){
    
    
    if (loadModel(uName, uBlenderFile)) {
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,1);
        
        setEntityForwardVector(viewDirectionVector);
        
        translateTo(0.0, 0.5, -6.0);
        
        tankGun=new TankGun();
        
        tankGun->init("tankhead", "tankscript.u4d");
        
        tankGun->setEntityForwardVector(viewDirectionVector);
        
        addChild(tankGun);
        
    }
    
    
}

void Tank::update(double dt){
    
    if (getState()==kAiming) {
        
        tankGun->setJoystickData(joyStickData);
        tankGun->changeState(kAiming);
    }
}

//
//  Flank.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/8/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "Flank.h"
#include "FlankRotor.h"
#include "FlankGun.h"


Flank::Flank(){
    
    
}

Flank::~Flank(){
    
    
}


void Flank::init(const char* uName, const char* uBlenderFile){
    
    
    if (loadModel(uName, uBlenderFile)) {
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,-1);
        
        setEntityForwardVector(viewDirectionVector);
    
        translateTo(0.0,0.3,6.0);
        
        flankRotor=new FlankRotor();
        
        flankRotor->init("flankrotor", "flankscript.u4d");
        
        flankRotor->setEntityForwardVector(viewDirectionVector);
        
        addChild(flankRotor);
        
        flankGun=new FlankGun();
        
        flankGun->init("flankgun", "flankscript.u4d");
        
        flankGun->setEntityForwardVector(viewDirectionVector);
        
        flankRotor->addChild(flankGun);
        
    }
    
    
}

void Flank::update(double dt){
    
    if (getState()==kAiming) {
        
        flankRotor->setJoystickData(joyStickData);
        flankRotor->changeState(kAiming);
        
        flankGun->setJoystickData(joyStickData);
        flankGun->changeState(kAiming);
      
    }    
}

U4DEngine::U4DVector3n Flank::getAimVector(){
    
    float zView =flankGun->getViewInDirection().z;
    float xView=flankRotor->getViewInDirection().x;
    float yView=flankGun->getViewInDirection().y;
    
    U4DEngine::U4DVector3n aimVector(xView,yView,zView);
    
    return aimVector;
    
}

FlankGun* Flank::getFlankGun(){
    
    return flankGun;
}

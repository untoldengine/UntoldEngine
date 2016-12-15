//
//  AntiAircraft.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/8/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "AntiAircraft.h"
#include "AntiAircraftRotor.h"
#include "AntiAircraftGun.h"
#include "Bullet.h"

AntiAircraft::AntiAircraft(){
    
    
}

AntiAircraft::~AntiAircraft(){
    
    
}


void AntiAircraft::init(const char* uName, const char* uBlenderFile){
    
    
    if (loadModel(uName, uBlenderFile)) {
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,-1);
        
        setEntityForwardVector(viewDirectionVector);
    
        translateTo(0.0,0.3,6.0);
        
        antiAircraftRotor=new AntiAircraftRotor();
        
        antiAircraftRotor->init("antiaircraftrotor", "antiaircraftscript.u4d");
        
        antiAircraftRotor->setEntityForwardVector(viewDirectionVector);
        
        addChild(antiAircraftRotor);
        
        antiAircraftGun=new AntiAircraftGun();
        
        antiAircraftGun->init("antiaircraftgun", "antiaircraftscript.u4d");
        
        antiAircraftGun->setEntityForwardVector(viewDirectionVector);
        
        antiAircraftRotor->addChild(antiAircraftGun);
        
        changeState(kNull);
        
        setCollisionFilterGroupIndex(kAllies);
        
    }
    
    
}

void AntiAircraft::update(double dt){
    
    if (getState()==kAiming) {
        
        antiAircraftRotor->setJoystickData(joyStickData);
        antiAircraftRotor->changeState(kAiming);
        
        antiAircraftGun->setJoystickData(joyStickData);
        antiAircraftGun->changeState(kAiming);
      
    }else if (getState()==kShooting){
        
        
        if(world!=NULL){
            
            //create the bullet
            Bullet *bullet=new Bullet();
            
            bullet->init("bullet", "bulletscript.u4d");
            
            U4DEngine::U4DVector3n position=getAbsolutePosition();
            
            U4DEngine::U4DVector3n aimVector=getAimVector();
            
            bullet->setShootingParameters(world, position, aimVector);
            
            bullet->shoot();
            
            setCollisionFilterGroupIndex(kAllies);
            
        }
        
        changeState(kNull);
    }
}

U4DEngine::U4DVector3n AntiAircraft::getAimVector(){
    
    float zView =antiAircraftGun->getViewInDirection().z;
    float xView=antiAircraftRotor->getViewInDirection().x;
    float yView=antiAircraftGun->getViewInDirection().y;
    
    U4DEngine::U4DVector3n aimVector(xView,yView,zView);
    
    return aimVector;
    
}

AntiAircraftGun* AntiAircraft::getAntiAircraftGun(){
    
    return antiAircraftGun;
}

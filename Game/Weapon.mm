//
//  Weapon.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/7/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "Weapon.h"

Weapon::Weapon(){
    
}

Weapon::~Weapon(){

}

void Weapon::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        
    }
    
    
}

void Weapon::update(double dt){
    
    
}

void Weapon::setWeaponBehavior(WeaponBehavior *uWeaponBehavior){
    
    aimBehavior=uWeaponBehavior;
    
}

void Weapon::aim(U4DEngine::U4DVector3n &uTarget){
    
    aimBehavior->aim(this, uTarget);
    
}

void Weapon::setState(GameEntityState uState){
    entityState=uState;
}

GameEntityState Weapon::getState(){
    return entityState;
}

void Weapon::changeState(GameEntityState uState){
    
    
    setState(uState);
    
    switch (uState) {
        case kAiming:
            
            
            break;
            
        case kShooting:
            
            
            break;
            
        default:
            
            break;
    }
    
}

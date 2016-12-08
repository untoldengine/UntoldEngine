//
//  AimLeftRight.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/7/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "AimLeftRight.h"
#include "Weapon.h"
#include "U4DVector3n.h"

AimLeftRight::AimLeftRight(){
    
}

AimLeftRight::~AimLeftRight(){
    
}

void AimLeftRight::aim(Weapon *uWeapon, U4DEngine::U4DVector3n &uTarget){
    
    U4DEngine::U4DVector3n setAim(uTarget.x,uWeapon->getAbsolutePosition().y,0.0);
    
    uWeapon->viewInDirection(setAim);
    
}

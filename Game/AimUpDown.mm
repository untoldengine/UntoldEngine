//
//  AimUpDown.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/7/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "AimUpDown.h"
#include "Weapon.h"
#include "U4DVector3n.h"


AimUpDown::AimUpDown(){
    
}

AimUpDown::~AimUpDown(){
    
}

void AimUpDown::aim(Weapon *uWeapon, U4DEngine::U4DVector3n &uTarget){
        
    U4DEngine::U4DVector3n view=uWeapon->getViewInDirection();
    U4DEngine::U4DVector3n targetView;
    
    float scalar=2.0;
    
    if (uTarget.y<=0.0) {
        targetView.y=uWeapon->getAbsolutePosition().y;
        scalar=1.0;
        
    }else{
        
        targetView.y=uWeapon->getAbsolutePosition().y*uTarget.y*scalar;
        
    }
    
    targetView.x=uWeapon->getAbsolutePosition().x;
    targetView.z=view.z;
    
    uWeapon->viewInDirection(targetView);
    
}

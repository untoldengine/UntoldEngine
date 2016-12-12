//
//  AimLeftRight.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/7/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef AimLeftRight_hpp
#define AimLeftRight_hpp

#include <stdio.h>
#include "WeaponBehavior.h"

class U4DVector3n;

class AimLeftRight:public WeaponBehavior {
    
public:
    
    AimLeftRight();
    
    ~AimLeftRight();
    
    void aim(Weapon *uWeapon, U4DEngine::U4DVector3n &uTarget);
};

#endif /* AimLeftRight_hpp */

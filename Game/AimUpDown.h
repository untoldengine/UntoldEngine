//
//  AimUpDown.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/7/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef AimUpDown_hpp
#define AimUpDown_hpp

#include <stdio.h>
#include "WeaponBehavior.h"

class Weapon;
class U4DVector3n;

using namespace U4DEngine;

class AimUpDown:public WeaponBehavior {
    
private:
    
    
public:
    
    AimUpDown();
    
    ~AimUpDown();
    
    void aim(Weapon *uWeapon, U4DEngine::U4DVector3n &uTarget);
    
};

#endif /* AimUpDown_hpp */

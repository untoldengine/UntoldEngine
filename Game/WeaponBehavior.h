//
//  WeaponBehavior.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/7/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef WeaponBehavior_hpp
#define WeaponBehavior_hpp

#include <stdio.h>
#include "U4DVector3n.h"

class Weapon;


class WeaponBehavior {
    
public:
    
    virtual void aim(Weapon *uWeapon, U4DEngine::U4DVector3n &uTarget)=0;
    
    virtual ~WeaponBehavior(){};
    
};

#endif /* WeaponBehavior_hpp */

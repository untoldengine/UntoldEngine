//
//  FlankGun.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/8/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef FlankGun_hpp
#define FlankGun_hpp

#include <stdio.h>
#include "Weapon.h"
#include "WeaponBehavior.h"

class FlankGun:public Weapon {
    
private:
    
    WeaponBehavior *aimLeftRight;
    
public:
    
    FlankGun();
    
    ~FlankGun();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};
#endif /* FlankGun_hpp */

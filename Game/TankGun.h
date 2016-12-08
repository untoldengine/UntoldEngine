//
//  TankGun.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/7/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef TankGun_hpp
#define TankGun_hpp

#include <stdio.h>
#include "Weapon.h"
#include "WeaponBehavior.h"

class TankGun:public Weapon {
    
private:

    WeaponBehavior *aimLeftRight;
    
public:
    
    TankGun();
    
    ~TankGun();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};

#endif /* TankGun_hpp */

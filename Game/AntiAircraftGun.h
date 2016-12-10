//
//  AntiAircraftGun.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/8/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef AntiAircraftGun_hpp
#define AntiAircraftGun_hpp

#include <stdio.h>
#include "Weapon.h"
#include "WeaponBehavior.h"

class AntiAircraftGun:public Weapon {
    
private:
    
    WeaponBehavior *aimLeftRight;
    
public:
    
    AntiAircraftGun();
    
    ~AntiAircraftGun();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};
#endif /* AntiAircraftGun_hpp */

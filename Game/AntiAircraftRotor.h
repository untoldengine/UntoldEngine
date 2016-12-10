//
//  AntiAircraftRotor.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/8/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef AntiAircraftRotor_hpp
#define AntiAircraftRotor_hpp

#include <stdio.h>
#include "Weapon.h"
#include "WeaponBehavior.h"

class AntiAircraftRotor:public Weapon {
    
private:
    
    WeaponBehavior *aimLeftRight;
    
public:
    
    AntiAircraftRotor();
    
    ~AntiAircraftRotor();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};
#endif /* AntiAircraftRotor_hpp */

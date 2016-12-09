//
//  FlankRotor.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/8/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef FlankRotor_hpp
#define FlankRotor_hpp

#include <stdio.h>
#include "Weapon.h"
#include "WeaponBehavior.h"

class FlankRotor:public Weapon {
    
private:
    
    WeaponBehavior *aimLeftRight;
    
public:
    
    FlankRotor();
    
    ~FlankRotor();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};
#endif /* FlankRotor_hpp */

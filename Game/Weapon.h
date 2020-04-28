//
//  Weapon.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/26/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef Weapon_hpp
#define Weapon_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class Weapon:public U4DEngine::U4DGameObject {

private:
    
public:
    
    Weapon();
    
    ~Weapon();

    bool init(const char* uModelName);
    
    void update(double dt);
    
    void shoot();
    
};

#endif /* Weapon_hpp */

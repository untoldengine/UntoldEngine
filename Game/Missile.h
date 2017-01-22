//
//  Missile.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/22/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef Missile_hpp
#define Missile_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class Missile:public U4DEngine::U4DGameObject {
    
private:
    
public:
    
    Missile();
    
    ~Missile();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};
#endif /* Missile_hpp */

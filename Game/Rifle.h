//
//  Rifle.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/22/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef Rifle_hpp
#define Rifle_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class Rifle: public U4DEngine::U4DGameObject {

private:
    
public:
    
    Rifle();
    
    ~Rifle();
    
    bool init(const char* uModelName);
    
    void update(double dt);
    
    void shoot(U4DEngine::U4DVector3n &uDirection);
    
};
#endif /* Rifle_hpp */

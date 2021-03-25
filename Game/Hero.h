//
//  Hero.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/8/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef Hero_hpp
#define Hero_hpp

#include <stdio.h>
#include "Player.h"

class Hero:public Player {

private:
    
    
    U4DEngine::U4DMatrix3n rampOrientation;
    
    
public:
    
    Hero();
    
    ~Hero();

    bool init(const char* uModelName);
    
    void update(double dt);
    
    
    
};
#endif /* Hero_hpp */

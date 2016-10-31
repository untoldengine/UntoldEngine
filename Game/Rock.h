//
//  Rocket.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/4/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Rocket_hpp
#define Rocket_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class Rock:public U4DEngine::U4DGameObject {
    
private:
    
public:
    
    Rock();
    
    ~Rock();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};

#endif /* Rocket_hpp */

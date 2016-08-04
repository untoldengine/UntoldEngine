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

class Rocket:public U4DEngine::U4DGameObject {
    
private:
    
public:
    
    Rocket();
    
    ~Rocket();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};

#endif /* Rocket_hpp */

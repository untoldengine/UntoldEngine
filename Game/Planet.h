//
//  Planet.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/4/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Planet_hpp
#define Planet_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class Planet:public U4DEngine::U4DGameObject {
    
private:
    
public:
    Planet();
    ~Planet();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};
#endif /* Planet_hpp */

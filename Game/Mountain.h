//
//  Mountain.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/4/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Mountain_hpp
#define Mountain_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class Mountain:public U4DEngine::U4DGameObject {
    
private:
    
public:
    Mountain();
    ~Mountain();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
};
#endif /* Mountain_hpp */

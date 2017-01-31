//
//  Floor.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/4/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef Floor_hpp
#define Floor_hpp

#include <stdio.h>
#include "U4DGameObject.h"

class Floor:public U4DEngine::U4DGameObject {
    
private:
    
public:
    Floor();
    
    ~Floor();
    
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
};

#endif /* Floor_hpp */

//
//  U4DImpulseForceGenerator.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DImpulseForceGenerator__
#define __UntoldEngine__U4DImpulseForceGenerator__

#include <stdio.h>
#include "U4DBodyForceGenerator.h"

namespace U4DEngine {
    
class U4DImpulseForceGenerator:public U4DBodyForceGenerator{
    
private:
    
    //impulse time
    float impulseTime;
    
    
public:
    
    U4DImpulseForceGenerator();
    
    ~U4DImpulseForceGenerator();
    
    void updateForce(U4DDynamicModel *uModel, float dt);

};

}

#endif /* defined(__UntoldEngine__U4DImpulseForceGenerator__) */

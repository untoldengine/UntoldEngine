//
//  U4DFoot.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/16/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DFoot_hpp
#define U4DFoot_hpp

#include <stdio.h>
#include "U4DDynamicAction.h"

namespace U4DEngine {

class U4DFoot:public U4DModel {
    
private:
    
    float kickMagnitude;
    
    U4DVector3n kickDirection;
    
public:
    
    U4DDynamicAction *kineticAction;
    
    bool allowedToKick;
    
    U4DFoot();
    
    ~U4DFoot();
    
    //init method. It loads all the rendering information among other things.
    bool init(const char* uModelName);
    
    void update(double dt);
    
    void setKickBallParameters(float uKickMagnitude, U4DVector3n &uKickDirection);
    
};

}
#endif /* U4DFoot_hpp */

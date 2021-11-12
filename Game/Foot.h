//
//  Foot.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/8/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef Foot_hpp
#define Foot_hpp

#include <stdio.h>


#include "U4DDynamicAction.h"

class Foot:public U4DEngine::U4DModel {
    
private:
    
    float kickMagnitude;
    
    U4DEngine::U4DVector3n kickDirection;
    
public:
    
    U4DEngine::U4DDynamicAction *kineticAction;
    
    Foot();
    
    ~Foot();
    
    //init method. It loads all the rendering information among other things.
    bool init(const char* uModelName);
    
    void update(double dt);
    
    void setKickBallParameters(float uKickMagnitude,U4DEngine::U4DVector3n &uKickDirection);
    
};

#endif /* Foot_hpp */

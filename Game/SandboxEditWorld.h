//
//  SandboxEditWorld.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef SandboxEditWorld_hpp
#define SandboxEditWorld_hpp

#include <stdio.h>
#include "U4DWorld.h"
#include "U4DModel.h"

class SandboxEditWorld:public U4DEngine::U4DWorld {
    
private:
    
    
public:
    
    SandboxEditWorld();
    
    ~SandboxEditWorld();
    
    void init();
    
    void update(double dt);

    //Sets the configuration for the engine: Perspective view, shadows, light
    void setupConfiguration();
    
    
};
#endif /* SandboxEditWorld_hpp */

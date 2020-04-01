//
//  Earth.h
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__Earth__
#define __UntoldEngine__Earth__

#include <iostream>
#include "U4DWorld.h"
#include "U4DGameObject.h"
#include "U4DAnimation.h"

class Earth:public U4DEngine::U4DWorld{

private:
    
    U4DEngine::U4DGameObject *cube;
    
public:
   
    Earth(){};
    ~Earth();
    
    void init();
    void update(double dt);

    //Sets the configuration for the engine: Perspective view, shadows, light
    void setupConfiguration();

    
};

#endif /* defined(__UntoldEngine__Earth__) */

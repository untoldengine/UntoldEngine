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
#include <vector>
#include "U4DWorld.h"
#include "U4DGameObject.h"
#include "U4DAnimation.h"
#include "U4DDynamicModel.h"
#include "Player.h"

class Earth:public U4DEngine::U4DWorld{

private:
    
    Player *player;
    U4DEngine::U4DGameObject *ground;
    U4DEngine::U4DGameObject *stones[31];
    U4DEngine::U4DGameObject *trees[28];
    U4DEngine::U4DGameObject *alien;
    U4DEngine::U4DGameObject *lander;
    U4DEngine::U4DGameObject *sky;
    
public:
   
    Earth(){};
    ~Earth();
    
    void init();
    void update(double dt);

    //Sets the configuration for the engine: Perspective view, shadows, light
    void setupConfiguration();

    
};

#endif /* defined(__UntoldEngine__Earth__) */

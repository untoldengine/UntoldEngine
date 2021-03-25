//
//  DemoWorld.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/7/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef DemoWorld_hpp
#define DemoWorld_hpp

#include <stdio.h>
#include "U4DWorld.h"
#include "U4DGameObject.h"
#include "Hero.h"
#include "Enemy.h"
#include "U4DShaderEntity.h"

class DemoWorld:public U4DEngine::U4DWorld {
    
private:
    
    U4DEngine::U4DShaderEntity *navigationShader;
    U4DEngine::U4DShaderEntity *minimapShader;
    Enemy *germanSoldier[3];
    Hero *hero;  
    
public:
    
    DemoWorld();
    
    ~DemoWorld();
    
    void init();
    
    void update(double dt);

    //Sets the configuration for the engine: Perspective view, shadows, light
    void setupConfiguration();
    
};
#endif /* DemoWorld_hpp */

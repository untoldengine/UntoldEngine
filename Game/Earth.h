//
//  Earth.h
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__Earth__
#define __UntoldEngine__Earth__

#include <iostream>
#include "U4DWorld.h"
#include "U4DVector3n.h"
#include "U4DParticleDust.h"

class MyCharacter;

class GameController;
class GameAsset;
class Floor;
class Rock;

class Earth:public U4DEngine::U4DWorld{

private:
    
    MyCharacter *robot;
    Floor *floor;
    GameAsset *tree;
    GameAsset *cloud;
    GameAsset *cloud2;
    Rock *rock;
    
    U4DEngine::U4DParticleDust *particle;
    
public:
   
    Earth(){
        
    };
    
    void init();
    void update(double dt);

};

#endif /* defined(__UntoldEngine__Earth__) */

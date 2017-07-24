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
#include "U4DSkybox.h"

class GameController;
class GameAsset;
class ModelAsset;
class SoccerPlayer;

class Earth:public U4DEngine::U4DWorld{

private:

    ModelAsset *littleMansion;
    ModelAsset *house1;
    ModelAsset *house2;
    ModelAsset *fort;
    GameAsset *ground;
    ModelAsset *player;
    
    U4DEngine::U4DSkybox *skybox;
    
public:
   
    Earth(){};
    
    void init();
    void update(double dt);

};

#endif /* defined(__UntoldEngine__Earth__) */

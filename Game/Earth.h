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


class GameController;
class GameAsset;
class ModelAsset;

class Earth:public U4DEngine::U4DWorld{

private:

    GameAsset *beet[4];
    GameAsset *cloud[4];
    GameAsset *bonfire;
    GameAsset *carrot[8];
    
    GameAsset *grass[15];
    GameAsset *land;
    GameAsset *pumpkin[3];
    GameAsset *raft;
    GameAsset *tent;
    GameAsset *tree[33];
    
    GameAsset *wood[3];
    
    GameAsset *lake;
    
    ModelAsset *modelCube[10];
    
public:
   
    Earth(){};
    
    void init();
    void update(double dt);

};

#endif /* defined(__UntoldEngine__Earth__) */

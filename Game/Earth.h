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

class Earth:public U4DEngine::U4DWorld{

private:

    GameAsset *bridge[4];
    GameAsset *cloud[12];
    GameAsset *fence[5];
    GameAsset *chosa;
    GameAsset *fireplace;
    GameAsset *grass[10];
    GameAsset *land[4];
    GameAsset *moss[6];
    GameAsset *ocean;
    GameAsset *stone[7];
    GameAsset *tree[34];
    GameAsset *trunk[5];
    GameAsset *weed[12];
    
public:
   
    Earth(){};
    
    void init();
    void update(double dt);

};

#endif /* defined(__UntoldEngine__Earth__) */

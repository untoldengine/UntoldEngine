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
#include "U4DText.h"
#include "U4DFontLoader.h"

class GameController;
class GameAsset;
class ModelAsset;
class GuardianModel;
class GoldAsset;

class Earth:public U4DEngine::U4DWorld{

private:
    
    ModelAsset *bag;
    ModelAsset *barrel[2];
    ModelAsset *box[2];
    ModelAsset *chestgold;
    ModelAsset *environment[12];
    ModelAsset *fence[3];
    ModelAsset *house[6];
    ModelAsset *lamp[2];
    ModelAsset *market[3];
    ModelAsset *marketstall[3];
    ModelAsset *metalchest;
    ModelAsset *palm[2];
    ModelAsset *pillar;
    ModelAsset *stone[6];
    ModelAsset *stonefence[4];
    ModelAsset *terrain;
    ModelAsset *tile[3];
    ModelAsset *well;
    ModelAsset *wood[2];
    GuardianModel *guardian;
    GoldAsset *gold[17];
    
    U4DEngine::U4DText *points;
    U4DEngine::U4DFontLoader *fontLoader;
    
public:
   
    Earth(){};
    ~Earth();
    
    void init();
    void update(double dt);

};

#endif /* defined(__UntoldEngine__Earth__) */

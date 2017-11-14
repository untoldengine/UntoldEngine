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
    
    ModelAsset *cube[16];
    ModelAsset *terrain;
    GuardianModel *guardian;
    
    
    U4DEngine::U4DText *points;
    U4DEngine::U4DFontLoader *fontLoader;
    
public:
   
    Earth(){};
    ~Earth();
    
    void init();
    void update(double dt);

};

#endif /* defined(__UntoldEngine__Earth__) */

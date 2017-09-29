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

    GameAsset *car[30];
    
public:
   
    Earth(){};
    
    void init();
    void update(double dt);

};

#endif /* defined(__UntoldEngine__Earth__) */

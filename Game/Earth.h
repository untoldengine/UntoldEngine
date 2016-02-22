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

class MyCharacter;
class MyPlane;
class GameController;
class Town;

class Earth:public U4DEngine::U4DWorld{

private:
    Town *cube2;
    Town *cube;
    Town *cube3;
    
    Town *cube4;
    Town *cube5;
    Town *cube6;
    
    int rotation;
public:
   
    Earth(){
        rotation=0;
    };
    
    void init();
    void action();
    void update(double dt);

};

#endif /* defined(__UntoldEngine__Earth__) */

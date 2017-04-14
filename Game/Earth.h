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
class U11Ball;
class U11Field;
class U11Player;
class U11Team;
class U11FieldGoal;

class Earth:public U4DEngine::U4DWorld{

private:

    U11Ball *ball;
    U11Field *field;
    U11Player *emelecPlayer10;
    U11Player *emelecPlayer11;
    U11Player *emelecPlayer9;
    U11Team *emelec;
    
    U11Player *barcelonaPlayer10;
    U11Player *barcelonaPlayer11;
    U11Player *barcelonaPlayer9;
    U11Team *barcelona;
    
    U11FieldGoal *fieldGoal1;
    U11FieldGoal *fieldGoal2;

public:
   
    Earth(){
        
    };
    
    void init();
    void update(double dt);

};

#endif /* defined(__UntoldEngine__Earth__) */

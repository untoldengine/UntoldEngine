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
class U11PlayerIndicator;

class Earth:public U4DEngine::U4DWorld{

private:

    U11Ball *ball;
    U11Field *field;
    U11Player *emelecPlayer10;
    U11Player *emelecPlayer11;
    U11Player *emelecPlayer9;
    U11Player *emelecPlayer8;
    U11Player *emelecPlayer7;
    U11Player *emelecPlayer6;
    U11Player *emelecPlayer5;
    U11Player *emelecPlayer4;
    U11Player *emelecPlayer3;
    U11Player *emelecPlayer2;
    U11Team *emelec;
    
    U11Player *barcelonaPlayer10;
    U11Player *barcelonaPlayer11;
    U11Player *barcelonaPlayer9;
    U11Player *barcelonaPlayer8;
    U11Player *barcelonaPlayer7;
    U11Player *barcelonaPlayer6;
    U11Player *barcelonaPlayer5;
    U11Player *barcelonaPlayer4;
    U11Player *barcelonaPlayer3;
    U11Player *barcelonaPlayer2;
    U11Team *barcelona;
    
    U11PlayerIndicator *playerIndicator;
    
    U11FieldGoal *fieldGoal1;
    U11FieldGoal *fieldGoal2;
    
public:
   
    Earth(){};
    
    void init();
    void update(double dt);

};

#endif /* defined(__UntoldEngine__Earth__) */

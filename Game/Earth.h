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
class SoccerBall;
class SoccerField;
class Floor;
class SoccerPlayer;

class Earth:public U4DEngine::U4DWorld{

private:

    SoccerBall *ball;
    SoccerField *field;
    SoccerPlayer *player;
    Floor *box1;
    Floor *box2;
    Floor *box3;
    Floor *box4;

public:
   
    Earth(){
        
    };
    
    void init();
    void update(double dt);

};

#endif /* defined(__UntoldEngine__Earth__) */

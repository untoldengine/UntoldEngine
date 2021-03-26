//
//  UserCommonProtocols.h
//  UntoldEngine
//
//  Created by Harold Serrano on 10/16/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#ifndef UserCommonProtocols_h
#define UserCommonProtocols_h

#include "U4DVector3n.h"
#include "U4DVector2n.h"

class Player;

typedef struct{
    
    U4DEngine::U4DVector3n direction;
    U4DEngine::U4DVector3n mousePosition;
    U4DEngine::U4DVector3n previousMousePosition;
    U4DEngine::U4DVector2n mouseDeltaPosition;
    bool changedDirection;
    
}JoystickMessageData;


enum MouseMovementDirection{
    forwardDir,
    backwardDir,
    rightDir,
    leftDir,
    noDir,
};

typedef enum{
    
    kHero=0x0002,
    kEnemySoldier=0x0004,
    kBullet=0x0008,
    kOppositePlayer=0x000A,
    
}GameEntityCollision;

typedef enum{
    
    idle,
    patrol,
    stealth,
    shooting,
    dead,
    
}PLAYERSTATE;

typedef enum{
    
    create,
    shot,
    destroy,
    
}BULLETSTATE;

#endif /* UserCommonProtocols_h */

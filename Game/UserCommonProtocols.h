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

typedef struct{
    
    U4DEngine::U4DVector3n direction;
    U4DEngine::U4DVector3n mousePosition;
    U4DEngine::U4DVector3n previousMousePosition;
    U4DEngine::U4DVector2n mouseDeltaPosition;
    bool changedDirection;
    
}JoystickMessageData;

enum{
    
    idle,
    walking,
    running,
    avoidance,
    arrive,
    pursuit,
    dribbling,
    halt,
    passing,
    supporting,
    shooting,
    defending,
    standtackle,
    contain,
    navigate,

}CHARACTERSTATE;

enum{
    
    selectingKit,
    selectingOptionsInMenu,
    
}MENUSTATE;

enum{
    
    stopped,
    rolling,
    
}BALLSTATE;

enum MouseMovementDirection{
    forwardDir,
    backwardDir,
    rightDir,
    leftDir,
    noDir,
};

typedef enum{
    
    kPlayer=0x0002,
    kEnemy=0x0004,
    kBullet=0x0008,
    
}GameEntityCollision;

#endif /* UserCommonProtocols_h */

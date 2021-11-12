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
#include <string>

typedef struct{
    
    U4DEngine::U4DVector3n direction;
    U4DEngine::U4DVector3n mousePosition;
    U4DEngine::U4DVector3n previousMousePosition;
    U4DEngine::U4DVector2n mouseDeltaPosition;
    bool changedDirection;
    
}JoystickMessageData;

enum{
    stopped,
    rolling,
    kicked,
    decelerating,
    
}BALLSTATE;

enum MouseMovementDirection{
    forwardDir,
    backwardDir,
    rightDir,
    leftDir,
    noDir,
};

enum PlayerState{
    chasing,
    idle,
    dribbling,
    shooting,
};

typedef enum{
    
    kPlayer=0x0002,
    kBall=0x0004,
    kFoot=0x0008,
    kOppositePlayer=0x000A,
    kGoalSensor=0x0020,
    
}GameEntityCollision;


#endif /* UserCommonProtocols_h */

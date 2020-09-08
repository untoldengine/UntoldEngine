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



enum{
    
    selectingKit,
    selectingOptionsInMenu,
    
}MENUSTATE;

enum{
    idle,
    stopped,
    rolling,
    kicked,
    decelerating,
    
}BALLSTATE;

typedef struct{
    
    Player *senderPlayer;
    Player *receiverPlayer;
    int msg;
    void *extraInfo;
    
}Message;

enum{
    
    msgChaseBall,
    msgInterceptBall,
    msgSupport,
    
}PlayerMessage;

enum MouseMovementDirection{
    forwardDir,
    backwardDir,
    rightDir,
    leftDir,
    noDir,
};

typedef enum{
    
    kPlayer=0x0002,
    kBall=0x0004,
    kFoot=0x0008,
    kOppositePlayer=0x000A,
    
}GameEntityCollision;

const float dribbleBallSpeed=30.0;
const float passBallSpeed=45.0;
const float shootBallSpeed=60.0;
const float runSpeed=15.0;
const float arriveMaxSpeed=25.0;
const float arriveStopRadius=0.5;
const float arriveSlowRadius=1.0;
const float pursuitMaxSpeed=30.0;
const float avoidanceMaxSpeed=35.0;

#endif /* UserCommonProtocols_h */

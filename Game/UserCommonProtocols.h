//
//  UserCommonProtocols.h
//  UntoldEngine
//
//  Created by Harold Serrano on 10/16/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef UserCommonProtocols_h
#define UserCommonProtocols_h

#include "U4DVector3n.h"

class GuardianModel;


enum{
    
    actionButtonA,
    actionButtonB,
    actionJoystick,
    
}TouchInputType;


enum{
    buttonPressed,
    buttonReleased,
    joystickActive,
    joystickInactive
    
}TouchInputData;

typedef struct{
    
    int touchInputType;
    int touchInputData;
    U4DEngine::U4DVector3n joystickDirection;
    bool joystickChangeDirection;
    
}TouchInputMessage;


//ADDED FOR DEMO

typedef struct{
    
    GuardianModel *sender;
    GuardianModel *receiver;
    int msg;
    void* extraInfo;
    
}Message;

enum{
    
    msgIdle,
    msgRun,
    msgJump,
    msgJoystickActive,
    msgJoystickNotActive
    
}MessageEnum;

typedef struct{
    
    U4DEngine::U4DVector3n direction;
    bool changedDirection;
    
}JoystickMessageData;

#endif /* UserCommonProtocols_h */

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

class GuardianModel;


enum{
    
    actionButtonA,
    actionButtonB,
    actionJoystick,
    
}ControllerInputType;


enum{
    buttonPressed,
    buttonReleased,
    joystickActive,
    joystickInactive
    
}ControllerInputData;

typedef struct{
    
    int controllerInputType;
    int controllerInputData;
    U4DEngine::U4DVector3n joystickDirection;
    bool joystickChangeDirection;
    
}ControllerInputMessage;

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

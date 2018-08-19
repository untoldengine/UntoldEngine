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

enum{
    
    actionButtonA,
    actionButtonB,
    actionButtonX,
    actionButtonY,
    actionLeftTrigger,
    actionRightTrigger,
    actionJoystick,
    actionRightJoystick,
    
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

typedef struct{
    
    U4DEngine::U4DVector3n direction;
    bool changedDirection;
    
}JoystickMessageData;

#endif /* UserCommonProtocols_h */

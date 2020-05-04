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

enum{
    
    actionButtonA,
    actionButtonB,
    actionButtonW,
    actionButtonS,
    actionButtonD,
    actionButtonX,
    actionButtonY,
    actionButtonF,
    actionKey1,
    actionKeyShift,
    actionKeySpace,
    actionLeftTrigger,
    actionRightTrigger,
    actionRightShoulder,
    actionLeftShoulder,
    actionJoystick,
    actionRightJoystick,
    actionMouseLeftTrigger,
    actionMouse
    
}ControllerInputType;


enum{
    buttonPressed,
    buttonReleased,
    joystickActive,
    joystickInactive,
    mouseActive,
    mouseInactive
    
}ControllerInputData;

typedef struct{
    
    int controllerInputType;
    int controllerInputData;
    U4DEngine::U4DVector3n joystickDirection;
    U4DEngine::U4DVector3n mousePosition;
    U4DEngine::U4DVector3n previousMousePosition;
    U4DEngine::U4DVector2n mouseDeltaPosition;
    bool joystickChangeDirection;
    bool mouseChangeDirection;
    
}ControllerInputMessage;

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
    patrol,
    patrolidle,
    shooting,
    dead,
    attack,
    avoidance,

}CHARACTERSTATE;

enum MouseMovementDirection{
    forwardDir,
    backwardDir,
    rightDir,
    leftDir,
};

typedef enum{
    
    kPlayer=0x0002,
    kEnemy=0x0004,
    kBullet=0x0008,
    
}GameEntityCollision;

#endif /* UserCommonProtocols_h */

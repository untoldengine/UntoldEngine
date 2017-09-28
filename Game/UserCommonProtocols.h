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



#endif /* UserCommonProtocols_h */

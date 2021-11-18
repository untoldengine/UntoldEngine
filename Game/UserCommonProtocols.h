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



enum MouseMovementDirection{
    forwardDir,
    backwardDir,
    rightDir,
    leftDir,
    noDir,
};



#endif /* UserCommonProtocols_h */

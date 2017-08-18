//
//  U4DJoystickStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/16/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DJoystickStateManager_hpp
#define U4DJoystickStateManager_hpp

#include <stdio.h>
#include "U4DJoystickStateInterface.h"

class U4DJoyStick;

namespace U4DEngine {
    
    class U4DJoystickStateManager{
        
    private:
        
        U4DJoyStick *joystick;
        
        U4DJoystickStateInterface *previousState;
        
        U4DJoystickStateInterface *currentState;
        
    public:
        
        U4DJoystickStateManager(U4DJoyStick *uJoyStick);
        
        ~U4DJoystickStateManager();
        
        void changeState(U4DJoystickStateInterface *uState);
        
        void update(double dt);
        
        U4DJoystickStateInterface *getCurrentState();
        
    };
    
}
#endif /* U4DJoystickStateManager_hpp */

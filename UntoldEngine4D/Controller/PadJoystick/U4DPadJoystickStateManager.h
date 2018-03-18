//
//  U4DPadJoystickStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/10/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPadJoystickStateManager_hpp
#define U4DPadJoystickStateManager_hpp

#include <stdio.h>
#include "U4DPadJoystickStateInterface.h"

class U4DPadJoystick;

namespace U4DEngine {
    
    class U4DPadJoystickStateManager{
        
    private:
        
        U4DPadJoystick *padJoystick;
        
        U4DPadJoystickStateInterface *previousState;
        
        U4DPadJoystickStateInterface *currentState;
        
    public:
        
        U4DPadJoystickStateManager(U4DPadJoystick *uPadJoystick);
        
        ~U4DPadJoystickStateManager();
        
        void changeState(U4DPadJoystickStateInterface *uState);
        
        void update(double dt);
        
        U4DPadJoystickStateInterface *getCurrentState();
        
    };
    
}
#endif /* U4DPadJoystickStateManager_hpp */

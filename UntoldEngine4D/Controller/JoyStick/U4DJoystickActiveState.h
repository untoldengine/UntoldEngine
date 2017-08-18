//
//  U4DJoystickActiveState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/16/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DJoystickActiveState_hpp
#define U4DJoystickActiveState_hpp

#include <stdio.h>

#include "U4DJoyStick.h"
#include "U4DJoystickStateInterface.h"

namespace U4DEngine {
    
    class U4DJoystickActiveState:public U4DJoystickStateInterface {
        
    private:
        
        U4DJoystickActiveState();
        
        ~U4DJoystickActiveState();
        
    public:
        
        static U4DJoystickActiveState* instance;
        
        static U4DJoystickActiveState* sharedInstance();
        
        void enter(U4DJoyStick *uJoyStick);
        
        void execute(U4DJoyStick *uJoyStick, double dt);
        
        void exit(U4DJoyStick *uJoyStick);
        
    };
    
}

#endif /* U4DJoystickActiveState_hpp */

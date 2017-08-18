//
//  U4DJoystickReleasedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/16/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DJoystickReleasedState_hpp
#define U4DJoystickReleasedState_hpp

#include <stdio.h>
#include "U4DJoyStick.h"
#include "U4DJoystickStateInterface.h"

namespace U4DEngine {
    
    class U4DJoystickReleasedState:public U4DJoystickStateInterface {
        
    private:
        
        U4DJoystickReleasedState();
        
        ~U4DJoystickReleasedState();
        
    public:
        
        static U4DJoystickReleasedState* instance;
        
        static U4DJoystickReleasedState* sharedInstance();
        
        void enter(U4DJoyStick *uJoyStick);
        
        void execute(U4DJoyStick *uJoyStick, double dt);
        
        void exit(U4DJoyStick *uJoyStick);
        
    };
    
}
#endif /* U4DJoystickReleasedState_hpp */

//
//  U4DJoystickIdleState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/16/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DJoystickIdleState_hpp
#define U4DJoystickIdleState_hpp

#include <stdio.h>
#include "U4DJoyStick.h"
#include "U4DJoystickStateInterface.h"

namespace U4DEngine {
    
    class U4DJoystickIdleState:public U4DJoystickStateInterface {
        
    private:
        
        U4DJoystickIdleState();
        
        ~U4DJoystickIdleState();
        
    public:
        
        static U4DJoystickIdleState* instance;
        
        static U4DJoystickIdleState* sharedInstance();
        
        void enter(U4DJoyStick *uJoyStick);
        
        void execute(U4DJoyStick *uJoyStick, double dt);
        
        void exit(U4DJoyStick *uJoyStick);
        
    };
    
}
#endif /* U4DJoystickIdleState_hpp */

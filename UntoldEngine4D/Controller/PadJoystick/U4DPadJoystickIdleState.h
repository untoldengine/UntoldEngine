//
//  U4DPadJoystickIdleState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/10/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#ifndef U4DPadJoystickIdleState_hpp
#define U4DPadJoystickIdleState_hpp

#include <stdio.h>
#include "U4DPadJoystick.h"
#include "U4DPadJoystickStateInterface.h"

namespace U4DEngine {
    
    class U4DPadJoystickIdleState:public U4DPadJoystickStateInterface {
        
    private:
        
        U4DPadJoystickIdleState();
        
        ~U4DPadJoystickIdleState();
        
    public:
        
        static U4DPadJoystickIdleState* instance;
        
        static U4DPadJoystickIdleState* sharedInstance();
        
        void enter(U4DPadJoystick *uPadJoystick);
        
        void execute(U4DPadJoystick *uPadJoystick, double dt);
        
        void exit(U4DPadJoystick *uPadJoystick);
        
    };
    
}
#endif /* U4DPadJoystickIdleState_hpp */

//
//  U4DPadJoystickReleasedState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/10/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#ifndef U4DPadJoystickReleasedState_hpp
#define U4DPadJoystickReleasedState_hpp

#include <stdio.h>
#include "U4DPadJoystick.h"
#include "U4DPadJoystickStateInterface.h"

namespace U4DEngine {
    
    class U4DPadJoystickReleasedState:public U4DPadJoystickStateInterface {
        
    private:
        
        U4DPadJoystickReleasedState();
        
        ~U4DPadJoystickReleasedState();
        
    public:
        
        static U4DPadJoystickReleasedState* instance;
        
        static U4DPadJoystickReleasedState* sharedInstance();
        
        void enter(U4DPadJoystick *uPadJoystick);
        
        void execute(U4DPadJoystick *uPadJoystick, double dt);
        
        void exit(U4DPadJoystick *uPadJoystick);
        
    };
    
}
#endif /* U4DPadJoystickReleasedState_hpp */

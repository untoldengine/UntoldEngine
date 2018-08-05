//
//  U4DPadJoystickActiveState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/10/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPadJoystickActiveState_hpp
#define U4DPadJoystickActiveState_hpp

#include <stdio.h>
#include "U4DPadJoystick.h"
#include "U4DPadJoystickStateInterface.h"

namespace U4DEngine {
    
    class U4DPadJoystickActiveState:public U4DPadJoystickStateInterface {
        
    private:
        
        U4DPadJoystickActiveState();
        
        ~U4DPadJoystickActiveState();
        
    public:
        
        static U4DPadJoystickActiveState* instance;
        
        static U4DPadJoystickActiveState* sharedInstance();
        
        void enter(U4DPadJoystick *uPadJoystick);
        
        void execute(U4DPadJoystick *uPadJoystick, double dt);
        
        void exit(U4DPadJoystick *uPadJoystick);
        
    };
    
}
#endif /* U4DPadJoystickActiveState_hpp */

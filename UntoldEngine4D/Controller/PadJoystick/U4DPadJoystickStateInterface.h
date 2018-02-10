//
//  U4DPadJoystickStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/10/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#ifndef U4DPadJoystickStateInterface_hpp
#define U4DPadJoystickStateInterface_hpp

#include <stdio.h>
#include "U4DPadJoystick.h"

namespace U4DEngine {
    
    class U4DPadJoystickStateInterface {
        
        
    public:
        
        virtual ~U4DPadJoystickStateInterface(){};
        
        virtual void enter(U4DPadJoystick *uPadJoystick)=0;
        
        virtual void execute(U4DPadJoystick *uPadJoystick, double dt)=0;
        
        virtual void exit(U4DPadJoystick *uPadJoystick)=0;
        
    };
    
}
#endif /* U4DPadJoystickStateInterface_hpp */

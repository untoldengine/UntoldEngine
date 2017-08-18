//
//  U4DJoystickStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/16/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DJoystickStateInterface_hpp
#define U4DJoystickStateInterface_hpp

#include <stdio.h>
#include "U4DJoyStick.h"

namespace U4DEngine {
    
    class U4DJoystickStateInterface {
        
        
    public:
        
        virtual ~U4DJoystickStateInterface(){};
        
        virtual void enter(U4DJoyStick *uJoyStick)=0;
        
        virtual void execute(U4DJoyStick *uJoyStick, double dt)=0;
        
        virtual void exit(U4DJoyStick *uJoyStick)=0;
        
    };
    
}
#endif /* U4DJoystickStateInterface_hpp */

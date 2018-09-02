//
//  U4DJoystickStateInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/16/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DJoystickStateInterface_hpp
#define U4DJoystickStateInterface_hpp

#include <stdio.h>
#include "U4DJoyStick.h"

namespace U4DEngine {
    
    /**
     * @ingroup controller
     * @brief The U4DJoystickStateInterface controls the state objects of the joystick such as active or released
     */
    class U4DJoystickStateInterface {
        
        
    public:
        
        virtual ~U4DJoystickStateInterface(){};
        
        /**
         * @brief Enter method
         * @details Initializes any properties required for the new state
         * 
         * @param uJoyStick joystick entity
         */
        virtual void enter(U4DJoyStick *uJoyStick)=0;
        
        /**
         * @brief Execute method
         * @details This method is constantly called by the state manager. It manages any state changes
         * 
         * @param uJoyStick Joystick entity
         * @param dt game tick
         */
        virtual void execute(U4DJoyStick *uJoyStick, double dt)=0;
        
        /**
         * @brief Exit method
         * @details This method is called before changing to a new state. It resets any needed properties of the entity
         * 
         * @param uJoyStick joystick entity
         */
        virtual void exit(U4DJoyStick *uJoyStick)=0;
        
    };
    
}
#endif /* U4DJoystickStateInterface_hpp */

//
//  U4DJoystickActiveState.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/16/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DJoystickActiveState_hpp
#define U4DJoystickActiveState_hpp

#include <stdio.h>

#include "U4DJoyStick.h"
#include "U4DJoystickStateInterface.h"

namespace U4DEngine {
    
    /**
     * @ingroup controller
     * @brief The U4DJoystickActiveState class manages the active state of the joystick
     * 
     */
    class U4DJoystickActiveState:public U4DJoystickStateInterface {
        
    private:
        
        /**
         * @brief Class constructor
         * @details The constructor is set as private since the class is a singleton
         */
        U4DJoystickActiveState();
        
        /**
         * @brief Class destructor
         */
        ~U4DJoystickActiveState();
        
    public:
        
        /**
         * @brief Static variable to prevent multiple instances of the class to be created.
         * @details This is necessary since the class is a singleton
         */
        static U4DJoystickActiveState* instance;
        
        /**
         * @brief Method to get a single instance of the class
         * @return gets one instance of the class
         */
        static U4DJoystickActiveState* sharedInstance();
        
        /**
         * @brief Enter method
         * @details Initializes any properties required for the new state
         * 
         * @param uJoyStick joystick entity
         */
        void enter(U4DJoyStick *uJoyStick);
        
        /**
         * @brief Execute method
         * @details This method is constantly called by the state manager. It checks the current position of the user input and translates the texture to that location.
         * 
         * @param uJoyStick Joystick entity
         * @param dt game tick
         */
        void execute(U4DJoyStick *uJoyStick, double dt);
        
        /**
         * @brief Exit method
         * @details This method is called before changing to a new state. It resets any needed properties of the entity
         * 
         * @param uJoyStick joystick entity
         */
        void exit(U4DJoyStick *uJoyStick);
        
    };
    
}

#endif /* U4DJoystickActiveState_hpp */

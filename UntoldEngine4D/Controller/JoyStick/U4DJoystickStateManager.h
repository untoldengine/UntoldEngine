//
//  U4DJoystickStateManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/16/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DJoystickStateManager_hpp
#define U4DJoystickStateManager_hpp

#include <stdio.h>
#include "U4DJoystickStateInterface.h"

class U4DJoyStick;

namespace U4DEngine {
    
    /**
     * @ingroup controller
     * @brief The U4DJoystickStateManager class manages the state of the U4DJoyStick
     */
    class U4DJoystickStateManager{
        
    private:
        
        /**
         * @brief pointer to the U4DJoyStick entity
         */
        U4DJoyStick *joystick;
        
        /**
         * @brief U4DJoystick previous state
         */
        U4DJoystickStateInterface *previousState;
        
        /**
         * @brief U4DJoyStick current state
         */
        U4DJoystickStateInterface *currentState;
        
    public:
        
        /**
         * @brief Class constructor
         * @details Initializes the U4DJoyStick states previous and current to null. It also sets the U4DJoyStick entity it will manage
         */
        U4DJoystickStateManager(U4DJoyStick *uJoyStick);
        
        /**
         * @brief Class destructor
         */
        ~U4DJoystickStateManager();
        
        /**
         * @brief Changes the state of the U4DJoyStick entity
         * @details Before changing states, it calls the exit method of the current state. Then calls the enter method of the new state
         * 
         * @param uState joystick state object
         */
        void changeState(U4DJoystickStateInterface *uState);
        
        /**
         * @brief Calls the execute method of the current state
         * @details This method is constantly called during every game tick
         * @param dt game tick
         */
        void update(double dt);
        
        /**
         * @brief Gets the current state of the U4DJoyStick entity
         * @return current state
         */
        U4DJoystickStateInterface *getCurrentState();
        
    };
    
}
#endif /* U4DJoystickStateManager_hpp */

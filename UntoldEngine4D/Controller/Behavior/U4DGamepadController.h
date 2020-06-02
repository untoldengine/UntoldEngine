//
//  U4DGamepadController.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/7/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DGamepadController_hpp
#define U4DGamepadController_hpp

#include <stdio.h>
#include <vector>
#include "U4DGameController.h"
#include "CommonProtocols.h"
#include "U4DVector2n.h"
#include "U4DPadButton.h"
#include "U4DPadJoystick.h"
#import <GameController/GameController.h>

namespace U4DEngine {
    
    /**
     * @ingroup controller
     * @brief The U4DGamepadController class manages all inputs from a game pad.
     * 
     */
    class U4DGamepadController:public U4DGameController{
        
    private:
        
        U4DPadButton *buttonA;
        U4DPadButton *buttonB;
        U4DPadButton *buttonX;
        U4DPadButton *buttonY;
        U4DPadButton *leftTrigger;
        U4DPadButton *rightTrigger;
        U4DPadButton *leftShoulder;
        U4DPadButton *rightShoulder;
        U4DPadButton *dPadButtonUp;
        U4DPadButton *dPadButtonDown;
        U4DPadButton *dPadButtonLeft;
        U4DPadButton *dPadButtonRight;
        U4DPadJoystick *leftJoystick;
        U4DPadJoystick *rightJoystick;
        
    public:
        
        /**
         * @brief Constructor for the class
         */
        U4DGamepadController();
        
        /**
         * @brief Destructor for the class
         */
        ~U4DGamepadController();
        
        /**
         * @brief Initialization method
         * @details In the initialization method, controller entity such as gamepad is created and callbacks are linked
         */
        void init();
        
        void getUserInputData(GCExtendedGamepad *gamepad, GCControllerElement *element);

    };
    
}

#endif /* U4DGamepadController_hpp */

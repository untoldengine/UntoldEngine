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
        
//        /**
//         * @brief This method is not implement in the gamepad controller
//         */
//        void touchBegan(const U4DTouches &touches){};
//
//        /**
//         * @brief This method is not implement in the gamepad controller
//         */
//        void touchMoved(const U4DTouches &touches){};
//
//        /**
//         * @brief This method is not implement in the gamepad controller
//         */
//        void touchEnded(const U4DTouches &touches){};
//
//        /**
//         * @brief This method is not implement in the gamepad controller
//         */
//        void macKeyPressBegan(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction){};
//
//        /**
//         * @brief This method is not implement in the gamepad controller
//         */
//        void macKeyPressEnded(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction){};
//
//        /**
//         * @brief This method is not implement in the gamepad controller
//         */
//        void macArrowKeyActive(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction, U4DVector2n & uPadAxis){};
//
//        /**
//         * @brief This method is not implement in the gamepad controller
//         */
//        void macMousePressBegan(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
//
//        /**
//         * @brief This method is not implement in the gamepad controller
//         */
//        void macMousePressEnded(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction){};
//
//        /**
//         * @brief This method is not implement in the gamepad controller
//         */
//        void macMouseDragged(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
//
//        /**
//         * @brief This method is not implement in the gamepad controller
//         */
//        void macMouseMoved(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
//
//        /**
//         * @brief This method is not implemented in the touch controller.
//         */
//        void macMouseDeltaMoved(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n &uMouseDelta){};
//
//        /**
//         * @brief This method is not implement in the gamepad controller
//         */
//        void macMouseExited(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
//
//        /**
//        * @brief A press on the game pad has began
//        * @details Engine detected a button press from the gamepad
//        *
//        * @param uGamePadElement Game pad element such as button, pad arrows
//        * @param uGamePadAction action detected on the gamepad
//        */
//        void padPressBegan(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction);
//
//        /**
//        * @brief A release on the game pad was detected
//        * @details The engine deteced a button release from the game gamepad
//        *
//         * @param uGamePadElement Game pad element such as button, pad arrows
//        * @param uGamePadAction action detected on the gamepad
//        */
//        void padPressEnded(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction);
//
//        /**
//        * @brief The joystick on the game pad was moved
//        * @details The engine detected joystick movement on the game pad
//        *
//        * @param uGamePadElement game pad element such as left or right joystick
//        * @param uGamePadAction action detected
//        * @param uPadAxis movement direction of the joystick
//        */
//        void padThumbStickMoved(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis);

//        /**
//         * @brief Update the state of the controller pad
//         * @details It changes the state of the controller such as pressed, released or moved
//         *
//         * @param uGamePadElement pad element such as button, arrow key
//         * @param uGamePadAction action on the pad
//         * @param uPadAxis movement direction vector
//         */
//        void changeState(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis);

    };
    
}

#endif /* U4DGamepadController_hpp */

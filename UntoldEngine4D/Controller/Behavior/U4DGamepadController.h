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
#include "U4DControllerInterface.h"
#include "CommonProtocols.h"
#include "U4DPadAxis.h"
#include "U4DVector2n.h"
#import <MetalKit/MetalKit.h>

namespace U4DEngine {
    
    /**
     * @ingroup controller
     * @brief The U4DGamepadController class manages all inputs from a game pad.
     * 
     */
    class U4DGamepadController:public U4DControllerInterface{
        
    private:
        
        /**
         * @brief The view component (mvc) linked to the controller
         * @details The view component (MVC) refers to the U4DWorld entity used in the game
         */
        U4DWorld *gameWorld;

        /**
         * @brief the model component (mvc) linked to the controller
         * @details The Model component refers to the U4DGameModel object.
         */
        U4DGameModelInterface *gameModel;

        /**
         * @brief variable to determine if an action was received
         */
        bool receivedAction;
        
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
        virtual void init(){};
        
        /**
         * @brief This method is not implement in the gamepad controller
         */
        void touchBegan(const U4DTouches &touches){};

        /**
         * @brief This method is not implement in the gamepad controller
         */
        void touchMoved(const U4DTouches &touches){};

        /**
         * @brief This method is not implement in the gamepad controller
         */
        void touchEnded(const U4DTouches &touches){};
        
        /**
         * @brief This method is not implement in the gamepad controller
         */
        void macKeyPressBegan(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction){};
        
        /**
         * @brief This method is not implement in the gamepad controller
         */
        void macKeyPressEnded(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction){};
        
        /**
         * @brief This method is not implement in the gamepad controller
         */
        void macArrowKeyActive(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction, U4DVector2n & uPadAxis){};
        
        /**
         * @brief This method is not implement in the gamepad controller
         */
        void macMousePressBegan(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
        
        /**
         * @brief This method is not implement in the gamepad controller
         */
        void macMousePressEnded(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction){};
        
        /**
         * @brief This method is not implement in the gamepad controller
         */
        void macMouseDragged(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
        
        /**
         * @brief This method is not implement in the gamepad controller
         */
        void macMouseMoved(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
        
        /**
         * @brief This method is not implement in the gamepad controller
         */
        void macMouseExited(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
                
        /**
        * @brief A press on the game pad has began
        * @details Engine detected a button press from the gamepad
        * 
        * @param uGamePadElement Game pad element such as button, pad arrows   
        * @param uGamePadAction action detected on the gamepad
        */
        void padPressBegan(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction);
        
        /**
        * @brief A release on the game pad was detected
        * @details The engine deteced a button release from the game gamepad
        * 
         * @param uGamePadElement Game pad element such as button, pad arrows
        * @param uGamePadAction action detected on the gamepad
        */
        void padPressEnded(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction);
        
        /**
        * @brief The joystick on the game pad was moved
        * @details The engine detected joystick movement on the game pad 
        * 
        * @param uGamePadElement game pad element such as left or right joystick
        * @param uGamePadAction action detected
        * @param uPadAxis movement direction of the joystick
        */
        void padThumbStickMoved(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis);

        /**
         * @brief Update the state of the controller pad
         * @details It changes the state of the controller such as pressed, released or moved
         * 
         * @param uGamePadElement pad element such as button, arrow key
         * @param uGamePadAction action on the pad
         * @param uPadAxis movement direction vector
         */
        void changeState(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis);
        
        /**
         * @brief Sets the current view component of the game
         * @details The view component (MVC) refers to the U4DWorld entity used in the game
         * 
         * @param uGameWorld the U4DWorld entity
         */   
        void setGameWorld(U4DWorld *uGameWorld);

        /**
         * @brief Sets the current Model component (MVC) of the game
         * @details The Model component referst to the U4DGameModel object.
         * 
         * @param uGameModel the U4DGameModel object
         */        
        void setGameModel(U4DGameModelInterface *uGameModel);
        
        /**
         * @brief Gets the current U4DWorld entity linked to the controller
         * @details The U4DWorld entity refers to the view component of the MVC
         * @return The current game world. i.e. view component
         */ 
        U4DWorld* getGameWorld();

        /**
         * @brief Gets the current U4DGameModel object linked to the controller
         * @details The U4DGameModel refers to the model component of the MVC
         * @return The current Game Model. i.e. game logic
         */
        U4DGameModelInterface* getGameModel();
        
        /**
         * @brief Sends user input to the linked U4DGameModel
         * @details The controller sends the user input information to the U4DGameModel
         * 
         * @param uData data containing the informationation about the user input
         */
        void sendUserInputUpdate(void *uData);
        
        /**
         * @brief Indicates that an action on the controller has been received
         * @details Gets set Whenever there is an action on the controller such as a press, release, movement.
         * 
         * @param uValue true for action has been detected.
         */
        void setReceivedAction(bool uValue);

    };
    
}

#endif /* U4DGamepadController_hpp */

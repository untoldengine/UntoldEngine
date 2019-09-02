//
//  U4DKeyboardInput.h
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __MVCTemplate__U4DKeyboardInput__
#define __MVCTemplate__U4DKeyboardInput__

#include <iostream>
#include <vector>
#include "U4DControllerInterface.h"
#include "CommonProtocols.h"
#import <MetalKit/MetalKit.h>

namespace U4DEngine {
    
    /**
     * @ingroup controller
     * @brief The U4DKeyboardController class manages the user inputs detected on the keyboard and mouse on a mac
     */
    class U4DKeyboardController:public U4DControllerInterface{
        
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
         * @brief Constructor for class
         */
        U4DKeyboardController();
        
        /**
         * @brief Destructor for class
         */
        ~U4DKeyboardController();
        
        /**
         * @brief Initialization method
         * @details In the initialization method, controller entities such as mac keys and mouse are created. Callbacks are also created and linked.
         */
        virtual void init(){};
        
        /**
         * @brief This method is not implemented in the keyboard controller
         */
        void touchBegan(const U4DTouches &touches){};

        /**
         * @brief This method is not implemented in the keyboard controller
         */
        void touchMoved(const U4DTouches &touches){};

        /**
         * @brief This method is not implemented in the keyboard controller
         */
        void touchEnded(const U4DTouches &touches){};
        
        /**
         * @brief This method is not implemented in the keyboard controller
         */
        void padPressBegan(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction){};
        
        /**
         * @brief This method is not implemented in the keyboard controller
         */
        void padPressEnded(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction){};
        
        /**
         * @brief This method is not implemented in the keyboard controller
         */
        void padThumbStickMoved(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis){};
        
        /**
         * @brief A key press on the mac was detected
         * @details The engine detected a key press
         * 
         * @param uKeyboardElement keyboard element such as a particular key
        * @param uKeyboardAction action on the key
        */
        void macKeyPressBegan(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction);
        
        /**
         * @brief A key release on the mac was detected
         * @details the engine detected a key release
         * 
         * @param uKeyboardElement keyboard element such as a key
         * @param uKeyboardAction action on the key
         */
        void macKeyPressEnded(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction);
        
        /**
         * @brief The arrow key is currently pressed
         * @details the engine has detected the arrow key being currently pressed
         * 
         * @param uKeyboardElement keyboard element such as the up, down, right, left key
         * @param uKeyboardAction action on the key
         * @param uPadAxis axis of the currently key being pressed. For example, the up arrow key will provide an axis of (0.0,1.0)
         */
        void macArrowKeyActive(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction, U4DVector2n & uPadAxis);
        
        /**
         * @brief The mouse was pressed
         * @details The engine has detected a mouse press
         * 
         * @param uMouseElement mouse element such as the right or left click
         * @param uMouseAction action on the mouse
         * @param uMouseAxis 
         */
        void macMousePressBegan(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis);
        
        /**
         * @brief The mouse was released    
         * @details the engine has detected a mouse release 
         * 
         * @param uMouseElement mouse element such as left or righ button   
         * @param uMouseAction action on the mouse
         */
        void macMousePressEnded(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction);
        
        /**
         * @brief The mouse is being dragged
         * @details The engine has detected mouse drag-movement
         * 
         * @param uMouseElement mouse element
         * @param uMouseAction action on the mouse
         * @param uMouseAxis movement direction in a 2D vector format. For example, if the mouse moves to the right, the vector is (1.0,0.0)
         */
        void macMouseDragged(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis);
        
        /**
         * @brief The mouse is being moved
         * @details The engine has detected mouse movement
         *
         * @param uMouseElement mouse element
         * @param uMouseAction action on the mouse
         * @param uMouseAxis movement direction in a 2D vector format. For example, if the mouse moves to the right, the vector is (1.0,0.0)
         */
        void macMouseMoved(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis);
        
        /**
         * @brief The mouse cursor is being moved and gets its delta movement
         * @details The engine has detected mouse movement
         *
         * @param uMouseElement mouse element
         * @param uMouseAction action on the mouse
         * @param uMouseDelta Delta movement direction in a 2D vector format.
         */
        void macMouseDeltaMoved(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n &uMouseDelta);
        
        /**
         * @brief The mouse cursor exited the window
         * @details The engine has detected mouse exit-movement
         *
         * @param uMouseElement mouse element
         * @param uMouseAction action on the mouse
         * @param uMouseAxis movement direction in a 2D vector format. For example, if the mouse moves to the right, the vector is (1.0,0.0)
         */
        void macMouseExited(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis);
        
        /**
         * @brief Updates the state of the controller
         * @details It changes the state of the controller such as if the key is pressed or released
         * 
         * @param uKeyboardElement keyboard element such as a mac key
         * @param uKeyboardAction action on the key
         * @param uPadAxis [description]
         */
        void changeState(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction, U4DVector2n & uPadAxis);
        
        /**
         * @brief Updates the state of the controller
         * @details It changes the state of the controller such as if the mouse is moved, a pressed began or ended
         * 
         * @param uMouseElement mouse element
         * @param uMouseAction action on the mouse
         * @param uMouseAxis the movement direction vector of the mouse
         */
        void changeState(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis);
        
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

#endif /* defined(__MVCTemplate__U4DKeyboardInput__) */

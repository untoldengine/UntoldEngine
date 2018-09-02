//
//  U4DControllerInterface.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DControllerInterface__
#define __UntoldEngine__U4DControllerInterface__

#include <iostream>
#include <vector>
#include "CommonProtocols.h"
#import <MetalKit/MetalKit.h>

namespace U4DEngine {
    
    class U4DEntity;
    class U4DTouches;
    class U4DButton;
    class U4DJoyStick;
    class U4DWorld;
    class U4DVector2n;
    class U4DGameModelInterface;
    class U4DPadAxis;
}

namespace U4DEngine {
    
/**
 * @ingroup controller
 * @brief The U4DController interface provides the behaviors for the different type of controllers
 */
class U4DControllerInterface{
  
private:
    
    
public:
    
    /**
     * @brief Virtual destructor for interface. The actual destructor implementation is set by the subclasses
     */
    virtual ~U4DControllerInterface(){};
    
    /**
     * @brief Touch has been detected
     * @details engine has detected touch began on iOS
     * 
     * @param touches touch object
     */
    virtual void touchBegan(const U4DTouches &touches)=0;
    
    /**
     * @brief Touch movement has been detected  
     * @details engine has detected a touch movement on iOS
     * 
     * @param touches touch object
     */
    virtual void touchMoved(const U4DTouches &touches)=0;
    
    /**
     * @brief Touch has been released
     * @details engine has detected touch ended on iOS
     * 
     * @param touches touch object
     */
    virtual void touchEnded(const U4DTouches &touches)=0;
    
    /**
     * @brief A press on the game pad has began
     * @details Engine detected a button press from the gamepad
     * 
     * @param uGamePadElement Game pad element such as button, pad arrows   
     * @param uGamePadAction action detected on the gamepad
     */
    virtual void padPressBegan(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction)=0;
    
    /**
     * @brief A release on the game pad was detected
     * @details The engine deteced a button release from the game gamepad
     * 
     * @param uGamePadElement Game pad element such as button, pad arrows
     * @param uGamePadAction action detected on the gamepad
     */
    virtual void padPressEnded(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction)=0;
    
    /**
     * @brief The joystick on the game pad was moved
     * @details The engine detected joystick movement on the game pad 
     * 
     * @param uGamePadElement game pad element such as left or right joystick
     * @param uGamePadAction action detected
     * @param uPadAxis movement direction of the joystick
     */
    virtual void padThumbStickMoved(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis)=0;
    
    /**
     * @brief A key press on the mac was detected
     * @details The engine detected a key press
     * 
     * @param uKeyboardElement keyboard element such as a particular key
     * @param uKeyboardAction action on the key
     */
    virtual void macKeyPressBegan(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction)=0;
    
    /**
     * @brief A key release on the mac was detected
     * @details the engine detected a key release
     * 
     * @param uKeyboardElement keyboard element such as a key
     * @param uKeyboardAction action on the key
     */
    virtual void macKeyPressEnded(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction)=0;
    
    /**
     * @brief The arrow key is currently pressed
     * @details the engine has detected the arrow key being currently pressed
     * 
     * @param uKeyboardElement keyboard element such as the up, down, right, left key
     * @param uKeyboardAction action on the key
     * @param uPadAxis axis of the currently key being pressed. For example, the up arrow key will provide an axis of (0.0,1.0)
     */
    virtual void macArrowKeyActive(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction, U4DVector2n & uPadAxis)=0;
    
    /**
     * @brief The mouse was pressed
     * @details The engine has detected a mouse press
     * 
     * @param uMouseElement mouse element such as the right or left click
     * @param uMouseAction action on the mouse
     * @param uMouseAxis 
     */
    virtual void macMousePressBegan(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis)=0;
    
    /**
     * @brief The mouse was released    
     * @details the engine has detected a mouse release 
     * 
     * @param uMouseElement mouse element such as left or righ button   
     * @param uMouseAction action on the mouse
     */
    virtual void macMousePressEnded(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction)=0;
    
    /**
     * @brief The mouse is being moved
     * @details The engine has detected mouse movement
     * 
     * @param uMouseElement mouse element
     * @param uMouseAction action on the mouse
     * @param uMouseAxis movement direction in a 2D vector format. For example, if the mouse moves to the right, the vector is (1.0,0.0)
     */
    virtual void macMouseDragged(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis)=0;
    
    /**
     * @brief initialization method
     * @details In the initialization method, controller entities such as buttons, joysticks, keyboards are created. callbacks are also created and linked
     */
    virtual void init()=0;
    
    /**
     * @brief Sets the current view component of the game
     * @details The view component (MVC) refers to the U4DWorld entity used in the game
     * 
     * @param uGameWorld the U4DWorld entity
     */
    virtual void setGameWorld(U4DWorld *uGameWorld)=0;
    
    /**
     * @brief Sets the current Model component (MVC) of the game
     * @details The Model component refers to the U4DGameModel object.
     * 
     * @param uGameModel the U4DGameModel object
     */
    virtual void setGameModel(U4DGameModelInterface *uGameModel)=0;
    
    /**
     * @brief Gets the current U4DWorld entity linked to the controller
     * @details The U4DWorld entity refers to the view component of the MVC
     * @return The current game world. i.e. view component
     */
    virtual U4DWorld* getGameWorld()=0;
    
    /**
     * @brief Gets the current U4DGameModel object linked to the controller
     * @details The U4DGameModel refers to the model component of the MVC
     * @return The current Game Model. i.e. game logic
     */
    virtual U4DGameModelInterface* getGameModel()=0;
    
    /**
     * @brief Indicates that an action on the controller has been received
     * @details Gets set Whenever there is an action on the controller such as a press, release, movement.
     * 
     * @param uValue true for action has been detected.
     */
    virtual void setReceivedAction(bool uValue)=0;
    
    /**
     * @brief Sends user input to the linked U4DGameModel
     * @details The controller sends the user input information to the U4DGameModel
     * 
     * @param uData data containing the informationation about the user input
     */
    virtual void sendUserInputUpdate(void *uData)=0;
};

}
#endif /* defined(__UntoldEngine__U4DControllerInterface__) */

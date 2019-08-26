//
//  U4DTouchesController.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DTouchesController__
#define __UntoldEngine__U4DTouchesController__

#include <iostream>
#include <vector>
#include "U4DControllerInterface.h"
#include "CommonProtocols.h"
#include "U4DVector2n.h"
#import <MetalKit/MetalKit.h>

namespace U4DEngine {
    
class U4DWorld;
class U4DGameModelInterface;
class U4DTouches;
class U4DButton;
class U4DJoyStick;
class U4DImage;
class U4DVector2n;
}

namespace U4DEngine {
    
/**
 * @ingroup controller
 * @brief The U4DTouchesController class manages the touch inputs (buttons and joysticks) detected on iOS devices
 */
class U4DTouchesController:public U4DControllerInterface{
  
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
    U4DTouchesController();
    
    /**
     * @brief Destructor for class
     */
    ~U4DTouchesController();

    /**
     * @brief initialization method
     * @details In the initialization method, controller entities such as buttons and joysticks are created. callbacks are also created and linked
     */
    virtual void init(){};
    
    /**
     * @brief Touch has been detected
     * @details engine has detected touch began on iOS
     * 
     * @param touches touch object
     */
    void touchBegan(const U4DTouches &touches);

    /**
     * @brief Touch movement has been detected  
     * @details engine has detected a touch movement on iOS
     * 
     * @param touches touch object
     */
    void touchMoved(const U4DTouches &touches);
    
    /**
     * @brief Touch has been released
     * @details engine has detected touch ended on iOS
     * 
     * @param touches touch object
     */
    void touchEnded(const U4DTouches &touches);
    
    /**
     * @brief This method is not implemented in the touch controller. 
     */
    void padPressBegan(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction){};
    
    /**
     * @brief This method is not implemented in the touch controller. 
     */
    void padPressEnded(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction){};
    
    /**
     * @brief This method is not implemented in the touch controller. 
     */
    void padThumbStickMoved(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis){};
    
    /**
     * @brief This method is not implemented in the touch controller. 
     */
    void macKeyPressBegan(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction){};
    
    /**
     * @brief This method is not implemented in the touch controller. 
     */
    void macKeyPressEnded(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction){};
    
    /**
     * @brief This method is not implemented in the touch controller. 
     */
    void macArrowKeyActive(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction, U4DVector2n & uPadAxis){};
    
    /**
     * @brief This method is not implemented in the touch controller. 
     */
    void macMousePressBegan(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
    
    /**
     * @brief This method is not implemented in the touch controller. 
     */
    void macMousePressEnded(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction){};
    
    /**
     * @brief This method is not implemented in the touch controller. 
     */
    void macMouseDragged(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
    
    /**
     * @brief This method is not implemented in the touch controller.
     */
    void macMouseMoved(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
    
    /**
     * @brief This method is not implemented in the touch controller.
     */
    void macMouseExited(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
    
    /**
     * @brief Updates the state of the controller
     * @details It changes the state of the controller such as pressed, released or moved
     * 
     * @param touches touch object received
     * @param touchState touch state such as pressed, released or moved
     */
    void changeState(const U4DTouches &touches,TOUCHSTATE &touchState);
    
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

#endif /* defined(__UntoldEngine__U4DTouchesController__) */

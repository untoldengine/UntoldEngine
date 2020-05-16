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
#include "U4DGameController.h"
#include "CommonProtocols.h"
#include "U4DVector2n.h"
#include "U4DTouches.h"

namespace U4DEngine {
    
/**
 * @ingroup controller
 * @brief The U4DTouchesController class manages the touch inputs (buttons and joysticks) detected on iOS devices
 */
class U4DTouchesController:public U4DGameController{
  
private:
    
    U4DTouches *userTouch;
    
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
    void init();
    
    
//    /**
//     * @brief Touch has been detected
//     * @details engine has detected touch began on iOS
//     * 
//     * @param touches touch object
//     */
//    void touchBegan(const U4DTouches &touches);
//
//    /**
//     * @brief Touch movement has been detected  
//     * @details engine has detected a touch movement on iOS
//     * 
//     * @param touches touch object
//     */
//    void touchMoved(const U4DTouches &touches);
//    
//    /**
//     * @brief Touch has been released
//     * @details engine has detected touch ended on iOS
//     * 
//     * @param touches touch object
//     */
//    void touchEnded(const U4DTouches &touches);
//    
//    /**
//     * @brief This method is not implemented in the touch controller. 
//     */
//    void padPressBegan(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction){};
//    
//    /**
//     * @brief This method is not implemented in the touch controller. 
//     */
//    void padPressEnded(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction){};
//    
//    /**
//     * @brief This method is not implemented in the touch controller. 
//     */
//    void padThumbStickMoved(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis){};
//    
//    /**
//     * @brief This method is not implemented in the touch controller. 
//     */
//    void macKeyPressBegan(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction){};
//    
//    /**
//     * @brief This method is not implemented in the touch controller. 
//     */
//    void macKeyPressEnded(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction){};
//    
//    /**
//     * @brief This method is not implemented in the touch controller. 
//     */
//    void macArrowKeyActive(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction, U4DVector2n & uPadAxis){};
//    
//    /**
//     * @brief This method is not implemented in the touch controller. 
//     */
//    void macMousePressBegan(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
//    
//    /**
//     * @brief This method is not implemented in the touch controller. 
//     */
//    void macMousePressEnded(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction){};
//    
//    /**
//     * @brief This method is not implemented in the touch controller. 
//     */
//    void macMouseDragged(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
//    
//    /**
//     * @brief This method is not implemented in the touch controller.
//     */
//    void macMouseMoved(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
//    
//    /**
//     * @brief This method is not implemented in the touch controller.
//     */
//    void macMouseDeltaMoved(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n &uMouseDelta){};
//    
//    /**
//     * @brief This method is not implemented in the touch controller.
//     */
//    void macMouseExited(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){};
    
//    /**
//     * @brief Updates the state of the controller
//     * @details It changes the state of the controller such as pressed, released or moved
//     *
//     * @param touches touch object received
//     * @param touchState touch state such as pressed, released or moved
//     */
//    void changeState(const U4DTouches &touches,TOUCHSTATE &touchState);
    
    
};

}

#endif /* defined(__UntoldEngine__U4DTouchesController__) */

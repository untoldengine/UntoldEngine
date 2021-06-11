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
#import <GameController/GameController.h>

namespace U4DEngine {
    
    class U4DEntity;
    class U4DTouches;
    class U4DLayer;
    class U4DWorld;
    class U4DVector2n;
    class U4DGameLogicInterface;
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
    
    
    virtual void changeState(INPUTELEMENTTYPE uInputElementType, INPUTELEMENTACTION uInputAction, U4DVector2n &uPosition)=0;
    
    /**
     * @brief initialization method
     * @details In the initialization method, controller entities such as buttons, joysticks, keyboards are created. callbacks are also created and linked
     */
    virtual void init()=0;
    
    virtual void update(double dt)=0;
    
    /**
     * @brief Sets the current view component of the game
     * @details The view component (MVC) refers to the U4DWorld entity used in the game
     * 
     * @param uGameWorld the U4DWorld entity
     */
    virtual void setGameWorld(U4DWorld *uGameWorld)=0;
    
    /**
     * @brief Sets the current Model component (MVC) of the game
     * @details The Model component refers to the U4DGameLogic object.
     * 
     * @param uGameLogic the U4DGameLogic object
     */
    virtual void setGameLogic(U4DGameLogicInterface *uGameLogic)=0;
    
    /**
     * @brief Gets the current U4DWorld entity linked to the controller
     * @details The U4DWorld entity refers to the view component of the MVC
     * @return The current game world. i.e. view component
     */
    virtual U4DWorld* getGameWorld()=0;
    
    /**
     * @brief Gets the current U4DGameLogic object linked to the controller
     * @details The U4DGameLogic refers to the model component of the MVC
     * @return The current Game Model. i.e. game logic
     */
    virtual U4DGameLogicInterface* getGameLogic()=0;
    
    /**
     * @brief Indicates that an action on the controller has been received
     * @details Gets set Whenever there is an action on the controller such as a press, release, movement.
     * 
     * @param uValue true for action has been detected.
     */
    virtual void setReceivedAction(bool uValue)=0;
    
    /**
     * @brief Sends user input to the linked U4DGameLogic
     * @details The controller sends the user input information to the U4DGameLogic
     * 
     * @param uData data containing the informationation about the user input
     */
    virtual void sendUserInputUpdate(void *uData)=0;
    
    virtual void getUserInputData(unichar uCharacter, INPUTELEMENTACTION uInputAction)=0;
    
    virtual void getUserInputData(INPUTELEMENTTYPE uInputElement, INPUTELEMENTACTION uInputAction, U4DVector2n &uPosition)=0;
    
    virtual void getUserInputData(INPUTELEMENTTYPE uInputElement, INPUTELEMENTACTION uInputAction)=0;
    
    virtual void getUserInputData(GCExtendedGamepad *gamepad, GCControllerElement *element)=0;
    
};

}
#endif /* defined(__UntoldEngine__U4DControllerInterface__) */

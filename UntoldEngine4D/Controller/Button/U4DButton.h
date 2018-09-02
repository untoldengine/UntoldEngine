//
//  U4DButton.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/11/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DButton__
#define __UntoldEngine__U4DButton__

#include <iostream>
#include <vector>
#include "U4DDirector.h"
#include "U4DEntity.h"
#include "U4DMultiImage.h"
#include "U4DTouches.h"
#include "U4DCallbackInterface.h"
#include "CommonProtocols.h"
#import <MetalKit/MetalKit.h>

namespace U4DEngine {
    class U4DImage;
    class U4DControllerInterface;
    class U4DButtonStateManager;
    class U4DButtonStateInterface;
}

namespace U4DEngine {

/**
 * @ingroup controller
 * @brief The U4DButton class manages button entities
 * 
 */
class U4DButton:public U4DEntity{
  
private:
    
    /**
     * @brief A state manager that updates the state of the button whenever it is pressed, released or moved
     */
    U4DButtonStateManager *stateManager;
    
    float left,right,bottom,top;
    
    /**
     * @brief position of the button
     */
    U4DVector3n centerPosition;
    
    /**
     * @brief current touch position detected
     */
    U4DVector3n currentTouchPosition;
    

public:
    
    /**
     * @brief Constructor for the class
     * @details It creates a button object at the position and with the dimension and images specified. It also creates a state manager
     * 
     * @param uName Name of the button
     * @param xPosition x-axis position
     * @param yPosition y-axis position
     * @param uWidth width of button
     * @param uHeight height of button
     * @param uButtonImage1 main image used for button. Normally used when button is idle/released
     * @param uButtonImage2 secondary image used for button. Normally used when button is pressed
     */
    U4DButton(std::string uName, float xPosition,float yPosition,float uWidth,float uHeight,const char* uButtonImage1,const char* uButtonImage2);
    
    /**
     * @brief Destructor for the class
     * @details deletes the state manager
     */
    ~U4DButton();
    
    /**
     * @brief Pointer to the callback object
     * @details This callback is used to inform the button which method to call upon pressed
     * 
     */
    U4DCallbackInterface *pCallback;
    
    /**
     * @brief Pointer to the controller interface
     * @details Usually the controller interface for button is the touch interface
     * 
     */
    U4DControllerInterface *controllerInterface;
    
    /**
     * @brief the buttonImages member is a U4DMultiImage entity 
     * @details This member holds both images for the pressed and released state
     * 
     */
    U4DMultiImage buttonImages;
    
    /**
     * @brief Renders the button
     * @details Renders the button with the image specified by its current state. If the button is in a pressed state, then it will render the main image. otherwise it renders the secondary image
     * 
     * @param uRenderEncoder encoder object
     */
    void render(id <MTLRenderCommandEncoder> uRenderEncoder);
    
    /**
     * @brief Calls the state manager to update the state of the button
     * @details The state manager updates the state of the button depending on the current touch position
     * 
     * @param dt game tick
     */
    void update(double dt);
    
    /**
     * @brief Informs the callback pointer to call the appropriate method
     * @details The method the callback pointer calls is set up during the initialization of the controller. This is set up by the user.
     */
    void action();

    /**
     * @brief Changes the state of the button depending on the touch position
     * @details It checks if the user input touch coordinates falls within the location of the buttons
     * 
     * @param uTouchState touch state such as began, ended, released
     * @param uTouchPosition position of touch
     */
    void changeState(TOUCHSTATE &uTouchState,U4DVector3n &uTouchPosition);
    
    /**
     * @brief Returns true if the button is pressed
     */
    bool getIsPressed();
    
    /**
     * @brief Returns true if button is released
     */
    bool getIsReleased();
    
    /**
     * @brief Initializes the callback interface
     * @details The callback is set during the controller initialization by the user. It sets which method to call if there is an action detected on the button
     * 
     * @param uAction callback interface object
     */
    void setCallbackAction(U4DCallbackInterface *uAction);
    
    /**
     * @brief Initializes the controller interface
     * @details The controller interface for buttons is usually the touch controller (U4DTouchController)
     * 
     * @param uControllerInterface controller interface object
     */
    void setControllerInterface(U4DControllerInterface* uControllerInterface);

};

}

#endif /* defined(__UntoldEngine__U4DButton__) */

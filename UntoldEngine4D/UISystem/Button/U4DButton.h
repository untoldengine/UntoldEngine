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
#include "U4DCallbackInterface.h"
#include "CommonProtocols.h"
#include "U4DShaderEntity.h"

namespace U4DEngine {
    class U4DImage;
    class U4DControllerInterface;
    class U4DText;
}

namespace U4DEngine {

/**
 * @ingroup controller
 * @brief The U4DButton class manages button entities
 * 
 */
class U4DButton:public U4DShaderEntity{
  
private:
    
    
    float left,right,bottom,top;
    
    /**
     * @brief position of the button of the texture
     */
    U4DVector2n centerPosition;
    
    /**
     * @brief current position detected
     */
    U4DVector2n currentPosition;
    
    int state;
    
    int previousState;
    
    U4DText *labelText;
    
    void initButtonProperties(std::string uName, float xPosition,float yPosition,float uWidth,float uHeight);
    
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
     */
    U4DButton(std::string uName, float xPosition,float yPosition,float uWidth,float uHeight, std::string uLabel, std::string uFontData);
    
    U4DButton(std::string uName, float xPosition,float yPosition,float uWidth,float uHeight,const char* uButtonImage);
    
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
     * @param uInputAction touch state such as began, ended, released
     * @param uPosition position of touch
     */
    bool changeState(INPUTELEMENTACTION uInputAction, U4DVector2n uPosition);
    
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

    void changeState(int uState);
    
    int getState();
    
    void setState(int uState);
    
    
    
};

}

#endif /* defined(__UntoldEngine__U4DButton__) */

//
//  U4DJoyStick.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/17/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DJoyStick__
#define __UntoldEngine__U4DJoyStick__

#include <iostream>
#include <vector>
#include "U4DDirector.h"
#include "U4DEntity.h"
#include "U4DImage.h"
#include "U4DCallbackInterface.h"
#include "CommonProtocols.h"
#import <MetalKit/MetalKit.h>

namespace U4DEngine {
    class U4DControllerInterface;
    class U4DJoystickStateInterface;
    class U4DJoystickStateManager;
}

namespace U4DEngine {
    
/**
 * @ingroup controller
 * @brief The U4DJoyStick class controls the joystick entity 
 */
class U4DJoyStick:public U4DEntity{
  
private:
    
    /**
     * @brief A state manager that updates the state of the joystick whenever it is moved or released
     */
    U4DJoystickStateManager *stateManager;
    
    /**
     * @brief width of joystick background texture
     */
    float backgroundWidth;

    /**
     * @brief height of joystick background texture
     */
    float backgroundHeight;
    
    /**
     * @brief width of joystick texture
     */
    float joyStickWidth;

    /**
     * @brief height of joystick texture
     */
    float joyStickHeight;
    
    /**
     * @brief state of joystick
     */
    TOUCHSTATE joyStickState;
    
public:
    
    /**
     * @brief Class constructor
     * @details creates the state manager and sets the texture for the joystick and translates it to the assigned position
     * 
     * @param uName name of joystick
     * @param xPosition x-axis position
     * @param yPosition y-axis position 
     * @param uBackGroundImage background joystick texture name
     * @param uBackgroundWidth background texture width
     * @param uBackgroundHeight background texture height
     * @param uJoyStickImage joystick texture name
     * @param uJoyStickWidth joystick texture width
     * @param uJoyStickHeight joystick texture height
     */
    U4DJoyStick(std::string uName, float xPosition,float yPosition,const char* uBackGroundImage,float uBackgroundWidth,float uBackgroundHeight,const char* uJoyStickImage,float uJoyStickWidth,float uJoyStickHeight);
    
    /**
     * @brief Class destructor
     */
    ~U4DJoyStick();
    
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
     * @brief background U4DImage entity for joystick
     */
    U4DImage backgroundImage;

    /**
     * @brief U4DImage entity for joystick
     */
    U4DImage joyStickImage;
    
    /**
     * @brief joystick data position 
     */
    U4DVector3n dataPosition;

    /**
     * @brief magnitude of data position. This is normalized
     */
    float dataMagnitude;
    
    /**
     * @brief original center position of the joystick
     */
    U4DVector3n originalPosition;
    
    /**
     * @brief current position of touch
     */
    U4DVector3n currentPosition;
    
    /**
     * @brief position of joystick background texture image
     */
    U4DVector3n centerBackgroundPosition;

    /**
     * @brief position of joystick texture image
     */
    U4DVector3n centerImagePosition;
    
    /**
     * @brief radius of joystick background texture
     */
    float backgroundImageRadius;

    /**
     * @brief radius of joystick texture
     */
    float joyStickImageRadius;
    
    /**
     * @brief Is the joystick currently being touched or moved
     */
    bool isActive;
    
    /**
     * @brief Did the joystick do a sudden reverse in direction
     */
    bool directionReversal;
    
    /**
     * @brief Renders both the background image and the joystick at its new position
     */
    void render(id <MTLRenderCommandEncoder> uRenderEncoder);

    /**
     * @brief Updates the state of joystick
     * @details The state manager updates the state of the joystick. The states are either idle, active or released
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
     * @brief Set the width texture of the joystick
     * 
     * @param uJoyStickWidth width
     */
    void setJoyStickWidth(float uJoyStickWidth);

    /**
     * @brief Set the height texture of the joystick
     * 
     * @param uJoyStickHeight height
     */
    void setJoyStickHeight(float uJoyStickHeight);

    /**
     * @brief Get the joystick texture width
     * @return width of texture
     */
    float getJoyStickWidth();

    /**
     * @brief Get the joystick texture height
     * @return height of texture
     */
    float getJoyStickHeight();
    
    /**
     * @brief Set the background texture width
     * 
     * @param uJoyStickBackgroundWidth texture width
     */
    void setJoyStickBackgroundWidth(float uJoyStickBackgroundWidth);

    /**
     * @brief Set the background texture height
     * 
     * @param uJoyStickBackgroundHeight texture height
     */
    void setJoyStickBackgroundHeight(float uJoyStickBackgroundHeight);
    
    /**
     * @brief Get the texture background width
     * @return texture width
     */
    float getJoyStickBackgroundWidth();

    /**
     * @brief Get the texture background height
     * @return texture height
     */
    float getJoyStickBackgroundHeight();
    
    /**
     * @brief Changes the state of the joystick
     * @details The state manager changes the state of the joystick to either active or released depending on the touch
     * 
     * @param uTouchState touch state. that is moved or released
     * @param uNewPosition touch position
     */
    void changeState(TOUCHSTATE &uTouchState,U4DVector3n &uNewPosition);
    
    /**
     * @brief Get the current state of the joystick entity
     * @return state of the entity
     */
    TOUCHSTATE getState();
    
    /**
     * @brief Sets the computed position of the joystick
     * @details This data is computed taking into account the current touch position, location of joystick and texture radius
     * 
     * @param uData computed data
     */
    void setDataPosition(U4DVector3n uData);

    /**
     * @brief Gets the computed position of joystick
     * @details This data is computed taking into account the current touch position, location of joystick and texture radius
     * @return computed data
     */
    U4DVector3n getDataPosition();
    
    /**
     * @brief Sets the magnitude position of the joystick
     * @details This is computed by subtracting the current position of the joystick and the position of the background texture
     * 
     * @param uValue magnitude
     */
    void setDataMagnitude(float uValue);

    /**
     * @brief Gets the magnitude position of the joystick
     * @details This is computed by subtracting the current position of the joystick and the position of the background texture 
     * @return magnitude of data
     */
    float getDataMagnitude();
    
    /**
     * @brief Get if the joystick is currently active
     * @return true for active. false for released or idle
     */
    bool getIsActive();
    
    /**
     * @brief Initializes the callback interface
     * @details The callback is set during the controller initialization by the user. It sets which method to call if there is an action detected on the joystick
     * 
     * @param uAction callback interface object
     */
    void setCallbackAction(U4DCallbackInterface *uAction);
    
    /**
     * @brief Initializes the controller interface
     * @details The controller interface for joystick is usually the touch controller (U4DTouchController)
     * 
     * @param uControllerInterface controller interface object
     */
    void setControllerInterface(U4DControllerInterface* uControllerInterface);
    
    /**
     * @brief Did the user reverse the joystick movement
     * @return true if a reversal in direction did occur
     */
    bool getDirectionReversal();

};

}

#endif /* defined(__UntoldEngine__U4DJoyStick__) */

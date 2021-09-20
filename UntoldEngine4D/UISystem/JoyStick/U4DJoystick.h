//
//  U4DJoystick.h
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
#include "U4DShaderEntity.h"

namespace U4DEngine {
    class U4DControllerInterface;

}

namespace U4DEngine {
    
/**
 * @ingroup controller
 * @brief The U4DJoystick class controls the joystick entity
 */
class U4DJoystick:public U4DShaderEntity{
  
private:
    
    
    int state;
    
    int previousState;
    
    /**
     * @brief current position of joystick texture
     */
    U4DVector2n currentPosition;
    
    /**
     * @brief position of joystick
     */
    U4DVector2n centerPosition;

    /**
     * @brief radius of joystick background texture
     */
    float backgroundRadius;

    /**
     * @brief radius of joystick texture
     */
    float joyStickRadius;
    
    /**
     * @brief Is the joystick currently being touched or moved
     */
    bool isActive;
    
    /**
     * @brief Did the joystick do a sudden reverse in direction
     */
    bool directionReversal;
    
    /**
     @brief store initial touchBegin flag.
     */
    bool touchBeginWithinBoundaryFlag;
    
    void initJoystickProperties(std::string uName, float xPosition,float yPosition, float uBackgroundWidth,float uBackgroundHeight);
    
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
     */
    U4DJoystick(std::string uName, float xPosition,float yPosition,const char* uBackGroundImage,float uBackgroundWidth,float uBackgroundHeight,const char* uJoyStickImage);
    
    U4DJoystick(std::string uName, float xPosition,float yPosition, float uBackgroundWidth,float uBackgroundHeight);
    
    /**
     * @brief Class destructor
     */
    ~U4DJoystick();
    
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
     * @brief joystick data position
     */
    U4DVector2n dataPosition;

    /**
     * @brief magnitude of data position. This is normalized
     */
    float dataMagnitude;
    
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
     * @brief Changes the state of the joystick
     * @details The state manager changes the state of the joystick to either active or released depending on the touch
     *
     * @param uInputAction touch state. that is moved or released
     * @param uPosition touch position
     */
    bool changeState(INPUTELEMENTACTION uInputAction, U4DVector2n uPosition);
    
    /**
     * @brief Sets the computed position of the joystick
     * @details This data is computed taking into account the current touch position, location of joystick and texture radius
     *
     * @param uData computed data
     */
    void setDataPosition(U4DVector2n uData);

    /**
     * @brief Gets the computed position of joystick
     * @details This data is computed taking into account the current touch position, location of joystick and texture radius
     * @return computed data
     */
    U4DVector2n getDataPosition();
    
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
     * @brief Did the user reverse the joystick movement
     * @return true if a reversal in direction did occur
     */
    bool getDirectionReversal();
    
    void changeState(int uState);
    
    int getState();
    
    void setState(int uState);

};

}

#endif /* defined(__UntoldEngine__U4DJoyStick__) */

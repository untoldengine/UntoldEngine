//
//  U4DPadJoystick.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/10/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DPadJoystick.h"
#include "U4DDirector.h"
#include "U4DControllerInterface.h"
#include "U4DPadJoystickStateManager.h"
#include "U4DPadJoystickIdleState.h"
#include "U4DPadJoystickActiveState.h"
#include "U4DPadJoystickReleasedState.h"
#include "CommonProtocols.h"
#include "U4DVector2n.h"

namespace U4DEngine {
    
    
    U4DPadJoystick::U4DPadJoystick(INPUTELEMENTTYPE uInputElementType, U4DControllerInterface* uControllerInterface):U4DInputElement(uInputElementType, uControllerInterface),isActive(false),directionReversal(false),dataPosition(0.0,0.0),dataMagnitude(0.0),padAxis(0.0,0.0){
        
        stateManager=new U4DPadJoystickStateManager(this);
        
        //set initial state
        stateManager->changeState(U4DPadJoystickIdleState::sharedInstance());
        
    }
    
    U4DPadJoystick::~U4DPadJoystick(){
        
        delete stateManager;
    }
    
    
    void U4DPadJoystick::setDataMagnitude(float uValue){
        
        dataMagnitude=uValue;
        
    }
    
    float U4DPadJoystick::getDataMagnitude(){
        
        return dataMagnitude;
        
    }
    
    void U4DPadJoystick::update(double dt){
        
        stateManager->update(dt);
        
    }
    
    void U4DPadJoystick::action(){
        
       CONTROLLERMESSAGE controllerMessage;
    
        controllerMessage.inputElementType=inputElementType;
    
        if (getIsActive()) {
    
            controllerMessage.inputElementAction=U4DEngine::padThumbstickMoved;
    
            U4DEngine::U4DVector2n joystickDirection=getDataPosition();
    
            //joystickDirection.normalize();
    
    
            if (getDirectionReversal()) {
    
                controllerMessage.joystickChangeDirection=true;
    
            }else{
    
                controllerMessage.joystickChangeDirection=false;
    
            }
    
            controllerMessage.joystickDirection=joystickDirection;
    
        }else {
    
           controllerMessage.inputElementAction=U4DEngine::padThumbstickReleased;
    
        }
    
        controllerInterface->sendUserInputUpdate(&controllerMessage);
        
    }
    
    
    void U4DPadJoystick::changeState(INPUTELEMENTACTION &uInputAction, U4DVector2n &uPosition){
        
        if (uInputAction==U4DEngine::padThumbstickMoved) {
            
            padAxis=uPosition;
            
            stateManager->changeState(U4DPadJoystickActiveState::sharedInstance());
            
        }else if(uInputAction==U4DEngine::padThumbstickReleased && (stateManager->getCurrentState()==U4DPadJoystickActiveState::sharedInstance())){
            
            padAxis=U4DVector2n(0.0,0.0);
            
            stateManager->changeState(U4DPadJoystickReleasedState::sharedInstance());
            
        }
        
    }
    
    
    void U4DPadJoystick::setDataPosition(U4DVector2n &uData){
        
        dataPosition=uData;
    }
    
    U4DVector2n U4DPadJoystick::getDataPosition(){
        
        return dataPosition;
    }
    
    bool U4DPadJoystick::getIsActive(){
        
        return (stateManager->getCurrentState()==U4DPadJoystickActiveState::sharedInstance());;
    }
    
    
    bool U4DPadJoystick::getDirectionReversal(){
        
        return directionReversal;
        
    }
    
}

//
//  U4DPadJoystick.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/10/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
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
    
    
    U4DPadJoystick::U4DPadJoystick(GAMEPADELEMENT &uPadElementType):isActive(false),controllerInterface(NULL),pCallback(NULL),directionReversal(false),dataPosition(0.0,0.0,0.0),dataMagnitude(0.0),padAxis(0.0,0.0){
        
        stateManager=new U4DPadJoystickStateManager(this);
        
        setEntityType(CONTROLLERINPUT);
        
        padElementType=uPadElementType;
        
        //set initial state
        stateManager->changeState(U4DPadJoystickIdleState::sharedInstance());
        
    }
    
    U4DPadJoystick::~U4DPadJoystick(){
        
        delete stateManager;
    }
    
    GAMEPADELEMENT U4DPadJoystick::getPadElementType(){
        
        return padElementType;
        
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
        
        pCallback->action();
    }
    
    
    void U4DPadJoystick::changeState(GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis){
        
        if (uGamePadAction==U4DEngine::padThumbstickMoved) {
            
            padAxis=uPadAxis;
            
            stateManager->changeState(U4DPadJoystickActiveState::sharedInstance());
            
        }else if(uGamePadAction==U4DEngine::padThumbstickReleased && (stateManager->getCurrentState()==U4DPadJoystickActiveState::sharedInstance())){
            
            padAxis=U4DPadAxis(0.0,0.0);
            
            stateManager->changeState(U4DPadJoystickReleasedState::sharedInstance());
            
        }
        
    }
    
    
    void U4DPadJoystick::setDataPosition(U4DVector3n uData){
        
        dataPosition=uData;
    }
    
    U4DVector3n U4DPadJoystick::getDataPosition(){
        
        return dataPosition;
    }
    
    bool U4DPadJoystick::getIsActive(){
        
        return (stateManager->getCurrentState()==U4DPadJoystickActiveState::sharedInstance());;
    }
    
    void U4DPadJoystick::setCallbackAction(U4DCallbackInterface *uAction){
        
        //set the callback
        pCallback=uAction;
        
    }
    
    void U4DPadJoystick::setControllerInterface(U4DControllerInterface* uControllerInterface){
        
        controllerInterface=uControllerInterface;
        
    }
    
    bool U4DPadJoystick::getDirectionReversal(){
        
        return directionReversal;
        
    }
    
}

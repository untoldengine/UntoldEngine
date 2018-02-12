//
//  U4DPadButton.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/8/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#include "U4DPadButton.h"
#include "U4DVector2n.h"
#include "U4DTouches.h"
#include "U4DDirector.h"
#include "U4DControllerInterface.h"
#include "U4DPadButtonPressedState.h"
#include "U4DPadButtonReleasedState.h"
#include "U4DPadButtonIdleState.h"
#include "CommonProtocols.h"
#include "U4DPadButtonStateManager.h"
#include "U4DNumerical.h"

namespace U4DEngine {
    
    U4DPadButton::U4DPadButton(GAMEPADELEMENT &uPadElementType){
        
        stateManager=new U4DPadButtonStateManager(this);
        
        padElementType=uPadElementType;
        
        setEntityType(CONTROLLERINPUT);
        
        //set initial state
        stateManager->changeState(U4DPadButtonReleasedState::sharedInstance());
        
    }
    
    U4DPadButton::~U4DPadButton(){
        
        delete stateManager;
        
    }
    
    GAMEPADELEMENT U4DPadButton::getPadElementType(){
        
        return padElementType;
        
    }
    
    void U4DPadButton::update(double dt){
        
        stateManager->update(dt);
        
    }
    
    void U4DPadButton::action(){
        
        pCallback->action();
        
    }
    
    void U4DPadButton::changeState(GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis){
        
        if(uGamePadAction==U4DEngine::padButtonPressed){
            
            stateManager->changeState(U4DPadButtonPressedState::sharedInstance());
            
        }else if (uGamePadAction==U4DEngine::padButtonReleased){
            
            stateManager->changeState(U4DPadButtonReleasedState::sharedInstance());
            
        }
        
    }
    
    void U4DPadButton::setCallbackAction(U4DCallbackInterface *uAction){
        
        //set the callback
        pCallback=uAction;
        
    }
    
    bool U4DPadButton::getIsPressed(){
        
        return (stateManager->getCurrentState()==U4DPadButtonPressedState::sharedInstance());
        
    }
    
    bool U4DPadButton::getIsReleased(){
        
        return (stateManager->getCurrentState()==U4DPadButtonReleasedState::sharedInstance());
        
    }
    
    void U4DPadButton::setControllerInterface(U4DControllerInterface* uControllerInterface){
        
        controllerInterface=uControllerInterface;
        
    }
    
    
}

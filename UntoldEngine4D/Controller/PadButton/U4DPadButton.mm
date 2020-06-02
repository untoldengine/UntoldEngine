//
//  U4DPadButton.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DPadButton.h"
#include "U4DVector2n.h"
#include "U4DDirector.h"
#include "U4DControllerInterface.h"
#include "U4DPadButtonPressedState.h"
#include "U4DPadButtonReleasedState.h"
#include "U4DPadButtonIdleState.h"
#include "CommonProtocols.h"
#include "U4DPadButtonStateManager.h"
#include "U4DNumerical.h"

namespace U4DEngine {
    
    U4DPadButton::U4DPadButton(INPUTELEMENTTYPE uInputElementType, U4DControllerInterface* uControllerInterface):U4DInputElement(uInputElementType, uControllerInterface){
        
        stateManager=new U4DPadButtonStateManager(this);
        
        //set initial state
        stateManager->changeState(U4DPadButtonIdleState::sharedInstance());
        
    }
    
    U4DPadButton::~U4DPadButton(){
        
        delete stateManager;
        
    }
    
    
    void U4DPadButton::update(double dt){
        
        stateManager->update(dt);
        
    }
    
    void U4DPadButton::action(){
        
        CONTROLLERMESSAGE controllerMessage;
    
        controllerMessage.inputElementType=inputElementType;
    
        if (getIsPressed()) {
    
            controllerMessage.inputElementAction=U4DEngine::padButtonPressed;
    
        }else if(getIsReleased()){
    
            controllerMessage.inputElementAction=U4DEngine::padButtonReleased;
    
        }
    
        controllerInterface->sendUserInputUpdate(&controllerMessage);
        
    }
    
    void U4DPadButton::changeState(INPUTELEMENTACTION &uInputAction, U4DVector2n &uPosition){
        
        if(uInputAction==U4DEngine::padButtonPressed){
            
            stateManager->changeState(U4DPadButtonPressedState::sharedInstance());
            
        }else if (uInputAction==U4DEngine::padButtonReleased){
            
            stateManager->changeState(U4DPadButtonReleasedState::sharedInstance());
            
        }
        
    }
    
    
    bool U4DPadButton::getIsPressed(){
        
        return (stateManager->getCurrentState()==U4DPadButtonPressedState::sharedInstance());
        
    }
    
    bool U4DPadButton::getIsReleased(){
        
        return (stateManager->getCurrentState()==U4DPadButtonReleasedState::sharedInstance());
        
    }
    
    
}

//
//  U4DKeys.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/3/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DMacKey.h"
#include "U4DControllerInterface.h"
#include "U4DMacKeyPressedState.h"
#include "U4DMacKeyReleasedState.h"
#include "U4DMacKeyActiveState.h"
#include "U4DMacKeyIdleState.h"
#include "CommonProtocols.h"
#include "U4DMacKeyStateManager.h"
#include "U4DNumerical.h"

namespace U4DEngine {
    
    U4DMacKey::U4DMacKey(INPUTELEMENTTYPE uInputElementType, U4DControllerInterface* uControllerInterface ):U4DInputElement(uInputElementType,uControllerInterface){
        
        stateManager=new U4DMacKeyStateManager(this);
        
        //set initial state
        stateManager->changeState(U4DMacKeyIdleState::sharedInstance());
        
    }
    
    U4DMacKey::~U4DMacKey(){
        
        delete stateManager;
        
    }
    
    
    
    void U4DMacKey::update(double dt){
        
        stateManager->update(dt);
        
    }
    
    void U4DMacKey::action(){
        
        //notify the game model
        
        CONTROLLERMESSAGE controllerMessage;
    
        controllerMessage.inputElementType=inputElementType;
    
        if (getIsPressed()) {
    
            controllerMessage.inputElementAction=U4DEngine::macKeyPressed;
    
        }else if(getIsReleased()){
    
            controllerMessage.inputElementAction=U4DEngine::macKeyReleased;
    
        }
        
        if(getIsActive()){
            controllerMessage.inputElementAction=U4DEngine::macKeyActive;
        }
    
        controllerInterface->sendUserInputUpdate(&controllerMessage);
        
    }
    
    void U4DMacKey::changeState(INPUTELEMENTACTION &uInputAction, U4DVector2n &uPosition){
        
        if(uInputAction==U4DEngine::macKeyPressed && (stateManager->getCurrentState()!=U4DMacKeyPressedState::sharedInstance() && stateManager->getCurrentState()!=U4DMacKeyActiveState::sharedInstance())){
            
            stateManager->changeState(U4DMacKeyPressedState::sharedInstance());
            
        }else if (uInputAction==U4DEngine::macKeyReleased){
            
            stateManager->changeState(U4DMacKeyReleasedState::sharedInstance());
            
        }
        
        if(stateManager->getCurrentState()==U4DMacKeyPressedState::sharedInstance() && uInputAction==U4DEngine::macKeyPressed){
            
            stateManager->changeState(U4DMacKeyActiveState::sharedInstance());
            
        }
        
    }
    
    
    bool U4DMacKey::getIsPressed(){
        
        return (stateManager->getCurrentState()==U4DMacKeyPressedState::sharedInstance());
        
    }
    
    bool U4DMacKey::getIsReleased(){
        
        return (stateManager->getCurrentState()==U4DMacKeyReleasedState::sharedInstance());
        
    }

    bool U4DMacKey::getIsActive(){
        return (stateManager->getCurrentState()==U4DMacKeyActiveState::sharedInstance());
    }

    
}

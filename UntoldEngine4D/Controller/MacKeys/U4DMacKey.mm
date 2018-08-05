//
//  U4DKeys.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/3/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DMacKey.h"
#include "U4DDirector.h"
#include "U4DControllerInterface.h"
#include "U4DMacKeyPressedState.h"
#include "U4DMacKeyReleasedState.h"
#include "U4DMacKeyIdleState.h"
#include "CommonProtocols.h"
#include "U4DMacKeyStateManager.h"
#include "U4DNumerical.h"

namespace U4DEngine {
    
    U4DMacKey::U4DMacKey(KEYBOARDELEMENT &uKeyboardElementType){
        
        stateManager=new U4DMacKeyStateManager(this);
        
        keyboardElementType=uKeyboardElementType;
        
        setEntityType(CONTROLLERINPUT);
        
        //set initial state
        stateManager->changeState(U4DMacKeyIdleState::sharedInstance());
        
    }
    
    U4DMacKey::~U4DMacKey(){
        
        delete stateManager;
        
    }
    
    KEYBOARDELEMENT U4DMacKey::getKeyboardElementType(){
        
        return keyboardElementType;
        
    }
    
    void U4DMacKey::update(double dt){
        
        stateManager->update(dt);
        
    }
    
    void U4DMacKey::action(){
        
        pCallback->action();
        
    }
    
    void U4DMacKey::changeState(KEYBOARDACTION &uKeyboardAction, const U4DVector2n &uPadAxis){
        
        if(uKeyboardAction==U4DEngine::macKeyPressed){
            
            stateManager->changeState(U4DMacKeyPressedState::sharedInstance());
            
        }else if (uKeyboardAction==U4DEngine::macKeyReleased){
            
            stateManager->changeState(U4DMacKeyReleasedState::sharedInstance());
            
        }
        
    }
    
    void U4DMacKey::setCallbackAction(U4DCallbackInterface *uAction){
        
        //set the callback
        pCallback=uAction;
        
    }
    
    bool U4DMacKey::getIsPressed(){
        
        return (stateManager->getCurrentState()==U4DMacKeyPressedState::sharedInstance());
        
    }
    
    bool U4DMacKey::getIsReleased(){
        
        return (stateManager->getCurrentState()==U4DMacKeyReleasedState::sharedInstance());
        
    }
    
    void U4DMacKey::setControllerInterface(U4DControllerInterface* uControllerInterface){
        
        controllerInterface=uControllerInterface;
        
    }
    
    
}

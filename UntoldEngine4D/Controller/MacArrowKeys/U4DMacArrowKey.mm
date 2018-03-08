//
//  U4DMacArrowKey.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/5/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#include "U4DMacArrowKey.h"

#include "U4DDirector.h"
#include "U4DControllerInterface.h"
#include "U4DMacArrowKeyStateManager.h"
#include "U4DMacArrowKeyIdleState.h"
#include "U4DMacArrowKeyActiveState.h"
#include "U4DMacArrowKeyReleasedState.h"
#include "CommonProtocols.h"
#include "U4DVector2n.h"

namespace U4DEngine {
    
    
    U4DMacArrowKey::U4DMacArrowKey(KEYBOARDELEMENT &uPadElementType):isActive(false),controllerInterface(NULL),pCallback(NULL),directionReversal(false),dataPosition(0.0,0.0,0.0),dataMagnitude(0.0),padAxis(0.0,0.0){
        
        stateManager=new U4DMacArrowKeyStateManager(this);
        
        setEntityType(CONTROLLERINPUT);
        
        padElementType=uPadElementType;
        
        //set initial state
        stateManager->changeState(U4DMacArrowKeyIdleState::sharedInstance());
        
    }
    
    U4DMacArrowKey::~U4DMacArrowKey(){
        
        delete stateManager;
    }
    
    KEYBOARDELEMENT U4DMacArrowKey::getKeyboardElementType(){
        
        return padElementType;
        
    }
    
    void U4DMacArrowKey::setDataMagnitude(float uValue){
        
        dataMagnitude=uValue;
        
    }
    
    float U4DMacArrowKey::getDataMagnitude(){
        
        return dataMagnitude;
        
    }
    
    void U4DMacArrowKey::update(double dt){
        
        stateManager->update(dt);
        
    }
    
    void U4DMacArrowKey::action(){
        
        pCallback->action();
    }
    
    
    void U4DMacArrowKey::changeState(KEYBOARDACTION &uKeyboardAction, const U4DVector2n &uPadAxis){
        
        if (uKeyboardAction==U4DEngine::macArrowKeyActive) {
            
            padAxis=uPadAxis;
            
            stateManager->changeState(U4DMacArrowKeyActiveState::sharedInstance());
            
        }else if(uKeyboardAction==U4DEngine::macArrowKeyReleased && (stateManager->getCurrentState()==U4DMacArrowKeyActiveState::sharedInstance())){
            
            padAxis=U4DVector2n(0.0,0.0);
            
            stateManager->changeState(U4DMacArrowKeyReleasedState::sharedInstance());
            
        }
        
    }
    
    
    void U4DMacArrowKey::setDataPosition(U4DVector3n uData){
        
        dataPosition=uData;
    }
    
    U4DVector3n U4DMacArrowKey::getDataPosition(){
        
        return dataPosition;
    }
    
    bool U4DMacArrowKey::getIsActive(){
        
        return (stateManager->getCurrentState()==U4DMacArrowKeyActiveState::sharedInstance());;
    }
    
    void U4DMacArrowKey::setCallbackAction(U4DCallbackInterface *uAction){
        
        //set the callback
        pCallback=uAction;
        
    }
    
    void U4DMacArrowKey::setControllerInterface(U4DControllerInterface* uControllerInterface){
        
        controllerInterface=uControllerInterface;
        
    }
    
    bool U4DMacArrowKey::getDirectionReversal(){
        
        return directionReversal;
        
    }
    
}

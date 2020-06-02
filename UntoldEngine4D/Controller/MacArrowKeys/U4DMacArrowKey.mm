//
//  U4DMacArrowKey.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/5/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
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
    
    
    U4DMacArrowKey::U4DMacArrowKey(INPUTELEMENTTYPE uInputElementType, U4DControllerInterface* uControllerInterface):U4DInputElement(uInputElementType,uControllerInterface),isActive(false),directionReversal(false),dataPosition(0.0,0.0),dataMagnitude(0.0),padAxis(0.0,0.0){
        
        stateManager=new U4DMacArrowKeyStateManager(this);
        
        inputElementType=uInputElementType;
        
        //set initial state
        stateManager->changeState(U4DMacArrowKeyIdleState::sharedInstance());
        
    }
    
    U4DMacArrowKey::~U4DMacArrowKey(){
        
        delete stateManager;
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
        
        //notify the game model
            
        CONTROLLERMESSAGE controllerMessage;
    
        controllerMessage.inputElementType=inputElementType;
    
        if (getIsActive()) {
            
            controllerMessage.inputElementAction=U4DEngine::macArrowKeyActive;
            
            //send the data position
            controllerMessage.arrowKeyDirection=dataPosition;
            
        }else{
    
            controllerMessage.inputElementAction=U4DEngine::macArrowKeyReleased;
        
        }
    
        controllerInterface->sendUserInputUpdate(&controllerMessage);
        
    }
    
    
    void U4DMacArrowKey::changeState(INPUTELEMENTACTION &uInputAction, U4DVector2n &uPosition){
        
        if (uInputAction==U4DEngine::macArrowKeyActive) {
            
            padAxis=uPosition;
            
            stateManager->changeState(U4DMacArrowKeyActiveState::sharedInstance());
            
        }else if(uInputAction==U4DEngine::macArrowKeyReleased && (stateManager->getCurrentState()==U4DMacArrowKeyActiveState::sharedInstance())){
            
            padAxis=U4DVector2n(0.0,0.0);
            
            stateManager->changeState(U4DMacArrowKeyReleasedState::sharedInstance());
            
        }
        
    }
    
    
    void U4DMacArrowKey::setDataPosition(U4DVector2n uData){
        
        dataPosition=uData;
    }
    
    U4DVector2n U4DMacArrowKey::getDataPosition(){
        
        return dataPosition;
    }
    
    bool U4DMacArrowKey::getIsActive(){
        
        return (stateManager->getCurrentState()==U4DMacArrowKeyActiveState::sharedInstance());;
    }
    
    bool U4DMacArrowKey::getDirectionReversal(){
        
        return directionReversal;
        
    }
    
}

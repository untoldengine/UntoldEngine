//
//  U4DMacMouse.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DMacMouse.h"
#include "U4DDirector.h"
#include "U4DControllerInterface.h"
#include "U4DMacMouseStateManager.h"
#include "U4DMacMouseIdleState.h"
#include "U4DMacMousePressedState.h"
#include "U4DMacMouseDraggedState.h"
#include "U4DMacMouseMovedState.h"
#include "U4DMacMouseDeltaMovedState.h"
#include "U4DMacMouseExitedState.h"
#include "U4DMacMouseReleasedState.h"
#include "CommonProtocols.h"
#include "U4DVector2n.h"

namespace U4DEngine {
    
    
U4DMacMouse::U4DMacMouse(INPUTELEMENTTYPE uInputElementType, U4DControllerInterface* uControllerInterface):U4DInputElement(uInputElementType,uControllerInterface),isActive(false),directionReversal(false),dataPosition(0.0,0.0),dataMagnitude(0.0),previousDataPosition(0.0,0.0),dataDeltaPosition(0.0, 0.0),previousDataDeltaPosition(0.0, 0.0){
        
        stateManager=new U4DMacMouseStateManager(this);
        
        //set initial state
        stateManager->changeState(U4DMacMouseIdleState::sharedInstance());
        
    }
    
    U4DMacMouse::~U4DMacMouse(){
        
        delete stateManager;
    }
    
    
    void U4DMacMouse::setDataMagnitude(float uValue){
        
        dataMagnitude=uValue;
        
    }
    
    float U4DMacMouse::getDataMagnitude(){
        
        return dataMagnitude;
        
    }
    
    void U4DMacMouse::update(double dt){
        
        stateManager->update(dt);
        
    }
    
    void U4DMacMouse::action(){
        
    //notify the game model
        
        CONTROLLERMESSAGE controllerMessage;
    
        controllerMessage.inputElementType=inputElementType;
    
        if (getIsPressed()) {
    
            controllerMessage.inputElementAction=U4DEngine::mouseButtonPressed;
    
        }else if(getIsReleased()){
    
            controllerMessage.inputElementAction=U4DEngine::mouseButtonReleased;
        
        //Dragged has not been implemented here
        
        }else if(getIsMoving()) {
        
                controllerMessage.inputElementAction=U4DEngine::mouseActive;

        }

        controllerMessage.mousePosition=getDataPosition();

        controllerMessage.previousMousePosition=getPreviousDataPosition();

        controllerMessage.mouseDeltaPosition=getDataDeltaPosition();
        
        controllerInterface->sendUserInputUpdate(&controllerMessage);
        
    }
    
    
    void U4DMacMouse::changeState(INPUTELEMENTACTION &uInputAction, U4DVector2n &uPosition){
        
        
        if (uInputAction==U4DEngine::mouseButtonPressed) {
            
            dataPosition=mapMousePosition(uPosition);
            
            stateManager->changeState(U4DMacMousePressedState::sharedInstance());
            
        }else if (uInputAction==U4DEngine::mouseButtonDragged) {
            
            dataPosition=uPosition;
            
            stateManager->changeState(U4DMacMouseDraggedState::sharedInstance());
            
        }else if(uInputAction==U4DEngine::mouseButtonReleased && ((stateManager->getCurrentState()==U4DMacMouseDraggedState::sharedInstance()) || (stateManager->getCurrentState()==U4DMacMousePressedState::sharedInstance()))){
            
            dataPosition=mapMousePosition(uPosition);
            
            stateManager->changeState(U4DMacMouseReleasedState::sharedInstance());
            
        }else if(uInputAction==U4DEngine::mouseActive){
            
            dataPosition=mapMousePosition(uPosition);
            
            stateManager->changeState(U4DMacMouseMovedState::sharedInstance());
            
            
        }else if(uInputAction==U4DEngine::mouseInactive){
            
            dataPosition=uPosition;
            
            stateManager->changeState(U4DMacMouseExitedState::sharedInstance());
            
        }else if (uInputAction==U4DEngine::mouseActiveDelta) {
            
            dataDeltaPosition=uPosition;

            stateManager->changeState(U4DMacMouseDeltaMovedState::sharedInstance());
            
        }
        
    }

    U4DVector2n U4DMacMouse::mapMousePosition(U4DVector2n &uPosition){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        U4DVector2n mapPosition;
        
        //map the location of the mouse cursor to the right space-non deltas
        float height=director->getDisplayHeight();
        float width=director->getDisplayWidth();
        
        mapPosition.x=(uPosition.x-width/2)/(width/2);
        mapPosition.y=(uPosition.y-height/2)/(height/2);
        
        return mapPosition;
        
    }
    
    
    void U4DMacMouse::setDataPosition(U4DVector2n uData){
        
        dataPosition=uData;
    }
    
    U4DVector2n U4DMacMouse::getDataPosition(){
        
        return dataPosition;
    }
    
    U4DVector2n U4DMacMouse::getDataDeltaPosition(){
        
        return dataDeltaPosition;
    }
    
    U4DVector2n U4DMacMouse::getPreviousDataPosition(){
        return previousDataPosition;
    }
    
    bool U4DMacMouse::getIsDragged(){
        
        return (stateManager->getCurrentState()==U4DMacMouseDraggedState::sharedInstance());;
    }
    
    bool U4DMacMouse::getIsPressed(){
        
        return (stateManager->getCurrentState()==U4DMacMousePressedState::sharedInstance());
        
    }
    
    bool U4DMacMouse::getIsReleased(){
        
        return (stateManager->getCurrentState()==U4DMacMouseReleasedState::sharedInstance());
        
    }
    
    bool U4DMacMouse::getDirectionReversal(){
        
        return directionReversal;
        
    }
    
    bool U4DMacMouse::getIsMoving(){
        
        return (stateManager->getCurrentState()==U4DMacMouseMovedState::sharedInstance() || stateManager->getCurrentState()==U4DMacMouseDeltaMovedState::sharedInstance());
        
    }
    
    U4DMacMouseStateManager *U4DMacMouse::getStateManager(){
        return stateManager;
    }
    
}

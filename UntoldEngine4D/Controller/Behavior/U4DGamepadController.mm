//
//  U4DGamepadController.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/7/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#include "U4DGamepadController.h"
#include "U4DGameModelInterface.h"
#include "U4DWorld.h"

namespace U4DEngine {
    
    //constructor
    U4DGamepadController::U4DGamepadController():receivedAction(false){}
    
    //destructor
    U4DGamepadController::~U4DGamepadController(){}
    
    void U4DGamepadController::setGameWorld(U4DWorld *uGameWorld){
        
        gameWorld=uGameWorld;
        
    }
    
    
    void U4DGamepadController::setGameModel(U4DGameModelInterface *uGameModel){
        
        gameModel=uGameModel;
        
    }
    
    U4DWorld* U4DGamepadController::getGameWorld(){
        
        return gameWorld;
    }
    
    U4DGameModelInterface* U4DGamepadController::getGameModel(){
        
        return gameModel;
    }
    
    void U4DGamepadController::padPressBegan(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction){
        
        //dummy axis
        U4DPadAxis padAxis(0.0,0.0);
        
        changeState(uGamePadElement, uGamePadAction, padAxis);
    }
    
    void U4DGamepadController::padPressEnded(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction){
        
        //dummy axis
        U4DPadAxis padAxis(0.0,0.0);
        
        changeState(uGamePadElement, uGamePadAction, padAxis);
        
    }
    
    void U4DGamepadController::padThumbStickMoved(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis){
        
        changeState(uGamePadElement, uGamePadAction, uPadAxis);
    }
    
    void U4DGamepadController::changeState(GAMEPADELEMENT &uGamePadElement, GAMEPADACTION &uGamePadAction, const U4DPadAxis &uPadAxis){
        
        U4DEntity *child=gameWorld;
        
        //change the state of the controller input
        while (child!=NULL) {
            
            if (child->getEntityType()==CONTROLLERINPUT && child->getPadElementType()==uGamePadElement) {
                
                child->changeState(uGamePadAction, uPadAxis);
                
            }
            
            child=child->next;
            
        }
        
    }
    
    void U4DGamepadController::sendUserInputUpdate(void *uData){
        
        gameModel->receiveUserInputUpdate(uData);
    }
    
    void U4DGamepadController::setReceivedAction(bool uValue){
        
        receivedAction=uValue;
    }
    
}

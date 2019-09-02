//
//  U4DKeyboardInput.cpp
//  MVCTemplate
//
//  Created by Harold Serrano on 4/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DKeyboardController.h"

#include "U4DGameModelInterface.h"
#include "U4DWorld.h"

namespace U4DEngine {
    
    //constructor
    U4DKeyboardController::U4DKeyboardController():receivedAction(false){}
    
    //destructor
    U4DKeyboardController::~U4DKeyboardController(){}
    
    void U4DKeyboardController::setGameWorld(U4DWorld *uGameWorld){
        
        gameWorld=uGameWorld;
        
    }
    
    void U4DKeyboardController::macKeyPressBegan(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction){
        
        //dummy axis
        U4DVector2n padAxis(0.0,0.0);
        
        changeState(uKeyboardElement, uKeyboardAction, padAxis);
    }
    
    void U4DKeyboardController::macKeyPressEnded(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction){
        
        //dummy axis
        U4DVector2n padAxis(0.0,0.0);
        
        changeState(uKeyboardElement, uKeyboardAction, padAxis);
    }
    
    void U4DKeyboardController::macArrowKeyActive(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction, U4DVector2n & uPadAxis){
        
        changeState(uKeyboardElement, uKeyboardAction, uPadAxis);
    }
    
    void U4DKeyboardController::macMousePressBegan(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){
        
        changeState(uMouseElement, uMouseAction, uMouseAxis);
    }
    
    void U4DKeyboardController::macMousePressEnded(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction){
        
        //dummy axis
        U4DVector2n mouseAxis(0.0,0.0);
        
        changeState(uMouseElement, uMouseAction, mouseAxis);
    }
    
    void U4DKeyboardController::macMouseDragged(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){
        
        changeState(uMouseElement, uMouseAction, uMouseAxis);
        
    }
    
    void U4DKeyboardController::macMouseMoved(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){
        
        changeState(uMouseElement, uMouseAction, uMouseAxis);
        
    }
    
    void U4DKeyboardController::macMouseDeltaMoved(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n &uMouseDelta){
        
        changeState(uMouseElement, uMouseAction, uMouseDelta);
    }
    
    void U4DKeyboardController::macMouseExited(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){
        
        changeState(uMouseElement, uMouseAction, uMouseAxis);
        
    }
    
    void U4DKeyboardController::setGameModel(U4DGameModelInterface *uGameModel){
        
        gameModel=uGameModel;
        
    }
    
    U4DWorld* U4DKeyboardController::getGameWorld(){
        
        return gameWorld;
    }
    
    U4DGameModelInterface* U4DKeyboardController::getGameModel(){
        
        return gameModel;
    }
    
    void U4DKeyboardController::changeState(KEYBOARDELEMENT &uKeyboardElement, KEYBOARDACTION &uKeyboardAction, U4DVector2n & uPadAxis){
        
        U4DEntity *child=gameWorld;
        
        //change the state of the controller input
        while (child!=NULL) {

            if (child->getEntityType()==CONTROLLERINPUT && child->getKeyboardElementType()==uKeyboardElement) {

                child->changeState(uKeyboardAction, uPadAxis);

            }

            child=child->next;

        }
        
    }
    
    void U4DKeyboardController::changeState(MOUSEELEMENT &uMouseElement, MOUSEACTION &uMouseAction, U4DVector2n & uMouseAxis){
        
        U4DEntity *child=gameWorld;
        
        //change the state of the controller input
        while (child!=NULL) {
            
            if (child->getEntityType()==CONTROLLERINPUT && child->getMouseElementType()==uMouseElement) {
                
                child->changeState(uMouseAction, uMouseAxis);
                
            }
            
            child=child->next;
            
        }
        
    }
    
    void U4DKeyboardController::sendUserInputUpdate(void *uData){
        
        gameModel->receiveUserInputUpdate(uData);
    }
    
    void U4DKeyboardController::setReceivedAction(bool uValue){
        
        receivedAction=uValue;
    }
    
}

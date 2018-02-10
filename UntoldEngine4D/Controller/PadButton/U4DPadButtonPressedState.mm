//
//  U4DPadButtonPressedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/8/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#include "U4DPadButtonPressedState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DPadButtonPressedState* U4DPadButtonPressedState::instance=0;
    
    U4DPadButtonPressedState::U4DPadButtonPressedState(){
        
    }
    
    U4DPadButtonPressedState::~U4DPadButtonPressedState(){
        
    }
    
    U4DPadButtonPressedState* U4DPadButtonPressedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DPadButtonPressedState();
        }
        
        return instance;
        
    }
    
    void U4DPadButtonPressedState::enter(U4DPadButton *uPadButton){
         
        if (uPadButton->pCallback!=NULL) {
            uPadButton->action();
        }
        
        
        if (uPadButton->controllerInterface !=NULL) {
            uPadButton->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DPadButtonPressedState::execute(U4DPadButton *uPadButton, double dt){
        
        
    }
    
    void U4DPadButtonPressedState::exit(U4DPadButton *uPadButton){
        
    }
    
}
